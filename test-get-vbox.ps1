$Path = Join-Path $PSScriptRoot 'get-vbox.ps1'
$Tokens = $null
$Errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$Errors) | Out-Null
if ($Errors.Count) { throw "get-vbox.ps1 has syntax errors: $Errors" }

$Script = Get-Content $Path -Raw
$Steps = @(
    '& $CleanerPath --force'
    'Start-BitsTransfer -Source ($BaseUrl + $InstallerName)'
    'Get-AuthenticodeSignature $InstallerPath'
    'Start-Process -FilePath $InstallerPath -Verb RunAs'
)
$Positions = @($Steps | ForEach-Object { $Script.IndexOf($_) })
if ($Positions -contains -1 -or ($Positions -join ',') -ne (($Positions | Sort-Object) -join ',') -or ([regex]::Matches($Script, '-Verb RunAs')).Count -ne 1) {
    throw 'Cleanup, download, signature verification and installer-only elevation must occur in that order'
}
