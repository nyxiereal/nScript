param(
    [switch]$Force
)

# Variables
$UserHome = $env:USERPROFILE

# Global counter for deleted items
$script:DeletedFileCount = 0
$script:DeletedFolderCount = 0

# Default configuration
$Configuration = @{
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
            "$UserHome\AppData\Roaming\Microsoft\Windows\Recent",
            "$UserHome\AppData\Local\Low\Microsoft\Internet Explorer",
            "$UserHome\AppData\Local\Microsoft\Windows\INetCache",
            "$UserHome\AppData\Local\Microsoft\Windows\INetCookies",
            "$UserHome\AppData\Roaming\Microsoft\Office\Recent",
            "$UserHome\AppData\Local\Microsoft\Windows\Clipboard",
            "$UserHome\.cache",
            "$UserHome\AppData\Local\Roblox",
            "$UserHome\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Roblox"
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
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
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
            # Allow deletion if filename contains "roblox" (case-insensitive)
            if ($Item.Name -match "roblox") {
                Write-Host "[*] Allowing deletion of excluded extension with 'roblox' in name: $($Item.FullName)" -ForegroundColor Cyan
                return $false
            }
            return $true
        }
    }
    
    return $false
}

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
        $items = Get-ChildItem -Path $expandedDir -Recurse -Force -ErrorAction SilentlyContinue
        $items = $items | Sort-Object { $_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count } -Descending

        foreach ($item in $items) {
            try {
                if (Test-ShouldExclude -Item $item -ExcludedExtensions $ExcludedExtensions) {
                    Write-Host "[*] Skipping excluded file: $($item.FullName) ($($item.Extension))"
                    continue
                }

                $ageHours = ((Get-Date) - $item.LastWriteTime).TotalHours

                if ($ForceMode -or $ageHours -gt $OlderThanHours) {
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

                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue

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
                Stop-Process -Name ($proc -replace '.exe$', '') -Force -ErrorAction SilentlyContinue
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

                    if (-not $ForceMode -and $ageHours -lt 24) {
                        Write-Host "[!] Skipping $expandedDir (only $([math]::Round($ageHours, 1))h old)" -ForegroundColor Yellow
                        $success = $true
                        break
                    }

                    if ($attempt -gt 1) {
                        Write-Host "[*] Retry attempt $attempt for: $expandedDir"
                        Start-Sleep -Seconds 3
                    }

                    Remove-Item -Path $expandedDir -Recurse -Force -ErrorAction SilentlyContinue
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

# Unpin all Start Menu tiles
function Clear-StartMenuTiles {
    Write-Host "[*] Unpinning all Start Menu tiles..."
    
    try {
        # Method 1: Clear via PowerShell cmdlet (Windows 10 1809+)
        if (Get-Command Get-StartApps -ErrorAction SilentlyContinue) {
            Write-Host "[*] Using Get-StartApps method..."
            $pinnedApps = Get-StartApps | Where-Object { $null -ne $_.AppID }
            
            foreach ($app in $pinnedApps) {
                try {
                    # Remove from Start using AppX
                    $package = Get-AppxPackage | Where-Object { $_.Name -like "*$($app.Name)*" } | Select-Object -First 1
                    if ($package) {
                        # Unpin via registry (more reliable)    
                        Write-Host "[*] Unpinning: $($app.Name)" -ForegroundColor Cyan
                    }
                }
                catch {
                    Write-Host "[-] Failed to unpin $($app.Name): $_" -ForegroundColor Red
                }
            }
        }
        
        # Method 2: Delete the Start Menu database directly
        Write-Host "[*] Clearing Start Menu database..."
        $startDbPath = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
        
        if (Test-Path $startDbPath) {
            # Stop Start Menu process
            Get-Process -Name StartMenuExperienceHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            
            # Delete the database file
            $dbFile = "$startDbPath\start.db"
            $dbJournal = "$startDbPath\start.db-journal"
            
            if (Test-Path $dbFile) {
                Remove-Item -Path $dbFile -Force -ErrorAction SilentlyContinue
                Write-Host "[+] Removed Start Menu database" -ForegroundColor Green
            }
            
            if (Test-Path $dbJournal) {
                Remove-Item -Path $dbJournal -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Method 3: Clear TileDataLayer database (Windows 11)
        $tileDataPath = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\TileDataLayer"
        if (Test-Path $tileDataPath) {
            Get-Process -Name StartMenuExperienceHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            
            Get-ChildItem -Path $tileDataPath -Recurse -Force -ErrorAction SilentlyContinue | 
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "[+] Cleared TileDataLayer" -ForegroundColor Green
        }
        
        # Method 4: Clear via registry
        Write-Host "[*] Clearing Start Menu registry entries..."
        $startMenuPaths = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"
        )
        
        foreach ($regPath in $startMenuPaths) {
            if (Test-Path $regPath) {
                Get-ChildItem -Path $regPath -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -like "*start.tilegrid*" -or $_.Name -like "*windows.data.placeholdertilecollection*" } |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        
        Write-Host "[+] Start Menu tiles cleared" -ForegroundColor Green
        Write-Host "[!] Restarting Windows Explorer..." -ForegroundColor Yellow
        
        # Restart Explorer
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process explorer
        
        Write-Host "[+] Windows Explorer restarted" -ForegroundColor Green
        Write-Host "[!] Please sign out and sign back in for complete effect" -ForegroundColor Yellow
    }
    catch {
        Write-Host "[-] Failed to clear Start Menu tiles: $_" -ForegroundColor Red
    }
}

# Clear File Explorer Quick Access recent files
function Clear-QuickAccessRecent {
    Write-Host "[*] Clearing File Explorer Quick Access recent files..."
    
    try {
        # Method 1: Clear via registry (Recent Files)
        $recentFilesPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs"
        if (Test-Path $recentFilesPath) {
            Remove-Item -Path $recentFilesPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "[+] Cleared recent documents registry" -ForegroundColor Green
        }
        
        # Method 2: Clear Quick Access automatic folders
        $shell32 = New-Object -ComObject Shell.Application
        
        # Get the Quick Access namespace
        $quickAccess = $shell32.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}")
        
        if ($quickAccess) {
            # Remove recent files from Quick Access
            $quickAccess.Items() | Where-Object { $_.IsFolder -eq $false } | ForEach-Object {
                try {
                    $quickAccess.RemoveItem($_.Path)
                }
                catch {
                    # Silently continue if item can't be removed
                }
            }
            Write-Host "[+] Cleared Quick Access recent files" -ForegroundColor Green
        }
        
        # Method 3: Clear AutomaticDestinations (Jump Lists)
        $jumpListPath = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
        if (Test-Path $jumpListPath) {
            Get-ChildItem -Path $jumpListPath -File -ErrorAction SilentlyContinue | 
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "[+] Cleared jump list recent files" -ForegroundColor Green
        }
        
        # Method 4: Clear CustomDestinations
        $customDestPath = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
        if (Test-Path $customDestPath) {
            Get-ChildItem -Path $customDestPath -File -ErrorAction SilentlyContinue | 
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "[+] Cleared custom destinations" -ForegroundColor Green
        }
        
        # Method 5: Clear TypedPaths (File Explorer address bar history)
        $typedPathsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
        if (Test-Path $typedPathsPath) {
            Remove-Item -Path $typedPathsPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "[+] Cleared typed paths history" -ForegroundColor Green
        }
        
        # Method 6: Clear RunMRU (Run dialog history)
        $runMRUPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
        if (Test-Path $runMRUPath) {
            Remove-Item -Path $runMRUPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "[+] Cleared Run dialog history" -ForegroundColor Green
        }
        
        Write-Host "[+] File Explorer Quick Access cleared" -ForegroundColor Green
    }
    catch {
        Write-Host "[-] Failed to clear Quick Access: $_" -ForegroundColor Red
    }
}

# Main program
try {
    Write-Host "[*] Starting nScript v1.0.6"
    
    if ($Force) {
        Write-Host "[!] WARNING: Force mode enabled - all files will be removed!" -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
    
    $playbook = $Configuration
    
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
    
    # Unpin Start Menu tiles
    Clear-StartMenuTiles

    # Clear File Explorer Quick Access
    Clear-QuickAccessRecent
    
    # Empty the recycle bin
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
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