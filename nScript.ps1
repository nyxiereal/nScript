param([switch]$Force)

# Config is a hashtable of paths, UserDirectories, BrowserInformation, and ExcludedExtensions.
# Stats is a mutable hashtable with DeletedFiles, DeletedFolders, SkippedFiles, FailedFiles.
# Invoke-NsWindowsCleanup -Stats $Stats -Config $Config is supplied by the Windows helper port;
# it must emit no pipeline output. Remove-NsTree is its protected-safe removal primitive.
function New-NsConfig {
    param([string]$UserProfile, [string]$ProgramData, [string]$ProgramFiles,
          [string]$ProgramFilesX86, [string]$AppData, [string]$LocalAppData,
          [string]$Temp, [string]$WindowsDirectory)

    $h = $UserProfile
    $d = $ProgramData
    $p = $ProgramFiles
    $x = $ProgramFilesX86
    # Every line is one Go buildUserDirectories entry, in the same order.
    $paths = @(
        'H|Downloads', 'H|Documents', 'H|Desktop', 'H|Videos', 'H|Music', 'H|Pictures',
        'H|3D Objects', 'H|Saved Games', 'H|Contacts', 'H|Links', 'H|Favorites',
        'H|AppData\Local\Temp', 'H|AppData\Roaming\Microsoft\Windows\Recent',
        'H|AppData\Local\Low\Microsoft\Internet Explorer',
        'H|AppData\Local\Microsoft\Windows\INetCache', 'H|AppData\Local\Microsoft\Windows\INetCookies',
        'H|AppData\Roaming\Microsoft\Office\Recent', 'H|AppData\Local\Microsoft\Windows\Clipboard',
        'H|.cache', 'H|AppData\Local\Roblox', 'H|AppData\Local\Programs\y8-browser',
        'H|AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Y8 Browser',
        'D|Microsoft\Windows\Start Menu\Programs\Y8 Browser',
        'H|AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Roblox.lnk',
        'H|AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Y8 Browser.lnk',
        'D|Microsoft\Windows\Start Menu\Programs\Startup\Roblox.lnk',
        'D|Microsoft\Windows\Start Menu\Programs\Startup\Y8 Browser.lnk',
        'H|AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Roblox',
        'H|AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord Inc',
        'H|AppData\Local\Discord', 'D|Microsoft\Windows\Start Menu\Programs\Epic Games Launcher.lnk',
        'X|Epic Games', 'H|AppData\Roaming\Microsoft\Windows\Start Menu\Programs\osu!.lnk',
        'H|AppData\Local\osu!', 'H|AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Paradox Interactive',
        'H|AppData\Local\Programs\Paradox Interactive', 'H|MicrosoftEdgeBackups',
        'H|AppData\Roaming\Godot', 'H|AppData\Roaming\.tlauncher', 'H|AppData\Roaming\.minecraft',
        'C|Steam', 'C|Flashpoint', 'P|Epic Games', 'D|Riot Games',
        'H|AppData\Local\Riot Games', 'H|AppData\Roaming\Riot Games', 'C|Riot Games',
        'H|AppData\Local\Programs\Riot Games',
        'H|AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Riot Games',
        'H|AppData\Local\EA Games', 'H|AppData\Roaming\Origin', 'H|AppData\Local\Origin',
        'P|Origin', 'X|Origin', 'H|AppData\Local\Battle.net', 'H|AppData\Roaming\Battle.net',
        'X|Battle.net', 'H|AppData\Local\Blizzard Entertainment',
        'H|AppData\Roaming\Blizzard Entertainment', 'H|AppData\Local\Steam',
        'H|AppData\Roaming\Steam', 'H|AppData\Local\Programs\Steam', 'X|Steam',
        'H|AppData\Local\Ubisoft Game Launcher', 'X|Ubisoft',
        'H|AppData\Roaming\GOG.com', 'H|AppData\Local\GOG.com', 'X|GOG Galaxy',
        'H|AppData\Roaming\Minecraft Launcher',
        'H|AppData\Local\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe',
        'H|AppData\Local\CrashDumps', 'H|AppData\Local\FortniteGame',
        'H|AppData\Local\UnrealEngine', 'H|AppData\Local\VALORANT',
        'H|AppData\Local\Rockstar Games',
        'H|AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Rockstar Games',
        'P|Rockstar Games', 'H|AppData\Local\2K', 'H|AppData\Roaming\2K',
        'H|AppData\Local\ROBLOX Corporation', 'H|AppData\Local\Roblox Studio',
        'H|AppData\Local\Programs\Roblox', 'X|Roblox', 'H|AppData\Local\Microsoft\Games',
        'H|AppData\Local\Packages\Microsoft.GamingApp_8wekyb3d8bbwe',
        'H|AppData\Local\Packages\Microsoft.XboxApp_8wekyb3d8bbwe',
        'H|AppData\Local\Packages\Microsoft.XboxGamingOverlay_8wekyb3d8bbwe',
        'H|AppData\Local\SquareEnix', 'H|AppData\Local\TeamViewer',
        'H|AppData\Roaming\TeamViewer', 'X|TeamViewer',
        'H|AppData\Local\AnyDesk', 'H|AppData\Roaming\AnyDesk', 'X|AnyDesk',
        'H|AppData\Local\Spotify', 'H|AppData\Roaming\Spotify',
        'H|AppData\Local\Programs\Spotify', 'H|AppData\Local\slack',
        'H|AppData\Roaming\Slack', 'H|AppData\Local\Programs\slack',
        'H|AppData\Local\Skype', 'H|AppData\Roaming\Skype',
        'H|AppData\Local\Microsoft\Skype for Desktop',
        'H|AppData\Local\WhatsApp', 'H|AppData\Roaming\WhatsApp',
        'H|AppData\Local\Telegram Desktop', 'H|AppData\Roaming\Telegram Desktop',
        'H|AppData\Local\qBittorrent', 'H|AppData\Roaming\qBittorrent',
        'H|AppData\Roaming\uTorrent', 'H|AppData\Local\uTorrent',
        'H|AppData\Roaming\BitTorrent', 'H|AppData\Local\BitTorrent',
        'H|AppData\Local\Twitch', 'H|AppData\Roaming\Twitch',
        'H|AppData\Local\Programs\Twitch', 'H|AppData\Local\itch', 'H|AppData\Roaming\itch'
    )
    $roots = @{ H = $h; D = $d; P = $p; X = $x; C = 'C:\' }
    $directories = @($paths | ForEach-Object {
        $parts = $_.Split('|', 2)
        [IO.Path]::Combine($roots[$parts[0]], $parts[1])
    })
    $browserRows = @{
        'firefox.exe' = @('AppData\Roaming\Mozilla\Firefox\Profiles', 'AppData\Local\Mozilla\Firefox\Profiles', 'AppData\Roaming\Mozilla\Firefox\profiles.ini')
        'chrome.exe' = @('AppData\Local\Google\Chrome\User Data')
        'msedge.exe' = @('AppData\Local\Microsoft\Edge\User Data')
        'opera.exe' = @('AppData\Roaming\Opera Software\Opera Stable', 'AppData\Local\Opera Software\Opera Stable', 'AppData\Local\Programs\Opera')
        'opera_gx.exe' = @('AppData\Roaming\Opera Software\Opera GX Stable', 'AppData\Local\Opera Software\Opera GX Stable', 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Przeglądarka Opera GX.lnk', 'AppData\Local\Programs\Opera GX')
        'brave.exe' = @('AppData\Local\BraveSoftware\Brave-Browser\User Data', 'AppData\Roaming\BraveSoftware')
        'vivaldi.exe' = @('AppData\Local\Vivaldi\User Data', 'AppData\Roaming\Vivaldi')
        'avgsecurebrowser.exe' = @('AppData\Local\AVG\Browser\User Data', 'AppData\Roaming\AVG\Browser')
        'avastsecurebrowser.exe' = @('AppData\Local\AVAST Software\Browser\User Data', 'AppData\Roaming\AVAST Software\Browser')
        'yandex.exe' = @('AppData\Local\Yandex\YandexBrowser\User Data', 'AppData\Roaming\Yandex')
        'torch.exe' = @('AppData\Local\Torch\User Data', 'AppData\Roaming\Torch')
        'chromium.exe' = @('AppData\Local\Chromium\User Data')
        'iexplore.exe' = @('AppData\Local\Microsoft\Windows\INetCache', 'AppData\Local\Microsoft\Windows\INetCookies', 'AppData\Local\Microsoft\Internet Explorer')
        'maxthon.exe' = @('AppData\Roaming\Maxthon5', 'AppData\Local\Maxthon5')
        'seamonkey.exe' = @('AppData\Roaming\Mozilla\SeaMonkey', 'AppData\Local\Mozilla\SeaMonkey')
        'waterfox.exe' = @('AppData\Roaming\Waterfox', 'AppData\Local\Waterfox')
        'palemoon.exe' = @('AppData\Roaming\Moonchild Productions\Pale Moon', 'AppData\Local\Moonchild Productions\Pale Moon')
        'slimjet.exe' = @('AppData\Local\Slimjet\User Data')
        'cent.exe' = @('AppData\Local\CentBrowser\User Data')
        'onedrive.exe' = @('AppData\Local\Microsoft\OneDrive')
    }
    $browsers = @{}
    foreach ($name in $browserRows.Keys) {
        $browsers[$name] = @($browserRows[$name] | ForEach-Object { [IO.Path]::Combine($h, $_) })
    }
    return @{
        UserProfile = $h; ProgramData = $d; ProgramFiles = $p; ProgramFilesX86 = $x
        AppData = $AppData; LocalAppData = $LocalAppData; Temp = $Temp
        WindowsDirectory = $WindowsDirectory
        BackupDirectory = [IO.Path]::Combine($h, '.nScript', 'registry-backups')
        UserDirectories = $directories; BrowserInformation = $browsers
        ExcludedExtensions = @('.iso', '.lnk')
    }
}

function Test-NsProtectedPath {
    param([string]$Path)
    # A directory component with either prefix protects that entire subtree, regardless of case.
    foreach ($part in ($Path -split '[\\/]')) {
        if ($part -match '^(?i:gt works3|gx works3)') { return $true }
    }
    return $false
}

function Test-NsCriticalPath {
    param([string]$Path)
    $pathText = $Path.TrimEnd('\', '/')
    foreach ($critical in @('C:\Windows\System32', 'C:\Windows\SysWOW64',
                            'C:\Program Files\Windows NT', 'C:\Program Files (x86)\Windows NT')) {
        if ($pathText.Equals($critical, [StringComparison]::OrdinalIgnoreCase) -or
            $pathText.StartsWith($critical + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Test-NsExcludedFile {
    param([string]$Path, [string[]]$ExcludedExtensions)
    $name = [IO.Path]::GetFileName($Path)
    $ext = [IO.Path]::GetExtension($name)
    if ($ExcludedExtensions -notcontains $ext) { return $false }
    foreach ($word in @('roblox', 'y8 browser', 'y8-browser', 'y8browser', 'paradox',
                         'opera', 'discord', 'osu', 'steam', 'epic games')) {
        if ($name.IndexOf($word, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $false }
    }
    return $true
}

function Assert-NsSafePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathRooted($Path) -or
        $Path -match '(^|[\\/])\.\.([\\/]|$)' -or $Path -match '^\\\\[?.]\\' -or
        $Path -match '~[0-9]+([\\/]|$)') { throw "Unsafe path: $Path" }
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.TrimEnd('\', '/') -eq $root.TrimEnd('\', '/') -or
        (Test-NsCriticalPath $full) -or (Test-NsProtectedPath $full)) { throw "Protected path: $Path" }
    # Inspect every ancestor before Get-ChildItem; never follow junctions/symlinks into another tree.
    $current = $root
    $rest = $full.Substring($root.Length).Split(@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($part in $rest) {
        $current = [IO.Path]::Combine($current, $part)
        try { $entry = Get-Item -LiteralPath $current -Force -ErrorAction Stop }
        catch {
            if ($_.CategoryInfo.Category -eq 'ObjectNotFound') { return }
            throw
        }
        if ($entry.PSProvider.Name -ne 'FileSystem' -or
            ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Reparse point in path: $current" }
    }
}

function Invoke-NsWalk {
    param([string]$Path, [hashtable]$Stats, [switch]$Unconditional,
          [switch]$KeepRoot, [datetime]$Cutoff, [string[]]$ExcludedExtensions)
    if ((Test-NsProtectedPath $Path) -or (Test-NsCriticalPath $Path)) {
        $Stats.SkippedFiles++; return
    }
    try { $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop }
    catch {
        if ($_.CategoryInfo.Category -eq 'ObjectNotFound') { return }
        $Stats.FailedFiles++; throw
    }
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $Stats.SkippedFiles++; return }
    if (-not $item.PSIsContainer) {
        if (-not $Unconditional -and ((Test-NsExcludedFile $Path $ExcludedExtensions) -or
            $item.LastWriteTime -gt $Cutoff)) { $Stats.SkippedFiles++; return }
        try { [IO.File]::Delete($Path); $Stats.DeletedFiles++ }
        catch { $Stats.FailedFiles++; throw }
        return
    }
    $failures = @()
    try { $children = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop) }
    catch { $Stats.FailedFiles++; throw }
    foreach ($child in $children) {
        try {
            Invoke-NsWalk -Path $child.FullName -Stats $Stats -Unconditional:$Unconditional `
                -Cutoff $Cutoff -ExcludedExtensions $ExcludedExtensions
        } catch { $failures += $_ }
    }
    if (-not $KeepRoot -and $failures.Count -eq 0) {
        try {
            # A protected/reparse/young child stays in place. Do not recurse or force a parent deletion.
            if (@(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop).Count -eq 0) {
                [IO.Directory]::Delete($Path, $false)
                $Stats.DeletedFolders++
            }
        } catch { $Stats.FailedFiles++; $failures += $_ }
    }
    if ($failures.Count) { throw "Could not completely clean ${Path}: $($failures[0])" }
}

function Remove-NsTree {
    param([string]$Path, [hashtable]$Stats)
    Assert-NsSafePath $Path
    Invoke-NsWalk -Path $Path -Stats $Stats -Unconditional
}

function Invoke-NsFileCleanup {
    param([hashtable]$Config, [hashtable]$Stats, [bool]$ForceMode)
    $cutoff = (Get-Date).AddHours(-24)
    foreach ($path in $Config.UserDirectories) {
        try {
            Assert-NsSafePath $path
            Invoke-NsWalk -Path $path -Stats $Stats -KeepRoot -Unconditional:$ForceMode `
                -Cutoff $cutoff -ExcludedExtensions $Config.ExcludedExtensions
        } catch { Write-Warning "Directory cleanup $path`: $_" }
    }
}

function Invoke-NsBrowserCleanup {
    param([hashtable]$Config, [hashtable]$Stats, [bool]$ForceMode)
    $owners = @{}
    foreach ($processName in $Config.BrowserInformation.Keys) {
        foreach ($path in $Config.BrowserInformation[$processName]) {
            if (-not $owners.ContainsKey($path)) { $owners[$path] = @() }
            $owners[$path] += $processName
        }
    }
    $running = @{}
    foreach ($processName in $Config.BrowserInformation.Keys) {
        $name = [IO.Path]::GetFileNameWithoutExtension($processName)
        $processes = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        if ($processes.Count -eq 0) { continue }
        if (-not $ForceMode) { $running[$processName] = $true; continue }
        try {
            foreach ($process in $processes) {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
                [void]$process.WaitForExit(1000)
            }
        } catch {
            $running[$processName] = $true
            Write-Warning "Could not stop $processName`: $_"
        }
    }
    foreach ($path in $owners.Keys) {
        $busy = $false
        foreach ($owner in $owners[$path]) { if ($running[$owner]) { $busy = $true } }
        if ($busy) { $Stats.SkippedFiles++; continue }
        $attempts = 1
        if ($ForceMode) { $attempts = 2 }
        for ($i = 0; $i -lt $attempts; $i++) {
            try { Remove-NsTree -Path $path -Stats $Stats; break }
            catch {
                if ($i + 1 -eq $attempts) { Write-Warning "Browser cleanup $path`: $_" }
                else { Start-Sleep -Seconds 1 }
            }
        }
    }
}

function Invoke-NsCleanup {
    param([bool]$ForceMode)
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'nScript only runs on Windows' }
    $variables = @{
        UserProfile = $env:USERPROFILE; ProgramData = $env:ProgramData
        ProgramFiles = $env:ProgramFiles; ProgramFilesX86 = ${env:ProgramFiles(x86)}
        AppData = $env:APPDATA; LocalAppData = $env:LOCALAPPDATA
        Temp = $env:TEMP; WindowsDirectory = $env:WINDIR
    }
    foreach ($name in $variables.Keys) {
        if ([string]::IsNullOrWhiteSpace($variables[$name])) { throw "$name environment variable not set" }
        Assert-NsSafePath ([IO.Path]::Combine($variables[$name], 'nscript-path-check'))
    }
    $config = New-NsConfig @variables
    $stats = @{ DeletedFiles = 0; DeletedFolders = 0; SkippedFiles = 0; FailedFiles = 0 }
    $version = '2.0.8'
    if ($ForceMode) { $version += '-force' }
    Write-Host "[*] Starting nScript v$version"
    if ($ForceMode) { Write-Warning 'Force mode deletes files regardless of age. Back up important data first.' }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    Write-Host '[*] Phase 1: File and directory cleanup'
    Invoke-NsFileCleanup -Config $config -Stats $stats -ForceMode $ForceMode
    Write-Host '[*] Phase 2: Browser data cleanup'
    Invoke-NsBrowserCleanup -Config $config -Stats $stats -ForceMode $ForceMode
    Write-Host '[*] Phase 3: Windows system cleanup'
    try { Invoke-NsWindowsCleanup -Stats $stats -Config $config }
    catch { Write-Warning "Windows cleanup: $_" }
    $clock.Stop()
    Write-Host '[+] nScript completed'
    Write-Host "[*] Files deleted: $($stats.DeletedFiles); folders deleted: $($stats.DeletedFolders)"
    Write-Host "[*] Files skipped: $($stats.SkippedFiles); failed operations: $($stats.FailedFiles)"
    Write-Host ('[*] Total items deleted: {0}; time taken: {1:N2} seconds' -f `
        ($stats.DeletedFiles + $stats.DeletedFolders), $clock.Elapsed.TotalSeconds)
    try {
        $drive = New-Object IO.DriveInfo 'C'
        if ($drive.IsReady -and $drive.TotalSize -gt 0) {
            $total = $drive.TotalSize / 1GB
            $free = $drive.TotalFreeSpace / 1GB
            Write-Host ('[*] Disk C: total {0:N2} GB; used {1:N2} GB ({2:N2}%); free {3:N2} GB ({4:N2}%)' -f `
                $total, ($total - $free), (100 * (1 - $free / $total)), $free, (100 * $free / $total))
        }
    } catch { Write-Warning "Disk information: $_" }
    Write-Host "[*] Registry backups created in: $($config.BackupDirectory)"
    Write-Host '[*] You can restore registry keys from backups if needed'
    Write-Host '[*] Made by Nyx :3 https://nyx.meowery.eu/'
}

if ($args.Count -gt 1 -or ($args.Count -eq 1 -and $args[0] -ne '--force') -or
    ($Force -and $args.Count)) { throw 'Usage: nScript.ps1 [-Force | --force]' }
Invoke-NsCleanup -ForceMode ($Force -or $args.Count -eq 1)
