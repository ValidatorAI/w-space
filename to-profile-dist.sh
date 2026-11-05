#!/usr/bin/env bash
# to-profile-dist.sh — convert a live Hermes profile into a profile DISTRIBUTION
# repository (distribution.yaml + shippable files + .env.template + git history),
# ready for `hermes profile install <git-url>` on any machine and
# `hermes profile update NAME` afterwards.
#
# Contract enforced here (verified against hermes_cli/profile_distribution.py):
#   distribution-owned : SOUL.md config.yaml mcp.json skills/ cron/jobs.json hooks/ plugins/
#   never shipped      : .env / auth / memories / sessions / state.db / caches / logs /
#                        runtime / skills dot-entries (.hub etc.) / *.lock / *.bak*
#   secret VALUES never leave the machine: only variable NAMES go into
#   .env.template and env_requires (only KEY|TOKEN|SECRET|PASSWORD-style names).
#
# Usage:
#   to-profile-dist.sh PROFILE [options]        (PROFILE = named profile; not 'default')
# Options:
#   -o, --out DIR      distribution dir to create (default: ./PROFILE-dist)
#   -H, --hermes-home P source HERMES_HOME (default: $HERMES_HOME or ~/.hermes)
#   -V, --version VER  manifest version (default: 0.1.0)
#   -r, --remote URL   git remote to add and push (branch below) after commit
#   -b, --branch NAME  git branch (default: main)
#   --no-git           build the dir but skip git init/commit
#   --force            overwrite an existing --out
#   -h, --help
set -euo pipefail

ORIG_PWD="$PWD"
PROFILE="" OUT="" HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
VERSION="0.1.0" REMOTE="" BRANCH="main" NO_GIT=0 FORCE=0

die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARNING: $*" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--out) OUT="$2"; shift 2;;
    -H|--hermes-home) HERMES_HOME="$2"; shift 2;;
    -V|--version) VERSION="$2"; shift 2;;
    -r|--remote) REMOTE="$2"; shift 2;;
    -b|--branch) BRANCH="$2"; shift 2;;
    --no-git) NO_GIT=1; shift;;
    --force) FORCE=1; shift;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    -*) die "unknown option $1";;
    *) PROFILE="$1"; shift;;
  esac
done

[ -n "$PROFILE" ] || die "PROFILE is required"
[ "$PROFILE" = default ] && die "distributing 'default' is not supported — its home is the whole HERMES_HOME; distribute named profiles instead"
SRC="$HERMES_HOME/profiles/$PROFILE"
[ -d "$SRC" ] || die "profile folder not found: $SRC"
command -v rsync >/dev/null || die "rsync not found"
OUT="${OUT:-$ORIG_PWD/$PROFILE-dist}"
[ "$OUT" = "$SRC" ] && die "--out must differ from the profile folder"
if [ -e "$OUT" ]; then
  [ "$FORCE" = 1 ] || die "$OUT exists — use --force to replace it"
  rm -rf "$OUT"
fi
mkdir -p "$OUT"

# ---- 1. copy the shippable surface ----
rsync -a \
  --exclude='.env' --exclude='.env.*' --exclude='auth.json' --exclude='auth.lock' \
  --exclude='memories/' --exclude='sessions/' --exclude='plans/' --exclude='workspace/' \
  --exclude='home/' --exclude='backups/' --exclude='cache/' --exclude='logs/' \
  --exclude='runtime/' --exclude='image_cache/' --exclude='audio_cache/' \
  --exclude='plugin-update-checks/' --exclude='terminal-sessions/' --exclude='sandboxes/' \
  --exclude='telemetry/' --exclude='pairing/' --exclude='platforms/' --exclude='skins/' \
  --exclude='state.db*' --exclude='*.db' --exclude='*.db-shm' --exclude='*.db-wal' \
  --exclude='*.lock' --exclude='*.bak' --exclude='*.bak-*' --exclude='__pycache__/' \
  --exclude='node/' --exclude='node_modules/' --exclude='bin/' --exclude='lsp/' \
  --exclude='skills/.*' --exclude='.curator_backups/' --exclude='.soul_backup_*/' \
  --exclude='.deleted/' --exclude='.profile-manifest' --exclude='.git' \
  --exclude='distribution.yaml' \
  "$SRC/" "$OUT/"

# ---- 2. cron: jobs.json is distribution-owned; every sibling is runtime state ----
if [ -d "$OUT/cron" ]; then
  if [ -f "$OUT/cron/jobs.json" ]; then
    find "$OUT/cron" -mindepth 1 -maxdepth 1 ! -name jobs.json -exec rm -rf {} +
  else
    rm -rf "$OUT/cron"
  fi
fi

# ---- 3. harvest secret NAMES (never values) from the profile .env ----
SECRETS=() ; ALLNAMES=()
if [ -f "$SRC/.env" ]; then
  while IFS= read -r v; do ALLNAMES+=("$v"); \
    case "$v" in *API_KEY*|*TOKEN*|*SECRET*|*PASSWORD*|*PASSWD*|*CREDENTIAL*) SECRETS+=("$v");; esac
  done < <(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$SRC/.env" | sort -u)
fi
[ ${#ALLNAMES[@]} -gt 0 ] || warn "no .env found at $SRC/.env — target will be key-less until you add one"

# .env.template: every var, empty values
: > "$OUT/.env.template"
for v in "${ALLNAMES[@]:-}"; do [ -n "$v" ] && echo "$v=" >> "$OUT/.env.template"; done

# ---- 4. distribution.yaml ----
DESC=""
if [ -f "$SRC/profile.yaml" ]; then
  DESC=$(sed -n 's/^description:[[:space:]]*//p' "$SRC/profile.yaml" | head -1 | sed 's/^"\(.*\)"$/\1/; s/^'"'"'\(.*\)'"'"'$/\1/; s/\\/\\\\/g; s/"/\\"/g')
fi
[ -n "$DESC" ] || DESC="Hermes profile $PROFILE, distributed via git."
{
  echo "name: $PROFILE"
  echo "version: $VERSION"
  echo "description: \"$DESC\""
  echo "author: $(git config user.name 2>/dev/null || hostname)"
  if [ ${#SECRETS[@]} -gt 0 ]; then
    echo "env_requires:"
    for v in "${SECRETS[@]}"; do
      echo "  - name: $v"
      echo "    description: required credential copied from the source profile"
      echo "    required: true"
    done
  fi
} > "$OUT/distribution.yaml"

# ---- 5. README ----
cat > "$OUT/README.md" <<EOF
# $PROFILE — Hermes profile distribution

Generated $(date -Is) from $SRC by to-profile-dist.sh.

Install on any machine:
    hermes profile install $( [ -n "$REMOTE" ] && echo "<this-repo-git-url>" || echo "git@...:USER/$PROFILE.git" )
    cp ~/.hermes/profiles/$PROFILE/.env.EXAMPLE ~/.hermes/profiles/$PROFILE/.env   # fill keys, chmod 600
    hermes -p $PROFILE chat -Q -q "reply with exactly: PROFILE-OK"

Iterate: edit the files here, bump version in distribution.yaml, push; then on each machine:
    hermes profile update $PROFILE
User data (memories, sessions, .env, auth) is never overwritten by updates;
config.yaml is preserved unless --force-config.
EOF

# ---- 6. git ----
if [ "$NO_GIT" = 0 ]; then
  command -v git >/dev/null || die "git not found (or use --no-git)"
  git -C "$OUT" init -q -b "$BRANCH"
  git -C "$OUT" add -A
  git -C "$OUT" -c user.name="${GIT_AUTHOR_NAME:-$(whoami)}" -c user.email="${GIT_AUTHOR_EMAIL:-$(whoami)@$(hostname)}" \
      commit -q -m "$PROFILE v$VERSION — profile distribution"
  if [ -n "$REMOTE" ]; then
    git -C "$OUT" remote add origin "$REMOTE"
    git -C "$OUT" push -u origin "$BRANCH" || warn "push failed — commit is local; push manually: git -C $OUT push -u origin $BRANCH"
  fi
fi

# ---- 7. leak check + report ----
# word-boundary patterns only — 'task-concu[r]ency' contains a lookalike 'sk-' run
LEAK_PAT='\bsk-[A-Za-z0-9]{16,}|-----BEGIN [A-Z ]*PRIVATE KEY|\b[A-Za-z0-9_]*(API_KEY|TOKEN|SECRET|PASSWORD)\b\s*[:=]\s*["'"'"']?[A-Za-z0-9+/_-]{24,}'
if [ "$NO_GIT" = 0 ]; then
  LEAK=$(cd "$OUT" && git ls-files -z | xargs -0 grep -lIE "$LEAK_PAT" 2>/dev/null | head -3 || true)
else
  LEAK=$(grep -rlIE "$LEAK_PAT" "$OUT" --exclude-dir=.git 2>/dev/null | head -3 || true)
fi
[ -n "$LEAK" ] && warn "possible secret VALUES in: $(echo "$LEAK" | tr '\n' ' ') — grep them before pushing!"

ARCH_SK=$(find "$SRC/skills/.archive" -name SKILL.md 2>/dev/null | wc -l)
SIZE=$(du -sh "$OUT" | cut -f1)
SKILLS=$(find "$OUT/skills" -name SKILL.md 2>/dev/null | wc -l)
echo "distribution ready: $OUT ($SIZE, $SKILLS skills)"
[ "$ARCH_SK" -gt 0 ] && echo "note: $ARCH_SK archived skills (skills/.archive/) intentionally not shipped — the installer cannot write skills/.* entries"
echo "manifest:"; sed -n '1,4p' "$OUT/distribution.yaml" | sed 's/^/  /'
echo "env_requires: ${#SECRETS[@]} secret vars | .env.template: ${#ALLNAMES[@]} vars (names only)"
[ "$NO_GIT" = 0 ] && echo "git: $(git -C "$OUT" log --oneline -1 2>/dev/null || echo 'no commit')$([ -n "$REMOTE" ] && echo " pushed → $REMOTE")"
echo "install test:  HERMES_HOME=/tmp/disttest hermes profile install $OUT -y   (remove /tmp/disttest after)"
