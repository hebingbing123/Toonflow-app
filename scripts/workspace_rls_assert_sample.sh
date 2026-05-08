#!/usr/bin/env bash
set -euo pipefail

INPUT_DIR="${INPUT_DIR:-}"

if [[ -z "$INPUT_DIR" ]]; then
  echo "INPUT_DIR is required" >&2
  exit 1
fi

SUMMARY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUMMARY_SCRIPT="$SUMMARY_SCRIPT_DIR/workspace_rls_summarize.sh"

if [[ ! -x "$SUMMARY_SCRIPT" ]]; then
  echo "workspace RLS summarize script not found or not executable: $SUMMARY_SCRIPT" >&2
  exit 1
fi

SUMMARY_FILE="$(mktemp)"
trap 'rm -f "$SUMMARY_FILE"' EXIT

INPUT_DIR="$INPUT_DIR" OUTPUT_FILE="$SUMMARY_FILE" bash "$SUMMARY_SCRIPT" >/dev/null

extract_value() {
  local table="$1"
  local column="$2"

  awk -F'|' -v target_table="\`$table\`" -v target_col="$column" '
    /^\| `/ {
      table=$2
      owner=$3
      member=$4
      outsider=$5
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", table)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", owner)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", member)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", outsider)
      if (table == target_table) {
        if (target_col == "owner") print owner
        else if (target_col == "member") print member
        else if (target_col == "outsider") print outsider
        found=1
        exit
      }
    }
    END {
      if (!found) exit 1
    }
  ' "$SUMMARY_FILE"
}

assert_equals() {
  local table="$1"
  local column="$2"
  local expected="$3"
  local actual
  actual="$(extract_value "$table" "$column")"
  if [[ "$actual" != "$expected" ]]; then
    echo "assertion failed: $table $column expected $expected but got $actual" >&2
    exit 1
  fi
}

assert_equals app_workspace owner 1
assert_equals app_workspace member 1
assert_equals app_workspace outsider 0

assert_equals app_workspace_member owner 1
assert_equals app_workspace_member member 1
assert_equals app_workspace_member outsider 0

for table in app_project app_script app_asset app_novel app_generation_job; do
  assert_equals "$table" owner 1
  assert_equals "$table" member 0
  assert_equals "$table" outsider 0
done

for table in app_agent_memory app_art_style; do
  assert_equals "$table" owner 0
  assert_equals "$table" member 0
  assert_equals "$table" outsider 0
done

echo "workspace RLS sample assertions passed for $INPUT_DIR"
