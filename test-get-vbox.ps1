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
