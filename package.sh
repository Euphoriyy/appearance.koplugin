#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp}"

WORK_DIR=$(mktemp -d)
trap "rm -rf '$WORK_DIR'" EXIT

mkdir -p "$WORK_DIR/appearance.koplugin"
cp -r "$SCRIPT_DIR/book" "$SCRIPT_DIR/lib" "$SCRIPT_DIR/ui" "$SCRIPT_DIR/widgets" "$WORK_DIR/appearance.koplugin/"
cp "$SCRIPT_DIR/LICENSE" "$SCRIPT_DIR/README.md" "$SCRIPT_DIR/main.lua" "$SCRIPT_DIR/_meta.lua" "$SCRIPT_DIR/themes.lua" "$WORK_DIR/appearance.koplugin/"

cd "$WORK_DIR"
zip -r "$OUTPUT_DIR/appearance.koplugin.zip" appearance.koplugin

ls -lh "$OUTPUT_DIR/appearance.koplugin.zip"
