#!/usr/bin/env bash
# Summarize UI/UX audit PNGs: dimensions, file size, likely-blank heuristic.
# Run after: bash scripts/run-ui-ux-audit-e2e.sh
#
# Usage (repo root):
#   bash scripts/analyze-ui-ux-audit-screenshots.sh
#   bash scripts/analyze-ui-ux-audit-screenshots.sh /path/to/e2e/parent
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="${1:-$ROOT/.codex/skills/ui-ux-audit/output/e2e}"

if [[ ! -d "$AUDIT" ]]; then
  printf 'No audit dir: %s\n' "$AUDIT" >&2
  exit 1
fi

printf '[ui-ux-audit-analyze] root=%s\n' "$AUDIT"

for vp in desktop mobile; do
  d="$AUDIT/$vp"
  [[ -d "$d" ]] || continue
  printf '\n== %s ==\n' "$vp"
  n=0
  suspect=0
  while IFS= read -r -d '' f; do
    n=$((n + 1))
    bytes=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
    # macOS sips
    w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth:/ {print $2}') || w='?'
    h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight:/ {print $2}') || h='?'
    flag=''
    if [[ "$bytes" -lt 8192 ]]; then
      flag=' SMALL_FILE'
      suspect=$((suspect + 1))
    fi
    printf '%8d B  %5sx%-5s  %s%s\n' "$bytes" "$w" "$h" "$(basename "$f")" "$flag"
  done < <(find "$d" -maxdepth 1 -name '*.png' -print0 | sort -z)
  printf 'total_png=%d suspect_small=%d\n' "$n" "$suspect"

  printf '\n-- duplicate PNG hashes (same bytes, different filenames) --\n'
  if command -v shasum >/dev/null 2>&1; then
    dup_line="$(find "$d" -maxdepth 1 -name '*.png' -print0 | xargs -0 shasum -a 256 2>/dev/null | awk '{print $1}' | sort | uniq -c | awk '$1>1 {print}' | head -5)"
    if [[ -z "$dup_line" ]]; then
      printf '(none)\n'
    else
      printf '%s\n' "$dup_line"
      printf '(showing up to 5 duplicate-hash groups; full list: pipe shasum through sort|uniq -c)\n'
    fi
  else
    printf 'shasum not available; skip duplicate check\n'
  fi
done

printf '\n[ui-ux-audit-analyze] done. SMALL_FILE may indicate blank capture; duplicate hashes often mean E2E did not change UI between captures.\n'
