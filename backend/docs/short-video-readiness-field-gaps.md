# Short-video readiness: stored fields vs Jellyfish-style extended checks

This document is the **auditable map** for **C2** in `.kiro/specs/short-video-space/tasks.md`: which readiness signals are implemented end-to-end in Postgres/API vs documented here as **no column / heuristic only**.

## Implemented in `GET /api/v1/projects/{project_id}/short-video-readiness` (schema v1)

| Concern | Source | Notes |
|--------|--------|--------|
| Timeline slot (“基础信息” slot ordering) | `app_storyboard.sb_index` | `has_basic_slot` is true when `sb_index IS NOT NULL`. |
| Prompt / shot context | `app_storyboard.prompt`, `app_storyboard.video_desc` | `has_prompt_context` when either is non-empty after trim. |
| Reference / key frame | `app_storyboard.file_path` | `has_reference_visual` when non-empty after trim. |
| Candidate review | `app_storyboard.metadata->shortVideo->candidateStatus` | `candidate_cleared` when value is **not** `'pending'`. Missing key ⇒ cleared (until **C4** lands). |
| In-flight generation | `app_generation_job` rows with `status IN ('queued','running')` and `payload.storyboard_numeric_id` | `no_blocking_job` when no such job targets the shot’s `numeric_id`. |

## Gaps / not represented as first-class columns (Jellyfish-style extras)

| Check (conceptual) | Status | Follow-up |
|-------------------|--------|-----------|
| Action beats / shot grammar | **No dedicated field** | Needs design (script graph vs shot metadata) before API. |
| Semantic defaults (camera, lighting intent) | **Partial** (prompt text only) | Could remain LLM-derived text until structured shot schema exists. |
| Provider / model availability | **Not in DB** | Runtime/config surface; not per-shot readiness v1. |
| Linked candidate assets from **`app_asset`** | **Not wired** | **C4**: `pending` / `linked` / `ignored` + migrations/API. |
| Multi-shot batch jobs listing many IDs in one payload | **Partial** | v1 only matches `payload.storyboard_numeric_id` (per-job enqueue pattern used today). |

## Related code

- Handler: `backend/src/projects/routes/handlers/detail/short_video_readiness.rs`
- Types: `backend/src/projects/routes/types.rs` (`ProjectShortVideoReadinessResponse`)
- A3 / MP-W5 生产概览（就绪分镜数、生成中任务、坏例数）: `GET /api/v1/projects/{id}/production-overview` — `handlers/detail/production_overview.rs`（就绪判定与本 readiness 端点一致）
