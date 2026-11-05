#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
COMPOSE_FILE="${COMPOSE_FILE:-$SCRIPT_DIR/docker-compose.build.yml}"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

ensure_env_value() {
  local key="$1"
  local value="$2"
  local escaped_key
  escaped_key="$(printf '%s' "$key" | sed 's/[[\.^$*+?()|{}[]/\\&/g')"

  if [[ -f "$ENV_FILE" ]] && grep -Eq "^${escaped_key}=" "$ENV_FILE"; then
    local current
    current="$(grep -E "^${escaped_key}=" "$ENV_FILE" | head -n 1 | cut -d= -f2-)"
    if [[ -n "$current" ]]; then
      return 0
    fi
    sed -i.bak -E "s|^${escaped_key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

write_or_keep_env() {
  local key="$1"
  local value="$2"
  if [[ -f "$ENV_FILE" ]] && grep -Eq "^${key}=" "$ENV_FILE"; then
    local current
    current="$(grep -E "^${key}=" "$ENV_FILE" | head -n 1 | cut -d= -f2-)"
    if [[ -n "$current" ]]; then
      return 0
    fi
    sed -i.bak -E "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

maybe_add_default_env() {
  local key="$1"
  local value="$2"
  if [[ -f "$ENV_FILE" ]] && grep -Eq "^${key}=" "$ENV_FILE"; then
    return 0
  fi
  printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
}

print_generated_summary() {
  echo
  echo "Generated/validated env file: $ENV_FILE"
  echo "Compose file: $COMPOSE_FILE"
  echo "App URL: http://localhost:3000"
  echo "Hermes dashboard: http://localhost:8080"
}

mkdir -p "$SCRIPT_DIR"
if [[ ! -f "$ENV_FILE" ]]; then
  touch "$ENV_FILE"
fi

maybe_add_default_env "RAILS_ENV" "production"
maybe_add_default_env "PORT" "3000"
maybe_add_default_env "HERMES_BASE_URI" "http://hermes:8642"
maybe_add_default_env "HERMES_STATUS_URI" "http://hermes:9119"
maybe_add_default_env "HERMES_DASHBOARD" "true"
maybe_add_default_env "HERMES_DASHBOARD_HOST" "0.0.0.0"
maybe_add_default_env "HERMES_DASHBOARD_PORT" "8080"
maybe_add_default_env "HERMES_MODEL" "hermes"
maybe_add_default_env "HERMES_DEFAULT_PROFILE" "delegator"

if ! grep -Eq '^SECRET_KEY_BASE=' "$ENV_FILE" || [[ -z "$(grep -E '^SECRET_KEY_BASE=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
  SECRET_KEY_BASE="$(openssl rand -base64 64 2>/dev/null | tr -d '\n' || ruby -e 'require "securerandom"; puts SecureRandom.base64(64)')"
  write_or_keep_env "SECRET_KEY_BASE" "$SECRET_KEY_BASE"
fi

if ! grep -Eq '^HERMES_API_KEY=' "$ENV_FILE" || [[ -z "$(grep -E '^HERMES_API_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
  HERMES_API_KEY="$(openssl rand -hex 32 2>/dev/null || ruby -e 'require "securerandom"; puts SecureRandom.hex(32)')"
  write_or_keep_env "HERMES_API_KEY" "$HERMES_API_KEY"
fi

if ! grep -Eq '^API_SERVER_KEY=' "$ENV_FILE" || [[ -z "$(grep -E '^API_SERVER_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
  API_SERVER_KEY="$(grep -E '^HERMES_API_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)"
  write_or_keep_env "API_SERVER_KEY" "$API_SERVER_KEY"
fi

if ! grep -Eq '^MCP_AUTH_TOKEN=' "$ENV_FILE" || [[ -z "$(grep -E '^MCP_AUTH_TOKEN=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
  MCP_AUTH_TOKEN="$(openssl rand -hex 32 2>/dev/null || ruby -e 'require "securerandom"; puts SecureRandom.hex(32)')"
  write_or_keep_env "MCP_AUTH_TOKEN" "$MCP_AUTH_TOKEN"
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "Ruby is required to generate VAPID keys; install Ruby or add VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY manually." >&2
  exit 1
fi

if ! grep -Eq '^VAPID_PUBLIC_KEY=' "$ENV_FILE" || ! grep -Eq '^VAPID_PRIVATE_KEY=' "$ENV_FILE" || [[ -z "$(grep -E '^VAPID_PUBLIC_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]] || [[ -z "$(grep -E '^VAPID_PRIVATE_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
  VAPID_OUTPUT="$(ruby "$SCRIPT_DIR/script/admin/create-vapid-key" 2>/dev/null || true)"
  VAPID_PUBLIC_KEY="$(printf '%s\n' "$VAPID_OUTPUT" | awk -F': ' '/PUBLIC KEY[[:space:]]*:/ {print $2}' | head -n 1 | tr -d '\r')"
  VAPID_PRIVATE_KEY="$(printf '%s\n' "$VAPID_OUTPUT" | awk -F': ' '/PRIVATE KEY[[:space:]]*:/ {print $2}' | head -n 1 | tr -d '\r')"

  if [[ -z "$VAPID_PUBLIC_KEY" || -z "$VAPID_PRIVATE_KEY" ]]; then
    echo "Unable to generate VAPID keys. Ensure Ruby is available and the helper script exists: $SCRIPT_DIR/script/admin/create-vapid-key" >&2
    exit 1
  fi

  write_or_keep_env "VAPID_PUBLIC_KEY" "$VAPID_PUBLIC_KEY"
  write_or_keep_env "VAPID_PRIVATE_KEY" "$VAPID_PRIVATE_KEY"
fi

if ! grep -Eq '^HERMES_API_KEY=' "$ENV_FILE" || ! grep -Eq '^API_SERVER_KEY=' "$ENV_FILE"; then
  echo "Required env keys were not created successfully." >&2
  exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
  print_generated_summary
  echo "Dry run only; Docker Compose was not started."
  exit 0
fi

echo "Starting Docker Compose with generated environment..."
docker compose -f "$COMPOSE_FILE" up --build -d

print_generated_summary
