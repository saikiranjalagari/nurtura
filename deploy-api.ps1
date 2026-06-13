# Deploy Nurtura API to Render (free tier) for mobile clients.
#
# Prerequisites:
#   1. Neon Postgres (free): https://neon.tech  -> copy connection string
#   2. OpenAI API key with billing enabled
#   3. Render account: https://render.com
#
# Usage:
#   .\deploy-api.ps1
#   Opens the one-click Render deploy page for this repo.

$ErrorActionPreference = "Stop"

$repoUrl = "https://github.com/saikiranjalagari/nurtura"
$deployUrl = "https://render.com/deploy?repo=$repoUrl"

Write-Host ""
Write-Host "Nurtura API — mobile backend deploy" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Step 1: Create a free Neon Postgres database"
Write-Host "  https://console.neon.tech/app/projects"
Write-Host "  Copy the connection string (starts with postgresql://)"
Write-Host ""
Write-Host "Step 2: Deploy API on Render (one-click)"
Write-Host "  Opening: $deployUrl"
Write-Host ""
Write-Host "  When prompted, set these environment variables:"
Write-Host "    DATABASE_URL     = your Neon connection string"
Write-Host "    OPENAI_API_KEY   = your OpenAI key"
Write-Host ""
Write-Host "Step 3: After deploy finishes, copy your API URL"
Write-Host "  Example: https://nurtura-api.onrender.com"
Write-Host "  Test:     https://nurtura-api.onrender.com/api/health"
Write-Host ""
Write-Host "Step 4: Build the Android app"
Write-Host '  .\deploy-mobile.ps1 -ApiBaseUrl "https://nurtura-api.onrender.com/api"'
Write-Host ""

Start-Process $deployUrl
