#!/usr/bin/env bash
# Web 書き出し。リポジトリ外に作業用プロジェクトを作り、このリポジトリを index/ としてコピーして書き出す。
# 使い方: GODOT=/path/to/Godot_v4.7 tools/build_web.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$REPO/../gemini-dungeon-build}"
GODOT="${GODOT:-godot}"
mkdir -p "$WORK/index" "$WORK/out"
rm -rf "$WORK/index"; mkdir -p "$WORK/index"
tar -C "$REPO" --exclude=.git --exclude="./index.*" --exclude=./design/image --exclude=./coi-serviceworker.js -cf - . | tar -C "$WORK/index" -xf -
cp "$REPO/tools/project.godot.example" "$WORK/project.godot"
cp "$REPO/tools/export_presets.cfg.example" "$WORK/export_presets.cfg"
"$GODOT" --headless --path "$WORK" --import
"$GODOT" --headless --path "$WORK" --export-release "Web" "$WORK/out/index.html"
# 生成された .uid をリポジトリに戻す
(cd "$WORK/index" && find core -name '*.uid') | while read -r f; do cp -n "$WORK/index/$f" "$REPO/$f" 2>/dev/null || true; done
rm -f "$REPO"/index.*
cp "$WORK"/out/index.* "$REPO/"
echo "done: $REPO/index.html"
