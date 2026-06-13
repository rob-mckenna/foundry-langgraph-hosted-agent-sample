# predeploy hook — removes stale azd env variables that can poison the
# Foundry Hosted Agent publish step.
#
# These are auto-generated outputs from earlier azd provisions that conflict
# with the azure.ai.agent host type. Safe to remove: azd provision will
# re-create any that are still needed.

$stalePrefixes = @("SERVICE_", "containerApp", "managedIdentity")

$envFile = if ($env:AZURE_ENV_NAME) {
    ".azure/$($env:AZURE_ENV_NAME)/.env"
} else { "" }

if (-not $envFile -or -not (Test-Path $envFile)) {
    Write-Host "No azd env file found - skipping stale var cleanup."
    exit 0
}

$lines = Get-Content $envFile
$removed = 0
$kept = @()

foreach ($line in $lines) {
    $isStale = $false
    foreach ($prefix in $stalePrefixes) {
        if ($line.StartsWith($prefix)) {
            $isStale = $true
            $removed++
            break
        }
    }
    if (-not $isStale) { $kept += $line }
}

if ($removed -gt 0) {
    $kept | Set-Content $envFile
    Write-Host "Cleaned $removed stale env variable(s) from $envFile"
} else {
    Write-Host "No stale env variables found - env is clean."
}
