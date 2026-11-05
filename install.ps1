param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $ScriptDir ".env"
$ComposeFile = Join-Path $ScriptDir "docker-compose.build.yml"

if (-not (Test-Path $ComposeFile)) {
    throw "Compose file not found: $ComposeFile"
}

function Set-OrKeepEnvValue {
    param(
        [string]$Key,
        [string]$Value
    )

    if (-not (Test-Path $EnvFile)) {
        New-Item -Path $EnvFile -ItemType File -Force | Out-Null
    }

    $lines = @()
    if (Test-Path $EnvFile) {
        $lines = Get-Content -Path $EnvFile
    }

    $existing = $lines | Where-Object { $_ -match "^$([regex]::Escape($Key))=" }
    if ($existing) {
        $existingValue = ($existing | Select-Object -First 1).Split("=", 2)[1]
        if (-not [string]::IsNullOrWhiteSpace($existingValue)) {
            return
        }
        $updated = @()
        foreach ($line in $lines) {
            if ($line -match "^$([regex]::Escape($Key))=") {
                $updated += "$Key=$Value"
            }
            else {
                $updated += $line
            }
        }
        Set-Content -Path $EnvFile -Value $updated
        return
    }

    Add-Content -Path $EnvFile -Value "$Key=$Value"
}

function New-RandomToken {
    param(
        [int]$Bytes = 32
    )

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $randomBytes = New-Object byte[] $Bytes
    $rng.GetBytes($randomBytes)
    $rng.Dispose()
    return [System.Convert]::ToBase64String($randomBytes)
}

function New-HexToken {
    param(
        [int]$Bytes = 32
    )

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $randomBytes = New-Object byte[] $Bytes
    $rng.GetBytes($randomBytes)
    $rng.Dispose()
    return ([System.BitConverter]::ToString($randomBytes) -replace '-', '').ToLowerInvariant()
}

function Get-EnvValue {
    param([string]$Key)

    if (-not (Test-Path $EnvFile)) { return $null }

    foreach ($line in Get-Content -Path $EnvFile) {
        if ($line -match "^$([regex]::Escape($Key))=") {
            return ($line.Split("=", 2))[1]
        }
    }

    return $null
}

if (-not (Test-Path $EnvFile)) {
    New-Item -Path $EnvFile -ItemType File -Force | Out-Null
}

$defaults = @(
    @{ Key = 'RAILS_ENV'; Value = 'production' },
    @{ Key = 'PORT'; Value = '3000' },
    @{ Key = 'HERMES_BASE_URI'; Value = 'http://hermes:8642' },
    @{ Key = 'HERMES_STATUS_URI'; Value = 'http://hermes:9119' },
    @{ Key = 'HERMES_DASHBOARD'; Value = 'true' },
    @{ Key = 'HERMES_DASHBOARD_HOST'; Value = '0.0.0.0' },
    @{ Key = 'HERMES_DASHBOARD_PORT'; Value = '8080' },
    @{ Key = 'HERMES_MODEL'; Value = 'hermes' },
    @{ Key = 'HERMES_DEFAULT_PROFILE'; Value = 'delegator' }
)

foreach ($entry in $defaults) {
    if (-not (Get-EnvValue -Key $entry.Key)) {
        Set-OrKeepEnvValue -Key $entry.Key -Value $entry.Value
    }
}

if (-not (Get-EnvValue -Key 'SECRET_KEY_BASE')) {
    Set-OrKeepEnvValue -Key 'SECRET_KEY_BASE' -Value (New-RandomToken -Bytes 64)
}

if (-not (Get-EnvValue -Key 'HERMES_API_KEY')) {
    Set-OrKeepEnvValue -Key 'HERMES_API_KEY' -Value (New-HexToken -Bytes 32)
}

if (-not (Get-EnvValue -Key 'API_SERVER_KEY')) {
    Set-OrKeepEnvValue -Key 'API_SERVER_KEY' -Value (Get-EnvValue -Key 'HERMES_API_KEY')
}

if (-not (Get-EnvValue -Key 'MCP_AUTH_TOKEN')) {
    Set-OrKeepEnvValue -Key 'MCP_AUTH_TOKEN' -Value (New-HexToken -Bytes 32)
}

if (-not (Get-EnvValue -Key 'VAPID_PUBLIC_KEY') -or -not (Get-EnvValue -Key 'VAPID_PRIVATE_KEY')) {
    if (-not (Get-Command ruby -ErrorAction SilentlyContinue)) {
        throw "Ruby is required to generate VAPID keys. Install Ruby and rerun this installer."
    }

    $vapIdOutput = & ruby (Join-Path $ScriptDir 'script/admin/create-vapid-key') 2>$null
    $publicKey = $null
    $privateKey = $null

    foreach ($line in $vapIdOutput) {
        if ($line -match '^PUBLIC KEY\s*:\s*(.+)$') {
            $publicKey = $matches[1].Trim()
        }
        elseif ($line -match '^PRIVATE KEY\s*:\s*(.+)$') {
            $privateKey = $matches[1].Trim()
        }
    }

    if (-not $publicKey -or -not $privateKey) {
        throw "Unable to generate VAPID keys from the Ruby helper script."
    }

    Set-OrKeepEnvValue -Key 'VAPID_PUBLIC_KEY' -Value $publicKey
    Set-OrKeepEnvValue -Key 'VAPID_PRIVATE_KEY' -Value $privateKey
}

if ($DryRun) {
    Write-Host "Dry run only; Docker Compose was not started."
    Write-Host "Env file: $EnvFile"
    Write-Host "Compose file: $ComposeFile"
    return
}

Write-Host "Starting Docker Compose with generated environment..."
& docker compose -f $ComposeFile up --build -d

Write-Host "Env file: $EnvFile"
Write-Host "App URL: http://localhost:3000"
Write-Host "Hermes dashboard: http://localhost:8080"
