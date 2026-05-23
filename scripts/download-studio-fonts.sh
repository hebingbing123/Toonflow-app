#!/usr/bin/env bash
# Downloads Studio UI fonts into frontend/assets/fonts/ (OFL-licensed).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/frontend/assets/fonts"
mkdir -p "$OUT"

BASE="https://raw.githubusercontent.com/google/fonts/main/ofl"

fetch() {
  local url="$1"
  local dest="$2"
  if [[ -f "$dest" ]]; then
    echo "skip $(basename "$dest")"
    return
  fi
  echo "fetch $(basename "$dest")"
  curl -fsSL "$url" -o "$dest"
}

fetch "$BASE/inter/Inter%5Bopsz,wght%5D.ttf" "$OUT/Inter-Variable.ttf"
fetch "$BASE/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf" "$OUT/SpaceGrotesk-Variable.ttf"
fetch "$BASE/notosanssc/NotoSansSC%5Bwght%5D.ttf" "$OUT/NotoSansSC-Variable.ttf"

echo "Done. Fonts in $OUT ($(du -sh "$OUT" | cut -f1))"
