#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage: bash scripts/agent-refactor-check.sh [--incremental|--quick|--full]

Agent-safe wrapper around scripts/refactor-check.sh.

Modes:
  (default)      Incremental check for day-to-day development
  --incremental  Same as default
  --quick        Fast pre-commit validation, skips tests
  --full         Full validation; only use before commit, completion, or when explicitly requested
EOF
}

MODE="incremental"

for arg in "$@"; do
  case "$arg" in
    --incremental)
      MODE="incremental"
      ;;
    --quick)
      MODE="quick"
      ;;
    --full)
      MODE="full"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$MODE" in
  incremental)
    echo "==> Agent gate: incremental mode"
    exec bash scripts/refactor-check.sh --incremental
    ;;
  quick)
    echo "==> Agent gate: quick mode"
    exec bash scripts/refactor-check.sh --quick
    ;;
  full)
    echo "==> Agent gate: full mode"
    echo "==> Use only before commit, before declaring completion, or when the user explicitly asks for full validation"
    exec bash scripts/refactor-check.sh
    ;;
esac
