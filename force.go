package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

const (
	Version          = "2.0.0-force"
	MaxConcurrentOps = 100 // Higher concurrency for force mode
)

var (
	deletedFileCount   atomic.Int64
	deletedFolderCount atomic.Int64
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
					fmt.Printf("[*] Allowing deletion of excluded extension with '%s' in name: %s\n", kw, path)
					return false
				}
			}
			return true
		}
	}
	return false
}

func removeOldUserDirectories(directories []string, excludedExts []string) {
	fmt.Println("[!] FORCE MODE ENABLED - Removing ALL files regardless of age, but respecting exclusions")

	var wg sync.WaitGroup
	semaphore := make(chan struct{}, MaxConcurrentOps)

	for _, dir := range directories {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			fmt.Printf("[*] Directory does not exist: %s\n", dir)
			continue
		}

		fmt.Printf("[*] Checking directory: %s\n", dir)

		// Collect all items first
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

		// Sort by depth (deepest first) for proper deletion
		sortByDepth(items)

		for _, item := range items {
			wg.Add(1)
			semaphore <- struct{}{}

			go func(path string) {
				defer wg.Done()
				defer func() { <-semaphore }()

				info, err := os.Stat(path)
				if err != nil {
					return
				}

				if shouldExclude(path, excludedExts) {
					fmt.Printf("[*] Skipping excluded file: %s\n", path)
					return
				}

				ageHours := time.Since(info.ModTime())

				// FORCE MODE: Remove everything
				if info.IsDir() {
					// Check for excluded files in directory
					hasExcluded := false
					filepath.Walk(path, func(p string, i os.FileInfo, e error) error {
						if e == nil && !i.IsDir() && shouldExclude(p, excludedExts) {
							hasExcluded = true
							return filepath.SkipDir
						}
						return nil
					})
					if hasExcluded {
						fmt.Printf("[*] Skipping folder with excluded files: %s\n", path)
						return
					}
				} else if isFileInUse(path) {
					fmt.Printf("[!] File in use, skipping: %s\n", path)
					return
				}

				err = os.RemoveAll(path)
				if err == nil {
					if info.IsDir() {
						deletedFolderCount.Add(1)
					} else {
						deletedFileCount.Add(1)
					}
					fmt.Printf("[+] Removed: %s (Age: %.1fh)\n", path, ageHours.Hours())
				}
			}(item)
		}
	}

	wg.Wait()
}

func sortByDepth(paths []string) {
	// Simple bubble sort by depth (number of separators)
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

func removeBrowserDataIfNotRunning(browserInfo map[string][]string) {
	fmt.Println("[*] Checking browser data...")

	var wg sync.WaitGroup

	for proc, dirs := range browserInfo {
		wg.Add(1)
		go func(processName string, directories []string) {
			defer wg.Done()

			fmt.Printf("[*] Checking process: %s\n", processName)
			running := isProcessRunning(processName)

			if running {
				fmt.Printf("[!] FORCE MODE: Killing process %s\n", processName)
				if err := killProcess(processName); err != nil {
					fmt.Printf("[-] Failed to kill process %s: %v\n", processName, err)
				} else {
					fmt.Printf("[+] Killed process %s\n", processName)
					time.Sleep(3 * time.Second)
				}
			}

			fmt.Printf("[*] Process %s not running, removing data\n", processName)

			for _, dir := range directories {
				maxRetries := 2

				for attempt := 1; attempt <= maxRetries; attempt++ {
					_, err := os.Stat(dir)
					if os.IsNotExist(err) {
						fmt.Printf("[*] Path does not exist: %s\n", dir)
						break
					}

					if attempt > 1 {
						fmt.Printf("[*] Retry attempt %d for: %s\n", attempt, dir)
						time.Sleep(3 * time.Second)
					}

					err = os.RemoveAll(dir)
					if err == nil {
						deletedFolderCount.Add(1)
						fmt.Printf("[+] Removed: %s\n", dir)
						break
					} else if attempt >= maxRetries {
						fmt.Printf("[-] Failed to remove after %d attempts: %s: %v\n", maxRetries, dir, err)
					}
				}
			}
		}(proc, dirs)
	}

	wg.Wait()
}

func removeEmptyDirectories(directories []string) {
	fmt.Println("[*] Scanning for empty directories...")

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

		// Sort deepest first
		sortByDepth(allDirs)

		for _, d := range allDirs {
			entries, err := os.ReadDir(d)
			if err == nil && len(entries) == 0 {
				if err := os.Remove(d); err == nil {
					deletedFolderCount.Add(1)
					fmt.Printf("[+] Removed empty directory: %s\n", d)
				}
			}
		}
	}
}

func clearStartMenuTiles() {
	fmt.Println("[*] Unpinning all Start Menu tiles...")

	userHome := os.Getenv("LOCALAPPDATA")

	// Stop Start Menu process
	killProcess("StartMenuExperienceHost.exe")
	time.Sleep(1 * time.Second)

	// Clear Start Menu database
	startDbPath := filepath.Join(userHome, "Packages", "Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy", "LocalState")
	if _, err := os.Stat(startDbPath); err == nil {
		dbFile := filepath.Join(startDbPath, "start.db")
		dbJournal := filepath.Join(startDbPath, "start.db-journal")

		if err := os.Remove(dbFile); err == nil {
			fmt.Println("[+] Removed Start Menu database")
		}
		os.Remove(dbJournal)
	}

	// Clear TileDataLayer (Windows 11)
	tileDataPath := filepath.Join(userHome, "Packages", "Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy", "TileDataLayer")
	if _, err := os.Stat(tileDataPath); err == nil {
		killProcess("StartMenuExperienceHost.exe")
		time.Sleep(1 * time.Second)
		if err := os.RemoveAll(tileDataPath); err == nil {
			fmt.Println("[+] Cleared TileDataLayer")
		}
	}

	fmt.Println("[+] Start Menu tiles cleared")
	fmt.Println("[!] Restarting Windows Explorer...")

	killProcess("explorer.exe")
	time.Sleep(2 * time.Second)

	cmd := &syscall.SysProcAttr{HideWindow: false}
	proc := &os.ProcAttr{
		Files: []*os.File{os.Stdin, os.Stdout, os.Stderr},
		Sys:   cmd,
	}
	os.StartProcess(filepath.Join(os.Getenv("WINDIR"), "explorer.exe"), []string{}, proc)

	fmt.Println("[+] Windows Explorer restarted")
	fmt.Println("[!] Please sign out and sign back in for complete effect")
}

func clearQuickAccessRecent() {
	fmt.Println("[*] Clearing File Explorer Quick Access recent files...")

	// Clear recent documents registry
	key, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs`, registry.ALL_ACCESS)
	if err == nil {
		registry.DeleteKey(key, "")
		key.Close()
		fmt.Println("[+] Cleared recent documents registry")
	}

	userHome := os.Getenv("APPDATA")

	// Clear AutomaticDestinations
	jumpListPath := filepath.Join(userHome, "Microsoft", "Windows", "Recent", "AutomaticDestinations")
	if entries, err := os.ReadDir(jumpListPath); err == nil {
		for _, entry := range entries {
			os.Remove(filepath.Join(jumpListPath, entry.Name()))
		}
		fmt.Println("[+] Cleared jump list recent files")
	}

	// Clear CustomDestinations
	customDestPath := filepath.Join(userHome, "Microsoft", "Windows", "Recent", "CustomDestinations")
	if entries, err := os.ReadDir(customDestPath); err == nil {
		for _, entry := range entries {
			os.Remove(filepath.Join(customDestPath, entry.Name()))
		}
		fmt.Println("[+] Cleared custom destinations")
	}

	// Clear TypedPaths
	key2, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths`, registry.ALL_ACCESS)
	if err == nil {
		registry.DeleteKey(key2, "")
		key2.Close()
		fmt.Println("[+] Cleared typed paths history")
	}

	// Clear RunMRU
	key3, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU`, registry.ALL_ACCESS)
	if err == nil {
		registry.DeleteKey(key3, "")
		key3.Close()
		fmt.Println("[+] Cleared Run dialog history")
	}

	fmt.Println("[+] File Explorer Quick Access cleared")
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

func setWallpaperFromURL(url string) {
	userHome := os.Getenv("USERPROFILE")
	wallpaperDir := filepath.Join(userHome, "Pictures")
	os.MkdirAll(wallpaperDir, 0755)

	wallpaperPath := filepath.Join(wallpaperDir, "tapeta.png")

	resp, err := http.Get(url)
	if err != nil {
		fmt.Printf("[-] Failed to download wallpaper: %v\n", err)
		return
	}
	defer resp.Body.Close()

	out, err := os.Create(wallpaperPath)
	if err != nil {
		fmt.Printf("[-] Failed to create wallpaper file: %v\n", err)
		return
	}
	defer out.Close()

	io.Copy(out, resp.Body)

	// Set wallpaper using SystemParametersInfo
	user32 := syscall.NewLazyDLL("user32.dll")
	systemParametersInfo := user32.NewProc("SystemParametersInfoW")

	wallpaperPathUTF16, _ := syscall.UTF16PtrFromString(wallpaperPath)
	systemParametersInfo.Call(
		uintptr(20), // SPI_SETDESKWALLPAPER
		uintptr(0),
		uintptr(unsafe.Pointer(wallpaperPathUTF16)),
		uintptr(3), // SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
	)

	fmt.Printf("[+] Wallpaper set to %s\n", wallpaperPath)
}

func clearRecycleBin() {
	shell32 := syscall.NewLazyDLL("shell32.dll")
	emptyRecycleBin := shell32.NewProc("SHEmptyRecycleBinW")

	emptyRecycleBin.Call(
		uintptr(0),
		uintptr(0),
		uintptr(0x0007), // SHERB_NOCONFIRMATION | SHERB_NOPROGRESSUI | SHERB_NOSOUND
	)
	fmt.Println("[+] Recycle bin emptied")
}

func getDiskInfo() {
	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	getDiskFreeSpaceEx := kernel32.NewProc("GetDiskFreeSpaceExW")

	var freeBytesAvailable, totalBytes, totalFreeBytes uint64

	drive, _ := syscall.UTF16PtrFromString("C:\\")
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
	fmt.Printf("[*] >  Total: %.2f GB\n", totalGB)
	fmt.Printf("[*] >  Used: %.2f GB (%.2f%%)\n", usedGB, usedPercent)
	fmt.Printf("[*] >  Free: %.2f GB (%.2f%%)\n", freeGB, freePercent)
}

func main() {
	if runtime.GOOS != "windows" {
		log.Fatal("This program only runs on Windows")
	}

	fmt.Printf("[*] Starting nScript v%s (Go Edition - FORCE MODE)\n", Version)
	fmt.Println("[!] WARNING: Force mode enabled - all files will be removed!")
	time.Sleep(3 * time.Second)

	config := getConfig()

	// Main cleanup operations with aggressive settings
	removeOldUserDirectories(config.UserDirectories, config.ExcludedExtensions)
	removeBrowserDataIfNotRunning(config.BrowserInformation)
	removeEmptyDirectories(config.UserDirectories)

	// UI customizations
	clearStartMenuTiles()
	clearQuickAccessRecent()
	enableDarkMode()
	setWallpaperFromURL("https://proxy.meowery.eu/tapeta.png")

	// Final cleanup
	clearRecycleBin()

	fmt.Println("\n[+] nScript completed")
	fmt.Println("[*] ============================================")
	fmt.Println("[*] Deletion Summary:")
	fmt.Printf("[*] >  Files deleted: %d\n", deletedFileCount.Load())
	fmt.Printf("[*] >  Folders deleted: %d\n", deletedFolderCount.Load())
	fmt.Printf("[*] >  Total items deleted: %d\n", deletedFileCount.Load()+deletedFolderCount.Load())

	getDiskInfo()

	fmt.Println("[*] ============================================")
	fmt.Println("[*] Made by Nyx :3 https://nyx.meowery.eu/")
	fmt.Println("[*] ============================================")
}
