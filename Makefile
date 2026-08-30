.PHONY: all build clean test deps help

# Variables
BINARY_NAME=nScript.exe
GO=go
GOFLAGS=-ldflags="-s -w"
GOOS=windows
GOARCH=amd64

all: deps build

help:
	@echo "nScript Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Download dependencies and build all binaries"
	@echo "  deps         - Download Go dependencies"
	@echo "  build        - Build normal mode binary"
	@echo "  clean        - Remove built binaries"
	@echo "  test         - Run tests"
	@echo "  help         - Show this help message"

deps:
	@echo "[*] Downloading dependencies..."
	$(GO) mod download
	@echo "[+] Dependencies downloaded"

build:
	@echo "[*] Building $(BINARY_NAME)..."
	GOOS=$(GOOS) GOARCH=$(GOARCH) CGO_ENABLED=0 $(GO) build $(GOFLAGS) -o $(BINARY_NAME) main.go
	@echo "[+] Built $(BINARY_NAME)"

clean:
	@echo "[*] Cleaning..."
	rm -f $(BINARY_NAME)
	@echo "[+] Cleaned"

test:
	@echo "[*] Running tests..."
	$(GO) test -v ./...
	@echo "[+] Tests complete"
