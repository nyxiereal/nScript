# Safe on any host: parse the cleaner, then load ONLY pure selectors/config functions.
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot 'nScript.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "nScript.ps1 syntax errors: $errors" }
# Catch missing integrated helpers without invoking any of them.
$defined = @($ast.EndBlock.Statements | Where-Object {
    $_ -is [System.Management.Automation.Language.FunctionDefinitionAst]
} | ForEach-Object { $_.Name })
$calls = $ast.FindAll({ param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -match '^[A-Za-z]+-Ns'
}, $true)
foreach ($call in $calls) {
    if ($defined -notcontains $call.GetCommandName()) { throw "Undefined helper: $($call.GetCommandName())" }
}
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'nScript.ps1'))
if ($source -match '\$env:TEMP\b') { throw 'Startup must not depend on unused TEMP, which can use short names' }
if ($source -notmatch '-KeepRoot -IgnoreAge:\$ForceMode' -or $source -match '-Unconditional:\$ForceMode') {
    throw 'General force cleanup must bypass age, not extension exclusions'
}
$allowed = @('New-NsConfig', 'Test-NsProtectedPath', 'Test-NsCriticalPath', 'Test-NsExcludedFile', 'Test-NsEligibleFile')
foreach ($name in $allowed) {
    $definitions = @($ast.EndBlock.Statements | Where-Object {
        $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $name
    })
    if ($definitions.Count -ne 1) { throw "Missing or repeated pure function $name" }
    . ([scriptblock]::Create($definitions[0].Extent.Text))
}
function Assert([bool]$condition, [string]$message) { if (-not $condition) { throw $message } }
Assert (Test-NsProtectedPath 'C:\Other\gX WoRkS3 tools\data') 'Protected subtree case/prefix'
Assert (Test-NsProtectedPath 'C:\GT Works3\x') 'Protected root'
Assert (-not (Test-NsProtectedPath 'C:\Other\GT Works2\data')) 'Unrelated subtree'
Assert (Test-NsCriticalPath 'C:\Windows\System32\drivers') 'Critical descendant'
Assert (-not (Test-NsCriticalPath 'C:\Windows\System32Other')) 'Critical boundary'
Assert (Test-NsExcludedFile 'C:\foo\archive.ISO' @('.iso', '.lnk')) 'ISO exclusion'
Assert (Test-NsExcludedFile 'C:\foo\random.lnk' @('.iso', '.lnk')) 'Shortcut exclusion'
Assert (-not (Test-NsExcludedFile 'C:\foo\Discord.lnk' @('.iso', '.lnk'))) 'Named shortcut exception'
Assert (-not (Test-NsExcludedFile 'C:\foo\roblox.ISO' @('.iso', '.lnk'))) 'Named ISO exception'
Assert (-not (Test-NsExcludedFile 'C:\foo\new.txt' @('.iso', '.lnk'))) 'Unexcluded file'
$cutoff = [datetime]'2024-01-02'
$excluded = @('.iso', '.lnk')
Assert (-not (Test-NsEligibleFile 'C:\foo\archive.iso' $excluded ($cutoff.AddDays(-3)) $cutoff $true)) 'Force preserves excluded ISO'
Assert (-not (Test-NsEligibleFile 'C:\foo\other.lnk' $excluded ($cutoff.AddDays(-3)) $cutoff $true)) 'Force preserves excluded shortcut'
Assert (Test-NsEligibleFile 'C:\foo\Discord.lnk' $excluded $cutoff $cutoff $true) 'Force retains named exceptions'
Assert (Test-NsEligibleFile 'C:\foo\young.txt' $excluded $cutoff $cutoff $true) 'Force bypasses age'
Assert (-not (Test-NsEligibleFile 'C:\foo\young.txt' $excluded $cutoff $cutoff $false)) 'Normal mode keeps young files'
Assert (Test-NsEligibleFile 'C:\foo\old.txt' $excluded ($cutoff.AddDays(-3)) $cutoff $false) 'Normal mode removes old files'
$config = New-NsConfig -UserProfile 'H:\Profile' -ProgramData 'D:\Data' `
    -ProgramFiles 'P:\Files' -ProgramFilesX86 'X:\Files' -AppData 'H:\Roaming' `
    -LocalAppData 'H:\Local' -WindowsDirectory 'C:\Windows'
Assert ($config.UserDirectories.Count -eq 140) '118 original paths plus 22 verified targets'
# Preserve the complete 118-entry Go baseline, not just its first and last elements.
$baseline = [string]::Join("`n", @($config.UserDirectories[0..117] | ForEach-Object { $_ -replace '[\\/]+', '\' }))
$sha = [Security.Cryptography.SHA256]::Create()
try { $digest = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($baseline))).Replace('-', '').ToLowerInvariant() }
finally { $sha.Dispose() }
Assert ($digest -eq 'b9be3f49bdf2e8c170796916c4c0867af75171b046726a0d9e06d356ca6e1598') 'Original 118-entry prefix changed'
$additional = @(
    'AppData\Local\Bloxstrap', 'AppData\Local\Fishstrap',
    'AppData\Local\Programs\PrismLauncher', 'AppData\Roaming\PrismLauncher',
    'AppData\Roaming\ModrinthApp',
    'AppData\Local\Programs\lunarclient', '.lunarclient',
    'AppData\Roaming\Vencord', 'AppData\Roaming\Vesktop',
    'AppData\Roaming\BetterDiscord',
    'AppData\Roaming\Discord', 'AppData\Roaming\CurseForge',
    'AppData\Local\Medal', 'AppData\Local\Programs\Medal', 'AppData\Roaming\Medal',
    'AppData\Roaming\Playnite',
    'AppData\Local\osulazer', 'AppData\Roaming\osu',
    'AppData\Local\Plutonium', 'AppData\Local\Nox'
)
for ($i = 0; $i -lt $additional.Count; $i++) {
    Assert ($config.UserDirectories[118 + $i] -eq [IO.Path]::Combine('H:\Profile', $additional[$i])) "Verified target $($additional[$i])"
}
Assert ($config.UserDirectories[138] -eq [IO.Path]::Combine('P:\Files', 'BlueStacks_nxt')) 'BlueStacks app root'
Assert ($config.UserDirectories[139] -eq [IO.Path]::Combine('D:\Data', 'BlueStacks_nxt')) 'BlueStacks data root'
Assert (@($config.UserDirectories | Sort-Object -Unique).Count -eq $config.UserDirectories.Count) 'Duplicate user path'
Assert ($config.BrowserInformation.Count -eq 20) 'Go browser count'
Assert (@($config.BrowserInformation.Values | ForEach-Object { $_ }).Count -eq 39) 'Go browser path parity count'
Assert ($config.UserDirectories[0] -eq [IO.Path]::Combine('H:\Profile', 'Downloads')) 'Downloads root'
Assert ($config.UserDirectories -contains [IO.Path]::Combine('C:\', 'Flashpoint')) 'System-root Flashpoint'
Assert ($config.UserDirectories -contains [IO.Path]::Combine('D:\Data', 'Microsoft\Windows\Start Menu\Programs\Startup\Roblox.lnk')) 'ProgramData shortcut'
Assert ($config.BrowserInformation['opera_gx.exe'] -contains [IO.Path]::Combine('H:\Profile', 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Przeglądarka Opera GX.lnk')) 'Polish path encoding'
Assert ($config.BackupDirectory -eq [IO.Path]::Combine('H:\Profile', '.nScript', 'registry-backups')) 'Backup outside Temp'
Assert ($config.ExcludedExtensions -contains '.iso' -and $config.ExcludedExtensions -contains '.lnk') 'Excluded extensions'
'Passed: AST and pure path/config checks (no cleaner executed)'
