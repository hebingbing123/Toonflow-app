#!/usr/bin/env bash
set -euo pipefail

SUMMARY_FILE="${SUMMARY_FILE:-}"
ALLOW_MATCH_OR_RLS_WIDENED="${ALLOW_MATCH_OR_RLS_WIDENED:-0}"
RESULT_JSON_FILE="${RESULT_JSON_FILE:-}"

if [[ -z "$SUMMARY_FILE" ]]; then
  echo "SUMMARY_FILE is required" >&2
  exit 1
fi

if [[ ! -f "$SUMMARY_FILE" ]]; then
  echo "summary file not found: $SUMMARY_FILE" >&2
  exit 1
fi

write_result_json() {
  local status="$1"
  local overall="$2"
  local message="$3"

  [[ -n "$RESULT_JSON_FILE" ]] || return 0

  mkdir -p "$(dirname "$RESULT_JSON_FILE")"
  cat > "$RESULT_JSON_FILE" <<EOF
{
  "status": "$status",
  "overall_verdict": "$overall",
  "allow_match_or_rls_widened": $ALLOW_MATCH_OR_RLS_WIDENED,
  "summary_file": "$SUMMARY_FILE",
  "message": "$message"
}
EOF
}

overall_verdict="$(awk -F': ' '/^Overall Verdict: /{print $2; exit}' "$SUMMARY_FILE")"
if [[ -n "$overall_verdict" ]]; then
  case "$overall_verdict" in
    pass)
      write_result_json "pass" "$overall_verdict" "workspace RLS summary assertions passed"
      echo "workspace RLS summary assertions passed for $SUMMARY_FILE"
      exit 0
      ;;
    warning)
      if [[ "$ALLOW_MATCH_OR_RLS_WIDENED" == "1" ]]; then
        write_result_json "pass" "$overall_verdict" "workspace RLS summary assertions passed (warning accepted)"
        echo "workspace RLS summary assertions passed for $SUMMARY_FILE (warning accepted)"
        exit 0
      fi
      write_result_json "fail" "$overall_verdict" "workspace RLS summary assertions failed: overall verdict is warning"
      echo "workspace RLS summary assertions failed: overall verdict is warning" >&2
      exit 1
      ;;
    fail)
      write_result_json "fail" "$overall_verdict" "workspace RLS summary assertions failed: overall verdict is fail"
      echo "workspace RLS summary assertions failed: overall verdict is fail" >&2
      exit 1
      ;;
  esac
fi

failures=0

while IFS='|' read -r _ table owner member outsider verdict _; do
  table="$(echo "$table" | xargs)"
  owner="$(echo "$owner" | xargs)"
  member="$(echo "$member" | xargs)"
  outsider="$(echo "$outsider" | xargs)"
  verdict="$(echo "$verdict" | tr -d '`' | xargs)"

  [[ "$table" == \`app_* ]] || continue

  case "$verdict" in
    partial_match|expected_mismatch|match)
      ;;
    match_or_rls_widened)
      if [[ "$ALLOW_MATCH_OR_RLS_WIDENED" != "1" ]]; then
        echo "assertion failed: $table is $verdict (owner=$owner member=$member outsider=$outsider)" >&2
        failures=$((failures + 1))
      fi
      ;;
    review_needed|security_bug|*)
      echo "assertion failed: $table is $verdict (owner=$owner member=$member outsider=$outsider)" >&2
      failures=$((failures + 1))
      ;;
  esac
done < "$SUMMARY_FILE"

if [[ "$failures" -ne 0 ]]; then
  write_result_json "fail" "fallback_parse" "workspace RLS summary assertions failed: $failures issue(s)"
  echo "workspace RLS summary assertions failed: $failures issue(s)" >&2
  exit 1
fi

write_result_json "pass" "fallback_parse" "workspace RLS summary assertions passed"
echo "workspace RLS summary assertions passed for $SUMMARY_FILE"
