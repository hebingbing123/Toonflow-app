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

classify_verdict() {
  local table="$1"
  local owner="$2"
  local member="$3"
  local outsider="$4"

  case "$table" in
    app_workspace|app_workspace_member)
      if [[ "$owner" =~ ^[0-9]+$ && "$member" =~ ^[0-9]+$ && "$outsider" =~ ^[0-9]+$ ]]; then
        if [[ "$owner" -ge 1 && "$member" -ge 1 && "$outsider" -eq 0 ]]; then
          echo "partial_match"
        else
          echo "review_needed"
        fi
      else
        echo "review_needed"
      fi
      ;;
    app_project|app_script|app_asset|app_novel|app_generation_job)
      if [[ "$owner" =~ ^[0-9]+$ && "$member" =~ ^[0-9]+$ && "$outsider" =~ ^[0-9]+$ ]]; then
        if [[ "$owner" -ge 1 && "$member" -eq 0 && "$outsider" -eq 0 ]]; then
          echo "expected_mismatch"
        elif [[ "$owner" -ge 1 && "$member" -ge 1 && "$outsider" -eq 0 ]]; then
          echo "match_or_rls_widened"
        elif [[ "$outsider" -ge 1 ]]; then
          echo "security_bug"
        else
          echo "review_needed"
        fi
      else
        echo "review_needed"
      fi
      ;;
    app_agent_memory|app_art_style)
      if [[ "$owner" == "0" && "$member" == "0" && "$outsider" == "0" ]]; then
        echo "match"
      else
        echo "review_needed"
      fi
      ;;
    *)
      echo "review_needed"
      ;;
  esac
}

emit_summary() {
  cat <<EOF
Date: $(date '+%Y-%m-%d %H:%M:%S %z')
Workspace: $workspace_id

Users:
- owner: $owner_user_id
- member: $member_user_id
- outsider: $outsider_user_id

Visible rows:

| Table | Owner | Member | Outsider | Verdict |
|-------|-------|--------|----------|---------|
EOF

  local table owner_count member_count outsider_count verdict
  for table in "${tables[@]}"; do
    owner_count="$(get_count "$OWNER_FILE" "$table")"
    member_count="$(get_count "$MEMBER_FILE" "$table")"
    outsider_count="$(get_count "$OUTSIDER_FILE" "$table")"
    verdict="$(classify_verdict "$table" "$owner_count" "$member_count" "$outsider_count")"
    printf '| `%s` | %s | %s | %s | `%s` |\n' \
      "$table" \
      "$owner_count" \
      "$member_count" \
      "$outsider_count" \
      "$verdict"
  done

  cat <<'EOF'

Verdict hints:

- `app_workspace` / `app_workspace_member` should usually stay at `partial_match`
- `app_project` / `app_script` / `app_asset` / `app_novel` / `app_generation_job` showing `owner > 0`, `member = 0`, `outsider = 0` is the current expected Rust-only mismatch shape
- `match_or_rls_widened` means member 直连也能看到项目域数据；这可能是预期收口，也可能代表 RLS 变更，需要结合本轮目标判读
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
