#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED_SCRIPT="$ROOT_DIR/scripts/workspace_rls_seed_sample.sh"
PROBE_MATRIX_SCRIPT="$ROOT_DIR/scripts/workspace_rls_probe_matrix.sh"
ASSERT_SCRIPT="$ROOT_DIR/scripts/workspace_rls_assert_sample.sh"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/.tmp/workspace-rls-sample"

if [[ ! -x "$SEED_SCRIPT" ]]; then
  echo "workspace RLS seed script not found or not executable: $SEED_SCRIPT" >&2
  exit 1
fi

if [[ ! -x "$PROBE_MATRIX_SCRIPT" ]]; then
  echo "workspace RLS probe matrix script not found or not executable: $PROBE_MATRIX_SCRIPT" >&2
  exit 1
fi

if [[ ! -x "$ASSERT_SCRIPT" ]]; then
  echo "workspace RLS assert script not found or not executable: $ASSERT_SCRIPT" >&2
  exit 1
fi

bash "$SEED_SCRIPT"

PROBE_WORKSPACE_ID="${PROBE_WORKSPACE_ID:-20000000-0000-0000-0000-000000000010}" \
OWNER_USER_ID="${OWNER_USER_ID:-10000000-0000-0000-0000-000000000001}" \
MEMBER_USER_ID="${MEMBER_USER_ID:-10000000-0000-0000-0000-000000000002}" \
OUTSIDER_USER_ID="${OUTSIDER_USER_ID:-10000000-0000-0000-0000-000000000003}" \
OUTPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}" \
bash "$PROBE_MATRIX_SCRIPT"

INPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}" bash "$ASSERT_SCRIPT"
