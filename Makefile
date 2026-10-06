.PHONY: all build test

all: build

# Source is the distribution artifact; do not run the cleaner while validating it.
build: test
	@echo "nScript.ps1 is ready for distribution"

test:
	pwsh -NoProfile -File ./test-get-vbox.ps1
	pwsh -NoProfile -File ./test-nscript.ps1
	pwsh -NoProfile -File ./test-nscript-windows.ps1
