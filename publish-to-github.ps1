# Publish Nurtura to GitHub (run once after creating a Personal Access Token)
# Create token: https://github.com/settings/tokens/new  (scope: repo)
# Usage: .\publish-to-github.ps1 -Token "ghp_your_token_here"

param(
    [Parameter(Mandatory = $true)]
    [string]$Token,
    [string]$Username = "saikiranjalagari",
    [string]$RepoName = "nurtura",
    [switch]$Private
)

$ErrorActionPreference = "Stop"
$ghZip = "$env:TEMP\gh-portable\gh.zip"
$ghExe = "$env:TEMP\gh-portable\bin\gh.exe"

if (-not (Test-Path $ghExe)) {
    New-Item -ItemType Directory -Force -Path "$env:TEMP\gh-portable" | Out-Null
    Invoke-WebRequest -Uri "https://github.com/cli/cli/releases/download/v2.93.0/gh_2.93.0_windows_amd64.zip" -OutFile $ghZip
    Expand-Archive -Path $ghZip -DestinationPath "$env:TEMP\gh-portable" -Force
}

$Token | & $ghExe auth login --hostname github.com --git-protocol https --with-token

git branch -M main

$existingRemote = git remote get-url origin 2>$null
$targetUrl = "https://github.com/$Username/$RepoName.git"
if ($LASTEXITCODE -ne 0) {
    git remote add origin $targetUrl
} elseif ($existingRemote -ne $targetUrl) {
    git remote set-url origin $targetUrl
}

$visibility = if ($Private) { "--private" } else { "--public" }
& $ghExe repo create "$Username/$RepoName" $visibility --source=. --remote=origin --push

Write-Host ""
Write-Host "Done! Repository: https://github.com/$Username/$RepoName" -ForegroundColor Green
