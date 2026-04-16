package ui

import (
	"fmt"
	"sync/atomic"
	"time"

	"nScript/internal/cleanup"
	"nScript/internal/config"
	"nScript/internal/system"
)

// ProgressTracker handles progress reporting
type ProgressTracker struct {
	stats    *cleanup.Stats
	stopFlag atomic.Bool
	label    string
}

// NewProgressTracker creates a new progress tracker
func NewProgressTracker(stats *cleanup.Stats) *ProgressTracker {
	return &ProgressTracker{
		stats: stats,
	}
}

// StartProgress starts progress reporting and returns a stop function
func (pt *ProgressTracker) StartProgress(label string) func() {
	pt.label = label
	pt.stopFlag.Store(false)
	done := make(chan struct{})

	go func() {
		ticker := time.NewTicker(config.UpdateInterval)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				if pt.stopFlag.Load() {
					return
				}
				files := pt.stats.DeletedFiles.Load()
				folders := pt.stats.DeletedFolders.Load()
				skipped := pt.stats.SkippedFiles.Load()
				failed := pt.stats.FailedFiles.Load()
				fmt.Printf("\r[*] %s | Files: %d | Folders: %d | Skipped: %d | Failed: %d",
					pt.label, files, folders, skipped, failed)
			case <-done:
				return
			}
		}
	}()

	return func() {
		pt.stopFlag.Store(true)
		done <- struct{}{}
		close(done)
		fmt.Println()
	}
}

// PrintHeader displays the application header
func PrintHeader(version string, forceMode bool) {
	versionStr := version
	if forceMode {
		versionStr += "-force"
	}

	fmt.Printf("[*] Starting nScript v%s\n", versionStr)

	if forceMode {
		fmt.Println("[!] Force mode enabled - all files will be removed!")
		fmt.Println("[!] WARNING: This will delete files regardless of age!")
		fmt.Println("[!] Make sure you have backups of important data!")
		time.Sleep(3 * time.Second)
	}
}

// PrintStats displays cleanup statistics
func PrintStats(stats *cleanup.Stats, elapsed time.Duration, diskInfo *system.DiskInfo) {
	fmt.Println("\n[+] nScript completed")
	fmt.Println("[*] ============================================")
	fmt.Println("[*] Deletion Summary:")
	fmt.Printf("[*]    Files deleted: %d\n", stats.DeletedFiles.Load())
	fmt.Printf("[*]    Folders deleted: %d\n", stats.DeletedFolders.Load())
	fmt.Printf("[*]    Files skipped: %d\n", stats.SkippedFiles.Load())
	fmt.Printf("[*]    Failed operations: %d\n", stats.FailedFiles.Load())
	fmt.Printf("[*]    Total items deleted: %d\n", stats.DeletedFiles.Load()+stats.DeletedFolders.Load())
	fmt.Printf("[*]    Time taken: %.2f seconds\n", elapsed.Seconds())

	if diskInfo != nil {
		fmt.Println("[*] ============================================")
		fmt.Println("[*] Disk Information (C:):")
		fmt.Printf("[*]    Total: %.2f GB\n", diskInfo.TotalGB)
		fmt.Printf("[*]    Used: %.2f GB (%.2f%%)\n", diskInfo.UsedGB, diskInfo.UsedPercent)
		fmt.Printf("[*]    Free: %.2f GB (%.2f%%)\n", diskInfo.FreeGB, diskInfo.FreePercent)
	}
}

// PrintClosingMessage displays the closing message
func PrintClosingMessage() {
	fmt.Println("[*] ============================================")
	fmt.Println("[*] Made by Nyx :3 https://nyx.meowery.eu/")
	fmt.Println("[*] ============================================")
	fmt.Print("[*] Closing in 3s...")
	time.Sleep(1 * time.Second)
	fmt.Print(" 2s...")
	time.Sleep(1 * time.Second)
	fmt.Print(" 1s...")
	time.Sleep(1 * time.Second)
	fmt.Println()
}

// ShowBackupInfo displays information about registry backups
func ShowBackupInfo(backupDir string) {
	fmt.Printf("[*] Registry backups created in: %s\n", backupDir)
	fmt.Println("[*] You can restore registry keys from backups if needed")
}
