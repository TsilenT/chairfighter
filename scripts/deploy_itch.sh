#!/usr/bin/env bash
#
# Deploy Chairfighter to itch.io.
#
# Builds a headless Godot Web (HTML5) export and pushes it to itch.io with butler.
# All credentials/config are read from ".itch.env" (gitignored) at the repo root.
# See ".itch.env.example" for the required variables.
#
# Usage:
#   scripts/deploy_itch.sh            # build + push
#   scripts/deploy_itch.sh --build    # build only, skip the itch.io push
#   scripts/deploy_itch.sh --dry-run  # build + show the butler command without pushing
#
set -euo pipefail

# --- locate repo root (this script lives in <root>/scripts) -------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

BUILD_ONLY=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --build)   BUILD_ONLY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

# --- load secrets/config ------------------------------------------------------
ENV_FILE="$ROOT_DIR/.itch.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
elif [ "$BUILD_ONLY" -eq 0 ]; then
  die "Missing $ENV_FILE. Copy .itch.env.example to .itch.env and fill it in."
fi

# itch.io credentials are only needed for the push, not for --build.
if [ "$BUILD_ONLY" -eq 0 ]; then
  : "${BUTLER_API_KEY:?Set BUTLER_API_KEY in .itch.env}"
  : "${ITCH_USER:?Set ITCH_USER in .itch.env}"
  : "${ITCH_GAME:?Set ITCH_GAME in .itch.env}"
  ITCH_CHANNEL="${ITCH_CHANNEL:-html5}"
  TARGET="$ITCH_USER/$ITCH_GAME:$ITCH_CHANNEL"
fi

# --- locate tools -------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"

GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
  for c in godot godot4 godot-headless; do
    if command -v "$c" >/dev/null 2>&1; then GODOT_BIN="$c"; break; fi
  done
fi
[ -n "$GODOT_BIN" ] || die "Godot binary not found. Install Godot or set GODOT_BIN."
if [ "$BUILD_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  command -v butler >/dev/null 2>&1 || die "butler not found on PATH (~/.local/bin)."
fi

# --- ensure export templates for the running Godot version --------------------
ensure_templates() {
  local ver_line ver tag tpz dest tmp
  ver_line="$("$GODOT_BIN" --version 2>/dev/null | tail -n1)"   # e.g. 4.6.3.stable.official.7d41c59c4
  # "4.6.3.stable" — major.minor.patch.release
  ver="$(printf '%s' "$ver_line" | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?\.(stable|beta[0-9]*|rc[0-9]*|dev[0-9]*)')"
  [ -n "$ver" ] || die "Could not parse Godot version from: $ver_line"

  local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  dest="$data_home/godot/export_templates/$ver"
  if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    log "Export templates present: $dest"
    return 0
  fi

  # turn "4.6.3.stable" into the release tag "4.6.3-stable"
  tag="$(printf '%s' "$ver" | sed -E 's/\.(stable|beta[0-9]*|rc[0-9]*|dev[0-9]*)$/-\1/')"
  tpz="Godot_v${tag}_export_templates.tpz"
  local url="https://github.com/godotengine/godot/releases/download/${tag}/${tpz}"

  log "Export templates missing — downloading $tpz from GitHub..."
  tmp="$(mktemp -d)"
  curl -fL --retry 3 -o "$tmp/$tpz" "$url" || die "Failed to download export templates ($url)"
  python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$tmp/$tpz" "$tmp"
  # The TPZ extracts to a 'templates/' dir; move its contents into the version dir.
  mkdir -p "$dest"
  cp -f "$tmp/templates/." "$dest/" 2>/dev/null || cp -rf "$tmp/templates/"* "$dest/"
  rm -rf "$tmp"
  log "Installed export templates to $dest"
}
ensure_templates

# --- build --------------------------------------------------------------------
OUT_DIR="$ROOT_DIR/build/web"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

log "Exporting Web build with $GODOT_BIN..."
# --headless: no window; --import first so resources are ready in CI/clean checkouts.
"$GODOT_BIN" --headless --path "$ROOT_DIR" --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release "Web" "$OUT_DIR/index.html"

[ -f "$OUT_DIR/index.html" ] || die "Export did not produce index.html — check the 'Web' preset in export_presets.cfg."
log "Build ready in $OUT_DIR ($(du -sh "$OUT_DIR" | cut -f1))"

if [ "$BUILD_ONLY" -eq 1 ]; then
  log "Build-only mode; skipping itch.io push."
  exit 0
fi

# --- push ---------------------------------------------------------------------
# Tag the upload with the current git short SHA when available.
USER_VERSION="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M)"

if [ "$DRY_RUN" -eq 1 ]; then
  log "[dry-run] butler push \"$OUT_DIR\" \"$TARGET\" --userversion \"$USER_VERSION\""
  exit 0
fi

log "Pushing to itch.io: $TARGET (version $USER_VERSION)"
butler push "$OUT_DIR" "$TARGET" --userversion "$USER_VERSION"
log "Done. View status: butler status \"$ITCH_USER/$ITCH_GAME\""
