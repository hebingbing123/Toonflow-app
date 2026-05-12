#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT/backend"
TARGET_DIR="$BACKEND_DIR/target"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/rust-target-maintenance.sh report
  bash scripts/rust-target-maintenance.sh clean

Commands:
  report  Show backend target size and the largest subdirectories/files.
  clean   Run cargo clean in backend and report reclaimed space.
EOF
}

report_target() {
  if [ ! -d "$TARGET_DIR" ]; then
    echo "backend/target does not exist."
    exit 0
  fi

  echo "==> backend/target total"
  du -sh "$TARGET_DIR"
  echo ""

  echo "==> Largest target subdirectories"
  du -sh "$TARGET_DIR"/* 2>/dev/null | sort -hr | head -n 20
  echo ""

  echo "==> Largest debug artifacts"
  find "$TARGET_DIR/debug" -type f -size +50M -print0 2>/dev/null \
    | xargs -0 ls -lhS 2>/dev/null \
    | head -n 20 || true
}

clean_target() {
  local before_kb after_kb reclaimed_kb

  if [ -d "$TARGET_DIR" ]; then
    before_kb=$(du -sk "$TARGET_DIR" 2>/dev/null | awk '{print $1}')
    before_kb=${before_kb:-0}
  else
    before_kb=0
  fi

  echo "==> Running cargo clean in backend/"
  (cd "$BACKEND_DIR" && cargo clean)

  if [ -d "$TARGET_DIR" ]; then
    after_kb=$(du -sk "$TARGET_DIR" 2>/dev/null | awk '{print $1}')
    after_kb=${after_kb:-0}
  else
    after_kb=0
  fi
  reclaimed_kb=$((before_kb - after_kb))

  echo ""
  echo "==> backend/target after clean"
  if [ -d "$TARGET_DIR" ]; then
    du -sh "$TARGET_DIR"
  else
    echo "0B"
  fi

  echo "==> Reclaimed"
  awk -v kb="$reclaimed_kb" 'BEGIN { printf "%.2f GiB\n", kb / 1024 / 1024 }'
}

case "${1:-report}" in
  report)
    report_target
    ;;
  clean)
    clean_target
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
