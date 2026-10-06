package system

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"golang.org/x/sys/windows/registry"
)

// ConfigureFirefoxPolicies sets user-scoped policies; Firefox applies them on its next launch.
func (rm *RegistryManager) ConfigureFirefoxPolicies() error {
	const path = `Software\Policies\Mozilla\Firefox`
	key, _, err := registry.CreateKey(registry.CURRENT_USER, path, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("create HKCU\\%s: %w", path, err)
	}
	defer key.Close()

	existing := "{}"
	values, typ, err := key.GetStringsValue("ExtensionSettings")
	switch {
	case err == nil:
		existing = strings.Join(values, "\n")
	case errors.Is(err, registry.ErrNotExist):
	case errors.Is(err, registry.ErrUnexpectedType) && typ == registry.SZ:
		existing, _, err = key.GetStringValue("ExtensionSettings")
		if err != nil {
			return fmt.Errorf("read HKCU\\%s\\ExtensionSettings: %w", path, err)
		}
	default:
		return fmt.Errorf("read HKCU\\%s\\ExtensionSettings (type %d): %w", path, typ, err)
	}
	merged, err := mergeFirefoxExtensionSettings(existing)
	if err != nil {
		return fmt.Errorf("HKCU\\%s\\ExtensionSettings: %w", path, err)
	}
	if err := key.SetStringsValue("ExtensionSettings", []string{merged}); err != nil {
		return fmt.Errorf("set HKCU\\%s\\ExtensionSettings: %w", path, err)
	}

	for _, name := range []string{"OverrideFirstRunPage", "OverridePostUpdatePage"} {
		if err := key.SetStringValue(name, ""); err != nil {
			return fmt.Errorf("set HKCU\\%s\\%s: %w", path, name, err)
		}
	}
	for _, name := range []string{"DontCheckDefaultBrowser", "BlockAboutConfig", "DisableSetDesktopBackground"} {
		if err := key.SetDWordValue(name, 1); err != nil {
			return fmt.Errorf("set HKCU\\%s\\%s: %w", path, name, err)
		}
	}

	homepagePath := path + `\Homepage`
	homepage, _, err := registry.CreateKey(registry.CURRENT_USER, homepagePath, registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("create HKCU\\%s: %w", homepagePath, err)
	}
	defer homepage.Close()
	for _, setting := range []struct{ name, value string }{
		{"URL", "https://duckduckgo.com/"},
		{"StartPage", "homepage-locked"},
	} {
		if err := homepage.SetStringValue(setting.name, setting.value); err != nil {
			return fmt.Errorf("set HKCU\\%s\\%s: %w", homepagePath, setting.name, err)
		}
	}
	if err := homepage.SetDWordValue("Locked", 1); err != nil {
		return fmt.Errorf("set HKCU\\%s\\Locked: %w", homepagePath, err)
	}

	searchPath := path + `\SearchEngines`
	search, _, err := registry.CreateKey(registry.CURRENT_USER, searchPath, registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("create HKCU\\%s: %w", searchPath, err)
	}
	defer search.Close()
	if err := search.SetStringValue("Default", "DuckDuckGo"); err != nil {
		return fmt.Errorf("set HKCU\\%s\\Default: %w", searchPath, err)
	}
	return nil
}

func mergeFirefoxExtensionSettings(existing string) (string, error) {
	var settings map[string]map[string]json.RawMessage
	if err := json.Unmarshal([]byte(existing), &settings); err != nil {
		return "", fmt.Errorf("parse existing JSON: %w", err)
	}
	if settings == nil {
		return "", errors.New("existing JSON must be an object")
	}
	if _, wrapped := settings["policies"]; wrapped {
		return "", errors.New("existing JSON must not contain a policies wrapper")
	}
	for id, entry := range settings {
		if entry == nil {
			return "", fmt.Errorf("existing extension %q must be an object", id)
		}
	}
	const extensionID = "uBlock0@raymondhill.net"
	if settings[extensionID] == nil {
		settings[extensionID] = make(map[string]json.RawMessage)
	}
	settings[extensionID]["installation_mode"] = json.RawMessage(`"force_installed"`)
	settings[extensionID]["install_url"] = json.RawMessage(`"https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"`)
	merged, err := json.Marshal(settings)
	if err != nil {
		return "", fmt.Errorf("encode ExtensionSettings: %w", err)
	}
	return string(merged), nil
}
