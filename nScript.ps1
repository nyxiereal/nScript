#Requires -Version 5.1
param([switch]$Force)

$ErrorActionPreference = 'Stop'

# One self-contained artifact; nothing is downloaded by the cleaner itself.
function New-NsConfig {
    param([string]$UserProfile, [string]$ProgramData, [string]$ProgramFiles,
          [string]$ProgramFilesX86, [string]$AppData, [string]$LocalAppData,
          [string]$WindowsDirectory)

    $h = $UserProfile
    $d = $ProgramData
    $p = $ProgramFiles
    $x = $ProgramFilesX86
    # Original 118 Go targets, then source-verified additions in docs/cleanup-targets.md.
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
        'H|AppData\Local\Programs\Twitch', 'H|AppData\Local\itch', 'H|AppData\Roaming\itch',
        # Additional app-specific defaults; no shared parent directories or discovery scans.
        'H|AppData\Local\Bloxstrap', 'H|AppData\Local\Fishstrap',
        'H|AppData\Local\Programs\PrismLauncher', 'H|AppData\Roaming\PrismLauncher',
        'H|AppData\Roaming\ModrinthApp',
        'H|AppData\Local\Programs\lunarclient', 'H|.lunarclient',
        'H|AppData\Roaming\Vencord', 'H|AppData\Roaming\Vesktop',
        'H|AppData\Roaming\BetterDiscord',
        'H|AppData\Roaming\Discord', 'H|AppData\Roaming\CurseForge',
        'H|AppData\Local\Medal', 'H|AppData\Local\Programs\Medal', 'H|AppData\Roaming\Medal',
        'H|AppData\Roaming\Playnite',
        'H|AppData\Local\osulazer', 'H|AppData\Roaming\osu',
        'H|AppData\Local\Plutonium', 'H|AppData\Local\Nox',
        'P|BlueStacks_nxt', 'D|BlueStacks_nxt'
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
        AppData = $AppData; LocalAppData = $LocalAppData
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

function Test-NsEligibleFile {
    param([string]$Path, [string[]]$ExcludedExtensions, [datetime]$LastWriteTime,
          [datetime]$Cutoff, [bool]$ForceMode)
    if (Test-NsExcludedFile $Path $ExcludedExtensions) { return $false }
    return ($ForceMode -or $LastWriteTime -lt $Cutoff)
}

function Assert-NsSafePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '^[A-Za-z]:[\\/]' -or
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
          [switch]$IgnoreAge, [switch]$KeepRoot, [datetime]$Cutoff, [string[]]$ExcludedExtensions)
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
        if (-not $Unconditional -and -not (Test-NsEligibleFile -Path $Path `
            -ExcludedExtensions $ExcludedExtensions -LastWriteTime $item.LastWriteTime `
            -Cutoff $Cutoff -ForceMode $IgnoreAge)) { $Stats.SkippedFiles++; return }
        try {
            if ($item.IsReadOnly) { $item.IsReadOnly = $false }
            [IO.File]::Delete($Path)
            $Stats.DeletedFiles++
        }
        catch { $Stats.FailedFiles++; throw }
        return
    }
    $failures = @()
    try { $children = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop) }
    catch { $Stats.FailedFiles++; throw }
    foreach ($child in $children) {
        try {
            Invoke-NsWalk -Path $child.FullName -Stats $Stats -Unconditional:$Unconditional `
                -IgnoreAge:$IgnoreAge -Cutoff $Cutoff -ExcludedExtensions $ExcludedExtensions
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
        $before = $Stats.FailedFiles
        try {
            Assert-NsSafePath $path
            Invoke-NsWalk -Path $path -Stats $Stats -KeepRoot -IgnoreAge:$ForceMode `
                -Cutoff $cutoff -ExcludedExtensions $Config.ExcludedExtensions
        } catch {
            if ($Stats.FailedFiles -eq $before) { $Stats.FailedFiles++ }
            Write-Warning "Directory cleanup $path`: $_"
        }
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
            $Stats.FailedFiles++
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
            $before = $Stats.FailedFiles
            try { Remove-NsTree -Path $path -Stats $Stats; break }
            catch {
                if ($i + 1 -eq $attempts) {
                    if ($Stats.FailedFiles -eq $before) { $Stats.FailedFiles++ }
                    Write-Warning "Browser cleanup $path`: $_"
                }
                else { Start-Sleep -Seconds 1 }
            }
        }
    }
}

function Assert-NsWindowsPath {
    param([string]$Path, [switch]$NoReparse)

    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '^[A-Za-z]:\\' -or
        $Path -match '[*?]' -or $Path -match '(^|[\\/])\.{1,2}([\\/]|$)' -or
        $Path -match '/' -or $Path.Substring(2) -match '[:<>|\"]' -or
        $Path -match '[\x00-\x1f]' -or $Path -match '[\\/]$') {
        throw "Invalid Windows path: $Path"
    }
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.TrimEnd('\') -match '^[A-Za-z]:$') { throw "Refusing drive root: $Path" }
    if ($NoReparse) {
        $part = $full
        while ($part) {
            if (Test-Path -LiteralPath $part -ErrorAction Stop) {
                if ((Get-Item -LiteralPath $part -Force -ErrorAction Stop).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    throw "Reparse point in path: $part"
                }
            }
            $parent = [IO.Directory]::GetParent($part)
            if ($null -eq $parent) { break }
            $part = $parent.FullName
        }
    }
}

function Assert-NsWindowsBackupDirectory {
    param([hashtable]$Config)

    Assert-NsWindowsPath -Path $Config.UserProfile -NoReparse
    $expected = Join-Path $Config.UserProfile '.nScript\registry-backups'
    Assert-NsWindowsPath -Path $expected -NoReparse
    Assert-NsWindowsPath -Path $Config.BackupDirectory -NoReparse
    if (-not [string]::Equals([IO.Path]::GetFullPath($expected).TrimEnd('\'),
            [IO.Path]::GetFullPath($Config.BackupDirectory).TrimEnd('\'),
            [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Registry backup directory must be USERPROFILE\.nScript\registry-backups'
    }
}

function Invoke-NsWindowsAttempt {
    param([string]$Name, [scriptblock]$Action, [hashtable]$Stats)

    $before = $Stats.FailedFiles
    try { & $Action | Out-Null }
    catch {
        if ($Stats.FailedFiles -eq $before) { $Stats.FailedFiles++ }
        Write-Warning ("Windows cleanup: {0}: {1}" -f $Name, $_.Exception.Message)
    }
}

function Remove-NsWindowsRegistryKey {
    param([string]$Path, [hashtable]$Stats, [hashtable]$Config)

    if ($Path -notmatch '^Software\\[^\\]+(\\[^\\]+)*$' -or $Path -match '(^|\\)\.{1,2}(\\|$)') {
        throw "Invalid registry path: $Path"
    }
    Assert-NsWindowsBackupDirectory -Config $Config
    Assert-NsWindowsPath -Path $Config.WindowsDirectory -NoReparse
    $key = "HKCU:\$Path"
    if (-not (Test-Path -LiteralPath $key -ErrorAction Stop)) { return }
    [void][IO.Directory]::CreateDirectory($Config.BackupDirectory)
    $backup = Join-Path $Config.BackupDirectory ("registry_{0}_{1}.reg" -f
        (Get-Date -Format 'yyyyMMdd_HHmmss_fffffff'), [guid]::NewGuid().ToString('N'))
    & (Join-Path $Config.WindowsDirectory 'System32\reg.exe') export "HKCU\$Path" $backup /y 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $backup -PathType Leaf) -or
        (Get-Item -LiteralPath $backup).Length -eq 0) {
        throw "Registry export failed for HKCU\$Path; key was not deleted"
    }
    Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
}

function Ensure-NsWindowsRegistryKey {
    param([string]$Path)

    if ($Path -notmatch '^HKCU:\\Software\\[^\\]+(\\[^\\]+)*$' -or $Path -match '(^|\\)\.{1,2}(\\|$)') {
        throw "Invalid registry path: $Path"
    }
    if (-not (Test-Path -LiteralPath $Path -ErrorAction Stop)) {
        [void](New-Item -Path $Path -Force -ErrorAction Stop)
    }
}

function Merge-NsFirefoxExtensionSettings {
    param([string]$Existing)

    if ($Existing -notmatch '^\s*\{') { throw 'Firefox ExtensionSettings must be a JSON object' }
    try { $settings = ConvertFrom-Json -InputObject $Existing -ErrorAction Stop }
    catch { throw "Invalid Firefox ExtensionSettings JSON: $($_.Exception.Message)" }
    if ($null -eq $settings -or $settings.GetType() -ne [System.Management.Automation.PSCustomObject]) { throw 'Firefox ExtensionSettings must be a JSON object' }
    if ($settings.PSObject.Properties['policies']) { throw 'Firefox ExtensionSettings must not contain a policies wrapper' }
    foreach ($entry in $settings.PSObject.Properties) {
        if ($null -eq $entry.Value -or $entry.Value.GetType() -ne [System.Management.Automation.PSCustomObject]) {
            throw "Firefox extension $($entry.Name) must be an object"
        }
    }
    $id = 'uBlock0@raymondhill.net'
    $ublock = $settings.PSObject.Properties[$id]
    if ($ublock) { $extension = $ublock.Value }
    else {
        $extension = [pscustomobject]@{}
        $settings | Add-Member -NotePropertyName $id -NotePropertyValue $extension
    }
    foreach ($field in @{
        installation_mode = 'force_installed'
        install_url = 'https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi'
    }.GetEnumerator()) {
        $extension | Add-Member -NotePropertyName $field.Key -NotePropertyValue $field.Value -Force
    }
    ConvertTo-Json -InputObject $settings -Depth 100 -Compress -WarningAction Stop -ErrorAction Stop
}

function Set-NsFirefoxPolicies {
    $path = 'HKCU:\Software\Policies\Mozilla\Firefox'
    Ensure-NsWindowsRegistryKey -Path $path
    $key = Get-Item -LiteralPath $path -ErrorAction Stop
    $existing = '{}'
    if ($key.GetValueNames() -contains 'ExtensionSettings') {
        $kind = $key.GetValueKind('ExtensionSettings')
        if ($kind -eq [Microsoft.Win32.RegistryValueKind]::MultiString) {
            $existing = [string]::Join("`n", [string[]]$key.GetValue('ExtensionSettings'))
        } elseif ($kind -eq [Microsoft.Win32.RegistryValueKind]::String) {
            $existing = [string]$key.GetValue('ExtensionSettings')
        } else { throw "Unsupported Firefox ExtensionSettings registry type: $kind" }
    }
    $merged = Merge-NsFirefoxExtensionSettings -Existing $existing
    [void](New-ItemProperty -LiteralPath $path -Name 'ExtensionSettings' -PropertyType MultiString -Value ([string[]]@($merged)) -Force -ErrorAction Stop)
    foreach ($name in @('OverrideFirstRunPage', 'OverridePostUpdatePage')) {
        [void](New-ItemProperty -LiteralPath $path -Name $name -PropertyType String -Value '' -Force -ErrorAction Stop)
    }
    foreach ($name in @('DontCheckDefaultBrowser', 'BlockAboutConfig', 'DisableSetDesktopBackground')) {
        [void](New-ItemProperty -LiteralPath $path -Name $name -PropertyType DWord -Value 1 -Force -ErrorAction Stop)
    }
    $homepage = "$path\Homepage"
    Ensure-NsWindowsRegistryKey -Path $homepage
    foreach ($pair in @(@('URL', 'https://duckduckgo.com/'), @('StartPage', 'homepage-locked'))) {
        [void](New-ItemProperty -LiteralPath $homepage -Name $pair[0] -PropertyType String -Value $pair[1] -Force -ErrorAction Stop)
    }
    [void](New-ItemProperty -LiteralPath $homepage -Name 'Locked' -PropertyType DWord -Value 1 -Force -ErrorAction Stop)
    $search = "$path\SearchEngines"
    Ensure-NsWindowsRegistryKey -Path $search
    [void](New-ItemProperty -LiteralPath $search -Name 'Default' -PropertyType String -Value 'DuckDuckGo' -Force -ErrorAction Stop)
}

function Set-NsChromePolicies {
    param([hashtable]$Config)

    Assert-NsWindowsPath -Path $Config.LocalAppData -NoReparse
    $userData = Join-Path $Config.LocalAppData 'Google\Chrome\User Data'
    $sentinel = Join-Path $userData 'First Run'
    Assert-NsWindowsPath -Path $sentinel -NoReparse
    $base = 'HKCU:\Software\Policies\Google\Chrome'
    $forcePath = "$base\ExtensionInstallForcelist"
    $id = 'ddkjiahejlhfcafbddmgiahcphecmpfh'
    $homepage = 'https://duckduckgo.com/'
    Ensure-NsWindowsRegistryKey -Path $forcePath
    $key = Get-Item -LiteralPath $forcePath -ErrorAction Stop
    $occupied = @{}
    $slot = $null
    foreach ($name in $key.GetValueNames()) {
        $number = 0
        if (-not [int]::TryParse($name, [ref]$number) -or $number -lt 1) { continue }
        $occupied[$number] = $true
        if ($key.GetValueKind($name) -ne [Microsoft.Win32.RegistryValueKind]::String) {
            throw "Chrome force-list value $name is not REG_SZ"
        }
        $value = [string]$key.GetValue($name)
        if ($value -eq $id -or $value.StartsWith("$id;", [StringComparison]::OrdinalIgnoreCase)) { $slot = $name }
    }
    if ($null -eq $slot) {
        $number = 1
        while ($occupied.ContainsKey($number)) { $number++ }
        $slot = [string]$number
    }
    [void](New-ItemProperty -LiteralPath $forcePath -Name $slot -PropertyType String -Value "$id;https://clients2.google.com/service/update2/crx" -Force -ErrorAction Stop)
    $startup = "$base\RestoreOnStartupURLs"
    Ensure-NsWindowsRegistryKey -Path $startup
    $key = Get-Item -LiteralPath $startup -ErrorAction Stop
    foreach ($name in $key.GetValueNames()) {
        Remove-ItemProperty -LiteralPath $startup -Name $name -ErrorAction Stop
    }
    [void](New-ItemProperty -LiteralPath $startup -Name '1' -PropertyType String -Value $homepage -Force -ErrorAction Stop)
    foreach ($pair in @(
        @('HomepageLocation', $homepage),
        @('DefaultSearchProviderName', 'DuckDuckGo'),
        @('DefaultSearchProviderKeyword', 'duckduckgo.com'),
        @('DefaultSearchProviderSearchURL', 'https://duckduckgo.com/?q={searchTerms}')
    )) {
        [void](New-ItemProperty -LiteralPath $base -Name $pair[0] -PropertyType String -Value $pair[1] -Force -ErrorAction Stop)
    }
    foreach ($pair in @(
        @('HomepageIsNewTabPage', 0), @('ShowHomeButton', 1), @('RestoreOnStartup', 4),
        @('DefaultSearchProviderEnabled', 1), @('PromotionsEnabled', 0), @('NTPCustomBackgroundEnabled', 0)
    )) {
        [void](New-ItemProperty -LiteralPath $base -Name $pair[0] -PropertyType DWord -Value $pair[1] -Force -ErrorAction Stop)
    }
    $extension = "$base\3rdparty\extensions\$id\policy"
    Ensure-NsWindowsRegistryKey -Path $extension
    [void](New-ItemProperty -LiteralPath $extension -Name 'disableFirstRunPage' -PropertyType DWord -Value 1 -Force -ErrorAction Stop)
    if ((Test-Path -LiteralPath $sentinel -ErrorAction Stop) -and
        -not (Test-Path -LiteralPath $sentinel -PathType Leaf -ErrorAction Stop)) {
        throw 'Chrome First Run sentinel exists but is not a file'
    }
    if (-not (Test-Path -LiteralPath $sentinel -ErrorAction Stop)) {
        [void][IO.Directory]::CreateDirectory($userData)
        $file = [IO.File]::Open($sentinel, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $file.Close()
    }
}

function Clear-NsWindowsRegistryChildren {
    param([string]$Path, [string]$Pattern, [hashtable]$Stats, [hashtable]$Config)

    $key = "HKCU:\$Path"
    if (-not (Test-Path -LiteralPath $key -ErrorAction Stop)) { return }
    foreach ($child in Get-ChildItem -LiteralPath $key -ErrorAction Stop) {
        if ($Pattern -and $child.PSChildName -notmatch $Pattern) { continue }
        Invoke-NsWindowsAttempt -Name $child.PSChildName -Stats $Stats -Action {
            Remove-NsWindowsRegistryKey -Path "$Path\$($child.PSChildName)" -Stats $Stats -Config $Config
        }
    }
}

function Clear-NsWindowsFolderEntries {
    param([string]$Path, [hashtable]$Stats, [string]$Pattern, [switch]$SkipDestinations)

    Assert-NsWindowsPath -Path $Path -NoReparse
    if (-not (Test-Path -LiteralPath $Path -ErrorAction Stop)) { return }
    foreach ($entry in Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop) {
        if ($Pattern -and $entry.Name -notmatch $Pattern) { continue }
        if ($SkipDestinations -and $entry.PSIsContainer -and
            $entry.Name -in @('AutomaticDestinations', 'CustomDestinations')) { continue }
        Invoke-NsWindowsAttempt -Name $entry.FullName -Stats $Stats -Action {
            Remove-NsTree -Path $entry.FullName -Stats $Stats
        }
    }
}

function Invoke-NsWindowsCleanup {
    param([hashtable]$Stats, [hashtable]$Config)

    if ($null -eq $Stats -or $null -eq $Config) { throw 'Windows cleanup requires Stats and Config' }
    foreach ($name in @('DeletedFiles', 'DeletedFolders', 'SkippedFiles', 'FailedFiles')) {
        if (-not $Stats.ContainsKey($name)) { throw "Windows cleanup stats missing $name" }
    }
    foreach ($name in @('UserProfile', 'AppData', 'LocalAppData', 'WindowsDirectory', 'BackupDirectory')) {
        Assert-NsWindowsPath -Path $Config[$name] -NoReparse
    }
    Assert-NsWindowsBackupDirectory -Config $Config
    $failures = $Stats.FailedFiles
    $startMenu = Join-Path $Config.LocalAppData 'Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy'
    Invoke-NsWindowsAttempt -Name 'stop Start Menu' -Stats $Stats -Action {
        Get-Process -Name StartMenuExperienceHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop
        Start-Sleep -Seconds 1
    }
    foreach ($path in @((Join-Path $startMenu 'LocalState\start.db'),
                        (Join-Path $startMenu 'LocalState\start.db-journal'),
                        (Join-Path $startMenu 'TileDataLayer'))) {
        Invoke-NsWindowsAttempt -Name $path -Stats $Stats -Action { Remove-NsTree -Path $path -Stats $Stats }
    }
    Invoke-NsWindowsAttempt -Name 'CloudStore Start Menu' -Stats $Stats -Action {
        Clear-NsWindowsRegistryChildren -Path 'Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount' -Pattern 'start\.tilegrid|windows\.data\.placeholdertilecollection|microsoft\.windows\.startmenuexperiencehost' -Stats $Stats -Config $Config
    }
    Invoke-NsWindowsAttempt -Name 'Windows 10 version' -Stats $Stats -Action {
        $build = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuildNumber -ErrorAction Stop).CurrentBuildNumber
        $number = 0
        if (-not [int]::TryParse($build, [ref]$number)) { throw 'Invalid Windows build number' }
        if ($number -ge 10240 -and $number -lt 19041) {
            foreach ($path in @((Join-Path $Config.UserProfile 'AppData\Local\TileDataLayer'),
                                (Join-Path $Config.LocalAppData 'Microsoft\Windows\Caches'))) {
                Invoke-NsWindowsAttempt -Name $path -Stats $Stats -Action { Remove-NsTree -Path $path -Stats $Stats }
            }
        }
    }
    Invoke-NsWindowsAttempt -Name 'restart Explorer' -Stats $Stats -Action {
        Assert-NsWindowsPath -Path $Config.WindowsDirectory -NoReparse
        Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        Start-Process -FilePath (Join-Path $Config.WindowsDirectory 'explorer.exe') -ErrorAction Stop
    }
    foreach ($path in @(
        'Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs',
        'Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths',
        'Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU',
        'Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU',
        'Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU',
        'Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU'
    )) {
        Invoke-NsWindowsAttempt -Name $path -Stats $Stats -Action {
            Remove-NsWindowsRegistryKey -Path $path -Stats $Stats -Config $Config
        }
    }
    $recent = Join-Path $Config.AppData 'Microsoft\Windows\Recent'
    foreach ($folder in @('AutomaticDestinations', 'CustomDestinations')) {
        Invoke-NsWindowsAttempt -Name $folder -Stats $Stats -Action {
            Clear-NsWindowsFolderEntries -Path (Join-Path $recent $folder) -Stats $Stats
        }
    }
    Invoke-NsWindowsAttempt -Name 'Recent Items' -Stats $Stats -Action {
        Clear-NsWindowsFolderEntries -Path $recent -Stats $Stats -SkipDestinations
    }
    Invoke-NsWindowsAttempt -Name 'thumbnail and icon caches' -Stats $Stats -Action {
        Clear-NsWindowsFolderEntries -Path (Join-Path $Config.LocalAppData 'Microsoft\Windows\Explorer') -Stats $Stats -Pattern '^(thumbcache_|iconcache)'
    }
    Invoke-NsWindowsAttempt -Name 'UserAssist' -Stats $Stats -Action {
        Clear-NsWindowsRegistryChildren -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist' -Stats $Stats -Config $Config
    }
    Invoke-NsWindowsAttempt -Name 'dark mode' -Stats $Stats -Action {
        $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Ensure-NsWindowsRegistryKey -Path $path
        foreach ($pair in @(@('SystemUsesLightTheme', 0), @('AppsUseLightTheme', 0), @('ForceDarkMode', 1))) {
            [void](New-ItemProperty -LiteralPath $path -Name $pair[0] -PropertyType DWord -Value $pair[1] -Force -ErrorAction Stop)
        }
    }
    Invoke-NsWindowsAttempt -Name 'Firefox policies' -Stats $Stats -Action { Set-NsFirefoxPolicies }
    Invoke-NsWindowsAttempt -Name 'Chrome policies' -Stats $Stats -Action { Set-NsChromePolicies -Config $Config }
    Invoke-NsWindowsAttempt -Name 'recycle bin' -Stats $Stats -Action {
        Clear-RecycleBin -Force -ErrorAction Stop
    }
    if ($Stats.FailedFiles -gt $failures) { throw "Windows cleanup completed with $($Stats.FailedFiles - $failures) failures" }
}

function Invoke-NsCleanup {
    param([bool]$ForceMode)
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'nScript only runs on Windows' }
    $variables = @{
        UserProfile = $env:USERPROFILE; ProgramData = $env:ProgramData
        ProgramFiles = $env:ProgramFiles; ProgramFilesX86 = ${env:ProgramFiles(x86)}
        AppData = $env:APPDATA; LocalAppData = $env:LOCALAPPDATA
        WindowsDirectory = $env:WINDIR
    }
    foreach ($name in $variables.Keys) {
        if ([string]::IsNullOrWhiteSpace($variables[$name])) { throw "$name environment variable not set" }
        Assert-NsSafePath $variables[$name]
    }
    $config = New-NsConfig @variables
    Assert-NsWindowsBackupDirectory -Config $config
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
    $before = $stats.FailedFiles
    try { Invoke-NsWindowsCleanup -Stats $stats -Config $config }
    catch {
        if ($stats.FailedFiles -eq $before) { $stats.FailedFiles++ }
        Write-Warning "Windows cleanup: $_"
    }
    $clock.Stop()
    if ($stats.FailedFiles) { Write-Warning 'nScript completed with cleanup failures; see warnings above.' }
    else { Write-Host '[+] nScript completed' }
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
    Write-Host "[*] Registry backup location: $($config.BackupDirectory)"
    Write-Host '[*] Made by Nyx :3 https://nyx.meowery.eu/'
}

if ($args.Count -gt 1 -or ($args.Count -eq 1 -and $args[0] -ne '--force') -or
    ($Force -and $args.Count)) { throw 'Usage: nScript.ps1 [-Force | --force]' }
Invoke-NsCleanup -ForceMode ($Force -or $args.Count -eq 1)
