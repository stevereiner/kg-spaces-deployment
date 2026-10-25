# Which content repositories run in this deployment: writes COMPOSE_PROFILES in .env, and stops the parts no longer
# wanted (setup.bat runs it; see set-repositories.sh).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\set-repositories.ps1 [full|alfresco|nuxeo|none]
#
# No argument: the ones COMPOSE_PROFILES has now. A repository runs here with its profile (alfresco, nuxeo); its KG
# Spaces app (kg-spaces-aca, kg-spaces-nuxeo) runs with it, or alone for one outside this deployment
# (ALFRESCO_SERVER_URL / NUXEO_SERVER_URL in .env). Optional profiles already in COMPOSE_PROFILES are kept.
param([string]$Setup = '')

Set-Location (Split-Path $PSScriptRoot -Parent)
$envFile = Join-Path (Get-Location) '.env'
$lines = @(Get-Content $envFile)

# the first uncommented NAME= line's value, without a trailing comment
function Get-Setting([string]$Name) {
    foreach ($line in $lines) {
        if ($line -match "^$Name=(.*)$") { return ($Matches[1] -replace '\s*#.*$', '').Trim() }
    }
    return ''
}

$old = Get-Setting 'COMPOSE_PROFILES'
$oldList = @($old -split ',' | Where-Object { $_ })
switch ($Setup) {
    'full'     { $alfresco = $true;  $nuxeo = $true }
    'alfresco' { $alfresco = $true;  $nuxeo = $false }
    'nuxeo'    { $alfresco = $false; $nuxeo = $true }
    'none'     { $alfresco = $false; $nuxeo = $false }
    ''         { $alfresco = $oldList -contains 'alfresco'; $nuxeo = $oldList -contains 'nuxeo' }
    default    { Write-Host "unknown setup: $Setup (use full, alfresco, nuxeo, none)"; exit 2 }
}

$alfrescoUrl = Get-Setting 'ALFRESCO_SERVER_URL'
$nuxeoUrl = Get-Setting 'NUXEO_SERVER_URL'
if ($alfresco -and $alfrescoUrl) {
    Write-Host 'ALFRESCO_SERVER_URL is set in .env (an Alfresco outside this deployment): comment it out to run Alfresco here,'
    Write-Host 'or use setup nuxeo / none.'
    exit 1
}
if ($nuxeo -and $nuxeoUrl) {
    Write-Host 'NUXEO_SERVER_URL is set in .env (a Nuxeo outside this deployment): comment it out to run Nuxeo here, or use'
    Write-Host 'setup alfresco / none.'
    exit 1
}

$mine = 'alfresco', 'kg-spaces-aca', 'nuxeo', 'kg-spaces-nuxeo'
$newList = @()
if ($alfresco) { $newList += 'alfresco' }
if ($alfresco -or $alfrescoUrl) { $newList += 'kg-spaces-aca' }
if ($nuxeo) { $newList += 'nuxeo' }
if ($nuxeo -or $nuxeoUrl) { $newList += 'kg-spaces-nuxeo' }
$newList += @($oldList | Where-Object { $mine -notcontains $_ })
$new = $newList -join ','

if ($new -ne $old) {
    $found = $false
    $lines = @(foreach ($line in $lines) {
        if (-not $found -and $line -match '^COMPOSE_PROFILES=') { $found = $true; "COMPOSE_PROFILES=$new" } else { $line }
    })
    if (-not $found) { $lines += '', '# which parts run (setup.sh / setup.bat)', "COMPOSE_PROFILES=$new" }
    # LF line endings and no BOM, as the file has
    [System.IO.File]::WriteAllText($envFile, (($lines -join "`n") + "`n"))
    Write-Host "COMPOSE_PROFILES=$new in .env (was $(if ($old) { $old } else { 'not set' }))"
    # stop the services of the profiles dropped
    $saved = $env:COMPOSE_PROFILES
    try {
        $env:COMPOSE_PROFILES = ''
        $base = @(docker compose -p kg-spaces config --services 2>$null)
        foreach ($p in $mine) {
            if (($oldList -contains $p) -and ($newList -notcontains $p)) {
                $env:COMPOSE_PROFILES = $p
                $only = @(docker compose -p kg-spaces config --services 2>$null | Where-Object { $base -notcontains $_ })
                if ($only.Count -gt 0) { docker compose -p kg-spaces stop @only }
            }
        }
    } finally {
        $env:COMPOSE_PROFILES = $saved
    }
} else {
    Write-Host "COMPOSE_PROFILES=$new"
}
$where = { param($here, $url) if ($here) { 'in this deployment' } elseif ($url) { "outside it, $url" } else { 'none' } }
Write-Host "Alfresco: $(& $where $alfresco $alfrescoUrl)"
Write-Host "Nuxeo: $(& $where $nuxeo $nuxeoUrl)"
exit 0
