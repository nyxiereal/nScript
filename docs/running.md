# Running nScript

nScript is a **destructive Windows 10/11 cleanup script**. Read [the cleanup targets and limitations](cleanup-targets.md) and `nScript.ps1` before opting in. Normal mode can delete files from Downloads, Documents and Desktop, as well as app data; it is not a preview. Back up required user data first, save work, and close apps/browsers. There is no implemented dry-run or `-WhatIf`, and there is no automatic undo for deleted files. Registry keys selected for deletion are exported first to `%USERPROFILE%\.nScript\registry-backups`; those backups survive the run, but do not cover files or every settings change. Browser policies written under HKCU persist after the run.

Run from the **account whose data you intend to clean**: HKCU and `%USERPROFILE%` refer to the process's account. Using another account's administrator credentials changes which profile/HKCU is targeted. Elevating the same account does not switch profiles, but increases what can be deleted; do not elevate the whole cleaner merely to chase access errors. Windows PowerShell 5.1 (`powershell.exe`) is required for the launchers and is the supported runtime for the cleaner. Execution policy and native application-control rules can block unsigned PowerShell scripts; normal script-file execution and the batch routes do not bypass either. Follow your organization's policy rather than disabling it.

**Avoid active shared sessions.** Process operations match names without an account/session filter. With elevated permissions, force mode can terminate other users' matching browsers/OneDrive; Explorer and StartMenuExperienceHost can be stopped in either mode. File/HKCU targeting the current account does not make process termination account-scoped.

## Read-only preflight

In Windows PowerShell, these commands **do not run cleanup**:

```powershell
$PSVersionTable.PSVersion
Get-ExecutionPolicy -List
```

Confirm you have the intended script/release before running anything: `nScript.ps1` in this checkout is the source artifact; the download launchers fetch `https://raw.githubusercontent.com/nyxiereal/nScript/dist/nScript.ps1`, **not** your working copy. A local edit is not live until the `dist` branch has the new artifact and the serving deployment is updated. The Vercel `/`, `/f`, `/v`, `/c` and `/fc` routes serve PowerShell text (not CMD syntax); `/nScript.ps1` serves the script itself, not a launcher. The release workflow is manual (`workflow_dispatch`), validates before publishing to `dist`, and a local build does not deploy anything. Check the source and hosted artifact separately before trusting a route.

## Choose an entry point

| Entry | Run it from | Result |
| --- | --- | --- |
| `/` or `get.ps1` | PowerShell | Download and run normal cleanup |
| `/f` or `get-force.ps1` | PowerShell | Download and run force cleanup |
| `/v` or `get-vbox.ps1` | PowerShell | Force cleanup, then app installations; despite the filename, this does not install VirtualBox |
| `/c` | PowerShell | Fetch `get.cmd`, then run normal cleanup through CMD/PowerShell |
| `/fc` | PowerShell | Fetch `get-force.cmd`, then run force cleanup through CMD/PowerShell |
| Downloaded `get.cmd` / `get-force.cmd` | Command Prompt or double-click | Normal / force cleanup; still uses PowerShell |
| Local `nScript.ps1` | PowerShell | Use this reviewed local copy without downloading the cleaner |

`get.cmd` is a different entry shell, not a different cleaner. Both it and `get.ps1` launch the downloaded artifact with `powershell.exe -NoProfile -File`. The `.exe` distribution has been retired.

## Destructive use (opt in deliberately)

From a Windows PowerShell session in the repository directory, choose **one** direct invocation (the second is more destructive):

```powershell
.\nScript.ps1             # normal cleanup, no preview
# OR, separately, if you intend force cleanup:
.\nScript.ps1 -Force      # also deletes newer eligible files and stops browsers
```

For the hosted normal launcher, **only after reviewing the served script and accepting cleanup**:

```powershell
irm https://clean.meowery.eu/ | iex
```

Use `/f` in that PowerShell URL for force cleanup. `/v` means force cleanup **followed by** ten app installations: it downloads a pinned portable x64 WinGet archive, verifies its SHA-256, checks `winget --version`, runs cleanup under the signed-in user first, then prompts for UAC once for installs via a separately verified private copy. If cleanup reports warnings but exits zero, `/v` still attempts installs. UAC is for installs, not a remedy for missed cleanup targets.

The package list is Inkscape, GIMP 3, VS Code, Python 3.14, Notepad++, Orwell Dev-C++, Temurin 25 JDK, PyCharm Community, Code::Blocks with MinGW, and IntelliJ IDEA Community. It requests machine scope except for GIMP, whose manifest does not declare a scope. The WinGet bundle is x64 and does not require App Installer registration. Cancelling UAC or failing an install does not undo the cleanup that already happened.

`/c` and `/fc` are PowerShell shims that download and invoke `get.cmd` (normal) and `get-force.cmd` (force) through `cmd.exe`; they are **not** commands to paste into CMD. If starting in `cmd.exe`, run the literal `get.cmd` or `get-force.cmd` batch file instead. Both paths still download the real script and require Windows PowerShell 5.1; neither is an execution-policy or app-control bypass. All launchers stage each download in a unique `%USERPROFILE%\.nScript\<run-id>` directory outside Temp and attempt to delete that run directory in `finally`, including on failure. Interrupted processes or locked files can leave staging leftovers. The separate `registry-backups` directory is persistent.

General file cleanup uses a 24-hour age cutoff in normal mode; force bypasses the age cutoff, **not** the `.iso`/`.lnk` exclusions or protected paths. Closed-browser profiles and Windows history/caches/recycle bin can be cleared in either mode regardless of age. See [cleanup targets](cleanup-targets.md) for scope and exceptions.

## Safe validation (not a cleanup run)

On a development host with PowerShell 7 (`pwsh`), from the repository root:

```powershell
pwsh -NoProfile -File ./test-get-vbox.ps1
pwsh -NoProfile -File ./test-nscript.ps1
pwsh -NoProfile -File ./test-nscript-windows.ps1
```

These tests parse/check launcher and workflow text and AST-extract only pure functions for checks; they never run or dot-source the cleaner or launchers. `make` and `./build.fish` run the same safe checks. The workflow **defines** a Windows PowerShell 5.1 smoke-test job (no cleanup execution) after the PowerShell 7 checks, before publishing; running PS7 tests locally does not prove the Windows 5.1 job ran, that cleanup works on a real account, or that deployment is current.

## When something goes wrong

- **Download/startup fails:** Check the network, execution policy and application-control message, whether `dist/nScript.ps1` really exists in the published branch, and whether the serving route is current. Launchers reject empty downloads and nonzero child exit codes; fatal startup errors stop the run. Do not substitute an EXE or assume a successful local build published the artifact.
- **Completed with warnings:** Read the *first specific warning* (directory, browser or Windows cleanup) and the failed/skipped counts. Cleanup is best-effort; it may report failures and still exit **0**. Zero does not mean all files were removed. Locked files or a running browser in normal mode can leave data behind; close apps and investigate the reported path before considering another run.
- **Files/apps remain:** `.iso`/`.lnk` exclusions (with named exceptions), `GT Works3`/`GX Works3` protected subtrees, critical directories, reparse points and inaccessible paths may remain. File/data removal is **not** a registered uninstall: services, drivers and registered apps may still be present. See [cleanup targets](cleanup-targets.md); avoid escalating the whole run to a different account to chase residues.
- **Browser settings remain:** HKCU Firefox/Chrome policies are persistent and may be overridden or blocked by managed machine policies. Inspect the actual warnings and your browser policy view rather than expecting cleanup to reset them.
