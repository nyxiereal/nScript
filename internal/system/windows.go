package system

import (
	"errors"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

// ProcessManager handles Windows process operations with improved safety
type ProcessManager struct {
	processCache map[string]*windows.ProcessEntry32
}

// NewProcessManager creates a new process manager
func NewProcessManager() *ProcessManager {
	return &ProcessManager{
		processCache: make(map[string]*windows.ProcessEntry32),
	}
}

// ProcessInfo contains process information
type ProcessInfo struct {
	Name string
	PID  uint32
}

// ListProcesses returns all running processes with validation
func (pm *ProcessManager) ListProcesses() ([]ProcessInfo, error) {
	snapshot, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return nil, fmt.Errorf("failed to create process snapshot: %v", err)
	}
	defer windows.CloseHandle(snapshot)

	var pe32 windows.ProcessEntry32

	// Validate struct size before using unsafe operations
	if unsafe.Sizeof(pe32) > math.MaxUint32 {
		return nil, errors.New("ProcessEntry32 struct size overflow")
	}
	pe32.Size = uint32(unsafe.Sizeof(pe32))

	if err := windows.Process32First(snapshot, &pe32); err != nil {
		return nil, fmt.Errorf("failed to get first process: %v", err)
	}

	var processes []ProcessInfo
	for {
		exeName := windows.UTF16ToString(pe32.ExeFile[:])
		if exeName != "" { // Validate process name
			processes = append(processes, ProcessInfo{
				Name: exeName,
				PID:  pe32.ProcessID,
			})
		}

		if err := windows.Process32Next(snapshot, &pe32); err != nil {
			break
		}
	}

	return processes, nil
}

// IsProcessRunning checks if a process is running with validation
func (pm *ProcessManager) IsProcessRunning(name string) bool {
	if name == "" {
		return false
	}

	processes, err := pm.ListProcesses()
	if err != nil {
		return false
	}

	name = strings.ToLower(name)
	for _, proc := range processes {
		if strings.ToLower(proc.Name) == name {
			return true
		}
	}

	return false
}

// KillProcess safely terminates a process with confirmation
func (pm *ProcessManager) KillProcess(name string, forceMode bool) error {
	if name == "" {
		return errors.New("process name cannot be empty")
	}

	processes, err := pm.ListProcesses()
	if err != nil {
		return fmt.Errorf("failed to list processes: %v", err)
	}

	name = strings.ToLower(name)
	var killed []uint32

	for _, proc := range processes {
		if strings.ToLower(proc.Name) == name {
			if !forceMode {
				fmt.Printf("[+] Killing process %s (PID: %d)\n", proc.Name, proc.PID)
			}

			handle, err := windows.OpenProcess(windows.PROCESS_TERMINATE, false, proc.PID)
			if err != nil {
				return fmt.Errorf("failed to open process %s (PID: %d): %v", proc.Name, proc.PID, err)
			}

			err = windows.TerminateProcess(handle, 0)
			windows.CloseHandle(handle) // Always close handle

			if err != nil {
				return fmt.Errorf("failed to terminate process %s (PID: %d): %v", proc.Name, proc.PID, err)
			}

			killed = append(killed, proc.PID)
		}
	}

	if len(killed) == 0 {
		return fmt.Errorf("process %s not found", name)
	}

	return nil
}

// GetWindowsVersion returns Windows version information with validation
func GetWindowsVersion() (major, minor, build uint32, err error) {
	version := windows.RtlGetVersion()

	// Validate version information
	if version.MajorVersion == 0 {
		return 0, 0, 0, errors.New("failed to get Windows version")
	}

	return version.MajorVersion, version.MinorVersion, version.BuildNumber, nil
}

// DiskInfo contains disk space information
type DiskInfo struct {
	TotalGB     float64
	UsedGB      float64
	FreeGB      float64
	UsedPercent float64
	FreePercent float64
}

// GetDiskInfo returns disk information for C: drive with validation
func GetDiskInfo() (*DiskInfo, error) {
	kernel32 := windows.NewLazyDLL("kernel32.dll")
	getDiskFreeSpaceEx := kernel32.NewProc("GetDiskFreeSpaceExW")

	var freeBytesAvailable, totalBytes, totalFreeBytes uint64

	drive, err := windows.UTF16PtrFromString("C:\\")
	if err != nil {
		return nil, fmt.Errorf("failed to create drive string: %v", err)
	}

	ret, _, err := getDiskFreeSpaceEx.Call(
		uintptr(unsafe.Pointer(drive)),
		uintptr(unsafe.Pointer(&freeBytesAvailable)),
		uintptr(unsafe.Pointer(&totalBytes)),
		uintptr(unsafe.Pointer(&totalFreeBytes)),
	)

	if ret == 0 {
		return nil, fmt.Errorf("GetDiskFreeSpaceEx failed: %v", err)
	}

	// Validate disk information
	if totalBytes == 0 {
		return nil, errors.New("invalid disk size returned")
	}

	totalGB := float64(totalBytes) / (1024 * 1024 * 1024)
	freeGB := float64(totalFreeBytes) / (1024 * 1024 * 1024)
	usedGB := totalGB - freeGB
	freePercent := (freeGB / totalGB) * 100
	usedPercent := 100 - freePercent

	return &DiskInfo{
		TotalGB:     totalGB,
		UsedGB:      usedGB,
		FreeGB:      freeGB,
		UsedPercent: usedPercent,
		FreePercent: freePercent,
	}, nil
}

// ClearRecycleBin empties the recycle bin with error handling
func ClearRecycleBin() error {
	shell32 := windows.NewLazyDLL("shell32.dll")
	emptyRecycleBin := shell32.NewProc("SHEmptyRecycleBinW")

	ret, _, err := emptyRecycleBin.Call(
		uintptr(0),      // hwnd
		uintptr(0),      // pszRootPath (null = all drives)
		uintptr(0x0007), // SHERB_NOCONFIRMATION | SHERB_NOPROGRESSUI | SHERB_NOSOUND
	)

	if ret != 0 {
		return fmt.Errorf("failed to empty recycle bin: %v", err)
	}

	return nil
}

// RestartExplorer safely restarts Windows Explorer
func RestartExplorer() error {
	pm := NewProcessManager()

	// Kill explorer
	if err := pm.KillProcess("explorer.exe", true); err != nil {
		return fmt.Errorf("failed to kill explorer: %v", err)
	}

	// Wait a moment
	time.Sleep(2 * time.Second)

	// Start explorer
	explorerPath := filepath.Join(os.Getenv("WINDIR"), "explorer.exe")
	cmd := &windows.SysProcAttr{HideWindow: false}
	proc := &os.ProcAttr{
		Files: []*os.File{os.Stdin, os.Stdout, os.Stderr},
		Sys:   cmd,
	}

	_, err := os.StartProcess(explorerPath, []string{}, proc)
	if err != nil {
		return fmt.Errorf("failed to restart explorer: %v", err)
	}

	return nil
}
