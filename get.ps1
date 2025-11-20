# nScript Installer - Normal Mode
# Usage: irm https://raw.githubusercontent.com/nyxiereal/nScript/master/install.ps1 | iex

$ErrorActionPreference = "Stop"

# Configuration
$RepoOwner = "nyxiereal"
$RepoName = "nScript"
$BinaryName = "nScript.exe"
$TempPath = Join-Path $env:TEMP "nScript"
$BinaryPath = Join-Path $TempPath $BinaryName

Write-Host "[*] nScript Downloader" -ForegroundColor Cyan
Write-Host "[*] Downloading and running nScript (Normal Mode)..." -ForegroundColor Cyan
Write-Host ""

# Create temp directory
if (-not (Test-Path $TempPath)) {
    New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
}

try {
    # Download from jsDelivr CDN (dist branch)
    $DownloadUrl = "https://cdn.jsdelivr.net/gh/$RepoOwner/$RepoName@dist/$BinaryName"
    
    Write-Host "[*] Downloading $BinaryName from CDN..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryPath -UseBasicParsing
    
    Write-Host "[+] Download complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[*] Running nScript..." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Run the binary
    & $BinaryPath
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[+] nScript execution completed!" -ForegroundColor Green
}
catch {
    Write-Host "[-] Error: $_" -ForegroundColor Red
    Write-Host "[-] Failed to download or execute nScript" -ForegroundColor Red
    exit 1
}
finally {
    # Cleanup
    if (Test-Path $BinaryPath) {
        Write-Host "[*] Cleaning up..." -ForegroundColor Yellow
        Remove-Item -Path $BinaryPath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "[*] For force mode (removes all files), use:" -ForegroundColor Cyan
Write-Host "    irm https://raw.githubusercontent.com/$RepoOwner/$RepoName/master/install-force.ps1 | iex" -ForegroundColor Cyan
