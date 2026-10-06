package system

import (
	"encoding/json"
	"testing"
)

func TestMergeFirefoxExtensionSettings(t *testing.T) {
	merged, err := mergeFirefoxExtensionSettings(`{"*":{"installation_mode":"blocked"},"other@example.org":{"installation_mode":"allowed"},"uBlock0@raymondhill.net":{"private_browsing":true}}`)
	if err != nil {
		t.Fatal(err)
	}
	var entries map[string]map[string]json.RawMessage
	if err := json.Unmarshal([]byte(merged), &entries); err != nil {
		t.Fatal(err)
	}
	if string(entries["*"]["installation_mode"]) != `"blocked"` ||
		string(entries["other@example.org"]["installation_mode"]) != `"allowed"` ||
		string(entries["uBlock0@raymondhill.net"]["private_browsing"]) != `true` ||
		string(entries["uBlock0@raymondhill.net"]["installation_mode"]) != `"force_installed"` ||
		string(entries["uBlock0@raymondhill.net"]["install_url"]) != `"https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"` {
		t.Fatalf("unexpected merged settings: %s", merged)
	}
	for _, invalid := range []string{`null`, `[]`, `{"*":null}`, `{"*":"blocked"}`, `{"policies":{"ExtensionSettings":{}}}`} {
		if _, err := mergeFirefoxExtensionSettings(invalid); err == nil {
			t.Errorf("accepted invalid settings: %s", invalid)
		}
	}
}
