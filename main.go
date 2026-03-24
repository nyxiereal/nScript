package main

import (
	"fmt"
	"log"
	"os"
	"runtime"
	"time"

	"nScript/internal/cleanup"
	"nScript/internal/config"
	"nScript/internal/system"
	"nScript/internal/ui"
)

func main() {
	// Ensure we're running on Windows
	if runtime.GOOS != "windows" {
		log.Fatal("This program only runs on Windows")
	}

	// Parse command line arguments
	forceMode := parseArguments()

	// Initialize configuration
	cfg := config.GetConfig()

	// Display header and warnings
	ui.PrintHeader(config.Version, forceMode)

	// Confirm destructive operations in force mode
	if forceMode {
		if !ui.ConfirmationPrompt("Force mode will delete ALL files regardless of age. Continue?") {
			fmt.Println("[*] Operation cancelled by user")
			return
		}
	}

	// Initialize components
	cleaner := cleanup.NewCleaner()
	windowsCleaner := cleanup.NewWindowsCleaner()
	progressTracker := ui.NewProgressTracker(cleaner.GetStats())

	fmt.Println("\n[*] Starting cleanup operations...")
	startTime := time.Now()

	// Phase 1: File and directory cleanup with streaming
	fmt.Println("\n[*] Phase 1: File and directory cleanup")
	stopProgress := progressTracker.StartProgress("Cleaning directories")

	err := cleaner.StreamingCleanDirectories(
		cfg.UserDirectories,
		config.OnlyRemoveOlderThan,
		cfg.ExcludedExtensions,
		forceMode,
	)
	stopProgress()

	if err != nil {
		fmt.Printf("[-] Warning: Directory cleanup encountered errors: %v\n", err)
	}

	// Phase 2: Browser data cleanup
	fmt.Println("\n[*] Phase 2: Browser data cleanup")
	err = cleaner.CleanBrowserData(cfg.BrowserInformation, forceMode)
	if err != nil {
		fmt.Printf("[-] Warning: Browser cleanup encountered errors: %v\n", err)
	}

	// Phase 3: Empty directory removal
	fmt.Println("\n[*] Phase 3: Empty directory cleanup")
	stopProgress = progressTracker.StartProgress("Removing empty directories")

	err = cleaner.RemoveEmptyDirectories(cfg.UserDirectories)
	stopProgress()

	if err != nil {
		fmt.Printf("[-] Warning: Empty directory cleanup encountered errors: %v\n", err)
	}

	// Phase 4: Windows-specific cleanup
	fmt.Println("\n[*] Phase 4: Windows system cleanup")
	err = windowsCleaner.RunAllWindowsCleanup()
	if err != nil {
		fmt.Printf("[-] Warning: Windows cleanup encountered errors: %v\n", err)
	}

	// Calculate elapsed time
	elapsed := time.Since(startTime)

	// Get disk information for final report
	diskInfo, err := system.GetDiskInfo()
	if err != nil {
		fmt.Printf("[-] Warning: Could not get disk information: %v\n", err)
	}

	// Display final statistics
	ui.PrintStats(cleaner.GetStats(), elapsed, diskInfo)

	// Show backup information
	registryManager := system.NewRegistryManager()
	ui.ShowBackupInfo(registryManager.GetBackupDirectory())

	// Display closing message
	ui.PrintClosingMessage()
}

// parseArguments parses command line arguments and returns force mode status
func parseArguments() bool {
	forceMode := false
	for _, arg := range os.Args[1:] {
		if arg == "-Force" || arg == "--force" {
			forceMode = true
		} else {
			// Show help for unknown arguments
			fmt.Printf("Unknown argument: %s\n", arg)
			showHelp()
			os.Exit(1)
		}
	}
	return forceMode
}

// showHelp displays usage information
func showHelp() {
	fmt.Println("nScript - Windows System Cleaner")
	fmt.Println("Usage:")
	fmt.Println("  nScript.exe           - Normal mode (removes files older than 24 hours)")
	fmt.Println("  nScript.exe --force   - Force mode (removes ALL files regardless of age)")
	fmt.Println("  nScript.exe -Force    - Alternative force mode syntax")
	fmt.Println()
	fmt.Println("WARNING: Force mode is destructive and cannot be undone!")
	fmt.Println("Always ensure you have backups of important data before running.")
}
