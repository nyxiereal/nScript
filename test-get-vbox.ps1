$Path = Join-Path $PSScriptRoot 'get-vbox.ps1'
$Tokens = $null
$Errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$Errors) | Out-Null
if ($Errors.Count) { throw "get-vbox.ps1 has syntax errors: $Errors" }

$Script = Get-Content $Path -Raw
$Steps = @(
    'Start-BitsTransfer -Source ''https://raw.githubusercontent.com/nyxiereal/nScript/dist/winget-portable.zip''',
    'Expand-Archive -LiteralPath $WingetArchive',
    '& $WingetPath --version',
    '& $CleanerPath --force',
    '$Install = {',
    'Start-Process -FilePath ''powershell.exe'' -Verb RunAs'
)
$Positions = @($Steps | ForEach-Object { $Script.IndexOf($_) })
if ($Positions -contains -1 -or ($Positions -join ',') -ne (($Positions | Sort-Object) -join ',') -or ([regex]::Matches($Script, '-Verb RunAs')).Count -ne 1) {
    throw 'Portable WinGet must start before user cleanup and the single elevation'
}
if (-not $Script.Contains('& $WingetPath @Options') -or -not $Script.Contains('$WingetArchive.Replace("''", "''''")') -or
    -not $Script.Contains('Copy-Item -LiteralPath $WingetArchive -Destination $TrustedArchive') -or
    ([regex]::Matches($Script, 'Get-FileHash -LiteralPath')).Count -ne 2) {
    throw 'Elevated installs must use a verified private copy of portable WinGet'
}
foreach ($Id in @('Inkscape.Inkscape', 'GIMP.GIMP.3', 'Microsoft.VisualStudioCode', 'Python.Python.3.14', 'Notepad++.Notepad++', 'Orwell.Dev-C++', 'EclipseAdoptium.Temurin.25.JDK', 'JetBrains.PyCharm.Community', 'CodeBlocks.CodeBlocks.MinGW', 'JetBrains.IntelliJIDEA.Community')) {
    if (-not $Script.Contains("'$Id'")) { throw "Missing package: $Id" }
}
foreach ($Flag in @('--exact', '--scope', '--silent', '--disable-interactivity', '--accept-source-agreements', '--accept-package-agreements')) {
    if (-not $Script.Contains("'$Flag'")) { throw "Missing WinGet flag: $Flag" }
}
if ($Script -match 'VirtualBox|Embarcadero') { throw 'Old installer still present' }

foreach ($Dropper in @('get.ps1', 'get-force.ps1', 'get-vbox.ps1')) {
    $Body = Get-Content (Join-Path $PSScriptRoot $Dropper) -Raw
    if ($Body -notmatch '\$env:USERPROFILE\s+[''\"]\.nScript[''\"]' -or $Body -match '\$env:TEMP\b') {
        throw "$Dropper must stage the executable outside the Temp cleanup target"
    }
}

foreach ($Dropper in @('get.cmd', 'get-force.cmd')) {
    $Body = Get-Content (Join-Path $PSScriptRoot $Dropper) -Raw
    if ($Body -notmatch '%USERPROFILE%\\\.nScript' -or $Body -match '%TEMP%|%TMP%') {
        throw "$Dropper must stage the executable outside the Temp cleanup target"
    }
    if ($Body -notmatch 'curl\.exe -fsSL' -or $Body -notmatch 'certutil -urlcache -split -f' -or $Body -notmatch 'LSS 100000') {
        throw "$Dropper must use the LOLBin downloaders and reject partial downloads"
    }
    if ($Body -notmatch 'del /f /q "%BinaryPath%"') {
        throw "$Dropper must delete the staged executable"
    }
}
if ((Get-Content (Join-Path $PSScriptRoot 'get.cmd') -Raw) -match '--force' -or
    (Get-Content (Join-Path $PSScriptRoot 'get-force.cmd') -Raw) -notmatch '"%BinaryPath%" --force') {
    throw 'Only get-force.cmd may pass force mode'
}

$Manifest = Get-Content (Join-Path $PSScriptRoot 'vercel.json') -Raw | ConvertFrom-Json
$Shims = @{ 'get-cmd.ps1' = 'get.cmd'; 'get-force-cmd.ps1' = 'get-force.cmd' }
foreach ($Shim in $Shims.GetEnumerator()) {
    $ShimPath = Join-Path $PSScriptRoot $Shim.Key
    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($ShimPath, [ref]$Tokens, [ref]$Errors) | Out-Null
    if ($Errors.Count) { throw "$($Shim.Key) has syntax errors: $Errors" }
    $Body = Get-Content $ShimPath -Raw
    if ($Body -notmatch [regex]::Escape("https://clean.meowery.eu/$($Shim.Value)")) {
        throw "$($Shim.Key) must bootstrap $($Shim.Value)"
    }
    if ($Body -notmatch 'Invoke-WebRequest' -or $Body -notmatch 'cmd\.exe /c' -or $Body -notmatch 'Remove-Item') {
        throw "$($Shim.Key) must fetch the batch launcher, run it through cmd.exe, and clean up"
    }
}
foreach ($Route in @(@('/c', '/get-cmd.ps1'), @('/fc', '/get-force-cmd.ps1'))) {
    if (($Manifest.rewrites | Where-Object source -eq $Route[0]).destination -ne $Route[1]) {
        throw "$($Route[0]) must serve $($Route[1])"
    }
}
foreach ($Route in @('/', '/f', '/v', '/c', '/fc')) {
    $Header = @($Manifest.headers | Where-Object source -eq $Route | ForEach-Object { $_.headers } | Where-Object key -eq 'Content-Type')
    if ($Header.Count -ne 1 -or $Header[0].value -notmatch '^text/plain') {
        throw "$Route must be served as text/plain so irm | iex can read it"
    }
}
