$Force = $true

# Variables
$UserHome = $env:USERPROFILE

# Global counter for deleted items
$script:DeletedFileCount = 0
$script:DeletedFolderCount = 0

# Default playbook configuration
$DefaultPlaybook = @{
    configuration = @{
        OnlyRemoveOlderThanHours = 24
        UserDirectories          = @(
            "$UserHome\Downloads",
            "$UserHome\Documents",
            "$UserHome\Desktop",
            "$UserHome\Videos",
            "$UserHome\Music",
            "$UserHome\Pictures",
            "$UserHome\3D Objects",
            "$UserHome\Saved Games",
            "$UserHome\Contacts",
            "$UserHome\Links",
            "$UserHome\Favorites",
            "$UserHome\AppData\Local\Temp",
            "$UserHome\AppData\Roaming\Microsoft\Windows\Recent"
        )
        BrowserInformation       = @{
            "firefox.exe" = @(
                "$UserHome\AppData\Roaming\Mozilla\Firefox\Profiles",
                "$UserHome\AppData\Local\Mozilla\Firefox\Profiles",
                "$UserHome\AppData\Roaming\Mozilla\Firefox\profiles.ini"
            )
            "chrome.exe"  = @(
                "$UserHome\AppData\Local\Google\Chrome\User Data"
            )
            "msedge.exe"  = @(
                "$UserHome\AppData\Local\Microsoft\Edge\User Data"
            )
            "opera.exe"   = @(
                "$UserHome\AppData\Roaming\Opera Software",
                "$UserHome\AppData\Local\Opera Software"
            )
        }
        # Extensions to exclude from deletion
        ExcludedExtensions       = @(
            ".iso", ".vdi", ".sav", ".vbox", ".vbox-prev",
            ".vmdk", ".vhd", ".hdd", ".nvram", ".ova",
            ".ovf", ".vbox-extpack", ".vhdx", ".qcow2", ".img", ".lnk"
        )
    }
}

# Check if a file is in use
function Test-FileInUse {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) { return $false }
    
    try {
        $file = [System.IO.File]::Open($FilePath, 'Open', 'Write')
        $file.Close()
        return $false
    }
    catch {
        return $true
    }
}

# Remove empty directories recursively
function Remove-EmptyDirectories {
    param (
        [string[]]$Directories,
        [string[]]$ExcludedExtensions
    )
    
    Write-Host "[*] Scanning for empty directories..."
    
    foreach ($dir in $Directories) {
        $expandedDir = $ExecutionContext.InvokeCommand.ExpandString($dir)
        
        if (-not (Test-Path $expandedDir)) {
            continue
        }
        
        # Get all subdirectories recursively
        $allDirs = @(Get-ChildItem -Path $expandedDir -Directory -Recurse -Force -ErrorAction SilentlyContinue)
        
        # Process from deepest to shallowest
        $allDirs | Sort-Object -Property FullName -Descending | ForEach-Object {
            try {
                $items = @(Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue)
                
                if ($items.Count -eq 0) {
                    Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                    $script:DeletedFolderCount++
                    Write-Host "[+] Removed empty directory: $($_.FullName)" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "[-] Failed to remove empty directory $($_.FullName): $_" -ForegroundColor Red
            }
        }
    }
}

# Check if item should be excluded
function Test-ShouldExclude {
    param(
        [System.IO.FileSystemInfo]$Item,
        [string[]]$ExcludedExtensions
    )
    
    # If it's a file, check its extension
    if (-not $Item.PSIsContainer) {
        $extension = $Item.Extension.ToLower()
        if ($ExcludedExtensions -contains $extension) {
            return $true
        }
    }
    
    return $false
}

# Remove old user files/directories
# Remove old user files/directories
function Remove-OldUserDirectories {
    param (
        [string[]]$Directories,
        [int]$OlderThanHours,
        [string[]]$ExcludedExtensions,
        [bool]$ForceMode
    )
    
    if ($ForceMode) {
        Write-Host "[!] FORCE MODE ENABLED - Removing ALL files regardless of age, but respecting exclusions" -ForegroundColor Yellow
    }
    else {
        Write-Host "[*] Scanning directories, removing files older than $OlderThanHours hours"
    }
    
    foreach ($dir in $Directories) {
        $expandedDir = $ExecutionContext.InvokeCommand.ExpandString($dir)
        
        if (-not (Test-Path $expandedDir)) {
            Write-Host "[*] Directory does not exist: $expandedDir"
            continue
        }
        
        Write-Host "[*] Checking directory: $expandedDir"
        # Get all items recursively
        $items = Get-ChildItem -Path $expandedDir -Recurse -Force -ErrorAction SilentlyContinue
        
        # Sort by depth (deepest first) so we delete files before their parent folders
        $items = $items | Sort-Object { $_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count } -Descending
        
        foreach ($item in $items) {
            try {
                # Check if file should be excluded (always, regardless of force mode)
                if (Test-ShouldExclude -Item $item -ExcludedExtensions $ExcludedExtensions) {
                    Write-Host "[*] Skipping excluded file: $($item.FullName) ($($item.Extension))"
                    continue
                }
                
                $ageHours = ((Get-Date) - $item.LastWriteTime).TotalHours
                
                # In force mode, ignore age check
                if ($ForceMode -or $ageHours -gt $OlderThanHours) {
                    # Skip if it's a directory with excluded files
                    if ($item.PSIsContainer) {
                        $hasExcludedFiles = Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue | 
                        Where-Object { -not $_.PSIsContainer -and $ExcludedExtensions -contains $_.Extension.ToLower() }
                        
                        if ($hasExcludedFiles) {
                            Write-Host "[*] Skipping folder with excluded files: $($item.FullName)" -ForegroundColor Yellow
                            continue
                        }
                    }
                    
                    if (-not $item.PSIsContainer -and (Test-FileInUse -FilePath $item.FullName)) {
                        Write-Host "[!] File in use, skipping: $($item.FullName)" -ForegroundColor Yellow
                        continue
                    }
                    
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                    
                    # Increment counters
                    if ($item.PSIsContainer) {
                        $script:DeletedFolderCount++
                    }
                    else {
                        $script:DeletedFileCount++
                    }
                    
                    Write-Host "[+] Removed: $($item.FullName) (Age: $([math]::Round($ageHours, 1))h)" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "[-] Failed to remove $($item.FullName): $_" -ForegroundColor Red
            }
        }
    }
}

# Remove browsing data from a browser if it is not currently running
function Remove-BrowserDataIfNotRunning {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$BrowserInfo,
        [bool]$ForceMode
    )
    
    Write-Host "[*] Checking browser data..."
    
    foreach ($proc in $BrowserInfo.Keys) {
        if (-not $proc) { continue }
        
        Write-Host "[*] Checking process: $proc"
        $procRunning = Get-Process -Name ($proc -replace '.exe$', '') -ErrorAction SilentlyContinue
        
        if ($procRunning -and $ForceMode) {
            Write-Host "[!] FORCE MODE: Killing process $proc" -ForegroundColor Yellow
            try {
                Stop-Process -Name ($proc -replace '.exe$', '') -Force -ErrorAction Stop
                Write-Host "[+] Killed process $proc" -ForegroundColor Green
                Write-Host "[*] Waiting 3 seconds for cleanup..."
                Start-Sleep -Seconds 3
            }
            catch {
                Write-Host "[-] Failed to kill process $proc : $_" -ForegroundColor Red
            }
        }
        elseif ($procRunning) {
            Write-Host "[!] Process $proc is running, skipping" -ForegroundColor Yellow
            continue
        }
        
        Write-Host "[*] Process $proc not running, removing data"
        
        foreach ($dir in $BrowserInfo[$proc]) {
            $maxRetries = if ($ForceMode) { 2 } else { 1 }
            $attempt = 0
            $success = $false
            
            while ($attempt -lt $maxRetries -and -not $success) {
                $attempt++
                
                try {
                    $expandedDir = $ExecutionContext.InvokeCommand.ExpandString($dir)
                    
                    if (-not (Test-Path $expandedDir)) {
                        Write-Host "[*] Path does not exist: $expandedDir"
                        $success = $true
                        break
                    }
                    
                    $item = Get-Item $expandedDir
                    $ageHours = ((Get-Date) - $item.LastWriteTime).TotalHours
                    
                    # In force mode, ignore age check
                    if (-not $ForceMode -and $ageHours -lt 24) {
                        Write-Host "[!] Skipping $expandedDir (only $([math]::Round($ageHours, 1))h old)" -ForegroundColor Yellow
                        $success = $true
                        break
                    }
                    
                    if ($attempt -gt 1) {
                        Write-Host "[*] Retry attempt $attempt for: $expandedDir"
                        Start-Sleep -Seconds 3
                    }
                    
                    Remove-Item -Path $expandedDir -Recurse -Force -ErrorAction Stop
                    $script:DeletedFolderCount++
                    Write-Host "[+] Removed: $expandedDir" -ForegroundColor Green
                    $success = $true
                }
                catch {
                    if ($attempt -ge $maxRetries) {
                        Write-Host "[-] Failed to remove after $maxRetries attempts: $expandedDir : $_" -ForegroundColor Red
                    }
                    else {
                        Write-Host "[-] Attempt $attempt failed for $expandedDir : $_" -ForegroundColor Red
                    }
                }
            }
        }
    }
}

# Get disk information
function Get-DiskInfo {
    param([string]$DriveLetter = "C:")
    
    try {
        # Get disk usage
        $drive = Get-PSDrive -Name ($DriveLetter -replace ':', '') -ErrorAction Stop
        $totalGB = [math]::Round($drive.Free / 1GB + $drive.Used / 1GB, 2)
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        $usedGB = [math]::Round($drive.Used / 1GB, 2)
        $freePercent = [math]::Round(($drive.Free / ($drive.Free + $drive.Used)) * 100, 2)
        $usedPercent = [math]::Round(100 - $freePercent, 2)
        
        # Get disk type (SSD/HDD)
        $physicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq 0 } | Select-Object -First 1
        $diskType = if ($physicalDisk) { $physicalDisk.MediaType } else { "Unknown" }
        
        return @{
            TotalGB     = $totalGB
            FreeGB      = $freeGB
            UsedGB      = $usedGB
            FreePercent = $freePercent
            UsedPercent = $usedPercent
            DiskType    = $diskType
        }
    }
    catch {
        Write-Host "[-] Error getting disk info: $_" -ForegroundColor Red
        return $null
    }
}

# Main program
try {
    Write-Host "[*] Starting nScript v1.0.1"
    
    if ($Force) {
        Write-Host "[!] WARNING: Force mode enabled - all files will be removed!" -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
    
    $playbook = $DefaultPlaybook
    
    if ($playbook.configuration.UserDirectories) {
        Remove-OldUserDirectories `
            -Directories $playbook.configuration.UserDirectories `
            -OlderThanHours $playbook.configuration.OnlyRemoveOlderThanHours `
            -ExcludedExtensions $playbook.configuration.ExcludedExtensions `
            -ForceMode $Force
    }
    
    if ($playbook.configuration.BrowserInformation) {
        Remove-BrowserDataIfNotRunning `
            -BrowserInfo $playbook.configuration.BrowserInformation `
            -ForceMode $Force
    }
    
    # Remove empty directories
    Remove-EmptyDirectories `
        -Directories $playbook.configuration.UserDirectories `
        -ExcludedExtensions $playbook.configuration.ExcludedExtensions
    
    # Empty the recycle bin
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Host "[+] Recycle bin emptied" -ForegroundColor Green
    }
    catch {
        Write-Host "[-] Failed to empty recycle bin: $_" -ForegroundColor Red
    }
    
    Write-Host "`n[+] nScript completed" -ForegroundColor Green
    Write-Host "[*] ============================================"
    Write-Host "[*] Deletion Summary:"
    Write-Host "[*] >  Files deleted: $script:DeletedFileCount"
    Write-Host "[*] >  Folders deleted: $script:DeletedFolderCount"
    Write-Host "[*] >  Total items deleted: $($script:DeletedFileCount + $script:DeletedFolderCount)"
    
    $diskInfo = Get-DiskInfo
    if ($diskInfo) {
        Write-Host "[*] ============================================"
        Write-Host "[*] Disk Information (C:):"
        Write-Host "[*] >  Total: $($diskInfo.TotalGB) GB"
        Write-Host "[*] >  Used: $($diskInfo.UsedGB) GB ($($diskInfo.UsedPercent)%)"
        Write-Host "[*] >  Free: $($diskInfo.FreeGB) GB ($($diskInfo.FreePercent)%)"
        Write-Host "[*] >  Disk Type: $($diskInfo.DiskType)"
    }
    Write-Host "[*] ============================================"
    Write-Host "[*] Made by Nyx :3 https://nyx.meowery.eu/"
    Write-Host "[*] ============================================"
}
catch {
    Write-Host "[-] Critical error: $_" -ForegroundColor Red
    exit 1
}