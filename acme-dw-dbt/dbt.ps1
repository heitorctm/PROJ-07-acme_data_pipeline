# Script to run dbt with environment variables loaded
# Usage: .\dbt.ps1 [dbt command] [arguments]
# IMPORTANT: always pass --target prod (the 'dev' target is disabled; see profiles.yml).
# Examples:
#   .\dbt.ps1 debug --target prod
#   .\dbt.ps1 compile --select tag:staging --target prod
#   .\dbt.ps1 run --select tag:sales --target prod

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
    Write-Host "Usage: .\dbt.ps1 [command] [arguments]"
    Write-Host ""
    Write-Host "IMPORTANT: always pass --target prod (the 'dev' target is disabled)."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\dbt.ps1 debug --target prod"
    Write-Host "  .\dbt.ps1 compile --select tag:staging --target prod"
    Write-Host "  .\dbt.ps1 run --select tag:sales --target prod"
    exit 1
}

Write-Host "Running: uv run dbt $args"
Write-Host ""

uv run dbt @args
exit $LASTEXITCODE
