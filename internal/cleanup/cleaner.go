package cleanup

import (
	"errors"
	"fmt"
	"io/fs"
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

// Stats tracks cleanup statistics.
type Stats struct {
	DeletedFiles   atomic.Int64
	DeletedFolders atomic.Int64
	SkippedFiles   atomic.Int64
	FailedFiles    atomic.Int64
}

// Cleaner handles file and directory cleanup operations.
type Cleaner struct {
	stats          *Stats
	processManager *system.ProcessManager
	semaphore      chan struct{}
}

// NewCleaner creates a new cleaner instance.
func NewCleaner() *Cleaner {
	return &Cleaner{
		stats:          &Stats{},
		processManager: system.NewProcessManager(),
		semaphore:      make(chan struct{}, config.MaxConcurrentOps),
	}
}

// GetStats returns current cleanup statistics.
func (c *Cleaner) GetStats() *Stats {
	return c.stats
}

// ValidatePath ensures a path is safe to operate on.
func (c *Cleaner) ValidatePath(path string) error {
	if path == "" {
		return errors.New("path cannot be empty")
	}

	cleanPath := filepath.Clean(path)
	if !filepath.IsAbs(cleanPath) {
		return fmt.Errorf("path must be absolute: %s", path)
	}

	criticalPaths := []string{
		`C:\Windows\System32`,
		`C:\Windows\SysWOW64`,
		`C:\Program Files\Windows NT`,
		`C:\Program Files (x86)\Windows NT`,
	}
	lowerPath := strings.ToLower(cleanPath)
	for _, critical := range criticalPaths {
		lowerCritical := strings.ToLower(filepath.Clean(critical))
		if lowerPath == lowerCritical || strings.HasPrefix(lowerPath, lowerCritical+string(filepath.Separator)) {
			return fmt.Errorf("cannot operate on critical system path: %s", path)
		}
	}

	return nil
}

var allowedDeletionKeywords = []string{"roblox", "paradox", "opera", "discord", "osu", "steam", "epic games"}

// ShouldExclude checks if a file should be excluded based on extension and keywords.
func (c *Cleaner) ShouldExclude(path string, excludedExts []string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	for _, excluded := range excludedExts {
		if ext != excluded {
			continue
		}

		lowerName := strings.ToLower(filepath.Base(path))
		for _, keyword := range allowedDeletionKeywords {
			if strings.Contains(lowerName, keyword) {
				fmt.Printf("\n[*] Allowing deletion of excluded extension with '%s' in name: %s\n", keyword, path)
				return false
			}
		}
		return true
	}
	return false
}

type cleanupItem struct {
	path    string
	modTime time.Time
}

func (c *Cleaner) processItemsBatch(items []cleanupItem, olderThan time.Duration, excludedExts []string, forceMode bool) error {
	var wg sync.WaitGroup
	errCh := make(chan error, len(items))

	for _, item := range items {
		wg.Add(1)
		c.semaphore <- struct{}{}

		go func(item cleanupItem) {
			defer wg.Done()
			defer func() { <-c.semaphore }()

			if c.ShouldExclude(item.path, excludedExts) || (!forceMode && time.Since(item.modTime) <= olderThan) {
				c.stats.SkippedFiles.Add(1)
				return
			}

			if err := os.Remove(item.path); err != nil {
				c.stats.FailedFiles.Add(1)
				errCh <- fmt.Errorf("remove %s: %w", item.path, err)
				return
			}
			c.stats.DeletedFiles.Add(1)
		}(item)
	}

	wg.Wait()
	close(errCh)

	var errs []error
	for err := range errCh {
		errs = append(errs, err)
	}
	return errors.Join(errs...)
}

// StreamingCleanDirectories removes eligible files in one traversal per root,
// then removes directories that became empty.
func (c *Cleaner) StreamingCleanDirectories(directories []string, olderThan time.Duration, excludedExts []string, forceMode bool) error {
	if forceMode {
		fmt.Println("[!] Removing ALL non-excluded files...")
	} else {
		fmt.Printf("[*] Scanning directories, removing files older than %.0f hours...\n", olderThan.Hours())
	}

	var errs []error
	for _, dir := range directories {
		if err := c.ValidatePath(dir); err != nil {
			c.stats.SkippedFiles.Add(1)
			errs = append(errs, err)
			continue
		}

		if _, err := os.Lstat(dir); errors.Is(err, fs.ErrNotExist) {
			continue
		} else if err != nil {
			c.stats.FailedFiles.Add(1)
			errs = append(errs, fmt.Errorf("inspect %s: %w", dir, err))
			continue
		}

		if err := c.processDirectoryStreaming(dir, olderThan, excludedExts, forceMode); err != nil {
			errs = append(errs, fmt.Errorf("clean %s: %w", dir, err))
		}
	}

	return errors.Join(errs...)
}

func (c *Cleaner) processDirectoryStreaming(root string, olderThan time.Duration, excludedExts []string, forceMode bool) error {
	rootInfo, err := os.Lstat(root)
	if err != nil {
		return err
	}
	if !rootInfo.IsDir() {
		return c.processItemsBatch([]cleanupItem{{path: root, modTime: rootInfo.ModTime()}}, olderThan, excludedExts, forceMode)
	}

	batch := make([]cleanupItem, 0, config.MaxBatchSize)
	var directories []string
	var errs []error

	flush := func() {
		if len(batch) == 0 {
			return
		}
		if err := c.processItemsBatch(batch, olderThan, excludedExts, forceMode); err != nil {
			errs = append(errs, err)
		}
		batch = batch[:0]
	}

	walkErr := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			c.stats.FailedFiles.Add(1)
			errs = append(errs, fmt.Errorf("walk %s: %w", path, walkErr))
			return nil
		}
		if path == root {
			return nil
		}
		if entry.IsDir() {
			directories = append(directories, path)
			return nil
		}

		var modTime time.Time
		if !forceMode {
			info, err := entry.Info()
			if err != nil {
				c.stats.FailedFiles.Add(1)
				errs = append(errs, fmt.Errorf("inspect %s: %w", path, err))
				return nil
			}
			modTime = info.ModTime()
		}

		batch = append(batch, cleanupItem{path: path, modTime: modTime})
		if len(batch) == config.MaxBatchSize {
			flush()
		}
		return nil
	})
	flush()
	if walkErr != nil {
		errs = append(errs, walkErr)
	}

	// Reverse lexical order puts every child before its parent.
	sort.Sort(sort.Reverse(sort.StringSlice(directories)))
	for _, path := range directories {
		if err := os.Remove(path); err == nil {
			c.stats.DeletedFolders.Add(1)
		} else if !errors.Is(err, fs.ErrNotExist) {
			entries, readErr := os.ReadDir(path)
			if readErr != nil || len(entries) == 0 {
				c.stats.FailedFiles.Add(1)
				errs = append(errs, fmt.Errorf("remove directory %s: %w", path, err))
			}
		}
	}

	return errors.Join(errs...)
}

// CleanBrowserData removes browser data if browsers aren't running.
func (c *Cleaner) CleanBrowserData(browserInfo map[string][]string, forceMode bool) error {
	fmt.Println("[*] Checking browser data...")

	processes, err := c.processManager.ListProcesses()
	if err != nil {
		return err
	}
	running := make(map[string]bool, len(processes))
	for _, process := range processes {
		running[strings.ToLower(process.Name)] = true
	}

	var wg sync.WaitGroup
	errCh := make(chan error, len(browserInfo))
	for processName, directories := range browserInfo {
		wg.Add(1)
		go func(processName string, directories []string) {
			defer wg.Done()

			if running[strings.ToLower(processName)] {
				if !forceMode {
					return
				}
				if err := c.processManager.KillProcess(processName, true); err != nil {
					errCh <- fmt.Errorf("kill %s: %w", processName, err)
					return
				}
				fmt.Printf("[+] Killed %s\n", processName)
				time.Sleep(time.Second)
			}

			if err := c.cleanBrowserDirectories(directories, forceMode); err != nil {
				errCh <- fmt.Errorf("clean %s data: %w", processName, err)
			}
		}(processName, directories)
	}

	wg.Wait()
	close(errCh)

	var errs []error
	for err := range errCh {
		errs = append(errs, err)
	}
	return errors.Join(errs...)
}

func (c *Cleaner) cleanBrowserDirectories(directories []string, forceMode bool) error {
	var wg sync.WaitGroup
	errCh := make(chan error, len(directories))
	seen := make(map[string]struct{}, len(directories))

	for _, dir := range directories {
		if _, duplicate := seen[dir]; duplicate {
			continue
		}
		seen[dir] = struct{}{}

		if err := c.ValidatePath(dir); err != nil {
			errCh <- err
			continue
		}

		wg.Add(1)
		c.semaphore <- struct{}{}
		go func(path string) {
			defer wg.Done()
			defer func() { <-c.semaphore }()

			maxRetries := 1
			if forceMode {
				maxRetries = 2
			}
			for attempt := 1; attempt <= maxRetries; attempt++ {
				if attempt > 1 {
					time.Sleep(time.Second)
				}
				if err := os.RemoveAll(path); err == nil {
					return
				} else if attempt == maxRetries {
					c.stats.FailedFiles.Add(1)
					errCh <- fmt.Errorf("remove %s: %w", path, err)
				}
			}
		}(dir)
	}

	wg.Wait()
	close(errCh)

	var errs []error
	for err := range errCh {
		errs = append(errs, err)
	}
	return errors.Join(errs...)
}
