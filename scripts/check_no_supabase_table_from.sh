#!/usr/bin/env bash
# Fail if Flutter code queries Supabase business tables directly (HEALTH-013).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if rg "\.from\('app_" "$ROOT/frontend/lib" -q 2>/dev/null; then
  echo "ERROR: direct Supabase .from('app_*') found in frontend/lib (use rust_api + Rust API)" >&2
  rg "\.from\('app_" "$ROOT/frontend/lib" || true
  exit 1
fi
echo "OK: no direct Supabase app_* table queries in frontend/lib"
