# Removes the deployment's containers that have no network: a start that failed while setting up networking (e.g. a
# host port already taken) leaves its container created without one, and starting that container again later gives a
# service that can't reach the others. docker compose up then creates them again; volumes are kept. setup.bat runs it
# before starting (see remove-detached.sh).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\remove-detached.ps1

Set-Location (Split-Path $PSScriptRoot -Parent)

# {{json .}}: Windows PowerShell mangles quotes inside native arguments, so no {{.Label "..."}} here
$services = @(foreach ($line in docker ps -a --filter label=com.docker.compose.project=kg-spaces --format '{{json .}}') {
    $c = $line | ConvertFrom-Json
    if ([string]::IsNullOrEmpty($c.Networks)) {
        ($c.Labels -split ',' | Where-Object { $_ -like 'com.docker.compose.service=*' }) -replace '^com\.docker\.compose\.service=', ''
    }
}) | Where-Object { $_ } | Sort-Object -Unique

if ($services) {
    Write-Host "Containers left without a network by an earlier failed start, removed (compose creates them again): $($services -join ' ')"
    docker compose -p kg-spaces rm -f -s @services
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
exit 0
