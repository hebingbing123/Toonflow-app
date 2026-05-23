#!/usr/bin/env bash
# 从 website/assets/source/ 设计拼板裁剪宣传页素材
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/.tmp/website-crop-venv"
PY="$ROOT/scripts/crop-website-assets.py"

SRC_DIR="$ROOT/website/assets/source"
shopt -s nullglob 2>/dev/null || true
_found=0
for _g in \
  "$SRC_DIR"/Gemini*.png \
  "$SRC_DIR"/ChatGP*.png \
  "$SRC_DIR"/design-board.png \
  "$SRC_DIR"/design-vertical.png; do
  if [[ -f "$_g" ]]; then _found=1; break; fi
done
if [[ "$_found" -ne 1 ]]; then
  echo "Missing design sources under $SRC_DIR (need Gemini*.png or board fallback)" >&2
  exit 1
fi

mkdir -p "$ROOT/.tmp"
if [[ ! -x "$VENV/bin/python3" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q pillow
fi

"$VENV/bin/python3" "$PY"
