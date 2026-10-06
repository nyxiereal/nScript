package system

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"golang.org/x/sys/windows/registry"
)

// ConfigureChromePolicies sets per-user Chrome policies for the next browser launch.
// Machine and organization policies may take precedence over these user policies.
func (rm *RegistryManager) ConfigureChromePolicies() error {
	localAppData := os.Getenv("LOCALAPPDATA")
	if !filepath.IsAbs(localAppData) {
		return fmt.Errorf("LOCALAPPDATA must be an absolute path to create the Chrome First Run sentinel")
	}

	const (
		chromeKey   = `Software\Policies\Google\Chrome`
		extensionID = "ddkjiahejlhfcafbddmgiahcphecmpfh"
		installURL  = extensionID + ";https://clients2.google.com/service/update2/crx"
		homepage    = "https://duckduckgo.com/"
	)

	forcePath := chromeKey + `\ExtensionInstallForcelist`
	force, _, err := registry.CreateKey(registry.CURRENT_USER, forcePath, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("open HKCU\\%s: %w", forcePath, err)
	}
	defer force.Close()

	names, err := force.ReadValueNames(-1)
	if err != nil {
		return fmt.Errorf("read HKCU\\%s values: %w", forcePath, err)
	}
	occupied := make(map[int]bool, len(names))
	slot := ""
	for _, name := range names {
		n, err := strconv.Atoi(name)
		if err != nil || n < 1 {
			continue
		}
		occupied[n] = true
		value, _, err := force.GetStringValue(name)
		if err != nil {
			return fmt.Errorf("read HKCU\\%s\\%s: %w", forcePath, name, err)
		}
		if value == extensionID || strings.HasPrefix(value, extensionID+";") {
			slot = name
		}
	}
	if slot == "" {
		for n := 1; ; n++ {
			if !occupied[n] {
				slot = strconv.Itoa(n)
				break
			}
		}
	}
	if err := force.SetStringValue(slot, installURL); err != nil {
		return fmt.Errorf("set HKCU\\%s\\%s: %w", forcePath, slot, err)
	}

	startupPath := chromeKey + `\RestoreOnStartupURLs`
	startup, _, err := registry.CreateKey(registry.CURRENT_USER, startupPath, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("open HKCU\\%s: %w", startupPath, err)
	}
	defer startup.Close()

	urls, err := startup.ReadValueNames(-1)
	if err != nil {
		return fmt.Errorf("read HKCU\\%s values: %w", startupPath, err)
	}
	for _, name := range urls {
		if err := startup.DeleteValue(name); err != nil {
			return fmt.Errorf("delete HKCU\\%s\\%s: %w", startupPath, name, err)
		}
	}
	if err := startup.SetStringValue("1", homepage); err != nil {
		return fmt.Errorf("set HKCU\\%s\\1: %w", startupPath, err)
	}

	chrome, _, err := registry.CreateKey(registry.CURRENT_USER, chromeKey, registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("open HKCU\\%s: %w", chromeKey, err)
	}
	defer chrome.Close()
	for _, policy := range []struct{ name, value string }{
		{"HomepageLocation", homepage},
		{"DefaultSearchProviderName", "DuckDuckGo"},
		{"DefaultSearchProviderKeyword", "duckduckgo.com"},
		{"DefaultSearchProviderSearchURL", "https://duckduckgo.com/?q={searchTerms}"},
	} {
		if err := chrome.SetStringValue(policy.name, policy.value); err != nil {
			return fmt.Errorf("set HKCU\\%s\\%s: %w", chromeKey, policy.name, err)
		}
	}
	for _, policy := range []struct {
		name  string
		value uint32
	}{
		{"HomepageIsNewTabPage", 0},
		{"ShowHomeButton", 1},
		{"RestoreOnStartup", 4},
		{"DefaultSearchProviderEnabled", 1},
		{"PromotionsEnabled", 0},
		{"NTPCustomBackgroundEnabled", 0},
	} {
		if err := chrome.SetDWordValue(policy.name, policy.value); err != nil {
			return fmt.Errorf("set HKCU\\%s\\%s: %w", chromeKey, policy.name, err)
		}
	}

	extensionPath := chromeKey + `\3rdparty\extensions\` + extensionID + `\policy`
	extension, _, err := registry.CreateKey(registry.CURRENT_USER, extensionPath, registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("open HKCU\\%s: %w", extensionPath, err)
	}
	defer extension.Close()
	if err := extension.SetDWordValue("disableFirstRunPage", 1); err != nil {
		return fmt.Errorf("set HKCU\\%s\\disableFirstRunPage: %w", extensionPath, err)
	}

	userData := filepath.Join(localAppData, "Google", "Chrome", "User Data")
	if err := os.MkdirAll(userData, 0755); err != nil {
		return fmt.Errorf("create Chrome user data directory %s: %w", userData, err)
	}
	sentinel := filepath.Join(userData, "First Run")
	file, err := os.OpenFile(sentinel, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0644)
	if os.IsExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("create Chrome First Run sentinel %s: %w", sentinel, err)
	}
	if err := file.Close(); err != nil {
		return fmt.Errorf("close Chrome First Run sentinel %s: %w", sentinel, err)
	}
	return nil
}
