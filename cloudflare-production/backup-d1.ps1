$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

foreach ($tool in @('node', 'npm', 'npx')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool is required. Install Node.js LTS first." }
}

$Wrangler = 'npx'
$WranglerArgs = @('--yes', 'wrangler@latest')
$DatabaseName = 'angelshop-production'
$backupDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupFile = Join-Path $backupDir "angelshop-production-$stamp.sql"

& $Wrangler @WranglerArgs whoami | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Cloudflare login required. Run npx wrangler login first.' }
& $Wrangler @WranglerArgs d1 export $DatabaseName --remote --output $backupFile
if ($LASTEXITCODE -ne 0) { throw 'D1 export failed; no backup was confirmed.' }
if (-not (Test-Path $backupFile) -or (Get-Item $backupFile).Length -lt 100) {
    throw 'Backup output is missing or unexpectedly small. Check Wrangler output before relying on it.'
}
Write-Host "D1 backup created: $backupFile" -ForegroundColor Green
Write-Warning 'This SQL file contains customer and order data. Keep it private, encrypt it at rest, and never commit it to GitHub.'
