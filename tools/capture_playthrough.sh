#!/usr/bin/env bash
# Full-playthrough verification + capture.
#   tools/capture_playthrough.sh check    — headless gate (fast, CI-style)
#   tools/capture_playthrough.sh video    — rendered MovieWriter run (AVI + shots)
set -uo pipefail
cd "$(dirname "$0")/.."
SCRIPT="res://tests/playthrough/full_run.json"
MODE="${1:-check}"

if [ "$MODE" = "check" ]; then
	CHAIRFIGHTER_DEMO="$SCRIPT" timeout "${DEMO_TIMEOUT:-900}" \
		flock -w 900 /tmp/chairfighter_godot.lock godot --headless --path . 2>&1 | tail -30
	exit "${PIPESTATUS[0]}"
fi

if [ "$MODE" = "video" ]; then
	mkdir -p build/playthrough
	CHAIRFIGHTER_DEMO="$SCRIPT" timeout "${DEMO_TIMEOUT:-2400}" \
		flock -w 900 /tmp/chairfighter_godot.lock godot --path . \
		--write-movie build/playthrough/full_run.avi --resolution 1280x720 2>&1 | tail -30
	CODE="${PIPESTATUS[0]}"
	ls -lh build/playthrough/full_run.avi 2>/dev/null || true
	exit "$CODE"
fi

echo "usage: $0 [check|video]"
exit 2
