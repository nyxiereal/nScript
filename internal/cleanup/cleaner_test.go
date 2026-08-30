package cleanup

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestStreamingCleanDirectories(t *testing.T) {
	root := t.TempDir()
	oldDir := filepath.Join(root, "old")
	if err := os.Mkdir(oldDir, 0o755); err != nil {
		t.Fatal(err)
	}

	oldFile := filepath.Join(oldDir, "delete.txt")
	newFile := filepath.Join(root, "keep.txt")
	excludedFile := filepath.Join(root, "keep.iso")
	for _, path := range []string{oldFile, newFile, excludedFile} {
		if err := os.WriteFile(path, []byte("test"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	oldTime := time.Now().Add(-48 * time.Hour)
	if err := os.Chtimes(oldFile, oldTime, oldTime); err != nil {
		t.Fatal(err)
	}

	cleaner := NewCleaner()
	if err := cleaner.StreamingCleanDirectories([]string{root}, 24*time.Hour, []string{".iso"}, false); err != nil {
		t.Fatal(err)
	}

	if _, err := os.Stat(oldFile); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("old file was not deleted: %v", err)
	}
	if _, err := os.Stat(oldDir); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("empty directory was not deleted: %v", err)
	}
	for _, path := range []string{newFile, excludedFile} {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("preserved file %s: %v", path, err)
		}
	}
}
