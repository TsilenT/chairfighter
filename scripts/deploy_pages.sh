#!/usr/bin/env bash
#
# Deploy the Web build to GitHub Pages (chairfighter.stevets.ai).
#
# Publishes build/web (building it first if missing) to an orphan gh-pages
# branch with a CNAME file. Pages must be enabled once on the repo (source:
# gh-pages branch, root) — scripts/deploy_itch.sh --build produces the same
# artifact this reuses.
#
# Usage: scripts/deploy_pages.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

DOMAIN="chairfighter.stevets.ai"
OUT_DIR="$ROOT_DIR/build/web"

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

if [ ! -f "$OUT_DIR/index.html" ]; then
	log "No web build found — building via deploy_itch.sh --build"
	"$SCRIPT_DIR/deploy_itch.sh" --build
fi

SHA="$(git rev-parse --short HEAD)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp -r "$OUT_DIR/." "$TMP/"
printf '%s\n' "$DOMAIN" > "$TMP/CNAME"
touch "$TMP/.nojekyll"

log "Publishing to gh-pages (version $SHA)"
git -C "$TMP" init -q -b gh-pages
git -C "$TMP" add -A
git -C "$TMP" -c user.name="$(git config user.name)" -c user.email="$(git config user.email || echo deploy@local)" \
	commit -qm "deploy: web build $SHA"
git -C "$TMP" push -qf "$(git -C "$ROOT_DIR" remote get-url origin)" gh-pages:gh-pages

log "Done → https://$DOMAIN (once DNS + Pages cert are in place)"
