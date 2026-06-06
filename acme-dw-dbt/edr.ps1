# Script to run the `edr` CLI (elementary-data) with local env vars and profiles.yml.
# Analogous to dbt.ps1 — loads .env and points --profiles-dir to the project root.
# Usage: .\edr.ps1 [edr command] [arguments]
# IMPORTANT: always pass --profile-target prod (the 'dev' target is disabled).
# Examples:
#   .\edr.ps1 report --profile-target prod
#   .\edr.ps1 monitor --profile-target prod

$envFile = Join-Path $PSScriptRoot ".env"

if (-not (Test-Path $envFile)) {
    Write-Host "Error: .env file not found."
    Write-Host "Create the .env based on .env.example"
    exit 1
}

# load variables from .env
Get-Content $envFile | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
    $parts = $_ -split '=', 2
    [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), 'Process')
}

if ($args.Count -eq 0) {
    Write-Host "Usage: .\edr.ps1 [command] [arguments]"
    Write-Host ""
    Write-Host "Examples (always with --profile-target prod):"
    Write-Host "  .\edr.ps1 report --profile-target prod    # generates local HTML"
    Write-Host "  .\edr.ps1 monitor --profile-target prod   # fires alerts (Slack/Teams)"
    exit 1
}

Write-Host "Running: uv run edr $args --profiles-dir ."
Write-Host ""

uv run edr @args --profiles-dir .
exit $LASTEXITCODE
