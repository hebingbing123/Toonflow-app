#!/usr/bin/env bash
# 从 OpenFlow 设计拼板图裁剪宣传页素材 → website/assets/screenshots/
# 源图默认在 Cursor assets；可设 DESIGN_BOARD / DESIGN_VERT 覆盖。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/website/assets/screenshots"
BOARD="${DESIGN_BOARD:-$ROOT/website/assets/source/design-board.png}"
VERT="${DESIGN_VERT:-$ROOT/website/assets/source/design-vertical.png}"

if [[ ! -f "$BOARD" || ! -f "$VERT" ]]; then
  echo "Missing design sources. Set DESIGN_BOARD and DESIGN_VERT." >&2
  exit 1
fi

mkdir -p "$OUT"

crop() {
  local src=$1 y=$2 x=$3 h=$4 w=$5 name=$6
  local tmp="$OUT/.tmp-crop.png"
  cp "$src" "$tmp"
  sips --cropOffset "$y" "$x" --cropToHeightWidth "$h" "$w" "$tmp" --out "$OUT/$name" >/dev/null
}

echo "Cropping from design board: $BOARD"
crop "$BOARD" 55 8 280 192 "mobile-01-projects.png"
crop "$BOARD" 55 208 280 192 "mobile-02-script.png"
crop "$BOARD" 55 408 280 192 "mobile-03-storyboard.png"
crop "$BOARD" 55 608 280 192 "mobile-04-team.png"
crop "$BOARD" 55 808 280 208 "mobile-05-summary.png"
crop "$BOARD" 68 12 268 175 "mobile-app.png"
crop "$BOARD" 355 20 245 480 "desktop-studio.png"
crop "$BOARD" 455 600 210 380 "web-app.png"
crop "$BOARD" 640 12 180 238 "feature-script.png"
crop "$BOARD" 640 262 180 238 "feature-storyboard.png"
crop "$BOARD" 640 512 180 238 "feature-collab.png"
crop "$BOARD" 640 762 180 238 "feature-private.png"
cp "$BOARD" "$OUT/design-board-full.png"

echo "Cropping from vertical sheet: $VERT"
crop "$VERT" 720 10 290 552 "hero-main.png"
crop "$VERT" 830 35 185 500 "hero-app.png"
crop "$VERT" 95 8 290 564 "features-trio.png"
crop "$VERT" 100 8 280 182 "panel-script.png"
crop "$VERT" 100 192 280 188 "panel-storyboard.png"
crop "$VERT" 100 382 280 182 "panel-collab.png"

rm -f "$OUT/.tmp-crop.png"
echo "Done → $OUT"
