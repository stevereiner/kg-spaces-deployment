# Lists running containers of other stacks that hold host ports this deployment publishes, and exits 1 when there
# are any (setup.bat runs it before starting; see check-ports.sh). Other programs on those ports aren't seen.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-ports.ps1

Set-Location (Split-Path $PSScriptRoot -Parent)

$ports = @(docker compose -p kg-spaces config 2>$null |
    Select-String '^\s+published:\s*"?(\d+)"?\s*$' |
    ForEach-Object { $_.Matches[0].Groups[1].Value })

# {{json .}}: Windows PowerShell mangles quotes inside native arguments, so no {{.Label "..."}} here
$busy = @(foreach ($line in docker ps --format '{{json .}}') {
    $c = $line | ConvertFrom-Json
    $project = ($c.Labels -split ',' | Where-Object { $_ -like 'com.docker.compose.project=*' }) -replace '^com\.docker\.compose\.project=', ''
    if ($project -eq 'kg-spaces') { continue }
    foreach ($m in [regex]::Matches([string]$c.Ports, ':(\d+)->')) {
        $p = $m.Groups[1].Value
        if ($ports -contains $p) {
            $from = if ($project) { "compose project $project" } else { 'not from compose' }
            "  $($c.Names) ($from): port $p"
        }
    }
}) | Sort-Object -Unique

if ($busy) {
    Write-Host 'Containers of other stacks hold ports this deployment uses:'
    $busy | ForEach-Object { Write-Host $_ }
    Write-Host 'Stop them first (docker compose -p <project> stop, or docker stop <container>), then run setup again.'
    exit 1
}
Write-Host "no other containers on the deployment's ports"
exit 0
