# Short video optimization smoke runbook

Concise checklist after pulling short-video vertical changes (voice clone mock, timeline reorder, candidate video URLs, pre-assembly).

## 1. Database migrations

From repo root, with Supabase CLI linked to your project:

```bash
supabase db push
```

Recent migrations to verify (non-exhaustive):

| Migration | Purpose |
|-----------|---------|
| `20260616120000_app_project_character_voice.sql` | Character `voice_config` |
| `20260616130000_app_video_prompt_cache.sql` | Video prompt cache |
| `20260616140000` (if present) | Related short-video columns |
| `20260617140000_numeric_id_removal_window_policy.sql` | Numeric ID deprecation comments |
| `20260617150000_app_project_timeline.sql` | NLE timeline `app_project_timeline` |
| `20260617160000_app_project_timeline_revision.sql` | Timeline revision history (M4a) |

Confirm `app_project.metadata` can store `shortVideo.clonedVoices[]` (no extra migration required).

## 2. Backend env

```bash
# Voice clone (default mock — no vendor keys)
export TOONFLOW_VOICE_CLONE_PROVIDER=mock

# Optional real stub (returns 501/400 until wired)
# export TOONFLOW_VOICE_CLONE_PROVIDER=azure
# export AZURE_SPEECH_KEY=...
# export AZURE_SPEECH_REGION=...
```

Start API (`backend/`, port per your `.env`).

## 3. API smoke (curl)

Replace `TOKEN`, `PROJECT_UUID`.

```bash
# Readiness
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/v1/projects/$PROJECT_UUID/short-video-readiness" | jq .

# Timeline (Wave 7 / NLE M1–M3)
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/v1/projects/$PROJECT_UUID/short-video-timeline" | jq .

# Apply rough-cut template (M3) — short_drama_default | dialogue_punch
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"templateId":"short_drama_default"}' \
  "$BASE/api/v1/projects/$PROJECT_UUID/short-video-timeline/apply-template" | jq .

# Save timeline with subtitles/transitions/voiceover (schemaVersion 4 + effect preset)
curl -s -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"schemaVersion":4,"expectedRevision":0,"tracks":{"video":[{"storyboardNumericId":1,"sourceUrl":"https://example.com/a.mp4","inMs":0,"outMs":3000,"effectPresetId":"vivid"}],"subtitles":[{"startMs":0,"endMs":2000,"text":"smoke"}],"transitions":[],"voiceover":[]}}' \
  "$BASE/api/v1/projects/$PROJECT_UUID/short-video-timeline" | jq .

# List timeline revisions (M4a)
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/v1/projects/$PROJECT_UUID/short-video-timeline/revisions" | jq .

# Restore revision 1 (M4a)
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"revision":1}' \
  "$BASE/api/v1/projects/$PROJECT_UUID/short-video-timeline/restore" | jq .

# Timeline preview job (M1+ M2 crossfade/subtitles + M3 VO ducking + M4b vivid/cinematic filters)
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/v1/projects/$PROJECT_UUID/short-video-timeline/preview" | jq .

# Export check
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/v1/projects/$PROJECT_UUID/short-video-export-check" | jq .

# Mock voice clone
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"projectId":"'"$PROJECT_UUID"'","displayName":"Smoke","audioBase64":"'"$(echo -n test | base64)"'"}' \
  "$BASE/api/v1/tts/clone-voice" | jq .

# Production data (candidateVideoUrls on mediaSlots)
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"projectUuid":"'"$PROJECT_UUID"'","scriptId":1,"ids":[1]}' \
  "$BASE/api/v1/production/get-production-data" | jq '.data[0].mediaSlots.candidateVideoUrls'
```

## 4. Flutter manual paths (短视频 Space)

1. Select a **short drama** project.
2. **Readiness** panel — blocking reasons visible.
3. **Characters** — clone voice (mock sample) → save → preview TTS.
4. **Candidate compare** — list shows `candidateVideoUrls`; **选用** calls `selectVideo`.
5. **Timeline** panel — trim in/out, BGM; **字幕轨** / **转场** / **配音轨**; **撤销/重做** (unsaved); **历史版本** → restore; per-clip **效果预设** (vivid/cinematic/bw/speed); save + **生成预览**.
6. **Pre-assembly** — enqueue job; download manifest from task center when complete.
7. **Export check** — gaps listed before export.

## 5. Optional script

See [`scripts/smoke_short_video_space.sh`](../../scripts/smoke_short_video_space.sh) (requires `TOKEN`, `PROJECT_UUID`, `BASE`).

## 6. Nine-platform publish fixture

Reference payload only: [`scripts/fixtures/publish-nine-platform-sample.json`](../../scripts/fixtures/publish-nine-platform-sample.json).
