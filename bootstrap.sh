#!/bin/sh
set -eu

PROFILE_DIR="${HERMES_PROFILE_DIR:-/opt/data/profiles}"
PROFILE_BASE_URL="${HERMES_PROFILE_BASE_URL:-https://github.com/ValidatorAI}"
PROFILE_NAMES="${HERMES_PROFILE_NAMES:-message_analyzer workspace w_ai project_manager coder business_analyst market_research}"

mkdir -p /opt/data

for name in $PROFILE_NAMES; do
  profile_path="$PROFILE_DIR/$name"

  if [ ! -d "$profile_path" ] || [ -z "$(ls -A "$profile_path" 2>/dev/null)" ]; then
    repo_url="${PROFILE_BASE_URL}/$name"
    echo "Installing Hermes profile $name from $repo_url"
    if ! hermes profile install "$repo_url" --alias "$name"; then
      echo "Hermes profile install failed for $name" >&2
    fi
  else
    echo "Hermes profile already present: $name"
  fi
done

exec hermes gateway run
