# Spec gap audit (Task 15)

Date: 2026-05-15. Method: map each requirements document to current repo surfaces (Rust `backend/`, Flutter `frontend/`, migrations, `.kiro` task checklists). Status legend: **Done** = implemented and wired; **Partial** = subset or ops-only; **Gap** = no clear owner in tree.

## drama-platform-completion (`requirements.md`, 需求 1–18)

| Req | Theme | Status | Notes |
|-----|--------|--------|-------|
| 1 | StylePackPicker / `PATCH …/style-config` | Done | Project editor + API |
| 2 | Memory tier UI + cost | Done | Memory workbench + `memory/cost-overview` |
| 3 | Skill versions UI + rollback | Done | Skills harness + `skill-versions` |
| 4 | Patch regeneration UI | Done | Production patch + storyboard flows |
| 5 | Quality review filters (stage/grade) | Done | `quality_reviews/` + API |
| 6 | Stage summary auto-write | Partial | Worker paths vary by flow; core tables exist |
| 7 | StyleBible auto-init | Done | Project/style flows |
| 8 | Skill change notifications | Partial | Version rows + logs; product “toast” depth not audited |
| 9 | Pre-generation quality gate | Done | `production/quality_gate` + Flutter hooks |
| 10 | Anti-AI / realism | Partial | rules + `anti_ai.rs`; continuous product tuning |
| 11 | Token optimization | Done | `sub_agent/memory.rs`, usage meta |
| 12 | Automated memory (Codex-like) | Partial | Tiers + policy; not all narrative paths expose UX |
| 13 | Attribution / patch escalation | Done | `patch/` + quality gate memory |
| 14 | Quality-driven optimization | Done | `bad-case-stats`, suggested_action, dashboard |
| 15 | Role memory + budget tiers | Done | Schema + memory policy |
| 16 | Prompt hygiene / observation governance | Partial | Video prompt memory + negative constraints; edge cases remain |
| 17 | Token ↔ quality analytics | Done | Quality dashboard + token efficiency rows |
| 18 | Task center (retry, quota, status) | Done | Jobs REST + Flutter task center |

## drama-quality-benchmark-ops (`requirements.md`, 需求 1–10)

| Req | Theme | Status | Notes |
|-----|--------|--------|-------|
| 1 | Benchmark case registry | Done | `prompting/benchmark/registry` |
| 2 | Experiment run / variants | Done | `experiments/` |
| 3 | Tiered replay / cost | Done | `sample_tier`, cost estimate paths |
| 4 | Judge rubric | Done | `judge/` |
| 5 | Review queue | Done | `review_queue/` + PG contract |
| 6 | Observation assets | Done | `observation_assets/` |
| 7 | Memory profiles + ROI | Done | `memory_profiles/` |
| 8 | Promotion gate | Done | `promotion_gate/` + contract test aligned to `/experiments/{id}/gate` |
| 9 | Trends / regression monitoring | Done | `GET /benchmark/trends` + Flutter |
| 10 | Spec boundary / extensions | Done | Scoped to benchmark modules; cross-spec in platform doc |

## ai-drama-quality-optimization (`requirements.md`)

| Status | Notes |
|--------|-------|
| Done (per `.kiro/specs/ai-drama-quality-optimization/tasks.md`) | All numbered implementation tasks marked complete; enforcement via Rust property tests + skills/prompts. Ongoing: prompt drift when skills change outside repo process. |

## Residual / out of scope for this pass

- **Task 4–5** in `platform-refactor-quality-boost/tasks.md` (large Dart file splits): still open; not part of Tasks 7–16 batch.
- **i18n / generated l10n drift**: may fail some `flutter test` locales until `flutter gen-l10n` / arb sync (deferred per user).

## Task 16 — `yarn refactor:agent --full` (2026-05-15)

- Targeted checks in this batch: `cargo test -p openflow-server --lib` filters (`anti_ai`, `attribution::tests`, `benchmark_property_tests`, `settings::agent_memory`), plus `flutter analyze` on touched Dart and `flutter test` on `quality_reviews_workbench_dialog_view_test` / `benchmark_workbench_support_test` — all green.
- Full-repo `yarn refactor:agent --full`: **one** `flutter test` failure under full parallel suite — `agent_workspaces_section_test.dart` (“Script pane plan writeback hint…”, `findsOneWidget`). The same case **passes in isolation** (`flutter test test/agent_workspaces_section_test.dart --name "plan writeback hint"`), consistent with **order-dependent / shared test state** rather than a deterministic regression from Tasks 7–16. Follow-up: hunt global singletons or run the shard with `--concurrency=1` if CI flakes continue.
