#!/usr/bin/env bash
# 从 website/assets/source/ 设计拼板裁剪宣传页素材
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/.tmp/website-crop-venv"
PY="$ROOT/scripts/crop-website-assets.py"

SRC_DIR="$ROOT/website/assets/source"
if ! ls "$SRC_DIR"/ChatGPT*.png "$SRC_DIR"/158268*.jpg "$SRC_DIR"/design-board.png "$SRC_DIR"/design-vertical.png 2>/dev/null | head -1 >/dev/null; then
  echo "Missing design sources under $SRC_DIR" >&2
  exit 1
fi

mkdir -p "$ROOT/.tmp"
if [[ ! -x "$VENV/bin/python3" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q pillow
fi

"$VENV/bin/python3" "$PY"
