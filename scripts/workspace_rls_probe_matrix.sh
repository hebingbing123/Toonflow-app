#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE_SCRIPT="$ROOT_DIR/scripts/workspace_rls_probe.sh"
OUTPUT_DIR="${OUTPUT_DIR:-}"

if [[ ! -x "$PROBE_SCRIPT" ]]; then
  echo "workspace RLS probe script not found or not executable: $PROBE_SCRIPT" >&2
  exit 1
fi

if [[ -z "${PROBE_WORKSPACE_ID:-}" ]]; then
  echo "PROBE_WORKSPACE_ID is required" >&2
  exit 1
fi

if [[ -z "${OWNER_USER_ID:-}" ]]; then
  echo "OWNER_USER_ID is required" >&2
  exit 1
fi

if [[ -z "${MEMBER_USER_ID:-}" ]]; then
  echo "MEMBER_USER_ID is required" >&2
  exit 1
fi

if [[ -z "${OUTSIDER_USER_ID:-}" ]]; then
  echo "OUTSIDER_USER_ID is required" >&2
  exit 1
fi

if [[ -n "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR"
fi

run_probe() {
  local label="$1"
  local user_id="$2"
  local output_file=""

  echo
  echo "===== workspace RLS probe: ${label} ====="
  if [[ -n "$OUTPUT_DIR" ]]; then
    output_file="$OUTPUT_DIR/${label}.txt"
    PROBE_USER_ID="$user_id" \
    PROBE_WORKSPACE_ID="$PROBE_WORKSPACE_ID" \
    bash "$PROBE_SCRIPT" | tee "$output_file"
    echo "saved ${label} output to ${output_file}"
  else
    PROBE_USER_ID="$user_id" \
    PROBE_WORKSPACE_ID="$PROBE_WORKSPACE_ID" \
    bash "$PROBE_SCRIPT"
  fi
}

run_probe owner "$OWNER_USER_ID"
run_probe member "$MEMBER_USER_ID"
run_probe outsider "$OUTSIDER_USER_ID"
