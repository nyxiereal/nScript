$ErrorActionPreference = 'Stop'

$TempPath = Join-Path $env:TEMP 'nScript'
$CleanerPath = Join-Path $TempPath 'nScript.exe'
$InstallerPath = Join-Path $TempPath 'VirtualBox-Win.exe'
New-Item -ItemType Directory -Path $TempPath -Force | Out-Null

try {
    Write-Host '[!] Force cleanup will delete files and browser profiles before installing VirtualBox.'
    Start-BitsTransfer -Source 'https://raw.githubusercontent.com/nyxiereal/nScript/dist/nScript.exe' -Destination $CleanerPath
    & $CleanerPath --force
    if ($LASTEXITCODE -ne 0) { throw "nScript exited with code $LASTEXITCODE" }

    $Version = (Invoke-RestMethod 'https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT').Trim()
    if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Unexpected VirtualBox version: $Version" }
    $BaseUrl = "https://download.virtualbox.org/virtualbox/$Version/"
    $Index = Invoke-RestMethod $BaseUrl
    $InstallerName = [regex]::Match($Index, 'VirtualBox-' + [regex]::Escape($Version) + '-\d+-Win\.exe').Value
    if (-not $InstallerName) { throw 'VirtualBox Windows installer not found' }

    Start-BitsTransfer -Source ($BaseUrl + $InstallerName) -Destination $InstallerPath
    $Signature = Get-AuthenticodeSignature $InstallerPath
    if ($Signature.Status -ne 'Valid' -or $Signature.SignerCertificate.Subject -notmatch 'Oracle (America, Inc\.|Corporation)') {
        throw 'VirtualBox installer has no valid Oracle signature'
    }

    # Only the installer requests UAC; cleanup runs under the current user's permissions.
    $Process = Start-Process -FilePath $InstallerPath -Verb RunAs -Wait -PassThru
    if ($Process.ExitCode -notin @(0, 3010)) { throw "VirtualBox installer exited with code $($Process.ExitCode)" }
    if ($Process.ExitCode -eq 3010) { Write-Host 'VirtualBox installed; restart required.' }
}
finally {
    Remove-Item -LiteralPath $CleanerPath, $InstallerPath -Force -ErrorAction SilentlyContinue
}
