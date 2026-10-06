#!/usr/bin/env fish

# PowerShell is the artifact; only run static/safe checks, never cleanup.
pwsh -NoProfile -File ./test-get-vbox.ps1; or exit $status
pwsh -NoProfile -File ./test-nscript.ps1; or exit $status
echo 'nScript.ps1 is ready for distribution'
