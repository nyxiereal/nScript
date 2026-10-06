function Assert-NsWindowsPath {
    param([string]$Path, [switch]$NoReparse)

    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '^[A-Za-z]:\\' -or
        $Path -match '[*?\[\]]' -or $Path -match '(^|[\\/])\.{1,2}([\\/]|$)' -or
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
    # The core defines this function when the fragments are concatenated; fail before any mutations if omitted.
    if (-not (Get-Command Remove-NsTree -CommandType Function -ErrorAction SilentlyContinue)) {
        throw 'Remove-NsTree is missing; concatenate the core before invoking Windows cleanup'
    }
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
