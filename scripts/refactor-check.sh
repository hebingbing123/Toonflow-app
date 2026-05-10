#!/usr/bin/env bash
# Local gate for Rust + Flutter + OpenAPI (matches .github/workflows/ci.yml intent).
# Usage: 
#   yarn refactor:check              # Full check (default)
#   yarn refactor:check --quick      # Quick check (skip tests)
#   yarn refactor:check --incremental # Incremental check (only changed files)
#   bash scripts/refactor-check.sh [--quick|--incremental]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Parse arguments
MODE="full"
for arg in "$@"; do
  case "$arg" in
    --quick)
      MODE="quick"
      ;;
    --incremental)
      MODE="incremental"
      ;;
    --help)
      echo "Usage: $0 [--quick|--incremental]"
      echo ""
      echo "Modes:"
      echo "  (default)      Full check: all lints, tests, and validations"
      echo "  --quick        Quick check: skip tests, only lints and validations"
      echo "  --incremental  Incremental: only check modified files (fastest)"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Detect changed files for incremental mode
if [ "$MODE" = "incremental" ]; then
  echo "==> Detecting changed files..."
  
  # Get changed files (staged + unstaged)
  CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")
  STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")
  ALL_CHANGED="$CHANGED_FILES"$'\n'"$STAGED_FILES"
  
  # Determine which components changed
  BACKEND_CHANGED=false
  FRONTEND_CHANGED=false
  OPENAPI_CHANGED=false
  
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    
    case "$file" in
      backend/*)
        BACKEND_CHANGED=true
        # Check if OpenAPI-related files changed
        if [[ "$file" =~ (openapi|routes|handlers) ]]; then
          OPENAPI_CHANGED=true
        fi
        ;;
      frontend/*)
        FRONTEND_CHANGED=true
        ;;
      scripts/check_openapi_drift.sh|scripts/check_rust_api_consistency.sh)
        OPENAPI_CHANGED=true
        ;;
    esac
  done <<< "$ALL_CHANGED"
  
  echo "   Backend changed: $BACKEND_CHANGED"
  echo "   Frontend changed: $FRONTEND_CHANGED"
  echo "   OpenAPI changed: $OPENAPI_CHANGED"
  
  # If nothing changed, skip all checks
  if [ "$BACKEND_CHANGED" = false ] && [ "$FRONTEND_CHANGED" = false ]; then
    echo "==> No relevant changes detected, skipping all checks"
    echo "OK: refactor-check passed (no changes)."
    exit 0
  fi
fi

# OpenAPI checks (only if backend or OpenAPI changed, or in full mode)
if [ "$MODE" = "full" ] || [ "$MODE" = "quick" ] || [ "$OPENAPI_CHANGED" = true ]; then
  echo "==> merged OpenAPI export (YAML parse)"
  (cd backend && cargo run --quiet --bin export-openapi) | ruby -ryaml -e "YAML.load(STDIN.read)"

  echo "==> OpenAPI drift detection"
  bash scripts/check_openapi_drift.sh

  echo "==> rust_api contract consistency"
  bash scripts/check_rust_api_consistency.sh
else
  echo "==> Skipping OpenAPI checks (no relevant changes)"
fi

# Backend checks (only if backend changed, or in full mode)
if [ "$MODE" = "full" ] || [ "$MODE" = "quick" ] || [ "$BACKEND_CHANGED" = true ]; then
  echo "==> backend/ (fmt, clippy)"
  (
    cd backend
    cargo fmt -- --check
    cargo clippy -- -D warnings
  )
  
  # Tests only in full mode
  if [ "$MODE" = "full" ]; then
    echo "==> backend/ (test)"
    (cd backend && cargo test -- --test-threads=1)
  else
    echo "==> Skipping backend tests (quick/incremental mode)"
  fi
else
  echo "==> Skipping backend checks (no relevant changes)"
fi

# Frontend checks (only if frontend changed, or in full mode)
if [ "$MODE" = "full" ] || [ "$MODE" = "quick" ] || [ "$FRONTEND_CHANGED" = true ]; then
  echo "==> frontend/ (pub get, analyze)"
  if command -v flutter >/dev/null 2>&1; then
    (
      cd frontend
      flutter pub get
      flutter analyze
    )
    
    # Tests only in full mode
    if [ "$MODE" = "full" ]; then
      echo "==> frontend/ (test)"
      (cd frontend && flutter test)
    else
      echo "==> Skipping frontend tests (quick/incremental mode)"
    fi
  else
    echo "WARN: flutter not in PATH — skipped frontend steps. Install Flutter or use CI." >&2
    exit 1
  fi
else
  echo "==> Skipping frontend checks (no relevant changes)"
fi

echo "OK: refactor-check passed ($MODE mode)."
