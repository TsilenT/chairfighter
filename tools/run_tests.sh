#!/usr/bin/env bash
# Headless test gate. Fails on nonzero exit OR any script/load error in the
# output — Godot can report "TESTS PASS" even when a file failed to parse.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="$(timeout "${TEST_TIMEOUT:-180}" godot --headless --path . -s res://tests/run_all.gd 2>&1)"
CODE=$?
echo "$OUT"
if [ $CODE -ne 0 ]; then
	echo "GATE: FAIL (exit $CODE)"
	exit 1
fi
if echo "$OUT" | grep -qE "SCRIPT ERROR|ERROR: Failed to load|Parse Error"; then
	echo "GATE: FAIL (script errors in output)"
	exit 1
fi
if ! echo "$OUT" | grep -q "TESTS PASS"; then
	echo "GATE: FAIL (no TESTS PASS marker)"
	exit 1
fi
echo "GATE: PASS"
