package system

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"golang.org/x/sys/windows/registry"
)

// RegistryManager handles Windows registry operations with backup functionality
type RegistryManager struct {
	backupDir string
}

// NewRegistryManager creates a new registry manager
func NewRegistryManager() *RegistryManager {
	backupDir := filepath.Join(os.Getenv("TEMP"), "nScript_registry_backup")
	os.MkdirAll(backupDir, 0755)

	return &RegistryManager{
		backupDir: backupDir,
	}
}

// BackupKey creates a backup of a registry key before deletion
func (rm *RegistryManager) BackupKey(root registry.Key, path string) error {
	if path == "" {
		return errors.New("registry path cannot be empty")
	}

	timestamp := time.Now().Format("20060102_150405")
	backupFile := filepath.Join(rm.backupDir, fmt.Sprintf("%s_%s.backup", strings.ReplaceAll(path, "\\", "_"), timestamp))

	// Create backup file
	file, err := os.Create(backupFile)
	if err != nil {
		return fmt.Errorf("failed to create backup file: %v", err)
	}
	defer file.Close()

	// Write registry path info
	file.WriteString(fmt.Sprintf("Registry Key Backup\n"))
	file.WriteString(fmt.Sprintf("Path: %s\n", path))
	file.WriteString(fmt.Sprintf("Root: %v\n", root))
	file.WriteString(fmt.Sprintf("Timestamp: %s\n", time.Now().String()))
	file.WriteString("---\n")

	// Try to backup key values
	key, err := registry.OpenKey(root, path, registry.QUERY_VALUE|registry.ENUMERATE_SUB_KEYS)
	if err != nil {
		file.WriteString(fmt.Sprintf("Key not accessible: %v\n", err))
		return nil // Key doesn't exist or not accessible - that's ok for backup
	}
	defer key.Close()

	// Backup values
	valueNames, err := key.ReadValueNames(-1)
	if err == nil {
		file.WriteString("Values:\n")
		for _, valueName := range valueNames {
			val, _, err := key.GetValue(valueName, nil)
			if err == nil {
				file.WriteString(fmt.Sprintf("  %s = %v\n", valueName, val))
			}
		}
	}

	// Backup subkeys
	subkeyNames, err := key.ReadSubKeyNames(-1)
	if err == nil {
		file.WriteString("Subkeys:\n")
		for _, subkeyName := range subkeyNames {
			file.WriteString(fmt.Sprintf("  %s\n", subkeyName))
		}
	}

	return nil
}

// DeleteKeyWithBackup safely deletes a registry key after backing it up
func (rm *RegistryManager) DeleteKeyWithBackup(root registry.Key, path string) error {
	if path == "" {
		return errors.New("registry path cannot be empty")
	}

	// Create backup first
	if err := rm.BackupKey(root, path); err != nil {
		return fmt.Errorf("backup failed: %v", err)
	}

	// Delete the key
	return rm.DeleteKeyRecursive(root, path)
}

// DeleteKeyRecursive recursively deletes a registry key with improved error handling
func (rm *RegistryManager) DeleteKeyRecursive(root registry.Key, path string) error {
	if path == "" {
		return errors.New("registry path cannot be empty")
	}

	key, err := registry.OpenKey(root, path, registry.ENUMERATE_SUB_KEYS|registry.SET_VALUE)
	if err != nil {
		// Key doesn't exist - that's fine
		if err == registry.ErrNotExist {
			return nil
		}
		return fmt.Errorf("failed to open key %s: %v", path, err)
	}

	// Get all subkeys
	subkeys, err := key.ReadSubKeyNames(-1)
	key.Close()

	if err == nil {
		// Recursively delete subkeys
		for _, subkey := range subkeys {
			subkeyPath := path + `\` + subkey
			if err := rm.DeleteKeyRecursive(root, subkeyPath); err != nil {
				// Log error but continue with other subkeys
				fmt.Printf("[-] Failed to delete subkey %s: %v\n", subkeyPath, err)
			}
		}
	}

	// Delete the key itself
	err = registry.DeleteKey(root, path)
	if err != nil && err != registry.ErrNotExist {
		return fmt.Errorf("failed to delete key %s: %v", path, err)
	}

	return nil
}

// ClearQuickAccessRecent clears File Explorer Quick Access with backup
func (rm *RegistryManager) ClearQuickAccessRecent() error {
	fmt.Println("[*] Clearing File Explorer Quick Access recent files...")

	// Registry keys to clear
	registryKeys := []string{
		`Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs`,
		`Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths`,
		`Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU`,
	}

	for _, regPath := range registryKeys {
		if err := rm.DeleteKeyWithBackup(registry.CURRENT_USER, regPath); err != nil {
			fmt.Printf("[-] Failed to clear %s: %v\n", regPath, err)
		}
	}

	// Clear file system locations
	userHome := os.Getenv("APPDATA")

	locations := []string{
		filepath.Join(userHome, "Microsoft", "Windows", "Recent", "AutomaticDestinations"),
		filepath.Join(userHome, "Microsoft", "Windows", "Recent", "CustomDestinations"),
	}

	for _, location := range locations {
		if entries, err := os.ReadDir(location); err == nil {
			for _, entry := range entries {
				if err := os.Remove(filepath.Join(location, entry.Name())); err != nil {
					fmt.Printf("[-] Failed to remove %s: %v\n", entry.Name(), err)
				}
			}
		}
	}

	fmt.Println("[+] File Explorer Quick Access cleared")
	return nil
}

// ClearExplorerUserAssist clears Explorer UserAssist data with backup
func (rm *RegistryManager) ClearExplorerUserAssist() error {
	fmt.Println("[*] Clearing Explorer UserAssist data (registry)...")
	regPath := `Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist`

	// Get subkeys to delete
	key, err := registry.OpenKey(registry.CURRENT_USER, regPath, registry.ENUMERATE_SUB_KEYS)
	if err != nil {
		return fmt.Errorf("could not open UserAssist key: %v", err)
	}
	defer key.Close()

	subkeys, err := key.ReadSubKeyNames(-1)
	if err != nil {
		return fmt.Errorf("failed to read subkeys: %v", err)
	}

	for _, sub := range subkeys {
		fullPath := regPath + `\` + sub
		if err := rm.DeleteKeyWithBackup(registry.CURRENT_USER, fullPath); err != nil {
			fmt.Printf("[-] Failed to delete UserAssist subkey %s: %v\n", fullPath, err)
		}
	}

	fmt.Println("[+] Explorer UserAssist data cleared")
	return nil
}

// ClearComDlgMRU clears common Open/Save dialog MRU entries with backup
func (rm *RegistryManager) ClearComDlgMRU() error {
	fmt.Println("[*] Clearing common Open/Save dialog MRU entries (ComDlg32)...")

	keys := []string{
		`Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU`,
		`Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU`,
		`Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU`,
	}

	for _, k := range keys {
		if err := rm.DeleteKeyWithBackup(registry.CURRENT_USER, k); err != nil {
			fmt.Printf("[-] Failed to clear %s: %v\n", k, err)
		}
	}

	fmt.Println("[+] ComDlg32 MRU entries cleared")
	return nil
}

// ClearStartMenuRegistry clears Start Menu registry entries with backup
func (rm *RegistryManager) ClearStartMenuRegistry() error {
	fmt.Println("[*] Clearing Start Menu registry entries...")
	regPath := `Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount`

	key, err := registry.OpenKey(registry.CURRENT_USER, regPath, registry.ENUMERATE_SUB_KEYS)
	if err != nil {
		return fmt.Errorf("could not open CloudStore key: %v", err)
	}
	defer key.Close()

	subkeys, err := key.ReadSubKeyNames(-1)
	if err != nil {
		return fmt.Errorf("failed to read subkeys: %v", err)
	}

	// Delete subkeys that contain start menu related data
	for _, subkey := range subkeys {
		lowerSubkey := strings.ToLower(subkey)
		if strings.Contains(lowerSubkey, "start.tilegrid") ||
			strings.Contains(lowerSubkey, "windows.data.placeholdertilecollection") ||
			strings.Contains(lowerSubkey, "microsoft.windows.startmenuexperiencehost") {

			fullPath := regPath + `\` + subkey
			if err := rm.DeleteKeyWithBackup(registry.CURRENT_USER, fullPath); err != nil {
				fmt.Printf("[-] Failed to delete Start Menu registry key %s: %v\n", fullPath, err)
			}
		}
	}

	fmt.Println("[+] Start Menu registry cache cleared")
	return nil
}

// EnableDarkMode enables Windows dark mode through registry
func (rm *RegistryManager) EnableDarkMode() error {
	regPath := `Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`

	key, err := registry.OpenKey(registry.CURRENT_USER, regPath, registry.ALL_ACCESS)
	if err != nil {
		// Create the key if it doesn't exist
		key, _, err = registry.CreateKey(registry.CURRENT_USER, regPath, registry.ALL_ACCESS)
		if err != nil {
			return fmt.Errorf("failed to create/open Personalize key: %v", err)
		}
	}
	defer key.Close()

	// Set dark mode values
	values := map[string]uint32{
		"SystemUsesLightTheme": 0,
		"AppsUseLightTheme":    0,
		"ForceDarkMode":        1,
	}

	for name, value := range values {
		if err := key.SetDWordValue(name, value); err != nil {
			return fmt.Errorf("failed to set %s: %v", name, err)
		}
	}

	return nil
}

// GetBackupDirectory returns the backup directory path
func (rm *RegistryManager) GetBackupDirectory() string {
	return rm.backupDir
}
