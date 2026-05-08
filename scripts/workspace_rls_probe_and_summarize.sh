#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE_MATRIX_SCRIPT="$ROOT_DIR/scripts/workspace_rls_probe_matrix.sh"
SUMMARIZE_SCRIPT="$ROOT_DIR/scripts/workspace_rls_summarize.sh"
ASSERT_SUMMARY_SCRIPT="$ROOT_DIR/scripts/workspace_rls_assert_summary.sh"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/.tmp/workspace-rls-$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}"

if [[ ! -x "$PROBE_MATRIX_SCRIPT" ]]; then
  echo "workspace RLS probe matrix script not found or not executable: $PROBE_MATRIX_SCRIPT" >&2
  exit 1
fi

if [[ ! -x "$SUMMARIZE_SCRIPT" ]]; then
  echo "workspace RLS summarize script not found or not executable: $SUMMARIZE_SCRIPT" >&2
  exit 1
fi

if [[ ! -x "$ASSERT_SUMMARY_SCRIPT" ]]; then
  echo "workspace RLS summary assert script not found or not executable: $ASSERT_SUMMARY_SCRIPT" >&2
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

OUTPUT_DIR="$OUTPUT_DIR" \
PROBE_WORKSPACE_ID="$PROBE_WORKSPACE_ID" \
OWNER_USER_ID="$OWNER_USER_ID" \
MEMBER_USER_ID="$MEMBER_USER_ID" \
OUTSIDER_USER_ID="$OUTSIDER_USER_ID" \
bash "$PROBE_MATRIX_SCRIPT"

INPUT_DIR="$OUTPUT_DIR" \
OUTPUT_FILE="$OUTPUT_DIR/summary.md" \
JSON_OUTPUT_FILE="$OUTPUT_DIR/summary.json" \
bash "$SUMMARIZE_SCRIPT"

SUMMARY_FILE="$OUTPUT_DIR/summary.md" \
ALLOW_MATCH_OR_RLS_WIDENED="${ALLOW_MATCH_OR_RLS_WIDENED:-0}" \
bash "$ASSERT_SUMMARY_SCRIPT"

echo "workspace RLS probe artifacts ready in $OUTPUT_DIR"
