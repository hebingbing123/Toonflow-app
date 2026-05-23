#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec flutter pub run ui_audit:ui_audit "$@"
