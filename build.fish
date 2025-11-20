#!/usr/bin/env fish

# nScript Build Script for Fish Shell
# Builds both normal and force mode binaries for Windows

set BINARY_NAME "nScript.exe"
set FORCE_BINARY_NAME "nScript-force.exe"

echo "[*] Building nScript"
echo ""

# Check if Go is installed
if not command -v go &> /dev/null
    echo "[-] Go is not installed. Please install Go first."
    exit 1
end

# Download dependencies
echo "[*] Downloading dependencies..."
go mod download
if test $status -ne 0
    echo "[-] Failed to download dependencies"
    exit 1
end
echo "[+] Dependencies downloaded"
echo ""

# Build normal mode
echo "[*] Building $BINARY_NAME (Normal Mode)..."
env GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o $BINARY_NAME main.go
if test $status -ne 0
    echo "[-] Failed to build $BINARY_NAME"
    exit 1
end
echo "[+] Built $BINARY_NAME"
echo ""

# Build force mode
echo "[*] Building $FORCE_BINARY_NAME (Force Mode)..."
env GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o $FORCE_BINARY_NAME force.go
if test $status -ne 0
    echo "[-] Failed to build $FORCE_BINARY_NAME"
    exit 1
end
echo "[+] Built $FORCE_BINARY_NAME"
echo ""

# Show file sizes
if test -f $BINARY_NAME
    set size (du -h $BINARY_NAME | cut -f1)
    echo "[*] $BINARY_NAME size: $size"
end

if test -f $FORCE_BINARY_NAME
    set size (du -h $FORCE_BINARY_NAME | cut -f1)
    echo "[*] $FORCE_BINARY_NAME size: $size"
end

echo ""
echo "[+] Build complete!"
echo ""
echo "Usage:"
echo "  Normal Mode:  irm https://raw.githubusercontent.com/nyxiereal/nScript/master/install.ps1 | iex"
echo "  Force Mode:   irm https://raw.githubusercontent.com/nyxiereal/nScript/master/install-force.ps1 | iex"
