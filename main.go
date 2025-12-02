package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

const (
	Version             = "2.0.5"
	OnlyRemoveOlderThan = 24 * time.Hour
	MaxConcurrentOps    = 500
	UpdateInterval      = 50 * time.Millisecond
)

var (
	deletedFileCount   atomic.Int64
	deletedFolderCount atomic.Int64
	skippedFileCount   atomic.Int64
	failedFileCount    atomic.Int64
	stopCounter        atomic.Bool
)

type Config struct {
	UserDirectories    []string
	BrowserInformation map[string][]string
	ExcludedExtensions []string
}

func getConfig() *Config {
	userHome := os.Getenv("USERPROFILE")
	programData := os.Getenv("ProgramData")
	programFilesX86 := os.Getenv("ProgramFiles(x86)")

	return &Config{
		UserDirectories: []string{
			filepath.Join(userHome, "Downloads"),
			filepath.Join(userHome, "Documents"),
			filepath.Join(userHome, "Desktop"),
			filepath.Join(userHome, "Videos"),
			filepath.Join(userHome, "Music"),
			filepath.Join(userHome, "Pictures"),
			filepath.Join(userHome, "3D Objects"),
			filepath.Join(userHome, "Saved Games"),
			filepath.Join(userHome, "Contacts"),
			filepath.Join(userHome, "Links"),
			filepath.Join(userHome, "Favorites"),
			filepath.Join(userHome, "AppData", "Local", "Temp"),
			filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Recent"),
			filepath.Join(userHome, "AppData", "Local", "Low", "Microsoft", "Internet Explorer"),
			filepath.Join(userHome, "AppData", "Local", "Microsoft", "Windows", "INetCache"),
			filepath.Join(userHome, "AppData", "Local", "Microsoft", "Windows", "INetCookies"),
			filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Office", "Recent"),
			filepath.Join(userHome, "AppData", "Local", "Microsoft", "Windows", "Clipboard"),
			filepath.Join(userHome, ".cache"),
			filepath.Join(userHome, "AppData", "Local", "Roblox"),
			filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Roblox"),
			filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Discord Inc"),
			filepath.Join(userHome, "AppData", "Local", "Discord"),
			filepath.Join(programData, "Microsoft", "Windows", "Start Menu", "Programs", "Epic Games Launcher.lnk"),
			filepath.Join(programFilesX86, "Epic Games"),
			filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "osu!.lnk"),
			filepath.Join(userHome, "AppData", "Local", "osu!"),
			filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Paradox Interactive"),
			filepath.Join(userHome, "AppData", "Local", "Programs", "Paradox Interactive"),
			filepath.Join(userHome, "MicrosoftEdgeBackups"),
			filepath.Join(userHome, "AppData", "Roaming", "Godot"),
			filepath.Join("C:", "Steam"),
			filepath.Join("C:", "Program Files", "Epic Games"),
			filepath.Join("C:", "ProgramData", "Riot Games"),
		},
		BrowserInformation: map[string][]string{
			"firefox.exe": {
				filepath.Join(userHome, "AppData", "Roaming", "Mozilla", "Firefox", "Profiles"),
				filepath.Join(userHome, "AppData", "Local", "Mozilla", "Firefox", "Profiles"),
				filepath.Join(userHome, "AppData", "Roaming", "Mozilla", "Firefox", "profiles.ini"),
			},
			"chrome.exe": {
				filepath.Join(userHome, "AppData", "Local", "Google", "Chrome", "User Data"),
			},
			"msedge.exe": {
				filepath.Join(userHome, "AppData", "Local", "Microsoft", "Edge", "User Data"),
			},
			"opera.exe": {
				filepath.Join(userHome, "AppData", "Roaming", "Opera Software"),
				filepath.Join(userHome, "AppData", "Local", "Opera Software"),
				filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Przeglądarka Opera GX.lnk"),
				filepath.Join(userHome, "AppData", "Local", "Programs", "Opera GX"),
			},
			"onedrive.exe": {
				filepath.Join(userHome, "AppData", "Local", "Microsoft", "OneDrive"),
			},
		},
		ExcludedExtensions: []string{
			".iso", ".vdi", ".sav", ".vbox", ".vbox-prev",
			".vmdk", ".vhd", ".hdd", ".nvram", ".ova",
			".ovf", ".vbox-extpack", ".vhdx", ".qcow2", ".img", ".lnk",
		},
	}
}

func isFileInUse(path string) bool {
	file, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return true
	}
	file.Close()
	return false
}

func shouldExclude(path string, excludedExts []string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	for _, excluded := range excludedExts {
		if ext == excluded {
			allowKeywords := []string{"roblox", "paradox", "opera", "discord", "osu", "steam", "epic games"}
			lowerName := strings.ToLower(filepath.Base(path))
			for _, kw := range allowKeywords {
				if strings.Contains(lowerName, kw) {
					fmt.Printf("\n[*] Allowing deletion of excluded extension with '%s' in name: %s\n", kw, path)
					return false
				}
			}
			return true
		}
	}
	return false
}

func startProgressCounter(label string) func() {
	stopCounter.Store(false)
	done := make(chan struct{})

	go func() {
		ticker := time.NewTicker(UpdateInterval)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				files := deletedFileCount.Load()
				folders := deletedFolderCount.Load()
				skipped := skippedFileCount.Load()
				failed := failedFileCount.Load()
				fmt.Printf("\r[*] %s | Files: %d | Folders: %d | Skipped: %d | Failed: %d",
					label, files, folders, skipped, failed)
			case <-done:
				return
			}
		}
	}()

	return func() {
		stopCounter.Store(true)
		done <- struct{}{}
		close(done)
		fmt.Println()
	}
}

func removeOldUserDirectories(directories []string, olderThan time.Duration, excludedExts []string, forceMode bool) {
	if forceMode {
		fmt.Println("[!] Removing ALL files regardless of age...")
	} else {
		fmt.Printf("[*] Scanning directories, removing files older than %.0f hours...\n", olderThan.Hours())
	}

	stopProgress := startProgressCounter("Cleaning directories")
	defer stopProgress()

	var wg sync.WaitGroup
	semaphore := make(chan struct{}, MaxConcurrentOps)

	for _, dir := range directories {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue
		}

		var items []string
		filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if path != dir {
				items = append(items, path)
			}
			return nil
		})

		sortByDepth(items)

		for _, item := range items {
			wg.Add(1)
			semaphore <- struct{}{}

			go func(path string) {
				defer wg.Done()
				defer func() { <-semaphore }()

				info, err := os.Stat(path)
				if err != nil {
					failedFileCount.Add(1)
					return
				}

				if shouldExclude(path, excludedExts) {
					skippedFileCount.Add(1)
					return
				}

				ageHours := time.Since(info.ModTime())

				if forceMode || ageHours > olderThan {
					if info.IsDir() {
						hasExcluded := false
						filepath.Walk(path, func(p string, i os.FileInfo, e error) error {
							if e != nil || i.IsDir() {
								return nil
							}
							if shouldExclude(p, excludedExts) {
								hasExcluded = true
								return filepath.SkipDir
							}
							return nil
						})
						if hasExcluded {
							skippedFileCount.Add(1)
							return
						}
					} else if isFileInUse(path) {
						skippedFileCount.Add(1)
						return
					}

					err = os.RemoveAll(path)
					if err == nil {
						if info.IsDir() {
							deletedFolderCount.Add(1)
						} else {
							deletedFileCount.Add(1)
						}
					} else {
						failedFileCount.Add(1)
					}
				}
			}(item)
		}
	}

	wg.Wait()
}

func sortByDepth(paths []string) {
	for i := 0; i < len(paths); i++ {
		for j := i + 1; j < len(paths); j++ {
			depth1 := strings.Count(paths[i], string(filepath.Separator))
			depth2 := strings.Count(paths[j], string(filepath.Separator))
			if depth2 > depth1 {
				paths[i], paths[j] = paths[j], paths[i]
			}
		}
	}
}

func isProcessRunning(name string) bool {
	snapshot, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return false
	}
	defer windows.CloseHandle(snapshot)

	var pe32 windows.ProcessEntry32
	pe32.Size = uint32(unsafe.Sizeof(pe32))

	if err := windows.Process32First(snapshot, &pe32); err != nil {
		return false
	}

	name = strings.ToLower(name)
	for {
		exeName := windows.UTF16ToString(pe32.ExeFile[:])
		if strings.ToLower(exeName) == name {
			return true
		}
		if err := windows.Process32Next(snapshot, &pe32); err != nil {
			break
		}
	}
	return false
}

func killProcess(name string) error {
	snapshot, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return err
	}
	defer windows.CloseHandle(snapshot)

	var pe32 windows.ProcessEntry32
	pe32.Size = uint32(unsafe.Sizeof(pe32))

	if err := windows.Process32First(snapshot, &pe32); err != nil {
		return err
	}

	name = strings.ToLower(name)
	for {
		exeName := windows.UTF16ToString(pe32.ExeFile[:])
		if strings.ToLower(exeName) == name {
			handle, err := windows.OpenProcess(windows.PROCESS_TERMINATE, false, pe32.ProcessID)
			if err == nil {
				windows.TerminateProcess(handle, 0)
				windows.CloseHandle(handle)
			}
		}
		if err := windows.Process32Next(snapshot, &pe32); err != nil {
			break
		}
	}
	return nil
}

func removeBrowserDataIfNotRunning(browserInfo map[string][]string, forceMode bool) {
	fmt.Println("[*] Checking browser data...")

	var wg sync.WaitGroup
	semaphore := make(chan struct{}, MaxConcurrentOps)

	for proc, dirs := range browserInfo {
		wg.Add(1)
		go func(processName string, directories []string) {
			defer wg.Done()

			running := isProcessRunning(processName)

			if running && forceMode {
				if err := killProcess(processName); err != nil {
					fmt.Printf("[-] Failed to kill %s: %v\n", processName, err)
					return
				}
				fmt.Printf("[+] Killed %s\n", processName)
				time.Sleep(1 * time.Second)
			} else if running {
				return
			}

			var dirWg sync.WaitGroup
			for _, dir := range directories {
				dirWg.Add(1)
				semaphore <- struct{}{}
				go func(d string) {
					defer dirWg.Done()
					defer func() { <-semaphore }()

					maxRetries := 1
					if forceMode {
						maxRetries = 2
					}

					for attempt := 1; attempt <= maxRetries; attempt++ {
						_, err := os.Stat(d)
						if os.IsNotExist(err) {
							break
						}

						if attempt > 1 {
							time.Sleep(1 * time.Second)
						}

						err = os.RemoveAll(d)
						if err == nil {
							fmt.Printf("[+] Removed %s data\n", processName)
							break
						} else if attempt == maxRetries {
							fmt.Printf("[-] Failed to remove %s: %v\n", d, err)
						}
					}
				}(dir)
			}
			dirWg.Wait()
		}(proc, dirs)
	}

	wg.Wait()
}

func removeEmptyDirectories(directories []string) {
	fmt.Println("[*] Scanning for empty directories...")

	stopProgress := startProgressCounter("Removing empty directories")
	defer stopProgress()

	var wg sync.WaitGroup
	semaphore := make(chan struct{}, MaxConcurrentOps)

	for _, dir := range directories {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue
		}

		var allDirs []string
		filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
			if err != nil || !info.IsDir() || path == dir {
				return nil
			}
			allDirs = append(allDirs, path)
			return nil
		})

		sortByDepth(allDirs)

		for _, d := range allDirs {
			wg.Add(1)
			semaphore <- struct{}{}
			go func(dirPath string) {
				defer wg.Done()
				defer func() { <-semaphore }()

				entries, err := os.ReadDir(dirPath)
				if err == nil && len(entries) == 0 {
					os.Remove(dirPath)
					deletedFolderCount.Add(1)
				}
			}(d)
		}
	}

	wg.Wait()
}

func getWindowsVersion() (major, minor, build uint32) {
	version := windows.RtlGetVersion()
	return version.MajorVersion, version.MinorVersion, version.BuildNumber
}

func clearStartMenuTiles() {
	fmt.Println("[*] Unpinning all Start Menu tiles...")

	major, _, build := getWindowsVersion()
	userHome := os.Getenv("LOCALAPPDATA")

	// Stop Start Menu process
	killProcess("StartMenuExperienceHost.exe")
	time.Sleep(1 * time.Second)

	// Method 1: Delete the Start Menu database directly
	fmt.Println("[*] Clearing Start Menu database...")
	startDbPath := filepath.Join(userHome, "Packages", "Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy", "LocalState")
	if _, err := os.Stat(startDbPath); err == nil {
		dbFile := filepath.Join(startDbPath, "start.db")
		dbJournal := filepath.Join(startDbPath, "start.db-journal")

		if err := os.Remove(dbFile); err == nil {
			fmt.Println("[+] Removed Start Menu database")
		}
		os.Remove(dbJournal)
	}

	// Method 2: Clear TileDataLayer database (works for both Win10 and Win11)
	fmt.Println("[*] Clearing TileDataLayer...")
	tileDataPath := filepath.Join(userHome, "Packages", "Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy", "TileDataLayer")
	if _, err := os.Stat(tileDataPath); err == nil {
		killProcess("StartMenuExperienceHost.exe")
		time.Sleep(1 * time.Second)

		// Recursively remove all files in TileDataLayer
		filepath.Walk(tileDataPath, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if path != tileDataPath {
				os.RemoveAll(path)
			}
			return nil
		})

		// Remove the directory itself
		if err := os.RemoveAll(tileDataPath); err == nil {
			fmt.Println("[+] Cleared TileDataLayer")
		}
	}

	// Method 3: Clear Start Menu registry entries via CloudStore
	fmt.Println("[*] Clearing Start Menu registry entries...")
	regPath := `Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount`

	key, err := registry.OpenKey(registry.CURRENT_USER, regPath, registry.ENUMERATE_SUB_KEYS|registry.QUERY_VALUE)
	if err == nil {
		subkeys, _ := key.ReadSubKeyNames(-1)
		key.Close()

		// Delete subkeys that contain start menu related data
		for _, subkey := range subkeys {
			lowerSubkey := strings.ToLower(subkey)
			if strings.Contains(lowerSubkey, "start.tilegrid") ||
				strings.Contains(lowerSubkey, "windows.data.placeholdertilecollection") ||
				strings.Contains(lowerSubkey, "microsoft.windows.startmenuexperiencehost") {

				fullPath := regPath + `\` + subkey
				// Recursively delete the registry key
				deleteRegistryKeyRecursive(registry.CURRENT_USER, fullPath)
			}
		}
		fmt.Println("[+] Cleared Start Menu registry cache")
	}

	// Windows 10 specific cleanup (for older builds)
	if major == 10 && build < 19041 {
		userProfile := os.Getenv("USERPROFILE")
		layoutPath := filepath.Join(userProfile, "AppData", "Local", "TileDataLayer")
		if _, err := os.Stat(layoutPath); err == nil {
			if err := os.RemoveAll(layoutPath); err == nil {
				fmt.Println("[+] Cleared Windows 10 TileDataLayer")
			}
		}

		cachePath := filepath.Join(userHome, "Microsoft", "Windows", "Caches")
		if _, err := os.Stat(cachePath); err == nil {
			if err := os.RemoveAll(cachePath); err == nil {
				fmt.Println("[+] Cleared Start Menu cache")
			}
		}
	}

	fmt.Println("[+] Start Menu tiles cleared")
	fmt.Println("[!] Restarting Windows Explorer...")

	killProcess("explorer.exe")
	time.Sleep(2 * time.Second)

	cmd := &windows.SysProcAttr{HideWindow: false}
	proc := &os.ProcAttr{
		Files: []*os.File{os.Stdin, os.Stdout, os.Stderr},
		Sys:   cmd,
	}
	os.StartProcess(filepath.Join(os.Getenv("WINDIR"), "explorer.exe"), []string{}, proc)

	fmt.Println("[+] Windows Explorer restarted")
	fmt.Println("[!] Please sign out and sign back in for complete effect")
}

func deleteRegistryKeyRecursive(root registry.Key, path string) error {
	key, err := registry.OpenKey(root, path, registry.ENUMERATE_SUB_KEYS|registry.SET_VALUE)
	if err != nil {
		return err
	}

	// Get all subkeys
	subkeys, err := key.ReadSubKeyNames(-1)
	key.Close()

	if err == nil {
		// Recursively delete subkeys
		for _, subkey := range subkeys {
			deleteRegistryKeyRecursive(root, path+`\`+subkey)
		}
	}

	// Delete the key itself
	return registry.DeleteKey(root, path)
}

func clearQuickAccessRecent() {
	fmt.Println("[*] Clearing File Explorer Quick Access recent files...")

	key, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs`, registry.ALL_ACCESS)
	if err == nil {
		registry.DeleteKey(key, "")
		key.Close()
		fmt.Println("[+] Cleared recent documents registry")
	}

	userHome := os.Getenv("APPDATA")

	jumpListPath := filepath.Join(userHome, "Microsoft", "Windows", "Recent", "AutomaticDestinations")
	if entries, err := os.ReadDir(jumpListPath); err == nil {
		for _, entry := range entries {
			os.Remove(filepath.Join(jumpListPath, entry.Name()))
		}
		fmt.Println("[+] Cleared jump list recent files")
	}

	customDestPath := filepath.Join(userHome, "Microsoft", "Windows", "Recent", "CustomDestinations")
	if entries, err := os.ReadDir(customDestPath); err == nil {
		for _, entry := range entries {
			os.Remove(filepath.Join(customDestPath, entry.Name()))
		}
		fmt.Println("[+] Cleared custom destinations")
	}

	key2, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths`, registry.ALL_ACCESS)
	if err == nil {
		registry.DeleteKey(key2, "")
		key2.Close()
		fmt.Println("[+] Cleared typed paths history")
	}

	key3, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU`, registry.ALL_ACCESS)
	if err == nil {
		registry.DeleteKey(key3, "")
		key3.Close()
		fmt.Println("[+] Cleared Run dialog history")
	}

	fmt.Println("[+] File Explorer Quick Access cleared")
}

func clearRecentItemsFolder() {
	fmt.Println("[*] Clearing Recent Items folder...")
	appData := os.Getenv("APPDATA")
	recentPath := filepath.Join(appData, "Microsoft", "Windows", "Recent")

	// If the directory doesn't exist, nothing to do
	if _, err := os.Stat(recentPath); os.IsNotExist(err) {
		return
	}

	entries, err := os.ReadDir(recentPath)
	if err != nil {
		fmt.Printf("[-] Failed to read Recent folder: %v\n", err)
		return
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
}

func clearThumbnailCache() {
	fmt.Println("[*] Clearing Explorer thumbnail cache...")
	localAppData := os.Getenv("LOCALAPPDATA")
	explorerPath := filepath.Join(localAppData, "Microsoft", "Windows", "Explorer")

	if _, err := os.Stat(explorerPath); os.IsNotExist(err) {
		return
	}

	entries, err := os.ReadDir(explorerPath)
	if err != nil {
		fmt.Printf("[-] Failed to read Explorer cache directory: %v\n", err)
		return
	}

	for _, entry := range entries {
		name := strings.ToLower(entry.Name())
		// Remove the Thumbcache and icon cache files
		if strings.HasPrefix(name, "thumbcache_") || strings.HasPrefix(name, "iconcache_") || strings.HasPrefix(name, "iconcache") {
			p := filepath.Join(explorerPath, entry.Name())
			if err := os.RemoveAll(p); err != nil {
				fmt.Printf("[-] Failed to remove %s: %v\n", p, err)
			}
		}
	}

	fmt.Println("[+] Explorer thumbnail cache cleared")
}

func clearExplorerUserAssist() {
	fmt.Println("[*] Clearing Explorer UserAssist data (registry)...")
	regPath := `Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\UserAssist`

	// We need to iterate subkeys and delete them for the current user
	key, err := registry.OpenKey(registry.CURRENT_USER, regPath, registry.ENUMERATE_SUB_KEYS|registry.SET_VALUE)
	if err != nil {
		// It's fine if it doesn't exist or we can't open it
		fmt.Printf("[-] Could not open UserAssist key: %v\n", err)
		return
	}
	subkeys, _ := key.ReadSubKeyNames(-1)
	key.Close()

	for _, sub := range subkeys {
		full := regPath + `\\` + sub
		if err := deleteRegistryKeyRecursive(registry.CURRENT_USER, full); err != nil {
			fmt.Printf("[-] Failed to delete UserAssist subkey %s: %v\n", full, err)
		}
	}
	fmt.Println("[+] Explorer UserAssist data cleared")
}

func clearComDlgMRU() {
	fmt.Println("[*] Clearing common Open/Save dialog MRU entries (ComDlg32)...")

	keys := []string{
		`Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ComDlg32\\OpenSavePidlMRU`,
		`Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ComDlg32\\OpenSaveMRU`,
		`Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ComDlg32\\LastVisitedPidlMRU`,
	}

	for _, k := range keys {
		if err := deleteRegistryKeyRecursive(registry.CURRENT_USER, k); err != nil {
			fmt.Printf("[-] Failed to clear %s: %v\n", k, err)
		}
	}

	fmt.Println("[+] ComDlg32 MRU entries cleared")
}

func enableDarkMode() {
	key, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`, registry.ALL_ACCESS)
	if err != nil {
		registry.CreateKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`, registry.ALL_ACCESS)
		key, _ = registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`, registry.ALL_ACCESS)
	}
	defer key.Close()

	key.SetDWordValue("SystemUsesLightTheme", 0)
	key.SetDWordValue("AppsUseLightTheme", 0)
	key.SetDWordValue("ForceDarkMode", 1)
}

func clearRecycleBin() {
	shell32 := windows.NewLazyDLL("shell32.dll")
	emptyRecycleBin := shell32.NewProc("SHEmptyRecycleBinW")

	emptyRecycleBin.Call(
		uintptr(0),
		uintptr(0),
		uintptr(0x0007),
	)
	fmt.Println("[+] Recycle bin emptied")
}

func getDiskInfo() {
	kernel32 := windows.NewLazyDLL("kernel32.dll")
	getDiskFreeSpaceEx := kernel32.NewProc("GetDiskFreeSpaceExW")

	var freeBytesAvailable, totalBytes, totalFreeBytes uint64

	drive, _ := windows.UTF16PtrFromString("C:\\")
	getDiskFreeSpaceEx.Call(
		uintptr(unsafe.Pointer(drive)),
		uintptr(unsafe.Pointer(&freeBytesAvailable)),
		uintptr(unsafe.Pointer(&totalBytes)),
		uintptr(unsafe.Pointer(&totalFreeBytes)),
	)

	totalGB := float64(totalBytes) / (1024 * 1024 * 1024)
	freeGB := float64(totalFreeBytes) / (1024 * 1024 * 1024)
	usedGB := totalGB - freeGB
	freePercent := (freeGB / totalGB) * 100
	usedPercent := 100 - freePercent

	fmt.Println("[*] ============================================")
	fmt.Println("[*] Disk Information (C:):")
	fmt.Printf("[*]    Total: %.2f GB\n", totalGB)
	fmt.Printf("[*]    Used: %.2f GB (%.2f%%)\n", usedGB, usedPercent)
	fmt.Printf("[*]    Free: %.2f GB (%.2f%%)\n", freeGB, freePercent)
}

func main() {
	if runtime.GOOS != "windows" {
		log.Fatal("This program only runs on Windows")
	}

	forceMode := false
	for _, arg := range os.Args[1:] {
		if arg == "-Force" || arg == "--force" {
			forceMode = true
		}
	}

	versionStr := Version
	if forceMode {
		versionStr += "-force"
	}

	fmt.Printf("[*] Starting nScript v%s\n", versionStr)

	if forceMode {
		fmt.Println("[!] Force mode enabled - all files will be removed!")
		time.Sleep(2 * time.Second)
	}

	config := getConfig()

	startTime := time.Now()

	removeOldUserDirectories(config.UserDirectories, OnlyRemoveOlderThan, config.ExcludedExtensions, forceMode)
	removeBrowserDataIfNotRunning(config.BrowserInformation, forceMode)
	removeEmptyDirectories(config.UserDirectories)

	clearStartMenuTiles()
	clearQuickAccessRecent()
	clearRecentItemsFolder()
	clearThumbnailCache()
	clearExplorerUserAssist()
	clearComDlgMRU()
	enableDarkMode()

	clearRecycleBin()

	elapsed := time.Since(startTime)

	fmt.Println("\n[+] nScript completed")
	fmt.Println("[*] ============================================")
	fmt.Println("[*] Deletion Summary:")
	fmt.Printf("[*]    Files deleted: %d\n", deletedFileCount.Load())
	fmt.Printf("[*]    Folders deleted: %d\n", deletedFolderCount.Load())
	fmt.Printf("[*]    Files skipped: %d\n", skippedFileCount.Load())
	fmt.Printf("[*]    Failed operations: %d\n", failedFileCount.Load())
	fmt.Printf("[*]    Total items deleted: %d\n", deletedFileCount.Load()+deletedFolderCount.Load())
	fmt.Printf("[*]    Time taken: %.2f seconds\n", elapsed.Seconds())

	getDiskInfo()

	fmt.Println("[*] ============================================")
	fmt.Println("[*] Made by Nyx :3 https://nyx.meowery.eu/")
	fmt.Println("[*] ============================================")
	fmt.Print("[*] Closing in 3s...")
	time.Sleep(1 * time.Second)
	fmt.Print("[*] Closing in 2s...")
	time.Sleep(1 * time.Second)
	fmt.Print("[*] Closing in 1s...")
	time.Sleep(1 * time.Second)
}
