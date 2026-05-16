#!/usr/bin/env bash
set -euo pipefail

SUMMARY_JSON_FILE="${SUMMARY_JSON_FILE:-}"
ASSERTION_JSON_FILE="${ASSERTION_JSON_FILE:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"
ENVIRONMENT_LABEL="${ENVIRONMENT_LABEL:-staging}"
RELEASE_LABEL="${RELEASE_LABEL:-}"

if [[ -z "$SUMMARY_JSON_FILE" ]]; then
  echo "SUMMARY_JSON_FILE is required" >&2
  exit 1
fi

if [[ ! -f "$SUMMARY_JSON_FILE" ]]; then
  echo "summary json file not found: $SUMMARY_JSON_FILE" >&2
  exit 1
fi

if [[ -n "$ASSERTION_JSON_FILE" && ! -f "$ASSERTION_JSON_FILE" ]]; then
  echo "assertion json file not found: $ASSERTION_JSON_FILE" >&2
  exit 1
fi

json_get_top_level() {
  local file="$1"
  local key="$2"
  awk -F'"' -v target="$key" '
    $2 == target {
      value = $4
      if (value == "" && $0 ~ /: [0-9]+/) {
        split($0, parts, ":")
        value = parts[2]
        gsub(/^[[:space:]]+|,[[:space:]]*$/, "", value)
      }
      print value
      exit
    }
  ' "$file"
}

json_get_user() {
  local file="$1"
  local key="$2"
  awk -F'"' -v target="$key" '
    /"users": \{/ {in_users=1; next}
    in_users && $2 == target {print $4; exit}
    in_users && /\}/ {in_users=0}
  ' "$file"
}

workspace_id="$(json_get_top_level "$SUMMARY_JSON_FILE" "workspace_id")"
overall_verdict="$(json_get_top_level "$SUMMARY_JSON_FILE" "overall_verdict")"
owner_user_id="$(json_get_user "$SUMMARY_JSON_FILE" "owner")"
member_user_id="$(json_get_user "$SUMMARY_JSON_FILE" "member")"
outsider_user_id="$(json_get_user "$SUMMARY_JSON_FILE" "outsider")"

assertion_status=""
assertion_message=""
if [[ -n "$ASSERTION_JSON_FILE" ]]; then
  assertion_status="$(json_get_top_level "$ASSERTION_JSON_FILE" "status")"
  assertion_message="$(json_get_top_level "$ASSERTION_JSON_FILE" "message")"
fi

render_snippet() {
  cat <<EOF
RLS validation:
- environment: $ENVIRONMENT_LABEL
- workspace: $workspace_id
- release: ${RELEASE_LABEL:-pending}
- owner user: $owner_user_id
- member user: $member_user_id
- outsider user: $outsider_user_id
- overall verdict: $overall_verdict
- assertion status: ${assertion_status:-not_recorded}
- summary artifact: \`$SUMMARY_JSON_FILE\`
EOF

  if [[ -n "$ASSERTION_JSON_FILE" ]]; then
    printf '%s\n' "- assertion artifact: \`$ASSERTION_JSON_FILE\`"
  fi

  if [[ -n "$assertion_message" ]]; then
    printf '%s\n' "- assertion note: $assertion_message"
  fi

  cat <<'EOF'
- follow-up:
EOF
}

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  render_snippet > "$OUTPUT_FILE"
  echo "saved checklist snippet to $OUTPUT_FILE"
else
  render_snippet
fi
