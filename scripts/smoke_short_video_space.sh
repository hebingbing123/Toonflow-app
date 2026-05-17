#!/usr/bin/env bash
# Optional HTTP smoke for short-video Space APIs. No live publish keys.
set -euo pipefail

BASE="${BASE:-http://127.0.0.1:8666}"
TOKEN="${TOKEN:?set TOKEN to a Supabase access JWT}"
PROJECT_UUID="${PROJECT_UUID:?set PROJECT_UUID}"

auth=(-H "Authorization: Bearer ${TOKEN}")

echo "== short-video-readiness =="
curl -sf "${auth[@]}" "${BASE}/api/v1/projects/${PROJECT_UUID}/short-video-readiness" | head -c 400
echo ""

echo "== short-video-timeline =="
curl -sf "${auth[@]}" "${BASE}/api/v1/projects/${PROJECT_UUID}/short-video-timeline" | head -c 400
echo ""

echo "== short-video-timeline preview enqueue =="
curl -sf -X POST "${auth[@]}" \
  "${BASE}/api/v1/projects/${PROJECT_UUID}/short-video-timeline/preview" | head -c 400
echo ""

echo "== short-video-export-check =="
curl -sf "${auth[@]}" "${BASE}/api/v1/projects/${PROJECT_UUID}/short-video-export-check" | head -c 400
echo ""

echo "== clone-voice (mock) =="
SAMPLE_B64=$(printf 'smoke-sample' | base64 | tr -d '\n')
curl -sf -X POST "${auth[@]}" -H "Content-Type: application/json" \
  -d "{\"projectId\":\"${PROJECT_UUID}\",\"displayName\":\"Smoke\",\"audioBase64\":\"${SAMPLE_B64}\"}" \
  "${BASE}/api/v1/tts/clone-voice" | head -c 400
echo ""

echo "OK (truncated JSON previews above)"
