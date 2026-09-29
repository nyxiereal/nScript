$ErrorActionPreference = 'Stop'

# Keep cleanup under the signed-in user's account, before the single UAC prompt.
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required. Install or update App Installer before running cleanup.'
}

# Force cleanup wipes Temp; stage the running executable outside its deletion targets.
$WorkPath = Join-Path $env:USERPROFILE '.nScript'
$CleanerPath = Join-Path $WorkPath 'nScript.exe'
New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null

try {
    Write-Host '[!] Force cleanup will delete files and browser profiles before installing apps.'
    Start-BitsTransfer -Source 'https://raw.githubusercontent.com/nyxiereal/nScript/dist/nScript.exe' -Destination $CleanerPath
    & $CleanerPath --force
    if ($LASTEXITCODE -ne 0) { throw "nScript exited with code $LASTEXITCODE" }

    # Encode the install commands because this script can be run via Invoke-Expression (no script path).
    $Install = {
        $ErrorActionPreference = 'Stop'
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            throw 'WinGet is unavailable in the elevated account. Install App Installer for that account.'
        }
        $Failed = @()
        foreach ($Id in @(
            'Inkscape.Inkscape',
            'GIMP.GIMP.3',
            'Microsoft.VisualStudioCode',
            'Python.Python.3.14',
            'Notepad++.Notepad++',
            'Orwell.Dev-C++',
            'EclipseAdoptium.Temurin.25.JDK',
            'JetBrains.PyCharm.Community',
            'CodeBlocks.CodeBlocks.MinGW',
            'JetBrains.IntelliJIDEA.Community'
        )) {
            $Options = @('install', '--id', $Id, '--exact', '--source', 'winget', '--silent', '--disable-interactivity', '--accept-source-agreements', '--accept-package-agreements')
            # GIMP's WinGet manifest does not declare a scope; the others support machine installs.
            if ($Id -ne 'GIMP.GIMP.3') { $Options += @('--scope', 'machine') }
            & winget.exe @Options
            if ($LASTEXITCODE -ne 0) { $Failed += "$Id ($LASTEXITCODE)" }
        }
        if ($Failed.Count) { throw "WinGet failed to install: $($Failed -join ', ')" }
    }
    $Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Install.ToString()))
    $Process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList "-NoProfile -EncodedCommand $Encoded" -Wait -PassThru
    if ($Process.ExitCode -ne 0) { throw 'One or more app installs failed. Check the elevated PowerShell window or WinGet logs.' }
    Write-Host 'App installation completed.'
}
finally {
    Remove-Item -LiteralPath $CleanerPath -Force -ErrorAction SilentlyContinue
}
