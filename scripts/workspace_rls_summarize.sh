#!/usr/bin/env bash
set -euo pipefail

INPUT_DIR="${INPUT_DIR:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"

if [[ -z "$INPUT_DIR" ]]; then
  echo "INPUT_DIR is required" >&2
  exit 1
fi

OWNER_FILE="$INPUT_DIR/owner.txt"
MEMBER_FILE="$INPUT_DIR/member.txt"
OUTSIDER_FILE="$INPUT_DIR/outsider.txt"

for file in "$OWNER_FILE" "$MEMBER_FILE" "$OUTSIDER_FILE"; do
  if [[ ! -f "$file" ]]; then
    echo "missing probe output file: $file" >&2
    exit 1
  fi
done

workspace_id="$(awk -F'=' '/probe_workspace_id=/{gsub(/ /,"",$2); print $2; exit}' "$OWNER_FILE")"
owner_user_id="$(awk -F'=' '/probe_user_id=/{gsub(/ /,"",$2); print $2; exit}' "$OWNER_FILE")"
member_user_id="$(awk -F'=' '/probe_user_id=/{gsub(/ /,"",$2); print $2; exit}' "$MEMBER_FILE")"
outsider_user_id="$(awk -F'=' '/probe_user_id=/{gsub(/ /,"",$2); print $2; exit}' "$OUTSIDER_FILE")"

extract_counts() {
  local file="$1"
  awk -F'|' '
    /==> visible rows scoped to target workspace/ {capture=1; next}
    /ROLLBACK/ {capture=0}
    capture && $1 ~ /app_/ {
      table=$1
      value=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", table)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print table "=" value
    }
  ' "$file"
}

get_count() {
  local file="$1"
  local table="$2"
  extract_counts "$file" | awk -F'=' -v target="$table" '$1 == target { print $2; found=1; exit } END { if (!found) print "n/a" }'
}

tables=(
  app_workspace
  app_workspace_member
  app_project
  app_script
  app_asset
  app_novel
  app_generation_job
  app_agent_memory
  app_art_style
)

emit_summary() {
  cat <<EOF
Date: $(date '+%Y-%m-%d %H:%M:%S %z')
Workspace: $workspace_id

Users:
- owner: $owner_user_id
- member: $member_user_id
- outsider: $outsider_user_id

Visible rows:

| Table | Owner | Member | Outsider |
|-------|-------|--------|----------|
EOF

  local table
  for table in "${tables[@]}"; do
    printf '| `%s` | %s | %s | %s |\n' \
      "$table" \
      "$(get_count "$OWNER_FILE" "$table")" \
      "$(get_count "$MEMBER_FILE" "$table")" \
      "$(get_count "$OUTSIDER_FILE" "$table")"
  done

  cat <<'EOF'

Verdict hints:

- `app_workspace` / `app_workspace_member` should usually stay at `partial_match`
- `app_project` / `app_script` / `app_asset` / `app_novel` / `app_generation_job` showing `owner > 0`, `member = 0`, `outsider = 0` is the current expected Rust-only mismatch shape
- Any unexpected `member > 0` or `outsider > 0` on those project-scoped tables should be reviewed before calling the run a match
EOF
}

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  emit_summary > "$OUTPUT_FILE"
  echo "saved summary to $OUTPUT_FILE"
else
  emit_summary
fi
