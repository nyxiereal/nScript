package cleanup

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"nScript/internal/system"
)

// WindowsCleaner handles Windows-specific cleanup operations
type WindowsCleaner struct {
	registryManager *system.RegistryManager
	processManager  *system.ProcessManager
}

// NewWindowsCleaner creates a new Windows-specific cleaner
func NewWindowsCleaner() *WindowsCleaner {
	return &WindowsCleaner{
		registryManager: system.NewRegistryManager(),
		processManager:  system.NewProcessManager(),
	}
}

// ClearStartMenuTiles clears Start Menu tiles with improved safety
func (wc *WindowsCleaner) ClearStartMenuTiles() error {
	fmt.Println("[*] Unpinning all Start Menu tiles...")

	major, _, build, err := system.GetWindowsVersion()
	if err != nil {
		return fmt.Errorf("failed to get Windows version: %v", err)
	}

	userHome := os.Getenv("LOCALAPPDATA")
	if userHome == "" {
		return fmt.Errorf("LOCALAPPDATA environment variable not set")
	}

	// Stop Start Menu process
	if err := wc.processManager.KillProcess("StartMenuExperienceHost.exe", true); err != nil {
		fmt.Printf("[-] Warning: Failed to stop Start Menu process: %v\n", err)
	}
	time.Sleep(1 * time.Second)

	// Method 1: Delete the Start Menu database directly
	fmt.Println("[*] Clearing Start Menu database...")
	startDbPath := filepath.Join(userHome, "Packages", "Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy", "LocalState")
	if _, err := os.Stat(startDbPath); err == nil {
		dbFiles := []string{
			filepath.Join(startDbPath, "start.db"),
			filepath.Join(startDbPath, "start.db-journal"),
		}

		for _, dbFile := range dbFiles {
			if err := os.Remove(dbFile); err == nil && strings.HasSuffix(dbFile, "start.db") {
				fmt.Println("[+] Removed Start Menu database")
			}
		}
	}

	// Method 2: Clear TileDataLayer database
	fmt.Println("[*] Clearing TileDataLayer...")
	tileDataPath := filepath.Join(userHome, "Packages", "Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy", "TileDataLayer")
	if _, err := os.Stat(tileDataPath); err == nil {
		wc.processManager.KillProcess("StartMenuExperienceHost.exe", true)
		time.Sleep(1 * time.Second)

		// Recursively remove all files in TileDataLayer
		err := filepath.Walk(tileDataPath, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if path != tileDataPath {
				os.RemoveAll(path)
			}
			return nil
		})

		if err == nil {
			if err := os.RemoveAll(tileDataPath); err == nil {
				fmt.Println("[+] Cleared TileDataLayer")
			}
		}
	}

	// Method 3: Clear Start Menu registry entries
	if err := wc.registryManager.ClearStartMenuRegistry(); err != nil {
		fmt.Printf("[-] Warning: Failed to clear Start Menu registry: %v\n", err)
	}

	// Windows 10 specific cleanup (for older builds)
	if major == 10 && build < 19041 {
		wc.cleanWindows10StartMenu()
	}

	fmt.Println("[+] Start Menu tiles cleared")
	fmt.Println("[!] Restarting Windows Explorer...")

	if err := system.RestartExplorer(); err != nil {
		fmt.Printf("[-] Warning: Failed to restart Explorer: %v\n", err)
	} else {
		fmt.Println("[+] Windows Explorer restarted")
	}

	fmt.Println("[!] Please sign out and sign back in for complete effect")
	return nil
}

// cleanWindows10StartMenu cleans Windows 10 specific Start Menu files
func (wc *WindowsCleaner) cleanWindows10StartMenu() {
	userProfile := os.Getenv("USERPROFILE")
	userLocal := os.Getenv("LOCALAPPDATA")

	locations := []string{
		filepath.Join(userProfile, "AppData", "Local", "TileDataLayer"),
		filepath.Join(userLocal, "Microsoft", "Windows", "Caches"),
	}

	for _, location := range locations {
		if _, err := os.Stat(location); err == nil {
			if err := os.RemoveAll(location); err == nil {
				fmt.Printf("[+] Cleared Windows 10 location: %s\n", filepath.Base(location))
			}
		}
	}
}

// ClearRecentItemsFolder clears the Recent Items folder
func (wc *WindowsCleaner) ClearRecentItemsFolder() error {
	fmt.Println("[*] Clearing Recent Items folder...")
	appData := os.Getenv("APPDATA")
	if appData == "" {
		return fmt.Errorf("APPDATA environment variable not set")
	}

	recentPath := filepath.Join(appData, "Microsoft", "Windows", "Recent")

	// If the directory doesn't exist, nothing to do
	if _, err := os.Stat(recentPath); os.IsNotExist(err) {
		return nil
	}

	entries, err := os.ReadDir(recentPath)
	if err != nil {
		return fmt.Errorf("failed to read Recent folder: %v", err)
	}

	for _, entry := range entries {
		name := entry.Name()
		// Skip subdirectories that are handled elsewhere
		if entry.IsDir() && (name == "AutomaticDestinations" || name == "CustomDestinations") {
			continue
		}

		// Remove files and shortcuts in the Recent folder
		p := filepath.Join(recentPath, name)
		if err := os.RemoveAll(p); err != nil {
			fmt.Printf("[-] Failed to remove %s: %v\n", p, err)
		}
	}

	fmt.Println("[+] Recent Items folder cleared")
	return nil
}

// ClearThumbnailCache clears Explorer thumbnail cache
func (wc *WindowsCleaner) ClearThumbnailCache() error {
	fmt.Println("[*] Clearing Explorer thumbnail cache...")
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		return fmt.Errorf("LOCALAPPDATA environment variable not set")
	}

	explorerPath := filepath.Join(localAppData, "Microsoft", "Windows", "Explorer")

	if _, err := os.Stat(explorerPath); os.IsNotExist(err) {
		return nil
	}

	entries, err := os.ReadDir(explorerPath)
	if err != nil {
		return fmt.Errorf("failed to read Explorer cache directory: %v", err)
	}

	for _, entry := range entries {
		name := strings.ToLower(entry.Name())
		// Remove the Thumbcache and icon cache files
		if strings.HasPrefix(name, "thumbcache_") ||
			strings.HasPrefix(name, "iconcache_") ||
			strings.HasPrefix(name, "iconcache") {
			p := filepath.Join(explorerPath, entry.Name())
			if err := os.RemoveAll(p); err != nil {
				fmt.Printf("[-] Failed to remove %s: %v\n", p, err)
			}
		}
	}

	fmt.Println("[+] Explorer thumbnail cache cleared")
	return nil
}

// RunAllWindowsCleanup runs all Windows-specific cleanup operations
func (wc *WindowsCleaner) RunAllWindowsCleanup() error {
	operations := []struct {
		name string
		fn   func() error
	}{
		{"Start Menu tiles", wc.ClearStartMenuTiles},
		{"Quick Access recent files", wc.registryManager.ClearQuickAccessRecent},
		{"Recent Items folder", wc.ClearRecentItemsFolder},
		{"Thumbnail cache", wc.ClearThumbnailCache},
		{"Explorer UserAssist", wc.registryManager.ClearExplorerUserAssist},
		{"ComDlg MRU", wc.registryManager.ClearComDlgMRU},
		{"Dark mode", wc.registryManager.EnableDarkMode},
	}

	var lastError error
	for _, op := range operations {
		if err := op.fn(); err != nil {
			fmt.Printf("[-] Warning: %s operation failed: %v\n", op.name, err)
			lastError = err
		}
	}

	// Clear recycle bin last
	fmt.Println("[*] Emptying recycle bin...")
	if err := system.ClearRecycleBin(); err != nil {
		fmt.Printf("[-] Warning: Failed to empty recycle bin: %v\n", err)
		lastError = err
	} else {
		fmt.Println("[+] Recycle bin emptied")
	}

	return lastError
}
