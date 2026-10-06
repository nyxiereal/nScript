# Static-only tests: never import, dot-source, or execute a launcher or cleanup script.
$ErrorActionPreference = 'Stop'
$Base = $PSScriptRoot
$Artifact = 'https://raw.githubusercontent.com/nyxiereal/nScript/dist/nScript.ps1'

function Require($Body, $Pattern, $Message) {
    if ($Body -notmatch $Pattern) { throw $Message }
}

$Scripts = @('get.ps1', 'get-force.ps1', 'get-vbox.ps1', 'get-cmd.ps1', 'get-force-cmd.ps1')
foreach ($Name in $Scripts) {
    $Path = Join-Path $Base $Name
    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$Errors) | Out-Null
    if ($Errors.Count) { throw "$Name has syntax errors: $Errors" }
    $Body = Get-Content -LiteralPath $Path -Raw
    Require $Body '\$env:USERPROFILE\s+''\.nScript''' "$Name must stage outside Temp"
    Require $Body 'NewGuid\(' "$Name must isolate downloads per run"
    Require $Body 'SecurityProtocol\s*=\s*\[Net.SecurityProtocolType\]::Tls12' "$Name must support TLS 1.2 on PS5.1"
    Require $Body 'Invoke-WebRequest.+-OutFile' "$Name must download to a file"
    Require $Body '\.Length -eq 0' "$Name must reject an empty download"
    Require $Body 'finally\s*\{' "$Name must clean up on failure"
    Require $Body 'Remove-Item -LiteralPath \$RunPath|Remove-Item -LiteralPath \$WorkPath' "$Name must remove its stage"
    if ($Body -match '\$env:TEMP|nScript\.exe|ExecutionPolicy Bypass') { throw "$Name contains a retired or unsafe launch path" }
}

foreach ($Name in @('get.ps1', 'get-force.ps1', 'get-vbox.ps1')) {
    $Body = Get-Content -LiteralPath (Join-Path $Base $Name) -Raw
    Require $Body ([regex]::Escape($Artifact)) "$Name must fetch the script artifact"
    Require $Body '& powershell\.exe -NoProfile -File \$' "$Name must run cleanup in a child process"
    Require $Body '\$LASTEXITCODE -ne 0' "$Name must report child failures"
}
$Normal = Get-Content -LiteralPath (Join-Path $Base 'get.ps1') -Raw
$Force = Get-Content -LiteralPath (Join-Path $Base 'get-force.ps1') -Raw
$VBox = Get-Content -LiteralPath (Join-Path $Base 'get-vbox.ps1') -Raw
if ($Normal -match '-File \$ScriptPath -Force' -or $Force -notmatch '-File \$ScriptPath -Force' -or $VBox -notmatch '-File \$CleanerPath -Force') {
    throw 'Only force routes may pass -Force to the cleaner'
}
$Steps = @('winget-portable.zip'' -OutFile', 'Get-FileHash -LiteralPath $WingetArchive', '& $WingetPath --version', '-File $CleanerPath -Force', '$Install = {', '-Verb RunAs')
$Positions = @($Steps | ForEach-Object { $VBox.IndexOf($_) })
if ($Positions -contains -1 -or ($Positions -join ',') -ne (($Positions | Sort-Object) -join ',') -or ([regex]::Matches($VBox, '-Verb RunAs')).Count -ne 1) {
    throw 'WinGet must be verified before signed-in user cleanup, then one UAC elevation'
}
Require $VBox 'Copy-Item -LiteralPath \$WingetArchive -Destination \$TrustedArchive' 'Elevated install must copy WinGet privately'
Require $VBox 'Get-FileHash -LiteralPath \$TrustedArchive' 'Elevated install must verify its private copy'
Require $VBox '& \$WingetPath @Options' 'Elevated install must use the verified WinGet copy'
foreach ($Id in @('Inkscape.Inkscape', 'GIMP.GIMP.3', 'Microsoft.VisualStudioCode', 'Python.Python.3.14', 'Notepad++.Notepad++', 'Orwell.Dev-C++', 'EclipseAdoptium.Temurin.25.JDK', 'JetBrains.PyCharm.Community', 'CodeBlocks.CodeBlocks.MinGW', 'JetBrains.IntelliJIDEA.Community')) {
    Require $VBox ([regex]::Escape("'$Id'")) "Missing package: $Id"
}
foreach ($Flag in @('--exact', '--scope', '--silent', '--disable-interactivity', '--accept-source-agreements', '--accept-package-agreements')) {
    Require $VBox ([regex]::Escape("'$Flag'")) "Missing WinGet flag: $Flag"
}
if ($VBox -match 'VirtualBox|Embarcadero') { throw 'Old installer still present' }

foreach ($Pair in @(@('get-cmd.ps1', 'get.cmd'), @('get-force-cmd.ps1', 'get-force.cmd'))) {
    $Body = Get-Content -LiteralPath (Join-Path $Base $Pair[0]) -Raw
    Require $Body ([regex]::Escape("https://clean.meowery.eu/$($Pair[1])")) "$($Pair[0]) must fetch the batch launcher"
    Require $Body 'cmd\.exe /d /v:off /s /c ''""%NSCRIPT_CMD%""''' "$($Pair[0]) must run the downloaded batch file"
    Require $Body '\$LASTEXITCODE -ne 0' "$($Pair[0]) must report batch failures"
}
foreach ($Name in @('get.cmd', 'get-force.cmd')) {
    $Body = Get-Content -LiteralPath (Join-Path $Base $Name) -Raw
    Require $Body ([regex]::Escape($Artifact)) "$Name must fetch the real script artifact"
    Require $Body '\$env:USERPROFILE ''\.nScript''' "$Name must stage outside Temp"
    Require $Body 'NewGuid\(' "$Name must isolate downloads per run"
    Require $Body 'SecurityProtocol=\[Net.SecurityProtocolType\]::Tls12' "$Name must support TLS 1.2"
    Require $Body 'Invoke-WebRequest.+-OutFile' "$Name must download to a file"
    Require $Body '\.Length -eq 0' "$Name must reject an empty download"
    Require $Body '& powershell\.exe -NoProfile -File \$p' "$Name must invoke a child PowerShell"
    Require $Body 'exit \$LASTEXITCODE' "$Name must propagate child exit codes"
    Require $Body 'finally \{ Remove-Item -LiteralPath \$r' "$Name must clean up on failure"
    Require $Body 'exit /b %ERRORLEVEL%' "$Name must propagate PowerShell failures"
    $Command = [regex]::Match($Body, '(?m)^powershell\.exe -NoProfile -Command "(.+)"\r?$')
    if (-not $Command.Success) { throw "$Name must provide one parseable PowerShell command" }
    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($Command.Groups[1].Value, [ref]$Tokens, [ref]$Errors) | Out-Null
    if ($Errors.Count) { throw "$Name embeds invalid PowerShell: $Errors" }
    if ($Body -match '%USERPROFILE%|%TEMP%|%TMP%|nScript\.exe|ExecutionPolicy Bypass') { throw "$Name must not interpolate an untrusted path through cmd" }
}
$Cmd = Get-Content -LiteralPath (Join-Path $Base 'get.cmd') -Raw
$ForceCmd = Get-Content -LiteralPath (Join-Path $Base 'get-force.cmd') -Raw
if ($Cmd -match '-File \$p -Force' -or $ForceCmd -notmatch '-File \$p -Force') { throw 'Only get-force.cmd may pass -Force' }

$Manifest = Get-Content -LiteralPath (Join-Path $Base 'vercel.json') -Raw | ConvertFrom-Json
$Routes = @{ '/' = '/get.ps1'; '/f' = '/get-force.ps1'; '/v' = '/get-vbox.ps1'; '/c' = '/get-cmd.ps1'; '/fc' = '/get-force-cmd.ps1' }
foreach ($Route in $Routes.Keys) {
    $Rewrite = @($Manifest.rewrites | Where-Object source -eq $Route)
    if ($Rewrite.Count -ne 1 -or $Rewrite[0].destination -ne $Routes[$Route]) { throw "Incorrect rewrite for $Route" }
}
if (@($Manifest.rewrites | Where-Object source -eq '/nScript.exe').Count) { throw 'Do not map a fake executable route' }
foreach ($Route in @($Routes.Keys) + @('/get.ps1', '/get-force.ps1', '/get-vbox.ps1', '/get-cmd.ps1', '/get-force-cmd.ps1', '/nScript.ps1')) {
    $Header = @($Manifest.headers | Where-Object source -eq $Route | ForEach-Object { $_.headers } | Where-Object key -eq 'Content-Type')
    if ($Header.Count -ne 1 -or $Header[0].value -ne 'text/plain; charset=utf-8') { throw "$Route must serve plain UTF-8 text" }
}
$Workflow = Get-Content -LiteralPath (Join-Path $Base '.github/workflows/build.yml') -Raw
foreach ($Needle in @('nScript.ps1', 'winget-portable.zip', 'v1.29.380', 'sha256sum -c -', 'get-vbox.ps1 | head -1', 'shell: powershell', 'test-get-vbox.ps1', 'test-nscript.ps1', 'test-nscript-windows.ps1')) {
    Require $Workflow ([regex]::Escape($Needle)) "Workflow missing $Needle"
}
if ($Workflow -match 'go build|setup-go|nScript\.exe|(?m)^\s*(?:\./|\.\\)(?:get(?:-force|-vbox|-cmd|-force-cmd)?|nScript)\.ps1\s*$') {
    throw 'Workflow must never build an EXE or execute cleanup'
}
foreach ($BuildFile in @('Makefile', 'build.fish')) {
    $Body = Get-Content -LiteralPath (Join-Path $Base $BuildFile) -Raw
    Require $Body 'test-get-vbox\.ps1' "$BuildFile must validate launchers"
    Require $Body 'test-nscript\.ps1' "$BuildFile must validate the core"
    if ($Body -match 'go build|go mod|nScript\.exe|\.\/nScript\.ps1') { throw "$BuildFile must not build or execute cleanup" }
}
Write-Host 'Launcher, route and release checks passed (static only).'
