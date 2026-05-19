#!/usr/bin/env bash
# Convenience wrapper: keep Supabase running between iterations, skip db reset.
#
#   bash scripts/run-ui-e2e-local.sh           # smoke
#   bash scripts/run-ui-e2e-local.sh --gallery
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export OPENFLOW_UI_E2E_SKIP_RESET=1
exec bash "$ROOT/scripts/run-ui-e2e.sh" "$@"
