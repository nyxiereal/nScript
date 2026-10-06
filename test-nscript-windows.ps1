# Parse only. Never load or invoke the cleanup fragment.
$source = Join-Path $PSScriptRoot 'nScript.Windows.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$functions = @($ast.EndBlock.Statements)
if ($functions.Count -eq 0 -or @($functions | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] }).Count) {
    throw 'Windows fragment must contain only function definitions'
}
$main = @($functions | Where-Object Name -eq 'Invoke-NsWindowsCleanup')
if ($main.Count -ne 1 -or $main[0].Body.Extent.Text -notmatch 'Get-Command Remove-NsTree -CommandType Function') {
    throw 'Windows cleanup must require the core tree remover before mutations'
}
$pure = @($functions | Where-Object Name -eq 'Merge-NsFirefoxExtensionSettings')
if ($pure.Count -ne 1) { throw 'Missing pure Firefox JSON merge function' }
# Only evaluate the AST-extracted, registry-free JSON function, never the full source.
Invoke-Expression $pure[0].Extent.Text
$inputJson = '{"other@example":{"installation_mode":"allowed","nested":{"a":1}},"uBlock0@raymondhill.net":{"custom":true}}'
$result = Merge-NsFirefoxExtensionSettings -Existing $inputJson | ConvertFrom-Json
if ($result.'other@example'.nested.a -ne 1 -or $result.'uBlock0@raymondhill.net'.custom -ne $true -or
    $result.'uBlock0@raymondhill.net'.installation_mode -ne 'force_installed' -or
    $result.'uBlock0@raymondhill.net'.install_url -ne 'https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi') {
    throw 'Firefox JSON merge lost fields or failed to set uBlock'
}
foreach ($bad in @('{', 'null', '[]', '{"policies":{}}', '{"other@example":null}', '{"other@example":1}', '{"other@example":[]}', '{"other@example":[{}]}')) {
    $rejected = $false
    try { $null = Merge-NsFirefoxExtensionSettings -Existing $bad }
    catch { $rejected = $true }
    if (-not $rejected) { throw "Accepted invalid Firefox JSON: $bad" }
}
'Windows AST and pure JSON merge checks passed'
