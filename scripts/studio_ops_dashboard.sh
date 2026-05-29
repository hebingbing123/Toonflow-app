#!/usr/bin/env bash
# Generate a static ops dashboard HTML snapshot (28 — local/staging).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${STUDIO_API_BASE_URL:-http://127.0.0.1:8666}"
OUT="${1:-$ROOT/docs/ops/studio-ops-dashboard.html}"
mkdir -p "$(dirname "$OUT")"

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

probe_json() {
  local path="$1"
  local url="${API_BASE}${path}"
  local code body
  code=$(curl -s -o /tmp/studio_ops_body.txt -w '%{http_code}' --connect-timeout 3 "$url" || echo "000")
  body=$(cat /tmp/studio_ops_body.txt 2>/dev/null || true)
  printf '{"path":%s,"status":%s,"ok":%s,"body":%s}\n' \
    "$(printf '%s' "$path" | json_escape)" \
    "$code" \
    "$( [[ "$code" =~ ^2 ]] && echo true || echo false )" \
    "$(printf '%s' "$body" | head -c 400 | json_escape)"
}

PROBES="[$(probe_json /health),$(probe_json /ready),$(probe_json /version)]"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat >"$OUT" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Studio Ops Dashboard</title>
  <style>
    :root { color-scheme: dark; font-family: ui-sans-serif, system-ui, sans-serif; }
    body { margin: 2rem; background: #0f1115; color: #e8eaed; }
    h1 { font-size: 1.25rem; margin-bottom: 0.25rem; }
    .meta { color: #9aa0a6; font-size: 0.875rem; margin-bottom: 1.5rem; }
    table { border-collapse: collapse; width: min(720px, 100%); }
    th, td { text-align: left; padding: 0.6rem 0.75rem; border-bottom: 1px solid #2a2f3a; }
    .ok { color: #6ee7a8; }
    .fail { color: #f87171; }
    pre { white-space: pre-wrap; word-break: break-word; font-size: 0.75rem; color: #c4c7ce; }
  </style>
</head>
<body>
  <h1>Studio Ops Dashboard</h1>
  <p class="meta">API base: ${API_BASE} · generated ${GENERATED_AT} UTC</p>
  <table>
    <thead><tr><th>Probe</th><th>HTTP</th><th>Body (trimmed)</th></tr></thead>
    <tbody id="rows"></tbody>
  </table>
  <script>
    const probes = ${PROBES};
    const tbody = document.getElementById('rows');
    for (const row of probes) {
      const tr = document.createElement('tr');
      tr.innerHTML = '<td>' + row.path + '</td>'
        + '<td class="' + (row.ok ? 'ok' : 'fail') + '">' + row.status + '</td>'
        + '<td><pre>' + row.body.replace(/</g, '&lt;') + '</pre></td>';
      tbody.appendChild(tr);
    }
  </script>
</body>
</html>
EOF

echo "Wrote $OUT"
