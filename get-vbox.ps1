$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Keep cleanup under the signed-in user's account, before the single UAC prompt.
# Stage WinGet outside cleanup targets; the elevated account gets a verified private copy.
$WorkPath = Join-Path (Join-Path $env:USERPROFILE '.nScript') ([guid]::NewGuid().ToString('N'))
$CleanerPath = Join-Path $WorkPath 'nScript.ps1'
$WingetPath = Join-Path $WorkPath 'winget-portable\winget.exe'
$WingetArchive = Join-Path $WorkPath 'winget-portable.zip'
$ExpectedWingetHash = '88536696deaa13ea7441df74a62dd782f8cac75e46a23407b63b7ce8d39989cc'
New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null

try {
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nyxiereal/nScript/dist/winget-portable.zip' -OutFile $WingetArchive -UseBasicParsing
    if ((Get-FileHash -LiteralPath $WingetArchive -Algorithm SHA256).Hash -ne $ExpectedWingetHash) {
        throw 'Portable WinGet download failed integrity check; cleanup was not run.'
    }
    Expand-Archive -LiteralPath $WingetArchive -DestinationPath (Split-Path $WingetPath) -Force
    & $WingetPath --version
    if ($LASTEXITCODE -ne 0) { throw 'Portable WinGet failed to start; cleanup was not run.' }

    Write-Host '[!] Force cleanup will delete files and browser profiles before installing apps.'
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nyxiereal/nScript/dist/nScript.ps1' -OutFile $CleanerPath -UseBasicParsing
    if ((Get-Item -LiteralPath $CleanerPath).Length -eq 0) { throw 'nScript download is empty.' }
    & powershell.exe -NoProfile -File $CleanerPath -Force
    if ($LASTEXITCODE -ne 0) { throw "nScript exited with code $LASTEXITCODE" }

    # Encode the install commands because this script can be run via Invoke-Expression (no script path).
    $Install = {
        $ErrorActionPreference = 'Stop'
        # Never execute a student-writable copy with administrator privileges.
        $TrustedPath = Join-Path $env:ProgramFiles ('nScript-winget-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $TrustedPath | Out-Null
        try {
            $TrustedArchive = Join-Path $TrustedPath 'winget.zip'
            Copy-Item -LiteralPath $WingetArchive -Destination $TrustedArchive
            if ((Get-FileHash -LiteralPath $TrustedArchive -Algorithm SHA256).Hash -ne $ExpectedWingetHash) {
                throw 'Portable WinGet archive changed before elevation.'
            }
            Expand-Archive -LiteralPath $TrustedArchive -DestinationPath $TrustedPath
            $WingetPath = Join-Path $TrustedPath 'winget.exe'
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
                & $WingetPath @Options
                if ($LASTEXITCODE -ne 0) { $Failed += "$Id ($LASTEXITCODE)" }
            }
            if ($Failed.Count) { throw "WinGet failed to install: $($Failed -join ', ')" }
        }
        finally {
            Remove-Item -LiteralPath $TrustedPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $PathLiteral = "'" + $WingetArchive.Replace("'", "''") + "'"
    $Setup = "`$WingetArchive = $PathLiteral`n`$ExpectedWingetHash = '$ExpectedWingetHash'`n"
    $Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Setup + $Install.ToString()))
    $Process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList "-NoProfile -EncodedCommand $Encoded" -Wait -PassThru
    if ($Process.ExitCode -ne 0) { throw 'One or more app installs failed. Check the elevated PowerShell window or WinGet logs.' }
    Write-Host 'App installation completed.'
}
finally {
    Remove-Item -LiteralPath $WorkPath -Recurse -Force -ErrorAction SilentlyContinue
}
