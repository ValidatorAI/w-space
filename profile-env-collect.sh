#!/usr/bin/env bash
# profile-env-collect.sh — given a Hermes profile DISTRIBUTION repo URL:
#   1. clone it (depth-1; GitHub tarball fallback if git is unavailable/fails)
#   2. harvest required env var NAMES from:
#        - distribution.yaml        env_requires (authoritative, with required/description/default)
#        - skills/*/SKILL.md        frontmatter required_environment_variables + setup.collect_secrets
#                                   + legacy prerequisites.env_vars
#        - mcp.json / config.yaml   ${VAR} placeholders
#   3. prompt the user ONE BY ONE for values (hidden input for KEY|TOKEN|SECRET|PASSWORD-style names)
#   4. write ~/.hermes/profiles/<name>/.env (merged, chmod 600) — optionally install the profile first
#
# Usage:
#   profile-env-collect.sh REPO_URL [options]
# Options:
#   -n, --name NAME      profile name (default: manifest 'name:', else repo basename)
#   -i, --install        run `hermes profile install <clone> -y` before writing .env
#   -o, --out FILE       write the collected .env to FILE instead of the profile path
#   -O, --overwrite      re-ask keys already present in the target .env and replace their values
#       --dry-run        print the harvested table and exit (no prompts, no writes)
#   -k, --keep-clone     do not delete the temp clone (prints its path)
#   -y, --yes            accept manifest defaults for empty answers where a default exists
#   -h, --help
set -euo pipefail

URL="" PNAME="" DO_INSTALL=0 OUT="" OVERWRITE=0 DRY_RUN=0 KEEP_CLONE=0 ASSUME_DEFAULTS=0

die()  { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARNING: $*" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--name) PNAME="$2"; shift 2;;
    -i|--install) DO_INSTALL=1; shift;;
    -o|--out) OUT="$2"; shift 2;;
    -O|--overwrite) OVERWRITE=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -k|--keep-clone) KEEP_CLONE=1; shift;;
    -y|--yes) ASSUME_DEFAULTS=1; shift;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    -*) die "unknown option $1";;
    *) [ -n "$URL" ] && die "one REPO_URL only"; URL="$1"; shift;;
  esac
done
[ -n "$URL" ] || die "REPO_URL is required (git URL or github.com/user/repo)"

HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/profile-env.XXXXXX")"
CLONE="$TMP/repo"
cleanup() { [ "$KEEP_CLONE" = 1 ] || rm -rf "$TMP"; }
trap cleanup EXIT

# ---- 1. fetch the repo -------------------------------------------------------
echo "==> fetching $URL"
if [ -d "$URL" ]; then
  CLONE="$URL"; echo "    using local directory"
elif command -v git >/dev/null 2>&1 && git clone --depth 1 --quiet "$URL" "$CLONE" 2>"$TMP/git.err"; then
  :
elif [[ "$URL" =~ ^(https?://)?(www\.)?github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
  # fallback: GitHub codeload tarball (works without git, needs curl)
  owner="${BASH_REMATCH[3]}"; repo="${BASH_REMATCH[4]}"
  command -v curl >/dev/null 2>&1 || die "git failed and curl unavailable: $(cat "$TMP/git.err" 2>/dev/null)"
  echo "    git clone failed — falling back to GitHub tarball"
  mkdir -p "$CLONE"
  curl -fsSL --retry 3 "https://codeload.github.com/$owner/$repo/tar.gz/HEAD" | tar -xz --strip-components=1 -C "$CLONE"
else
  die "clone failed: $(cat "$TMP/git.err" 2>/dev/null | head -2)"
fi

# ---- 2. harvest env-var names ------------------------------------------------
# rows (US-separated \x1f — NOT tab: tab is IFS whitespace and collapses empty fields):
# NAME <US> REQUIRED <US> DESCRIPTION <US> DEFAULT <US> SOURCE
HARVEST="$TMP/harvest.rows"
: > "$HARVEST"

# 2a. distribution.yaml: name/version + env_requires block
MANIFEST="$CLONE/distribution.yaml"
MNAME="" MVERSION=""
if [ -f "$MANIFEST" ]; then
  MNAME=$(awk -F': *' '/^name:[[:space:]]/{gsub(/[ "]/,"",$2); print $2; exit}' "$MANIFEST")
  MVERSION=$(awk -F': *' '/^version:[[:space:]]/{gsub(/[ "]/,"",$2); print $2; exit}' "$MANIFEST")
  awk '
    BEGIN { FS=""; inblk=0; name=""; desc=""; req="true"; def=""; U=sprintf("%c", 31) }
    function flush() {
      if (name != "") { gsub(U, " ", desc); printf "%s%s%s%s%s%s%s%s%s\n", name, U, req, U, desc, U, def, U, "manifest" }
      name=""; desc=""; req="true"; def=""
    }
    /^env_requires:[[:space:]]*$/ { inblk=1; next }
    inblk && /^[A-Za-z_-]/        { flush(); inblk=0 }
    inblk {
      line=$0; sub(/^[[:space:]]+/, "", line); sub(/^-[[:space:]]*/, "", line)
      if      (line ~ /^name:/)        { flush(); sub(/^name:[[:space:]]*/, "", line); gsub(/[ "]/, "", line); name=line }
      else if (line ~ /^description:/) { sub(/^description:[[:space:]]*/, "", line); gsub(/^"|"$/, "", line); desc=line }
      else if (line ~ /^required:/)    { sub(/^required:[[:space:]]*/, "", line); gsub(/[ "]/, "", line); req=line }
      else if (line ~ /^default:/)     { sub(/^default:[[:space:]]*/, "", line); gsub(/^"|"$/, "", line); def=line }
    }
    END { flush() }
  ' "$MANIFEST" >> "$HARVEST"
else
  warn "no distribution.yaml at repo root — harvesting skill/MCP declarations only"
fi

# 2b. skills: SKILL.md frontmatter (between the first pair of '---')
while IFS= read -r skillmd; do
  awk '
    BEGIN { U=sprintf("%c", 31); fm=0; block=""; name=""; desc=""; opt="false" }
    function emit() { if (name != "") print name U (opt=="true"?"false":"true") U desc U U "skills" }
    NR==1 && $0 ~ /^---[[:space:]]*$/ { fm=1; next }
    fm==0 { exit }
    $0 ~ /^---[[:space:]]*$/ { exit }
    {
      line=$0; sub(/\r$/, "", line)
      tline=line; sub(/^[[:space:]]+/, "", tline)
      if (tline ~ /^[A-Za-z_-]+:[[:space:]]*$/) { sub(/:.*$/, "", tline); block=tline; next }
      if (block=="required_environment_variables" || block=="collect_secrets" || block=="env_vars") {
        cur=line; sub(/^[[:space:]]+/, "", cur); sub(/^-[[:space:]]*/, "", cur)
        if      (cur ~ /^name:/ || cur ~ /^env_var:/) {
          emit(); sub(/^[a-z_]+:[[:space:]]*/, "", cur); gsub(/[ "]/, "", cur); name=cur; desc=""; opt="false"
        }
        else if (cur ~ /^description:/ || cur ~ /^prompt:/) { sub(/^[a-z]+:[[:space:]]*/, "", cur); gsub(/^"|"$/, "", cur); desc=cur }
        else if (cur ~ /^optional:/) { sub(/^optional:[[:space:]]*/, "", cur); gsub(/[ "]/, "", cur); opt=cur }
        else if (block=="env_vars" && cur ~ /^[A-Za-z_][A-Za-z0-9_]*$/) { emit(); name=cur; desc=""; opt="false" }
      }
    }
    END { emit() }
  ' "$skillmd" >> "$HARVEST"
done < <(find "$CLONE/skills" -name SKILL.md 2>/dev/null)

# 2c. ${VAR} placeholders in mcp.json / config.yaml (runtime interpolation points)
SKIP_RE='^(HOME|PATH|USER|SHELL|LANG|LC_|TMPDIR|PWD|XDG_|EDITOR|HERMES_HOME|PYTHON|DISPLAY|TERM|HOSTNAME|UID|GID|LOGNAME|IFS|TMP|BH_)'
for f in mcp.json config.yaml; do
  [ -f "$CLONE/$f" ] || continue
  grep -hoE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' "$CLONE/$f" | tr -d '${}' | sort -u |
    grep -Ev "$SKIP_RE" |
    awk -v src="$f" 'BEGIN{U=sprintf("%c",31); OFS=U} { print $1, "true", "placeholder referenced in " src, "", src }' >> "$HARVEST"
done

# dedupe: manifest rows were appended first (and skills before placeholders); first wins
SORTED="$TMP/unique.rows"
awk 'BEGIN{FS=sprintf("%c",31)} !seen[$1]++' "$HARVEST" > "$SORTED"
[ -s "$SORTED" ] || die "no environment variables found in $URL (no env_requires, no skill requirements, no \${VAR} placeholders)"

# ---- 3. resolve target + profile name ---------------------------------------
[ -n "$PNAME" ]  || PNAME="${MNAME:-$(basename "${URL%.git}")}"
if [ -z "$OUT" ]; then
  PROFILE_DIR="$HERMES_HOME_DIR/profiles/$PNAME"
  OUT="$PROFILE_DIR/.env"
fi

if [ "$DRY_RUN" = 1 ]; then
  echo "profile:   $PNAME  (version: ${MVERSION:-n/a})"
  echo "env would write to: $OUT"
  echo "harvested $(wc -l < "$SORTED") variable(s):"
  awk 'BEGIN{FS=sprintf("%c",31)} { printf "  • %-28s %s  [%s]%s\n", $1, ($2=="true"?"required":"optional "), $5, ($3?" — "$3:"") }' "$SORTED"
  exit 0
fi

if [ "$DO_INSTALL" = 1 ]; then
  command -v hermes >/dev/null 2>&1 || die "--install requested but hermes not on PATH"
  echo "==> installing profile '$PNAME' from the fetched tree"
  hermes profile install "$CLONE" --name "$PNAME" -y
  OUT="$HERMES_HOME_DIR/profiles/$PNAME/.env"
fi

# ---- 4. existing keys (don't clobber a filled .env) -------------------------
declare -A HAVE=()
if [ -f "$OUT" ]; then
  while IFS= read -r k; do HAVE["$k"]=1; done < <(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$OUT" | sort -u)
fi

# ---- 5. prompt one by one ----------------------------------------------------
US="$(printf '\037')"
total=$(wc -l < "$SORTED")
i=0; preset=0
COLLECT="$TMP/collected.rows"
: > "$COLLECT"
# NOTE: harvest rows are read on FD 3 — stdin must stay free for the interactive prompts.
while IFS="$US" read -r -u3 name required desc def src; do
  i=$((i+1))
  if [ "${HAVE[$name]:-}" = 1 ] && [ "$OVERWRITE" = 0 ]; then
    echo "[$i/$total] $name — already set in $OUT (pass -O to re-ask)"
    preset=$((preset+1)); continue
  fi
  tag="required"; [ "$required" = "true" ] || tag="optional"
  printf '\n[%d/%d] %s (%s, from %s)\n' "$i" "$total" "$name" "$tag" "$src"
  [ -n "$desc" ] && echo "       $desc"
  hidden=0
  case "$name" in *KEY|*TOKEN|*SECRET|*PASSWORD|*PASSWD|*CREDENTIAL*) hidden=1;; esac
  hint=""; [ -n "$def" ] && hint=" [default: $def]"
  while :; do
    val=""; rc=0
    if [ "$hidden" = 1 ]; then
      IFS= read -rs -p "       ${name}= (Enter to skip)${hint}: " val || rc=$?
      echo
    else
      IFS= read -r -p "       ${name}= (Enter to skip)${hint}: " val || rc=$?
    fi
    [ $rc -ne 0 ] && val=""                       # piped/EOF input: treat as empty
    if [ -z "$val" ] && [ -n "$def" ] && [ "$ASSUME_DEFAULTS" = 1 ]; then
      val="$def"; echo "       -> using manifest default"
    fi
    if [ -z "$val" ]; then
      if [ "$required" = "true" ] && [ "$ASSUME_DEFAULTS" = 0 ]; then
        ans="y"; IFS= read -r -p "       $name is required by the distribution — skip anyway? [y/N]: " ans || true
        { [ "$ans" = "y" ] || [ "$ans" = "Y" ]; } || continue
      fi
      echo "       -> skipped (set later in $OUT or via hermes -p $PNAME setup)"
      break
    fi
    printf '%s%s%s\n' "$name" "$US" "$val" >> "$COLLECT"
    break
  done
done 3< "$SORTED"

# ---- 6. merge into .env (only re-asked keys are replaced) ---------------------
entered=$(wc -l < "$COLLECT")
if [ "$entered" -eq 0 ]; then echo; echo "nothing entered — $OUT unchanged"; exit 0; fi
mkdir -p "$(dirname "$OUT")"
declare -A REPL=()
while IFS="$US" read -r k v; do REPL["$k"]=1; done < "$COLLECT"
NEW="$TMP/env.new"; : > "$NEW"
if [ -f "$OUT" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) printf '%s\n' "$line" >> "$NEW"; continue;; esac
    k="${line%%=*}"
    [ -n "${REPL[$k]:-}" ] || printf '%s\n' "$line" >> "$NEW"
  done < "$OUT"
fi
{
  cat "$NEW"
  echo
  echo "# --- added $(date -Is) by profile-env-collect.sh from $URL (profile $PNAME${MVERSION:+ v$MVERSION}) ---"
  while IFS="$US" read -r k v; do printf '%s=%s\n' "$k" "$v"; done < "$COLLECT"
} > "$OUT"
chmod 600 "$OUT"

skipped=$(( total - entered - preset ))
echo
echo "==> wrote $entered key(s) to $OUT (chmod 600); $preset already-set, $skipped skipped"
echo "    verify:  hermes -p $PNAME chat -q 'reply with PROFILE-OK'"
if [ "$KEEP_CLONE" = 1 ]; then echo "    clone kept at: $CLONE"; fi
exit 0
