# Running nScript

nScript is a **destructive Windows 10/11 cleanup script**. Read [the cleanup targets and limitations](cleanup-targets.md) and `nScript.ps1` before opting in. Normal mode can delete files from Downloads, Documents and Desktop, as well as app data; it is not a preview. Back up required user data first, save work, and close apps/browsers. There is no implemented dry-run or `-WhatIf`, and there is no automatic undo for deleted files. Registry keys selected for deletion are exported first to `%USERPROFILE%\.nScript\registry-backups`; those backups survive the run, but do not cover files or every settings change. Browser policies written under HKCU persist after the run.

Run from the **account whose data you intend to clean**: HKCU and `%USERPROFILE%` refer to the process's account. Using another account's administrator credentials changes which profile/HKCU is targeted. Elevating the same account does not switch profiles, but increases what can be deleted; do not elevate the whole cleaner merely to chase access errors. Windows PowerShell 5.1 is the supported runtime. Execution policy can block unsigned `.ps1` files; piping text into `iex` avoids launching a `.ps1` file, but it does not bypass application control or organizational restrictions. Follow your organization's policy rather than disabling it.

**Avoid active shared sessions.** Process operations match names without an account/session filter. With elevated permissions, force mode can terminate other users' matching browsers/OneDrive; Explorer and StartMenuExperienceHost can be stopped in either mode. File/HKCU targeting the current account does not make process termination account-scoped.

## Read-only preflight

In Windows PowerShell, these commands **do not run cleanup**:

```powershell
$PSVersionTable.PSVersion
Get-ExecutionPolicy -List
```

Confirm you have the intended script/release before running anything: `nScript.ps1` in this checkout is the single source. At deployment Vercel builds normal, force, and installer variants from it and serves them as UTF-8 PowerShell text. Local edits are not live until pushed to `master` and Vercel deploys. `/`, `/f`, `/v`, `/c`, and `/fc` each serve one complete script; `/c` and `/fc` are legacy aliases, not CMD launchers. Direct `/nScript.ps1`, `/force.ps1`, and `/install.ps1` serve the corresponding BOM-free variants for `irm | iex`; if saving one as a `.ps1` file for Windows PowerShell 5.1, save it as UTF-8 **with BOM** to preserve non-ASCII paths. `/winget-portable.zip` serves the pinned archive. Old `get*.ps1` URLs alias the complete scripts; `.cmd` launchers are retired. CI only validates on pushes to `master`, pull requests and manual dispatch; it does not publish. Check the source and hosted artifact separately before trusting a route.

## Choose an entry point

| Entry | Run it from | Result |
| --- | --- | --- |
| `/`, `/c`, or `/nScript.ps1` | PowerShell | Run normal cleanup from the response body |
| `/f`, `/fc`, or `/force.ps1` | PowerShell | Run force cleanup from the response body |
| `/v` or `/install.ps1` | PowerShell | Force cleanup, then app installations |
| Local `nScript.ps1` | PowerShell | Use this reviewed local copy without downloading the cleaner |

The retired `get*.ps1` URLs still alias these complete scripts for compatibility. No route downloads another script or invokes a batch file.

## Destructive use (opt in deliberately)

From a Windows PowerShell session in the repository directory, choose **one** direct invocation (the second is more destructive):

```powershell
.\nScript.ps1             # normal cleanup, no preview
# OR, separately, if you intend force cleanup:
.\nScript.ps1 -Force      # also deletes newer eligible files and stops browsers
# OR, separately, after reviewing the installer as well:
.\nScript.ps1 -InstallApps # force cleanup and ten app installations
```

For the hosted normal launcher, **only after reviewing the served script and accepting cleanup**:

```powershell
irm https://clean.meowery.eu/ | iex
```

Use `/f` in that PowerShell URL for force cleanup. `/v` means force cleanup **followed by** ten app installations: it downloads a pinned portable x64 WinGet archive, verifies its SHA-256, checks `winget --version`, runs cleanup under the signed-in user first, then prompts for UAC once for installs via a separately verified private copy. If cleanup reports warnings but exits zero, `/v` still attempts installs. UAC is for installs, not a remedy for missed cleanup targets.

The package list is Inkscape, GIMP 3, VS Code, Python 3.14, Notepad++, Orwell Dev-C++, Temurin 25 JDK, PyCharm Community, Code::Blocks with MinGW, and IntelliJ IDEA Community. It requests machine scope except for GIMP, whose manifest does not declare a scope. The WinGet bundle is x64 and does not require App Installer registration. `winget-portable.zip` (16,311,484 bytes, SHA-256 `88536696deaa13ea7441df74a62dd782f8cac75e46a23407b63b7ce8d39989cc`) is tracked on `master`, originally bundled from Microsoft's winget-cli v1.29.380 release; CI verifies it rather than rebuilding it. Cancelling UAC or failing an install does not undo the cleanup that already happened.

`/c` and `/fc` now serve the same complete PowerShell scripts as `/` and `/f`; they are **not** commands to paste into CMD. No cleanup script is staged or launched by another script. `/v` stages only the verified WinGet ZIP in a unique `%USERPROFILE%\.nScript\<run-id>` directory outside Temp, and removes it in `finally`; the separate `registry-backups` directory is persistent. Installing apps still requires one UAC prompt and a separate elevated PowerShell process with embedded commands, not a downloaded script.

General file cleanup uses a 24-hour age cutoff in normal mode; force bypasses the age cutoff, **not** the `.iso`/`.lnk` exclusions or protected paths. Closed-browser profiles and Windows history/caches/recycle bin can be cleared in either mode regardless of age. See [cleanup targets](cleanup-targets.md) for scope and exceptions.

## Safe validation (not a cleanup run)

On a development host with PowerShell 7 (`pwsh`), from the repository root:

```powershell
pwsh -NoProfile -File ./test-get-vbox.ps1
pwsh -NoProfile -File ./test-nscript.ps1
pwsh -NoProfile -File ./test-nscript-windows.ps1
```

These tests generate and parse/check the static route scripts and workflow text, and AST-extract only pure functions for checks; they never run or dot-source the cleaner. `make` and `./build.fish` run the same safe checks. CI runs the checks on Ubuntu PowerShell 7 and Windows PowerShell 5.1, then smoke-tests the bundled WinGet CLI and package search on Windows (no installs). Running PS7 tests locally does not prove the Windows 5.1 job ran, that cleanup works on a real account, or that deployment is current. Verify the Windows 5.1 CI result and production deployment after publishing.

## When something goes wrong

- **Download/startup fails:** Check the network, execution policy and application-control message, whether `nScript.ps1` and `winget-portable.zip` exist on `master`, and whether Vercel has built and deployed the current commit and routes. Fatal startup errors stop the run; `/v` verifies the ZIP before cleanup. Do not substitute an EXE or assume a successful local validation deployed the files.
- **Completed with warnings:** Read the *first specific warning* (directory, browser or Windows cleanup) and the failed/skipped counts. Cleanup is best-effort; it may report failures and still exit **0**. Zero does not mean all files were removed. Locked files or a running browser in normal mode can leave data behind; close apps and investigate the reported path before considering another run.
- **Files/apps remain:** `.iso`/`.lnk` exclusions (with named exceptions), `GT Works3`/`GX Works3` protected subtrees, critical directories, reparse points and inaccessible paths may remain. File/data removal is **not** a registered uninstall: services, drivers and registered apps may still be present. See [cleanup targets](cleanup-targets.md); avoid escalating the whole run to a different account to chase residues.
- **Browser settings remain:** HKCU Firefox/Chrome policies are persistent and may be overridden or blocked by managed machine policies. Inspect the actual warnings and your browser policy view rather than expecting cleanup to reset them.
