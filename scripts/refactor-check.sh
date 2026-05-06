#!/usr/bin/env bash
# Local gate for Rust + Flutter + OpenAPI (matches .github/workflows/ci.yml intent).
# Usage: yarn refactor:check   OR   bash scripts/refactor-check.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> merged OpenAPI export (YAML parse)"
(cd backend && cargo run --quiet --bin export-openapi) | ruby -ryaml -e "YAML.load(STDIN.read)"

echo "==> OpenAPI drift detection"
bash scripts/check_openapi_drift.sh

echo "==> rust_api contract consistency"
bash scripts/check_rust_api_consistency.sh

echo "==> backend/ (fmt, clippy, test)"
(
  cd backend
  cargo fmt -- --check
  cargo clippy -- -D warnings
  cargo test
)

echo "==> frontend/ (pub get, analyze, test)"
if command -v flutter >/dev/null 2>&1; then
  (
    cd frontend
    flutter pub get
    flutter analyze
    flutter test
  )
else
  echo "WARN: flutter not in PATH — skipped frontend steps. Install Flutter or use CI." >&2
  exit 1
fi

echo "OK: refactor-check passed."
