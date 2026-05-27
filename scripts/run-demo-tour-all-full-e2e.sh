#!/usr/bin/env bash
# Web + desktop full demo tour E2E (15 stops each).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/run-demo-tour-web-full-e2e.sh"
bash "$ROOT/scripts/run-demo-tour-desktop-full-e2e.sh"

printf '[demo-tour-all-full] PASSED web + desktop\n'
