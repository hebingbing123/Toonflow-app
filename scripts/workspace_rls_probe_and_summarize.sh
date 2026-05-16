#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE_MATRIX_SCRIPT="$ROOT_DIR/scripts/workspace_rls_probe_matrix.sh"
SUMMARIZE_SCRIPT="$ROOT_DIR/scripts/workspace_rls_summarize.sh"
ASSERT_SUMMARY_SCRIPT="$ROOT_DIR/scripts/workspace_rls_assert_summary.sh"
RENDER_SNIPPET_SCRIPT="$ROOT_DIR/scripts/workspace_rls_render_checklist_snippet.sh"
WRITE_MANIFEST_SCRIPT="$ROOT_DIR/scripts/workspace_rls_write_artifact_manifest.sh"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/.tmp/workspace-rls-$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}"
ENVIRONMENT_LABEL="${ENVIRONMENT_LABEL:-staging}"
RELEASE_LABEL="${RELEASE_LABEL:-}"

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

if [[ ! -x "$RENDER_SNIPPET_SCRIPT" ]]; then
  echo "workspace RLS checklist snippet script not found or not executable: $RENDER_SNIPPET_SCRIPT" >&2
  exit 1
fi

if [[ ! -x "$WRITE_MANIFEST_SCRIPT" ]]; then
  echo "workspace RLS artifact manifest script not found or not executable: $WRITE_MANIFEST_SCRIPT" >&2
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
RESULT_JSON_FILE="$OUTPUT_DIR/assertion.json" \
bash "$ASSERT_SUMMARY_SCRIPT"

SUMMARY_JSON_FILE="$OUTPUT_DIR/summary.json" \
ASSERTION_JSON_FILE="$OUTPUT_DIR/assertion.json" \
ENVIRONMENT_LABEL="$ENVIRONMENT_LABEL" \
RELEASE_LABEL="$RELEASE_LABEL" \
OUTPUT_FILE="$OUTPUT_DIR/checklist-snippet.md" \
bash "$RENDER_SNIPPET_SCRIPT"

OUTPUT_FILE="$OUTPUT_DIR/artifact-manifest.json" \
OUTPUT_DIR="$OUTPUT_DIR" \
WORKSPACE_ID="$PROBE_WORKSPACE_ID" \
OWNER_USER_ID="$OWNER_USER_ID" \
MEMBER_USER_ID="$MEMBER_USER_ID" \
OUTSIDER_USER_ID="$OUTSIDER_USER_ID" \
ENVIRONMENT_LABEL="$ENVIRONMENT_LABEL" \
RELEASE_LABEL="$RELEASE_LABEL" \
bash "$WRITE_MANIFEST_SCRIPT"

echo "workspace RLS probe artifacts ready in $OUTPUT_DIR"
