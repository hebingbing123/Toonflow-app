#!/usr/bin/env bash
# Quick sanity check for global-search saved views vertical slice (not full yarn refactor:check).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== backend: cargo check =="
( cd backend && cargo check -q )

echo "== frontend: dart analyze (saved views paths) =="
( cd frontend && dart analyze \
  lib/global_search/global_search_bar.dart \
  lib/global_search/search_results_page.dart \
  lib/rust_api/search/saved_views.dart \
  lib/home_page.dart \
)

echo "OK: saved views vertical slice compile/analyze passed."
