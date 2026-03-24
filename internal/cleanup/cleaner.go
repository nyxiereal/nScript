package cleanup

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"nScript/internal/config"
	"nScript/internal/system"
)

// Stats tracks cleanup statistics
type Stats struct {
	DeletedFiles   atomic.Int64
	DeletedFolders atomic.Int64
	SkippedFiles   atomic.Int64
	FailedFiles    atomic.Int64
}

// Cleaner handles file and directory cleanup operations
type Cleaner struct {
	stats           *Stats
	processManager  *system.ProcessManager
	registryManager *system.RegistryManager
	semaphore       chan struct{}
}

// NewCleaner creates a new cleaner instance
func NewCleaner() *Cleaner {
	return &Cleaner{
		stats:           &Stats{},
		processManager:  system.NewProcessManager(),
		registryManager: system.NewRegistryManager(),
		semaphore:       make(chan struct{}, config.MaxConcurrentOps),
	}
}

// GetStats returns current cleanup statistics
func (c *Cleaner) GetStats() *Stats {
	return c.stats
}

// ValidatePath ensures a path is safe to operate on
func (c *Cleaner) ValidatePath(path string) error {
	if path == "" {
		return errors.New("path cannot be empty")
	}

	// Prevent operations on system critical paths
	criticalPaths := []string{
		"C:\\Windows\\System32",
		"C:\\Windows\\SysWOW64",
		"C:\\Program Files\\Windows NT",
		"C:\\Program Files (x86)\\Windows NT",
	}

	cleanPath := filepath.Clean(path)
	for _, critical := range criticalPaths {
		if strings.HasPrefix(strings.ToLower(cleanPath), strings.ToLower(critical)) {
			return fmt.Errorf("cannot operate on critical system path: %s", path)
		}
	}

	return nil
}

// IsFileAccessible checks if a file can be opened for writing (improved naming)
func (c *Cleaner) IsFileAccessible(path string) bool {
	file, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return false
	}
	file.Close()
	return true
}

// ShouldExclude checks if a file should be excluded based on extension and keywords
func (c *Cleaner) ShouldExclude(path string, excludedExts []string) bool {
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

// SortByDepth sorts paths by depth (deepest first) using efficient O(n log n) algorithm
func (c *Cleaner) SortByDepth(paths []string) {
	sort.Slice(paths, func(i, j int) bool {
		return strings.Count(paths[j], string(filepath.Separator)) >
			strings.Count(paths[i], string(filepath.Separator))
	})
}

// ProcessItemsBatch processes a batch of items for cleanup
func (c *Cleaner) ProcessItemsBatch(items []string, olderThan time.Duration, excludedExts []string, forceMode bool) {
	var wg sync.WaitGroup

	for _, item := range items {
		if err := c.ValidatePath(item); err != nil {
			fmt.Printf("[-] Skipping invalid path %s: %v\n", item, err)
			c.stats.SkippedFiles.Add(1)
			continue
		}

		wg.Add(1)
		c.semaphore <- struct{}{} // Acquire semaphore

		go func(path string) {
			defer wg.Done()
			defer func() { <-c.semaphore }() // Release semaphore

			c.processItem(path, olderThan, excludedExts, forceMode)
		}(item)
	}

	wg.Wait()
}

// processItem processes a single item
func (c *Cleaner) processItem(path string, olderThan time.Duration, excludedExts []string, forceMode bool) {
	info, err := os.Stat(path)
	if err != nil {
		c.stats.FailedFiles.Add(1)
		return
	}

	if c.ShouldExclude(path, excludedExts) {
		c.stats.SkippedFiles.Add(1)
		return
	}

	ageHours := time.Since(info.ModTime())

	if forceMode || ageHours > olderThan {
		if info.IsDir() {
			// Check if directory contains excluded files
			hasExcluded := false
			filepath.Walk(path, func(p string, i os.FileInfo, e error) error {
				if e != nil || i.IsDir() {
					return nil
				}
				if c.ShouldExclude(p, excludedExts) {
					hasExcluded = true
					return filepath.SkipDir
				}
				return nil
			})
			if hasExcluded {
				c.stats.SkippedFiles.Add(1)
				return
			}
		} else if !c.IsFileAccessible(path) {
			c.stats.SkippedFiles.Add(1)
			return
		}

		err = os.RemoveAll(path)
		if err == nil {
			if info.IsDir() {
				c.stats.DeletedFolders.Add(1)
			} else {
				c.stats.DeletedFiles.Add(1)
			}
		} else {
			c.stats.FailedFiles.Add(1)
		}
	}
}

// StreamingCleanDirectories processes directories with streaming to reduce memory usage
func (c *Cleaner) StreamingCleanDirectories(directories []string, olderThan time.Duration, excludedExts []string, forceMode bool) error {
	if forceMode {
		fmt.Println("[!] Removing ALL files regardless of age...")
	} else {
		fmt.Printf("[*] Scanning directories, removing files older than %.0f hours...\n", olderThan.Hours())
	}

	for _, dir := range directories {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue
		}

		if err := c.ValidatePath(dir); err != nil {
			fmt.Printf("[-] Skipping invalid directory %s: %v\n", dir, err)
			continue
		}

		err := c.processDirectoryStreaming(dir, olderThan, excludedExts, forceMode)
		if err != nil {
			fmt.Printf("[-] Error processing directory %s: %v\n", dir, err)
		}
	}

	return nil
}

// processDirectoryStreaming processes a directory in streaming fashion
func (c *Cleaner) processDirectoryStreaming(dir string, olderThan time.Duration, excludedExts []string, forceMode bool) error {
	batch := make([]string, 0, config.MaxBatchSize)

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Continue walking despite errors
		}

		if path != dir {
			batch = append(batch, path)

			// Process batch when it's full
			if len(batch) >= config.MaxBatchSize {
				c.SortByDepth(batch)
				c.ProcessItemsBatch(batch, olderThan, excludedExts, forceMode)
				batch = batch[:0] // Reset batch
			}
		}

		return nil
	})

	// Process remaining items in batch
	if len(batch) > 0 {
		c.SortByDepth(batch)
		c.ProcessItemsBatch(batch, olderThan, excludedExts, forceMode)
	}

	return err
}

// RemoveEmptyDirectories removes empty directories with streaming
func (c *Cleaner) RemoveEmptyDirectories(directories []string) error {
	fmt.Println("[*] Scanning for empty directories...")

	for _, dir := range directories {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue
		}

		if err := c.ValidatePath(dir); err != nil {
			fmt.Printf("[-] Skipping invalid directory %s: %v\n", dir, err)
			continue
		}

		err := c.processEmptyDirectoriesStreaming(dir)
		if err != nil {
			fmt.Printf("[-] Error processing empty directories in %s: %v\n", dir, err)
		}
	}

	return nil
}

// processEmptyDirectoriesStreaming processes empty directories in batches
func (c *Cleaner) processEmptyDirectoriesStreaming(dir string) error {
	batch := make([]string, 0, config.MaxBatchSize)

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil || !info.IsDir() || path == dir {
			return nil
		}

		batch = append(batch, path)

		// Process batch when it's full
		if len(batch) >= config.MaxBatchSize {
			c.SortByDepth(batch)
			c.processEmptyDirectoryBatch(batch)
			batch = batch[:0] // Reset batch
		}

		return nil
	})

	// Process remaining directories
	if len(batch) > 0 {
		c.SortByDepth(batch)
		c.processEmptyDirectoryBatch(batch)
	}

	return err
}

// processEmptyDirectoryBatch processes a batch of empty directories
func (c *Cleaner) processEmptyDirectoryBatch(directories []string) {
	var wg sync.WaitGroup

	for _, dirPath := range directories {
		wg.Add(1)
		c.semaphore <- struct{}{}

		go func(path string) {
			defer wg.Done()
			defer func() { <-c.semaphore }()

			entries, err := os.ReadDir(path)
			if err == nil && len(entries) == 0 {
				if err := os.Remove(path); err == nil {
					c.stats.DeletedFolders.Add(1)
				}
			}
		}(dirPath)
	}

	wg.Wait()
}

// CleanBrowserData removes browser data if browsers aren't running
func (c *Cleaner) CleanBrowserData(browserInfo map[string][]string, forceMode bool) error {
	fmt.Println("[*] Checking browser data...")

	var wg sync.WaitGroup

	for proc, dirs := range browserInfo {
		wg.Add(1)
		go func(processName string, directories []string) {
			defer wg.Done()

			running := c.processManager.IsProcessRunning(processName)

			if running && forceMode {
				if err := c.processManager.KillProcess(processName, true); err != nil {
					fmt.Printf("[-] Failed to kill %s: %v\n", processName, err)
					return
				}
				fmt.Printf("[+] Killed %s\n", processName)
				time.Sleep(1 * time.Second)
			} else if running {
				return
			}

			c.cleanBrowserDirectories(processName, directories, forceMode)
		}(proc, dirs)
	}

	wg.Wait()
	return nil
}

// cleanBrowserDirectories cleans browser directories
func (c *Cleaner) cleanBrowserDirectories(processName string, directories []string, forceMode bool) {
	var wg sync.WaitGroup

	for _, dir := range directories {
		if err := c.ValidatePath(dir); err != nil {
			fmt.Printf("[-] Skipping invalid browser directory %s: %v\n", dir, err)
			continue
		}

		wg.Add(1)
		c.semaphore <- struct{}{}

		go func(d string) {
			defer wg.Done()
			defer func() { <-c.semaphore }()

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

	wg.Wait()
}
