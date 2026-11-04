#!/bin/sh
set -eu

PROFILE_DIR="${HERMES_PROFILE_DIR:-/opt/data/profiles}"
PROFILE_ALIAS="${HERMES_PROFILE_ALIAS:-default}"
PROFILE_SOURCE="${HERMES_PROFILE_SOURCE:-github.com/you/hermes-ai-settings}"

mkdir -p /opt/data

if [ ! -d "$PROFILE_DIR" ] || [ -z "$(ls -A "$PROFILE_DIR" 2>/dev/null)" ]; then
  echo "No Hermes profile directory found at $PROFILE_DIR; installing default profile from $PROFILE_SOURCE"
  if ! hermes profile install "$PROFILE_SOURCE" --alias "$PROFILE_ALIAS"; then
    echo "Hermes profile install failed; continuing startup anyway" >&2
  fi
fi

exec hermes gateway run
