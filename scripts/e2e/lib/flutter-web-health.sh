# Shared Flutter web bootstrap probes for demo-tour E2E shell scripts.
# Source from run-demo-tour-web-e2e.sh / run-demo-tour-web-full-e2e.sh

# HTTP 200 / bootstrap shell alone is insufficient — 5173 may serve index.html
# while main.dart.js is 404 (stale shelf process or wrong dev server).
flutter_bundle_ready() {
  local base="${1%/}"
  # Require compiled app bundle — bootstrap shell alone is not runnable.
  curl -sf -o /dev/null --max-time 5 "$base/main.dart.js" 2>/dev/null && return 0
  curl -sf -o /dev/null --max-time 5 "$base/main.dart.mjs" 2>/dev/null && return 0
  return 1
}

flutter_web_ready() {
  local url="${1:-${WEB_URL:-http://127.0.0.1:5173}}"
  local body
  body="$(curl -sfL --max-time 5 "$url" 2>/dev/null)" || return 1
  printf '%s' "$body" | grep -qiE \
    'flutter-view|flt-semantics|main\.dart\.js|dart_sdk\.js|flutter_bootstrap\.js' \
    || return 1
  flutter_bundle_ready "$url"
}

http_reachable() {
  local url="${1:-${WEB_URL:-http://127.0.0.1:5173}}"
  curl -sf -o /dev/null --max-time 5 "$url" 2>/dev/null
}

wait_for_flutter_web() {
  local url="${1:-$WEB_URL}"
  local max_attempts="${2:-120}"
  local root="${3:-}"
  local i
  for i in $(seq 1 "$max_attempts"); do
    if flutter_web_ready "$url"; then
      sleep 20
      if playwright_flutter_ready "$url" "$root"; then
        return 0
      fi
    fi
    sleep 2
  done
  return 1
}

# Curl probes can pass while headless browser still sees an empty shell (stale 5173).
playwright_flutter_ready() {
  local url="${1:-$WEB_URL}"
  local root="${2:-}"
  if [[ -z "$root" ]]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  fi
  WEB_URL="$url" node "$root/scripts/e2e/flutter-web-preflight.mjs" >/dev/null 2>&1
}

flutter_web_usable() {
  local url="${1:-$WEB_URL}"
  local root="${2:-}"
  flutter_web_ready "$url" && playwright_flutter_ready "$url" "$root"
}
