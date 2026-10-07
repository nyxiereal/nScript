import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const source = readFileSync('nScript.ps1', 'utf8');
const param = 'param([switch]$Force, [switch]$InstallApps)';
if (source.split(param).length !== 2) throw new Error('Unexpected nScript.ps1 parameter declaration');
mkdirSync('public', { recursive: true });
writeFileSync('public/nScript.ps1', source);
writeFileSync('public/force.ps1', source.replace(param, 'param([switch]$Force = $true, [switch]$InstallApps)'));
writeFileSync('public/install.ps1', source.replace(param, 'param([switch]$Force, [switch]$InstallApps = $true)'));
copyFileSync('winget-portable.zip', 'public/winget-portable.zip');
