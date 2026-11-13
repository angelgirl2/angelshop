$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

foreach ($tool in @('node', 'npm', 'npx')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool is required. Install Node.js LTS first." }
}

$DatabaseName = 'angelshop-production'
$Wrangler = 'npx'
$WranglerArgs = @('--yes', 'wrangler@latest')

function Invoke-Wrangler([string[]]$Arguments) {
    & $Wrangler @WranglerArgs @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Wrangler command failed: wrangler $($Arguments -join ' ')"
    }
}

function Convert-SecureToPlain([Security.SecureString]$Value) {
    if ($null -eq $Value) { return '' }
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

function New-RandomSecret([int]$Bytes = 48) {
    $buffer = New-Object byte[] $Bytes
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
    return [Convert]::ToBase64String($buffer).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Set-WorkerSecret([string]$Name, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    Write-Host "Setting Worker secret: $Name"
    $Value | & $Wrangler @WranglerArgs secret put $Name
    if ($LASTEXITCODE -ne 0) { throw "Could not set Worker secret $Name" }
}

Write-Host 'Angel Shop production deployment' -ForegroundColor Cyan
Write-Host 'A browser will open for Cloudflare authorization. Sign in to the account that should own this new Worker and D1 database.'
Write-Warning 'Cloudflare Workers Free allows 10 ms CPU per request. PBKDF2-SHA256 is a heavier authentication operation; test register/login after deployment and use Workers Paid/Standard if the Free CPU limit is exceeded. Do not lower password hashing iterations merely to bypass the limit.'
try {
    & $Wrangler @WranglerArgs whoami | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Cloudflare login is required.' }
} catch {
    Invoke-Wrangler @('login')
}

# Create an independent D1 resource only when this deployment folder has no binding yet.
$tomlPath = Join-Path $PSScriptRoot 'wrangler.toml'
$toml = Get-Content -Raw -Path $tomlPath
if ($toml -notmatch '(?m)^\[\[d1_databases\]\]') {
    Write-Host "Creating a new D1 database: $DatabaseName" -ForegroundColor Yellow
    Invoke-Wrangler @('d1', 'create', $DatabaseName, '--binding', 'DB', '--update-config')
    $toml = Get-Content -Raw -Path $tomlPath
}
if ($toml -notmatch '(?m)^\[\[d1_databases\]\]') {
    throw 'D1 binding was not written into wrangler.toml. Check the Wrangler create output and do not deploy without a database binding.'
}
if ($toml -notmatch '(?m)^migrations_dir\s*=') {
    $toml = [regex]::Replace($toml, '(?m)^(database_id\s*=\s*"[^"]+"\s*)$', '$1' + "`r`nmigrations_dir = `"migrations`"", 1)
    [System.IO.File]::WriteAllText($tomlPath, $toml, [System.Text.UTF8Encoding]::new($false))
}

Write-Host 'Applying production D1 migrations...' -ForegroundColor Yellow
Invoke-Wrangler @('d1', 'migrations', 'apply', $DatabaseName, '--remote', '--yes')

Write-Host 'Deploying independent production Worker...' -ForegroundColor Yellow
$deployOutput = & $Wrangler @WranglerArgs deploy 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-Host $deployOutput
    throw 'Worker deployment failed.'
}
Write-Host $deployOutput
$urlMatch = [regex]::Match($deployOutput, 'https://[a-zA-Z0-9.-]+\.workers\.dev')
$WorkerUrl = if ($urlMatch.Success) { $urlMatch.Value.TrimEnd('/') } else { Read-Host 'Worker URL was not detected. Enter the URL shown by Wrangler' }
if ($WorkerUrl -notmatch '^https://[a-zA-Z0-9.-]+\.workers\.dev$') {
    throw 'Worker URL must be the HTTPS workers.dev URL printed by Wrangler.'
}

$webhookSecret = New-RandomSecret
$rateLimitPepper = New-RandomSecret
Set-WorkerSecret 'WEBHOOK_SECRET' $webhookSecret
Set-WorkerSecret 'RATE_LIMIT_PEPPER' $rateLimitPepper

$botSecure = Read-Host 'Bale bot token (press Enter to skip bot notifications)' -AsSecureString
$botToken = Convert-SecureToPlain $botSecure
$adminChatId = ''
if (-not [string]::IsNullOrWhiteSpace($botToken)) {
    $adminChatId = Read-Host 'Bale administrator private chat ID (not a public group)'
    if ([string]::IsNullOrWhiteSpace($adminChatId)) { throw 'Admin chat ID is required when a Bale bot token is provided.' }
    Set-WorkerSecret 'BOT_TOKEN' $botToken
    Set-WorkerSecret 'ADMIN_CHAT_ID' $adminChatId
}

Write-Host 'Importing product catalog to D1 (existing rows are not deleted)...' -ForegroundColor Yellow
$catalogPath = Join-Path $PSScriptRoot '..\worker\products.json'
if (-not (Test-Path $catalogPath)) { throw "Product catalog not found: $catalogPath" }
$catalogUri = "$WorkerUrl/admin/catalog"
$catalogResult = Invoke-RestMethod -Method Post -Uri $catalogUri -Headers @{ 'X-Setup-Secret' = $webhookSecret } -ContentType 'application/json' -InFile $catalogPath
if (-not $catalogResult.ok) { throw "Catalog import failed: $($catalogResult.error)" }
Write-Host "Imported/updated $($catalogResult.count) products." -ForegroundColor Green

if (-not [string]::IsNullOrWhiteSpace($botToken)) {
    $webhookUri = "$WorkerUrl/bale/$webhookSecret"
    $baleResult = Invoke-RestMethod -Method Post -Uri "https://tapi.bale.ai/bot$botToken/setWebhook" -Body @{ url = $webhookUri }
    if (-not $baleResult.ok) {
        Write-Warning 'Worker is deployed, but Bale did not confirm webhook setup. Check the token and bot configuration.'
    } else {
        Write-Host 'Bale webhook configured.' -ForegroundColor Green
    }
}

$health = Invoke-RestMethod -Method Get -Uri "$WorkerUrl/health"
if (-not $health.ok -or $health.database -ne 'connected') { throw 'Health check did not confirm the D1 database.' }
$products = Invoke-RestMethod -Method Get -Uri "$WorkerUrl/products"
if (@($products).Count -lt 1) { throw 'Worker is live, but the product catalog is empty.' }

$deploymentDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.deployment'
New-Item -ItemType Directory -Force -Path $deploymentDir | Out-Null
Set-Content -Path (Join-Path $deploymentDir 'worker-url.txt') -Value $WorkerUrl -NoNewline
Set-Content -Path (Join-Path $deploymentDir 'webhook-secret.txt') -Value $webhookSecret -NoNewline
Write-Host ''
Write-Host 'DEPLOYMENT SUCCEEDED' -ForegroundColor Green
Write-Host "Worker: $WorkerUrl"
Write-Host "D1 database: $DatabaseName"
Write-Host 'Verify register/login CPU usage after deployment. Workers Paid/Standard is recommended if the Free 10 ms CPU limit is exceeded.'
Write-Host "Products visible: $(@($products).Count)"
Write-Host ''
Write-Host 'Build the app with:' -ForegroundColor Cyan
Write-Host "flutter pub get"
Write-Host "flutter build apk --release --dart-define=API_URL=$WorkerUrl"
Write-Host ''
Write-Host 'For GitHub Actions, save .deployment/worker-url.txt as WORKER_URL and .deployment/webhook-secret.txt as WEBHOOK_SECRET.'
Write-Host 'Never commit .deployment, android/key.properties, or android/keystore/angelshop.jks.'
