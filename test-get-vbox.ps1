# Static-only: generate route assets, parse text; never run cleanup or installers.
$ErrorActionPreference = 'Stop'
$Base = $PSScriptRoot
Push-Location $Base
try { & node build.mjs; if ($LASTEXITCODE -ne 0) { throw 'Static build failed' } }
finally { Pop-Location }

$Param = 'param([switch]$Force, [switch]$InstallApps)'
$Source = [IO.File]::ReadAllText((Join-Path $Base 'nScript.ps1'))
if ($Source.Split(@($Param), [StringSplitOptions]::None).Count -ne 2) { throw 'Expected one parameter declaration' }
$Variants = @{
    'nScript.ps1' = $Source
    'force.ps1' = $Source.Replace($Param, 'param([switch]$Force = $true, [switch]$InstallApps)')
    'install.ps1' = $Source.Replace($Param, 'param([switch]$Force, [switch]$InstallApps = $true)')
}
foreach ($Name in $Variants.Keys) {
    $Path = Join-Path (Join-Path $Base 'public') $Name
    $Body = [IO.File]::ReadAllText($Path)
    if ($Body -cne $Variants[$Name]) { throw "$Name must be built from the single source without other changes" }
    $Tokens = $null; $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$Errors) | Out-Null
    if ($Errors.Count) { throw "$Name has syntax errors: $Errors" }
    if ($Body -match '(?i)Invoke-WebRequest[^\r\n]*\.ps1|(?i)-File\s+\$|(?i)cmd\.exe|(?i)ExecutionPolicy\s+Bypass') {
        throw "$Name must never download or execute another script"
    }
}
if ($Source -notmatch 'Invoke-NsCleanup -ForceMode \$true\s+Invoke-NsInstallApps' -or
    $Source -notmatch 'else \{ Invoke-NsCleanup -ForceMode \(\$Force -or \$args.Count -eq 1\) \}') {
    throw 'Installer must force cleanup; normal and force must only clean'
}
$Hash = '88536696deaa13ea7441df74a62dd782f8cac75e46a23407b63b7ce8d39989cc'
$Bundle = Join-Path $Base 'winget-portable.zip'
if ((Get-Item -LiteralPath $Bundle).Length -ne 16311484 -or
    (Get-FileHash -LiteralPath $Bundle -Algorithm SHA256).Hash -ne $Hash -or
    (Get-FileHash -LiteralPath (Join-Path $Base 'public/winget-portable.zip') -Algorithm SHA256).Hash -ne $Hash) {
    throw 'Built WinGet bundle differs from the pinned artifact'
}
foreach ($Pattern in @(
    [regex]::Escape("`$ExpectedWingetHash = '$Hash'"),
    "-Uri 'https://clean\.meowery\.eu/winget-portable\.zip' -OutFile",
    'Get-FileHash -LiteralPath \$WingetArchive',
    'Copy-Item -LiteralPath \$WingetArchive -Destination \$TrustedArchive',
    'Get-FileHash -LiteralPath \$TrustedArchive',
    '& \$WingetPath @Options',
    '-Verb RunAs -ArgumentList "-NoProfile -EncodedCommand \$Encoded"'
)) { if ($Source -notmatch $Pattern) { throw "Missing installer safety check: $Pattern" } }
$Steps = @('winget-portable.zip'' -OutFile', 'Get-FileHash -LiteralPath $WingetArchive', '& $WingetPath --version', 'Invoke-NsCleanup -ForceMode $true', 'Invoke-NsInstallApps -WingetArchive')
$Positions = @($Steps | ForEach-Object { $Source.LastIndexOf($_) })
if ($Positions -contains -1 -or ($Positions -join ',') -ne (($Positions | Sort-Object) -join ',') -or
    ([regex]::Matches($Source, '-Verb RunAs')).Count -ne 1) {
    throw 'WinGet must be checked before cleanup, then elevated exactly once for installation'
}
foreach ($Id in @('Inkscape.Inkscape', 'GIMP.GIMP.3', 'Microsoft.VisualStudioCode', 'Python.Python.3.14', 'Notepad++.Notepad++', 'Orwell.Dev-C++', 'EclipseAdoptium.Temurin.25.JDK', 'JetBrains.PyCharm.Community', 'CodeBlocks.CodeBlocks.MinGW', 'JetBrains.IntelliJIDEA.Community')) {
    if (-not $Source.Contains("'$Id'")) { throw "Missing package: $Id" }
}
$Manifest = Get-Content -LiteralPath (Join-Path $Base 'vercel.json') -Raw | ConvertFrom-Json
if ($null -ne $Manifest.framework -or $Manifest.buildCommand -ne 'node build.mjs' -or $Manifest.outputDirectory -ne 'public') {
    throw 'Vercel must build self-contained static assets from the single source'
}
$Routes = @{ '/' = '/nScript.ps1'; '/f' = '/force.ps1'; '/v' = '/install.ps1'; '/c' = '/nScript.ps1'; '/fc' = '/force.ps1'; '/get.ps1' = '/nScript.ps1'; '/get-force.ps1' = '/force.ps1'; '/get-vbox.ps1' = '/install.ps1'; '/get-cmd.ps1' = '/nScript.ps1'; '/get-force-cmd.ps1' = '/force.ps1' }
if (@($Manifest.rewrites).Count -ne $Routes.Count) { throw 'Unexpected rewrite count' }
foreach ($Route in @($Routes.Keys) + @('/nScript.ps1', '/force.ps1', '/install.ps1')) {
    if ($Routes.ContainsKey($Route)) {
        $Rewrite = @($Manifest.rewrites | Where-Object source -eq $Route)
        if ($Rewrite.Count -ne 1 -or $Rewrite[0].destination -ne $Routes[$Route]) { throw "Wrong route: $Route" }
    }
    $Header = @($Manifest.headers | Where-Object source -eq $Route | ForEach-Object { $_.headers } | Where-Object key -eq 'Content-Type')
    if ($Header.Count -ne 1 -or $Header[0].value -ne 'text/plain; charset=utf-8') { throw "Missing UTF-8 header: $Route" }
}
$ZipHeader = @($Manifest.headers | Where-Object source -eq '/winget-portable.zip' | ForEach-Object { $_.headers } | Where-Object key -eq 'Content-Type')
if ($ZipHeader.Count -ne 1 -or $ZipHeader[0].value -ne 'application/zip') { throw 'WinGet must be served as ZIP' }
foreach ($Name in @('get.ps1', 'get-force.ps1', 'get-vbox.ps1', 'get-cmd.ps1', 'get-force-cmd.ps1', 'get.cmd', 'get-force.cmd')) {
    if (Test-Path -LiteralPath (Join-Path $Base $Name)) { throw "$Name must not remain as a launcher" }
}
$Workflow = Get-Content -LiteralPath (Join-Path $Base '.github/workflows/validate.yml') -Raw
foreach ($Name in @('test-get-vbox.ps1', 'test-nscript.ps1', 'test-nscript-windows.ps1')) {
    if (([regex]::Matches($Workflow, [regex]::Escape("./$Name"))).Count -ne 2) { throw "Both OS jobs must run $Name" }
}
if ($Workflow -match 'upload-artifact|git push|(?m)^\s*(?:\./|\.\\)(?:get(?:-force|-vbox)?|nScript)\.ps1\s*$') { throw 'CI must not publish or run cleanup' }
'Passed: single-source route build, WinGet integrity and workflow (static only)'
