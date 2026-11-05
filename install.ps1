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

function New-InfisicalFallbackValue {
    param([string]$Label = 'local')
    return "$Label-$([System.Guid]::NewGuid().ToString('N').Substring(0, 12))"
}

function Read-OptionalValue {
    param(
        [string]$Prompt,
        [string]$Default
    )

    if (-not $Host.UI.RawUI) {
        return $Default
    }

    $answer = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $Default
    }

    return $answer
}

function Set-InfisicalAliases {
    param(
        [string]$FieldName,
        [string]$Value
    )

    switch ($FieldName) {
        'INFISICAL_APP_ID' {
            Set-OrKeepEnvValue -Key 'INFISICAL_APP_ID' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL.APP_ID' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL__APP_ID' -Value $Value
        }
        'INFISICAL_APP_SECRET' {
            Set-OrKeepEnvValue -Key 'INFISICAL_APP_SECRET' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL.APP_SECRET' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL__APP_SECRET' -Value $Value
        }
        'INFISICAL_PROJECT_ID' {
            Set-OrKeepEnvValue -Key 'INFISICAL_PROJECT_ID' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL.PROJECT_ID' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL__PROJECT_ID' -Value $Value
        }
        'INFISICAL_PROJECT_ENVIRONMENT' {
            Set-OrKeepEnvValue -Key 'INFISICAL_PROJECT_ENVIRONMENT' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL_PROJECT_ENV' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL.PROJECT_ENVIRONMENT' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL.PROJECT_ENV' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL__PROJECT_ENVIRONMENT' -Value $Value
            Set-OrKeepEnvValue -Key 'INFISICAL__PROJECT_ENV' -Value $Value
        }
    }
}

function Normalize-DottedKey {
    param([string]$Key)

    $normalized = $Key -replace '\.', '_'
    $normalized = $normalized -replace '-', '_'
    $normalized = $normalized -replace '\s+', '_'
    return $normalized.ToUpperInvariant()
}

function Write-EnvFromDottedKeys {
    param([string]$Text)

    foreach ($line in ($Text -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^\s*#') { continue }
        if ($line -notmatch '=') { continue }

        $rawKey, $rawValue = $line.Split("=", 2)
        $normalizedKey = Normalize-DottedKey -Key $rawKey.Trim()

        switch ($normalizedKey) {
            'SECRET_KEY_BASE' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'HERMES_API_KEY' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'API_SERVER_KEY' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'MCP_AUTH_TOKEN' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'HERMES_BASE_URI' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'HERMES_STATUS_URI' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'HERMES_DASHBOARD' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'HERMES_DASHBOARD_HOST' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'HERMES_DASHBOARD_PORT' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'HERMES_MODEL' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'HERMES_DEFAULT_PROFILE' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'VAPID_PUBLIC_KEY' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
            'VAPID_PRIVATE_KEY' { Set-OrKeepEnvValue -Key $normalizedKey -Value $rawValue.Trim() }
        }
    }
}

function Import-InfisicalSecrets {
    if (-not (Get-Command infisical -ErrorAction SilentlyContinue)) {
        return $false
    }

    $token = $env:INFISICAL_TOKEN
    if (-not $token -and $env:INFISICAL_TOKEN_FILE) {
        if (Test-Path $env:INFISICAL_TOKEN_FILE) {
            $token = (Get-Content -Path $env:INFISICAL_TOKEN_FILE -Raw).Trim()
        }
    }

    if (-not $token) {
        return $false
    }

    $args = @('export', '--format=dotenv')
    if ($env:INFISICAL_PROJECT_ID) { $args += @("--projectId=$($env:INFISICAL_PROJECT_ID)") }
    if ($env:INFISICAL_PATH) { $args += @("--path=$($env:INFISICAL_PATH)") }
    if ($env:INFISICAL_URL) { $args += @("--domain=$($env:INFISICAL_URL)") }
    $args += @("--token=$token")

    try {
        $exportText = & infisical @args 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($exportText)) {
            return $false
        }

        Write-EnvFromDottedKeys -Text $exportText
        return $true
    }
    catch {
        return $false
    }
}

function Prompt-ForSecret {
    param(
        [string]$Key,
        [string]$Label,
        [scriptblock]$GenerateBlock
    )

    if ((Get-EnvValue -Key $Key)) {
        return
    }

    while ($true) {
        $choices = if ((-not [string]::IsNullOrWhiteSpace($env:INFISICAL_TOKEN)) -or (-not [string]::IsNullOrWhiteSpace($env:INFISICAL_PROJECT_ID)) -or (Get-Command infisical -ErrorAction SilentlyContinue)) {
            "Use [I]nfisical, [M]anual value, or [G]enerate random for $Label? [I/m/g]: "
        }
        else {
            "Use [M]anual value or [G]enerate random for $Label? [m/g]: "
        }

        try {
            $choice = Read-Host $choices
        }
        catch {
            $choice = 'g'
        }

        $normalizedChoice = ($choice ?? 'g').Trim().ToLowerInvariant()

        switch ($normalizedChoice) {
            'i' {
                if (Import-InfisicalSecrets) {
                    if ((Get-EnvValue -Key $Key)) { return }
                }
                Write-Warning "Infisical did not populate $Key. Try again or choose another option."
                continue
            }
            'm' {
                try {
                    $manualValue = Read-Host "Enter $Label"
                }
                catch {
                    $manualValue = $null
                }

                if (-not [string]::IsNullOrWhiteSpace($manualValue)) {
                    Set-OrKeepEnvValue -Key $Key -Value $manualValue
                    return
                }
                continue
            }
            default {
                $value = & $GenerateBlock
                Set-OrKeepEnvValue -Key $Key -Value $value
                return
            }
        }
    }
}

function Configure-InfisicalCredentials {
    if (-not $Host.UI.RawUI) {
        return
    }

    Write-Host ''
    Write-Host 'Infisical (optional): provide app credentials for external secret resolution.'
    Write-Host 'Leave blank to keep the generated fallbacks.'

    $response = Read-Host 'Use Infisical? [y/N]'
    if ($response -notmatch '^(y|yes)$') {
        return
    }

    $appId = Read-OptionalValue -Prompt 'App ID' -Default (New-InfisicalFallbackValue -Label 'app')
    $appSecret = Read-OptionalValue -Prompt 'App Secret' -Default (New-InfisicalFallbackValue -Label 'app-secret')
    $projectId = Read-OptionalValue -Prompt 'Project ID' -Default (New-InfisicalFallbackValue -Label 'project')
    $projectEnvironment = Read-OptionalValue -Prompt 'Project environment' -Default 'dev'

    Set-InfisicalAliases -FieldName 'INFISICAL_APP_ID' -Value $appId
    Set-InfisicalAliases -FieldName 'INFISICAL_APP_SECRET' -Value $appSecret
    Set-InfisicalAliases -FieldName 'INFISICAL_PROJECT_ID' -Value $projectId
    Set-InfisicalAliases -FieldName 'INFISICAL_PROJECT_ENVIRONMENT' -Value $projectEnvironment
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

Configure-InfisicalCredentials

if (-not (Get-EnvValue -Key 'SECRET_KEY_BASE')) {
    Set-OrKeepEnvValue -Key 'SECRET_KEY_BASE' -Value (New-RandomToken -Bytes 64)
}

if (-not (Get-EnvValue -Key 'HERMES_API_KEY')) {
    Prompt-ForSecret -Key 'HERMES_API_KEY' -Label 'Hermes API key' -GenerateBlock { New-HexToken -Bytes 32 }
}

if (-not (Get-EnvValue -Key 'API_SERVER_KEY')) {
    Set-OrKeepEnvValue -Key 'API_SERVER_KEY' -Value (Get-EnvValue -Key 'HERMES_API_KEY')
}

if (-not (Get-EnvValue -Key 'MCP_AUTH_TOKEN')) {
    Prompt-ForSecret -Key 'MCP_AUTH_TOKEN' -Label 'MCP auth token' -GenerateBlock { New-HexToken -Bytes 32 }
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
