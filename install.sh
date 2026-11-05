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

generate_infisical_fallback() {
  local label="${1:-local}"
  if command -v openssl >/dev/null 2>&1; then
    printf '%s-%s' "$label" "$(openssl rand -hex 8 2>/dev/null || printf 'fallback')"
  else
    printf '%s-fallback' "$label"
  fi
}

prompt_infisical_value() {
  local label="$1"
  local fallback="$2"
  local value

  if [[ ! -t 0 ]]; then
    printf '%s' "$fallback"
    return
  fi

  read -r -p "${label} [${fallback}]: " value
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
  else
    printf '%s' "$fallback"
  fi
}

write_infisical_aliases() {
  local field_name="$1"
  local value="$2"

  case "$field_name" in
    INFISICAL_APP_ID)
      write_or_keep_env "INFISICAL_APP_ID" "$value"
      write_or_keep_env "INFISICAL.APP_ID" "$value"
      write_or_keep_env "INFISICAL__APP_ID" "$value"
      ;;
    INFISICAL_APP_SECRET)
      write_or_keep_env "INFISICAL_APP_SECRET" "$value"
      write_or_keep_env "INFISICAL.APP_SECRET" "$value"
      write_or_keep_env "INFISICAL__APP_SECRET" "$value"
      ;;
    INFISICAL_PROJECT_ID)
      write_or_keep_env "INFISICAL_PROJECT_ID" "$value"
      write_or_keep_env "INFISICAL.PROJECT_ID" "$value"
      write_or_keep_env "INFISICAL__PROJECT_ID" "$value"
      ;;
    INFISICAL_PROJECT_ENVIRONMENT|INFISICAL_PROJECT_ENV)
      write_or_keep_env "INFISICAL_PROJECT_ENVIRONMENT" "$value"
      write_or_keep_env "INFISICAL_PROJECT_ENV" "$value"
      write_or_keep_env "INFISICAL.PROJECT_ENVIRONMENT" "$value"
      write_or_keep_env "INFISICAL.PROJECT_ENV" "$value"
      write_or_keep_env "INFISICAL__PROJECT_ENVIRONMENT" "$value"
      write_or_keep_env "INFISICAL__PROJECT_ENV" "$value"
      ;;
  esac
}

configure_infisical_credentials() {
  local use_infisical
  local app_id
  local app_secret
  local project_id
  local project_env

  if [[ ! -t 0 ]]; then
    return
  fi

  echo
  echo "Infisical (optional): provide app credentials for external secret resolution."
  echo "Leave values blank to keep the auto-generated fallbacks."

  read -r -p "Use Infisical? [y/N]: " use_infisical
  if [[ ! "$use_infisical" =~ ^[Yy](es)?$ ]]; then
    return
  fi

  app_id="$(prompt_infisical_value "App ID" "$(generate_infisical_fallback app)")"
  app_secret="$(prompt_infisical_value "App Secret" "$(generate_infisical_fallback app-secret)")"
  project_id="$(prompt_infisical_value "Project ID" "$(generate_infisical_fallback project)")"
  project_env="$(prompt_infisical_value "Project environment" "dev")"

  write_infisical_aliases "INFISICAL_APP_ID" "$app_id"
  write_infisical_aliases "INFISICAL_APP_SECRET" "$app_secret"
  write_infisical_aliases "INFISICAL_PROJECT_ID" "$project_id"
  write_infisical_aliases "INFISICAL_PROJECT_ENVIRONMENT" "$project_env"
  write_infisical_aliases "INFISICAL_PROJECT_ENV" "$project_env"
}

profile_repo_import() {
  local repo_url="${1:-}"
  local profile_name="${2:-${HERMES_DEFAULT_PROFILE:-delegator}}"
  local helper="$SCRIPT_DIR/profile-env-collect.sh"

  if [[ ! -f "$helper" ]]; then
    echo "Profile helper not found: $helper" >&2
    return 1
  fi

  if [[ -z "$repo_url" ]]; then
    read -r -p "Profile repo URL or local path: " repo_url || repo_url=""
  fi

  if [[ -z "$repo_url" ]]; then
    echo "No profile repo URL provided." >&2
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would fetch environment variables from profile repo: $repo_url"
    return 0
  fi

  bash "$helper" "$repo_url" -n "$profile_name" --out "$ENV_FILE"
}

prompt_profile_repo_manual_entry() {
  local label="$1"
  local choice=""
  local repo_url=""

  if [[ ! -t 0 ]]; then
    return 1
  fi

  read -r -p "Download environment variables from a Hermes profile repo for ${label}? [y/N]: " choice || choice="n"
  if [[ ! "$choice" =~ ^[Yy](es)?$ ]]; then
    return 1
  fi

  read -r -p "Profile repo URL or local path: " repo_url || repo_url=""
  if [[ -z "$repo_url" ]]; then
    echo "No profile repo URL provided; falling back to direct manual entry." >&2
    return 1
  fi

  if profile_repo_import "$repo_url" "${HERMES_DEFAULT_PROFILE:-delegator}"; then
    return 0
  fi

  echo "Profile repo import failed; falling back to direct manual entry." >&2
  return 1
}

normalize_hermes_dotted_key() {
  local raw_key="$1"
  raw_key="${raw_key//./_}"
  raw_key="${raw_key//-/_}"
  raw_key="${raw_key// /_}"
  raw_key="${raw_key^^}"
  printf '%s' "$raw_key"
}

write_env_from_dotted_keys() {
  local export_text="$1"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *=* ]] && continue

    local raw_key="${line%%=*}"
    local raw_value="${line#*=}"
    raw_key="$(normalize_hermes_dotted_key "$raw_key")"

    case "$raw_key" in
      SECRET_KEY_BASE|HERMES_API_KEY|API_SERVER_KEY|MCP_AUTH_TOKEN|HERMES_BASE_URI|HERMES_STATUS_URI|HERMES_DASHBOARD|HERMES_DASHBOARD_HOST|HERMES_DASHBOARD_PORT|HERMES_MODEL|HERMES_DEFAULT_PROFILE|VAPID_PUBLIC_KEY|VAPID_PRIVATE_KEY)
        write_or_keep_env "$raw_key" "$raw_value"
        ;;
    esac
  done <<< "$export_text"
}

load_infisical_secret_values() {
  if ! command -v infisical >/dev/null 2>&1; then
    return 1
  fi

  local token="${INFISICAL_TOKEN:-}"
  local project_id="${INFISICAL_PROJECT_ID:-}"
  local path="${INFISICAL_PATH:-/}"
  local domain="${INFISICAL_URL:-${INFISICAL_DOMAIN:-}}"

  if [[ -z "$token" ]] && [[ -n "${INFISICAL_TOKEN_FILE:-}" ]] && [[ -f "$INFISICAL_TOKEN_FILE" ]]; then
    token="$(tr -d '\r\n' < "$INFISICAL_TOKEN_FILE")"
  fi

  if [[ -z "$token" ]]; then
    return 1
  fi

  local -a cmd=(infisical export --format=dotenv --path="$path")
  [[ -n "$project_id" ]] && cmd+=(--projectId="$project_id")
  [[ -n "$token" ]] && cmd+=(--token="$token")
  [[ -n "$domain" ]] && cmd+=(--domain="$domain")

  local export_text
  if export_text="$("${cmd[@]}" 2>/dev/null)"; then
    write_env_from_dotted_keys "$export_text"
    return 0
  fi

  return 1
}

prompt_for_missing_hermes_key() {
  local choice=""
  if [[ -f "$ENV_FILE" ]] && grep -Eq '^HERMES_API_KEY=' "$ENV_FILE" && [[ -n "$(grep -E '^HERMES_API_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
    return 0
  fi

  while true; do
    if [[ -n "${INFISICAL_TOKEN:-}" || -n "${INFISICAL_PROJECT_ID:-}" ]] || command -v infisical >/dev/null 2>&1; then
      printf 'Missing HERMES_API_KEY. Use [I]nfisical, [M]anual value, or [G]enerate random? [I/m/g]: '
    else
      printf 'Missing HERMES_API_KEY. Use [M]anual value or [G]enerate random? [m/g]: '
    fi
    read -r choice || choice="g"

    case "${choice,,}" in
      i|infisical)
        if load_infisical_secret_values && grep -Eq '^HERMES_API_KEY=' "$ENV_FILE" && [[ -n "$(grep -E '^HERMES_API_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
          return 0
        fi
        echo "Infisical export did not populate HERMES_API_KEY; try again or pick another source." >&2
        ;;
      m|manual)
        if prompt_profile_repo_manual_entry "Hermes API key"; then
          return 0
        fi
        local manual_value=""
        printf 'Enter Hermes API key: '
        read -r manual_value || manual_value=""
        if [[ -n "$manual_value" ]]; then
          write_or_keep_env "HERMES_API_KEY" "$manual_value"
          return 0
        fi
        echo "Manual value was empty; try again." >&2
        ;;
      g|"")
        local generated_key
        generated_key="$(openssl rand -hex 32 2>/dev/null || ruby -e 'require "securerandom"; puts SecureRandom.hex(32)')"
        write_or_keep_env "HERMES_API_KEY" "$generated_key"
        return 0
        ;;
      *)
        echo "Invalid choice; please choose I, M, or G." >&2
        ;;
    esac
  done
}

prompt_for_missing_mcp_token() {
  local choice=""
  if [[ -f "$ENV_FILE" ]] && grep -Eq '^MCP_AUTH_TOKEN=' "$ENV_FILE" && [[ -n "$(grep -E '^MCP_AUTH_TOKEN=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
    return 0
  fi

  while true; do
    if [[ -n "${INFISICAL_TOKEN:-}" || -n "${INFISICAL_PROJECT_ID:-}" ]] || command -v infisical >/dev/null 2>&1; then
      printf 'Missing MCP_AUTH_TOKEN. Use [I]nfisical, [M]anual value, or [G]enerate random? [I/m/g]: '
    else
      printf 'Missing MCP_AUTH_TOKEN. Use [M]anual value or [G]enerate random? [m/g]: '
    fi
    read -r choice || choice="g"

    case "${choice,,}" in
      i|infisical)
        if load_infisical_secret_values && grep -Eq '^MCP_AUTH_TOKEN=' "$ENV_FILE" && [[ -n "$(grep -E '^MCP_AUTH_TOKEN=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
          return 0
        fi
        echo "Infisical export did not populate MCP_AUTH_TOKEN; try again or pick another source." >&2
        ;;
      m|manual)
        if prompt_profile_repo_manual_entry "MCP auth token"; then
          return 0
        fi
        local manual_value=""
        printf 'Enter MCP auth token: '
        read -r manual_value || manual_value=""
        if [[ -n "$manual_value" ]]; then
          write_or_keep_env "MCP_AUTH_TOKEN" "$manual_value"
          return 0
        fi
        echo "Manual value was empty; try again." >&2
        ;;
      g|"")
        local generated_key
        generated_key="$(openssl rand -hex 32 2>/dev/null || ruby -e 'require "securerandom"; puts SecureRandom.hex(32)')"
        write_or_keep_env "MCP_AUTH_TOKEN" "$generated_key"
        return 0
        ;;
      *)
        echo "Invalid choice; please choose I, M, or G." >&2
        ;;
    esac
  done
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

configure_infisical_credentials

if ! grep -Eq '^SECRET_KEY_BASE=' "$ENV_FILE" || [[ -z "$(grep -E '^SECRET_KEY_BASE=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
  SECRET_KEY_BASE="$(openssl rand -base64 64 2>/dev/null | tr -d '\n' || ruby -e 'require "securerandom"; puts SecureRandom.base64(64)')"
  write_or_keep_env "SECRET_KEY_BASE" "$SECRET_KEY_BASE"
fi

if ! grep -Eq '^HERMES_API_KEY=' "$ENV_FILE" || [[ -z "$(grep -E '^HERMES_API_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
  prompt_for_missing_hermes_key
fi

if ! grep -Eq '^API_SERVER_KEY=' "$ENV_FILE" || [[ -z "$(grep -E '^API_SERVER_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
  API_SERVER_KEY="$(grep -E '^HERMES_API_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)"
  write_or_keep_env "API_SERVER_KEY" "$API_SERVER_KEY"
fi

if ! grep -Eq '^MCP_AUTH_TOKEN=' "$ENV_FILE" || [[ -z "$(grep -E '^MCP_AUTH_TOKEN=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)" ]]; then
  prompt_for_missing_mcp_token
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
