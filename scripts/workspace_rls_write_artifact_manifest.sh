#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${OUTPUT_FILE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-}"
WORKSPACE_ID="${WORKSPACE_ID:-}"
OWNER_USER_ID="${OWNER_USER_ID:-}"
MEMBER_USER_ID="${MEMBER_USER_ID:-}"
OUTSIDER_USER_ID="${OUTSIDER_USER_ID:-}"
ENVIRONMENT_LABEL="${ENVIRONMENT_LABEL:-staging}"
RELEASE_LABEL="${RELEASE_LABEL:-}"

if [[ -z "$OUTPUT_FILE" ]]; then
  echo "OUTPUT_FILE is required" >&2
  exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  echo "OUTPUT_DIR is required" >&2
  exit 1
fi

if [[ -z "$WORKSPACE_ID" ]]; then
  echo "WORKSPACE_ID is required" >&2
  exit 1
fi

if [[ -z "$OWNER_USER_ID" || -z "$MEMBER_USER_ID" || -z "$OUTSIDER_USER_ID" ]]; then
  echo "OWNER_USER_ID, MEMBER_USER_ID, and OUTSIDER_USER_ID are required" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

cat > "$OUTPUT_FILE" <<EOF
{
  "environment": "$ENVIRONMENT_LABEL",
  "release": "${RELEASE_LABEL:-pending}",
  "workspace_id": "$WORKSPACE_ID",
  "users": {
    "owner": "$OWNER_USER_ID",
    "member": "$MEMBER_USER_ID",
    "outsider": "$OUTSIDER_USER_ID"
  },
  "output_dir": "$OUTPUT_DIR",
  "artifacts": {
    "owner_probe": "$OUTPUT_DIR/owner.txt",
    "member_probe": "$OUTPUT_DIR/member.txt",
    "outsider_probe": "$OUTPUT_DIR/outsider.txt",
    "summary_markdown": "$OUTPUT_DIR/summary.md",
    "summary_json": "$OUTPUT_DIR/summary.json",
    "assertion_json": "$OUTPUT_DIR/assertion.json",
    "checklist_snippet_markdown": "$OUTPUT_DIR/checklist-snippet.md"
  }
}
EOF

echo "saved workspace RLS artifact manifest to $OUTPUT_FILE"
