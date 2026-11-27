#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./build-hermes.sh --profile hardened --tag hermes:hardened
  ./build-hermes.sh --profile slim --tag hermes:slim
  ./build-hermes.sh --profile ultra-hardened --tag hermes:ultra

Options:
  -p, --profile PROFILE         One of: hardened, slim, ultra-hardened,
                               Dockerfile-hardened, Dockerfile-slim,
                               Dockerfile-ultra-hardened
  -t, --tag TAG                 Docker image tag (default: hermes:local)
  -r, --repo URL               Hermes repo URL (default: https://github.com/NousResearch/hermes-agent.git)
  -d, --dir DIR                 Clone destination directory (default: temp dir)
  -h, --help                    Show this help text
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_REPO_URL="https://github.com/NousResearch/hermes-agent.git"
PROFILE=""
TAG="hermes:local"
REPO_URL="$DEFAULT_REPO_URL"
CLONE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -p|--profile)
      [[ $# -ge 2 ]] || die "Missing value for --profile"
      PROFILE="$2"
      shift 2
      ;;
    -t|--tag)
      [[ $# -ge 2 ]] || die "Missing value for --tag"
      TAG="$2"
      shift 2
      ;;
    -r|--repo)
      [[ $# -ge 2 ]] || die "Missing value for --repo"
      REPO_URL="$2"
      shift 2
      ;;
    -d|--dir)
      [[ $# -ge 2 ]] || die "Missing value for --dir"
      CLONE_DIR="$2"
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "$PROFILE" ]] || {
  usage >&2
  die "A Dockerfile profile is required."
}

case "${PROFILE,,}" in
  hardened|dockerfile-hardened)
    PROFILE="hardened"
    SOURCE_FILE="Dockerfile-hardened"
    ;;
  slim|dockerfile-slim)
    PROFILE="slim"
    SOURCE_FILE="Dockerfile-slim"
    ;;
  ultra-hardened|dockerfile-ultra-hardened|ultra)
    PROFILE="ultra-hardened"
    SOURCE_FILE="Dockerfile-ultra-hardened"
    ;;
  *)
    die "Unsupported profile: $PROFILE. Use hardened, slim, ultra-hardened, Dockerfile-hardened, Dockerfile-slim, or Dockerfile-ultra-hardened."
    ;;
esac

SOURCE_PATH="$SCRIPT_DIR/$SOURCE_FILE"
[[ -f "$SOURCE_PATH" ]] || die "Dockerfile not found: $SOURCE_PATH"

command -v git >/dev/null 2>&1 || die "git is required but was not found in PATH"
command -v docker >/dev/null 2>&1 || die "docker is required but was not found in PATH"

if [[ -n "$CLONE_DIR" ]]; then
  mkdir -p -- "$CLONE_DIR" || die "Could not create clone directory: $CLONE_DIR"
else
  CLONE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hermes-agent.${PROFILE}.XXXXXX")"
fi

if [[ -d "$CLONE_DIR/.git" ]]; then
  printf 'Using existing Hermes clone at %s\n' "$CLONE_DIR"
else
  printf 'Cloning Hermes repo from %s into %s\n' "$REPO_URL" "$CLONE_DIR"
  git clone --depth 1 "$REPO_URL" "$CLONE_DIR" || die "git clone failed for $REPO_URL"
fi

printf 'Selected Dockerfile: %s\n' "$SOURCE_PATH"
printf 'Build context: %s\n' "$CLONE_DIR"
printf 'Image tag: %s\n' "$TAG"

# Use the selected Dockerfile from this folder while the cloned Hermes repo is the build context.
docker build \
  -f "$SOURCE_PATH" \
  -t "$TAG" \
  "$CLONE_DIR" || die "Docker build failed for tag $TAG"

echo
printf 'Build finished: %s\n' "$TAG"
