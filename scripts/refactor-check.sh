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

STEP_START=0
OPENAPI_SPEC_FILE=""
BACKEND_CHANGED=true
FRONTEND_CHANGED=true
OPENAPI_CHANGED=true

cleanup() {
  if [ -n "$OPENAPI_SPEC_FILE" ] && [ -f "$OPENAPI_SPEC_FILE" ]; then
    rm -f "$OPENAPI_SPEC_FILE"
  fi
}
trap cleanup EXIT

step_start() {
  STEP_START=$(date +%s)
}

step_finish() {
  local label="$1"
  local now elapsed
  now=$(date +%s)
  elapsed=$((now - STEP_START))
  echo "==> ${label} completed in ${elapsed}s"
}

need_flutter_pub_get() {
  local package_config="frontend/.dart_tool/package_config.json"
  if [ ! -f "$package_config" ]; then
    return 0
  fi

  if [ "frontend/pubspec.yaml" -nt "$package_config" ]; then
    return 0
  fi

  if [ -f "frontend/pubspec.lock" ] && [ "frontend/pubspec.lock" -nt "$package_config" ]; then
    return 0
  fi

  return 1
}

detect_changed_components() {
  local changed_files staged_files untracked_files all_changed file

  changed_files=$(git diff --name-only HEAD 2>/dev/null || echo "")
  staged_files=$(git diff --cached --name-only 2>/dev/null || echo "")
  untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")
  all_changed="$changed_files"$'\n'"$staged_files"$'\n'"$untracked_files"

  BACKEND_CHANGED=false
  FRONTEND_CHANGED=false
  OPENAPI_CHANGED=false

  while IFS= read -r file; do
    [ -z "$file" ] && continue

    case "$file" in
      backend/*)
        BACKEND_CHANGED=true
        if [[ "$file" =~ (openapi|routes|handlers) ]]; then
          OPENAPI_CHANGED=true
        fi
        ;;
      frontend/*)
        FRONTEND_CHANGED=true
        ;;
      frontend/pubspec.yaml|frontend/pubspec.lock)
        FRONTEND_CHANGED=true
        ;;
      scripts/check_openapi_drift.sh|scripts/check_rust_api_consistency.sh)
        OPENAPI_CHANGED=true
        ;;
    esac
  done <<< "$all_changed"
}

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

# Detect changed files for quick/incremental mode
if [ "$MODE" = "quick" ] || [ "$MODE" = "incremental" ]; then
  echo "==> Detecting changed files..."
  detect_changed_components
  
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
if [ "$MODE" = "full" ] || [ "$OPENAPI_CHANGED" = true ]; then
  echo "==> merged OpenAPI export (YAML parse)"
  # BSD mktemp requires XXXXXX at the end of the template (no ".yaml" suffix).
  OPENAPI_SPEC_FILE="$(mktemp "${TMPDIR:-/tmp}/toonflow-openapi.XXXXXX")"
  step_start
  (cd backend && cargo run --quiet --bin export-openapi) > "$OPENAPI_SPEC_FILE"
  ruby -ryaml -e "YAML.load(File.read('$OPENAPI_SPEC_FILE'))"
  step_finish "OpenAPI export + YAML parse"
  export TOONFLOW_OPENAPI_SPEC="$OPENAPI_SPEC_FILE"

  echo "==> OpenAPI drift detection"
  step_start
  bash scripts/check_openapi_drift.sh
  step_finish "OpenAPI drift detection"

  echo "==> rust_api contract consistency"
  step_start
  bash scripts/check_rust_api_consistency.sh
  step_finish "rust_api contract consistency"
else
  echo "==> Skipping OpenAPI checks (no relevant changes)"
fi

# Backend checks (only if backend changed, or in full mode)
if [ "$MODE" = "full" ] || [ "$BACKEND_CHANGED" = true ]; then
  echo "==> backend/ (fmt, clippy)"
  step_start
  (
    cd backend
    cargo fmt -- --check
    cargo clippy -- -D warnings
  )
  step_finish "backend fmt + clippy"
  
  # Tests only in full mode
  if [ "$MODE" = "full" ]; then
    echo "==> backend/ (test)"
    step_start
    # -j 1: serialize integration test binaries so sqlx::test DB setup does not race on shared template DB.
    (cd backend && cargo test -j 1 -- --test-threads=1)
    step_finish "backend test"
  else
    echo "==> Skipping backend tests (quick/incremental mode)"
  fi
else
  echo "==> Skipping backend checks (no relevant changes)"
fi

# Frontend checks (only if frontend changed, or in full mode)
if [ "$MODE" = "full" ] || [ "$FRONTEND_CHANGED" = true ]; then
  echo "==> frontend/ (pub get if needed, analyze)"
  if command -v flutter >/dev/null 2>&1; then
    if need_flutter_pub_get; then
      echo "==> frontend/ flutter pub get"
      step_start
      (cd frontend && flutter pub get)
      step_finish "frontend flutter pub get"
    else
      echo "==> Skipping flutter pub get (dependencies unchanged)"
    fi

    echo "==> frontend/ flutter analyze"
    step_start
    (cd frontend && flutter analyze)
    step_finish "frontend flutter analyze"
    
    # Tests only in full mode
    if [ "$MODE" = "full" ]; then
      echo "==> frontend/ (test)"
      step_start
      (cd frontend && flutter test)
      step_finish "frontend test"
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
