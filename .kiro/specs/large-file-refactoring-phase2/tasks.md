# Implementation Plan: Large File Refactoring Phase 2

## Overview

This implementation plan systematically refactors 20 oversized files (15 Rust backend, 5 Flutter frontend) to comply with the ≤800-line standard. Each task follows the pattern: analyze file → execute split → run gate check → commit. The refactoring proceeds in 3 phases (critical frontend → critical backend → medium priority) with incremental commits after each successful file split.

## Tasks

### Phase 1: Critical Frontend Files

- [x] 1. Refactor frontend/lib/short_video_space/section.dart (3164 lines → 7 modules)
  - Analyze current structure and identify split boundaries
  - Create section_state.dart (≈300 lines) with all state fields and getters
  - Create section_project.dart (≈500 lines) with project management functions
  - Create section_production.dart (≈600 lines) with production workflow functions
  - Create section_publish.dart (≈700 lines) with publishing operations
  - Create section_publish_scheduling.dart (≈600 lines) with scheduling logic
  - Create section_publish_copy.dart (≈400 lines) with copy management functions
  - Update section.dart (≈400 lines) to re-export all modules and delegate to sub-widgets
  - Update dependent files' imports (view.dart, etc.)
  - Run gate check: `cd frontend && flutter pub get && flutter analyze && flutter test`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(frontend): split section.dart into 7 modules (3164→400 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.3, 8.1, 11.1, 13.1_

- [x] 2. Refactor frontend/lib/short_video_space/view.dart (2376 lines → 8 modules)
  - Analyze current structure and identify widget extraction boundaries
  - Create view_project_selector.dart (≈300 lines) with project dropdown and controls
  - Create view_production_panel.dart (≈400 lines) with production overview and stats
  - Create view_candidate_compare.dart (≈350 lines) with candidate comparison UI
  - Create view_publish_drafts.dart (≈400 lines) with draft list and management
  - Create view_publish_calendar.dart (≈300 lines) with calendar scheduling UI
  - Create view_publish_jobs.dart (≈300 lines) with job status and monitoring
  - Create view_publish_audit.dart (≈250 lines) with audit log display
  - Update view.dart (≈300 lines) to compose extracted widgets
  - Update dependent files' imports
  - Run gate check: `cd frontend && flutter pub get && flutter analyze && flutter test`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(frontend): split view.dart into 8 widget components (2376→300 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.3, 8.1, 11.1, 13.1_

- [x] 3. Refactor frontend/lib/short_video_space/support.dart (1243 lines → 5 modules)
  - Analyze current structure and identify API/model boundaries
  - Create support_models.dart (≈300 lines) with all data classes and enums
  - Create support_project_api.dart (≈250 lines) with project-related API calls
  - Create support_production_api.dart (≈300 lines) with production-related API calls
  - Create support_publish_api.dart (≈400 lines) with publish-related API calls
  - Update support.dart (≈100 lines) to re-export all modules
  - Update dependent files' imports (section.dart, view.dart)
  - Run gate check: `cd frontend && flutter pub get && flutter analyze && flutter test`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(frontend): split support.dart into 5 modules (1243→100 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.3, 8.1, 11.5, 13.1_

- [x] 4. Checkpoint - Phase 1 complete
  - Ensure all Phase 1 tests pass, ask the user if questions arise.

### Phase 2: Critical Backend Files

- [x] 5. Refactor backend/src/publish/store.rs (1345 lines → 6 modules)
  - Analyze current structure and identify entity-based split boundaries
  - Create `publish/store/` directory; move store.rs → `store/mod.rs` (≈100 lines, re-exports only)
  - Create `store/profile.rs` (≈200 lines) with profile operations (list_profiles, insert_profile, fetch_profile, patch_profile_row, delete_profile)
  - Create `store/draft.rs` (≈400 lines) with draft operations (list_drafts, insert_draft, fetch_draft, patch_draft_row, delete_draft, merge_draft_platform_copy, batch_set_draft_scheduled_at, batch_archive_drafts, fetch_drafts_by_ids)
  - Create `store/target.rs` (≈200 lines) with target operations (list_targets, replace_targets_tx, replace_targets, draft_has_semi_auto_target)
  - Create `store/job.rs` (≈400 lines) with job operations (insert_publish_job, list_jobs, list_attempt_audit, list_low_performance_alerts, fetch_job_owned, cancel_job_if_non_terminal, retry_job_if_allowed, confirm_semi_auto_job, claim_next_publish_job, fail_publish_job_claim, await_publish_job_confirmation, clear_attempts_for_job, insert_publish_attempts, finalize_job_with_attempts)
  - Create `store/metric.rs` (≈200 lines) with metric operations (claim_next_metric_sync_cursor, complete_metric_sync_cursor, fail_metric_sync_cursor, insert_publish_performance_snapshot)
  - Update all `use crate::publish::store::*` references in handlers.rs and other dependents
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib publish`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split publish/store.rs into store/ submodules (1345→100 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.3, 13.1_

- [~] 6. Refactor backend/src/publish/handlers.rs (1100 lines → 6 modules)
  - Analyze current structure and identify resource-based handler grouping
  - Create `publish/handlers/` directory; move handlers.rs → `handlers/mod.rs` (≈150 lines, router + re-exports)
  - Create `handlers/profile.rs` (≈250 lines) with profile CRUD handlers (list_publish_profiles, create_publish_profile, get_publish_profile, patch_publish_profile, delete_publish_profile)
  - Create `handlers/draft.rs` (≈350 lines) with draft CRUD handlers (list_publish_drafts, create_publish_draft, get_publish_draft, patch_publish_draft, delete_publish_draft_handler) and helpers (resolve_scheduled_draft_window, validate_draft_status)
  - Create `handlers/target.rs` (≈150 lines) with target handlers (list_publish_targets, upsert_publish_targets)
  - Create `handlers/job.rs` (≈400 lines) with job handlers (publish_prepare_check, create_publish_job, list_publish_jobs, cancel_publish_job, retry_publish_job, confirm_publish_job_semi_auto)
  - Create `handlers/audit.rs` (≈200 lines) with audit/performance handlers (list_publish_audit, list_publish_performance_alerts, process_performance_alerts, publish_overview, publish_platform_matrix, platform_matrix_body)
  - Update all `use crate::publish::handlers::*` references
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib publish`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split publish/handlers.rs into handlers/ submodules (1100→150 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.4, 13.1_

- [~] 7. Refactor backend/src/publish/adapters.rs (1057 lines → 6 modules)
  - Analyze current structure: adapters.rs contains run_target_adapter (sandbox/live/manual_bridge routing), fetch_platform_metrics, and shared helpers
  - Create `publish/adapters/` directory; move adapters.rs → `adapters/mod.rs` (≈100 lines, PlatformAdapter trait, run_target_adapter entry point, re-exports)
  - Create `adapters/sandbox.rs` (≈100 lines) with run_sandbox_adapter and sandbox delivery logic
  - Create `adapters/live.rs` (≈200 lines) with run_live_adapter, attempt_live_delivery, check_platform_credentials, success_with_receipt, unsupported_platform, evidence_for_mode
  - Create `adapters/manual_bridge.rs` (≈100 lines) with run_manual_bridge_adapter logic
  - Create `adapters/routing.rs` (≈100 lines) with DeliveryRoute, route_for_mode
  - Create `adapters/metrics.rs` (≈200 lines) with fetch_platform_metrics, fetch_platform_metrics_mock, fetch_platform_metrics_live, fetch_platform_metrics_manual_bridge
  - Update all `use crate::publish::adapters::*` references
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib publish`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split publish/adapters.rs into adapters/ submodules (1057→100 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.6, 13.1_

- [~] 8. Refactor backend/src/production/workbench/meta/generate/memory/observation_style.rs (1035 lines → 4 modules)
  - Analyze current structure: functions group into filter/selection, scoring/ranking, compaction, and matching
  - Create `memory/observation_style/` directory; move observation_style.rs → `observation_style/mod.rs` (≈100 lines, pub re-exports of all pub(in ...) items)
  - Create `observation_style/filter.rs` (≈350 lines) with resolve_observation_filter_style_note, compact_observation_filter_candidate, select_contextual_observation_summary_style_note, select_pressure_prioritized_observation_filter_style_note
  - Create `observation_style/rank.rs` (≈350 lines) with rank_observation_summary_style_note_fragments, observation_summary_style_note_score, observation_summary_style_fragment_score, observation_summary_style_note_min_evidence
  - Create `observation_style/compact.rs` (≈300 lines) with normalize_observation_contextual_fragment, strip_observation_voice_mood_tail, restore_observation_delivery_signal_if_compaction_overtrims, supplement_observation_summary_voice_fragment, observation_summary_subject_locked_fallback_fragments
  - Create `observation_style/match.rs` (≈200 lines) with style_note_matches_shared_keyword_family, style_note_matches_mood_keyword, video_prompt_observation_conflicts_with_style, video_prompt_observation_is_irrelevant_to_storyboard, observation_style_note_context_evidence
  - Update dependent files' imports within `meta::generate`
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib production::workbench::meta::generate`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split memory/observation_style.rs into observation_style/ submodules (1035→100 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7, 13.1_

- [~] 9. Checkpoint - Phase 2 complete
  - Ensure all Phase 2 tests pass, ask the user if questions arise.

### Phase 3: Medium Priority Files

- [~] 10. Refactor backend/src/production/workbench/meta/generate/memory/style_selection.rs (940 lines → 4 modules)
  - Analyze current structure: functions group into loading/building, selection, compaction, and guardrail logic
  - Create `memory/style_selection/` directory; move style_selection.rs → `style_selection/mod.rs` (≈100 lines, re-exports)
  - Create `style_selection/load.rs` (≈250 lines) with load_video_prompt_memory_notes, build_video_prompt_memory_notes, build_video_prompt_memory_notes_with_pressure, rejected_video_memory_selection_bias
  - Create `style_selection/select.rs` (≈300 lines) with select_video_prompt_style_notes, select_scoped_contextual_summary_style_note, select_runtime_action_continuity_fallback, select_pressure_prioritized_style_note_candidate, PressureStyleCandidateSource
  - Create `style_selection/compact.rs` (≈350 lines) with compact_generation_brief_style_note_for_storyboard, compact_guardrail_sensitive_style_notes, compact_guardrail_sensitive_style_note, summary_style_note_only_repeats_storyboard_fields, supplement_compacted_voice_note, preserve_runtime_exact_camera_fragment, restore_runtime_exact_style_note_fragments, preserve_delivery_pair_if_compaction_overtrims
  - Update dependent files' imports within `meta::generate`
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib production::workbench::meta::generate`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split memory/style_selection.rs into style_selection/ submodules (940→100 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 11. Refactor backend/src/harness/sub_agent/scope.rs (903 lines → 3 modules)
  - Note: sub_agent/ directory already exists with mod.rs, memory.rs, spec.rs, tests.rs — scope.rs is already a submodule
  - Analyze current structure of scope.rs and identify split boundaries by scope type
  - Create `sub_agent/scope/` directory; move scope.rs → `scope/mod.rs` (≈150 lines, ScopeSignature struct, public entry points, re-exports)
  - Create `scope/project.rs` (≈300 lines) with project scope construction logic
  - Create `scope/production.rs` (≈400 lines) with production/storyboard scope construction logic (script scope can stay in mod.rs if small enough)
  - Update `sub_agent/mod.rs` to keep `mod scope;` declaration unchanged (path resolution is automatic)
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib harness::sub_agent`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split sub_agent/scope.rs into scope/ submodules (903→150 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 12. Refactor backend/src/production/workbench/video/generate/negative_prompt_analysis.rs (854 lines → 3 modules)
  - Note: video/generate/ already has negative_prompt_core.rs, negative_prompt_builder.rs, negative_prompt_risk.rs — follow same naming pattern
  - Create `video/generate/negative_prompt_analysis/` directory; move negative_prompt_analysis.rs → `negative_prompt_analysis/mod.rs` (≈150 lines, public entry points, re-exports)
  - Create `negative_prompt_analysis/detection.rs` (≈350 lines) with detection and classification logic
  - Create `negative_prompt_analysis/suggestion.rs` (≈350 lines) with suggestion generation logic
  - Update `video/generate/mod.rs` to keep `mod negative_prompt_analysis;` unchanged
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib production::workbench::video::generate`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split negative_prompt_analysis.rs into negative_prompt_analysis/ submodules (854→150 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 13. Refactor backend/src/publish/nine_platform_acceptance_tests.rs (835 lines → keep as single file with internal test modules)
  - Note: This is a test file. Rust test files use `mod` blocks internally rather than separate files — split into internal modules
  - Analyze current structure and identify per-platform test groups
  - Refactor to use internal `mod douyin { ... }`, `mod kuaishou { ... }`, `mod xiaohongshu { ... }`, `mod bilibili { ... }`, `mod wechat_channels { ... }` blocks (≈150 lines each)
  - Keep shared test helpers at the top of the file (≈100 lines)
  - If total still exceeds 800 lines after internal modularization, extract to `publish/nine_platform_acceptance_tests/` directory with per-platform files following the pattern in `meta/generate/tests/`
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend -- publish::nine_platform_acceptance_tests`
  - Verify file is ≤800 lines (or all submodule files are ≤800 lines)
  - Commit: `refactor(backend): modularize nine_platform_acceptance_tests.rs by platform (835→≤800 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 14. Refactor backend/src/prompting/benchmark/memory_profiles/handlers.rs (834 lines → 3 modules)
  - Note: memory_profiles/ already has mod.rs, types.rs, tests.rs — handlers.rs is a submodule; follow same pattern as publish/handlers/
  - Create `memory_profiles/handlers/` directory; move handlers.rs → `handlers/mod.rs` (≈150 lines, router, re-exports)
  - Create `handlers/profile.rs` (≈350 lines) with profile CRUD handlers
  - Create `handlers/benchmark.rs` (≈350 lines) with benchmark operation and analysis handlers
  - Update `memory_profiles/mod.rs` to keep `mod handlers;` declaration unchanged
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib prompting::benchmark::memory_profiles`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split memory_profiles/handlers.rs into handlers/ submodules (834→150 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 15. Refactor backend/src/production/workbench/meta/generate/tests/select_tests.rs (857 lines → split following existing pattern)
  - Note: tests/ directory already uses the pattern `*_tests_part1.rs` / `*_tests_part2.rs` (e.g. memory_trim_part1.rs, observation_tests_part1.rs) — follow same convention
  - Analyze current structure and split into two files by test category
  - Create `tests/select_tests_part1.rs` (≈430 lines) with first half of tests (unit + basic integration)
  - Create `tests/select_tests_part2.rs` (≈430 lines) with second half of tests (property-based + edge cases)
  - Update `tests/mod.rs` to declare both: `mod select_tests_part1;` and `mod select_tests_part2;`; remove or keep `mod select_tests;` as a barrel if needed
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib production::workbench::meta::generate`
  - Verify all files are ≤800 lines
  - Commit: `refactor(backend): split tests/select_tests.rs into part1/part2 (857→≤800 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 16. Refactor backend/src/production/workbench/video_prompt_memory/style_rank.rs (816 lines → 3 modules)
  - Note: video_prompt_memory/ already has style_build.rs, style_compact.rs, style_context.rs, style_notes.rs, style_role.rs — follow same `style_*.rs` naming pattern
  - Create `video_prompt_memory/style_rank/` directory; move style_rank.rs → `style_rank/mod.rs` (≈150 lines, public entry points, re-exports)
  - Create `style_rank/score.rs` (≈350 lines) with scoring and comparison logic
  - Create `style_rank/aggregate.rs` (≈300 lines) with aggregation and ranking logic
  - Update `video_prompt_memory/mod.rs` to keep `mod style_rank;` declaration unchanged
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib production::workbench::video_prompt_memory`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split video_prompt_memory/style_rank.rs into style_rank/ submodules (816→150 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 17. Refactor backend/src/publish/performance_rework.rs (812 lines → 3 modules)
  - Note: publish/ already has performance_rework.rs alongside ab_testing.rs, copy_cache.rs etc. — create a subdir following the same pattern as store/ and handlers/
  - Create `publish/performance_rework/` directory; move performance_rework.rs → `performance_rework/mod.rs` (≈150 lines, public entry points, re-exports)
  - Create `performance_rework/metrics.rs` (≈350 lines) with metrics collection and aggregation logic
  - Create `performance_rework/analysis.rs` (≈350 lines) with analysis and optimization suggestion logic
  - Update `publish/mod.rs` to keep `mod performance_rework;` declaration unchanged
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib publish`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split publish/performance_rework.rs into performance_rework/ submodules (812→150 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 18. Refactor backend/src/production/workbench/meta/generate/builder/transformation.rs (802 lines → 3 modules)
  - Note: builder/ already has anchors.rs, continuity.rs, core.rs, fields.rs, memory.rs, trimming.rs, validation.rs, utils.rs — follow same single-noun naming
  - Create `builder/transformation/` directory; move transformation.rs → `transformation/mod.rs` (≈150 lines, public entry points, re-exports)
  - Create `transformation/text.rs` (≈350 lines) with text transformation logic
  - Create `transformation/structure.rs` (≈350 lines) with structure and style transformation logic
  - Update `builder/mod.rs` to keep `mod transformation;` declaration unchanged
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib production::workbench::meta::generate::builder`
  - Verify all modules are ≤800 lines
  - Commit: `refactor(backend): split builder/transformation.rs into transformation/ submodules (802→150 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 19. Refactor backend/src/production/workbench/video/generate/tests/merge_budget_tests.rs (809 lines → split following existing pattern)
  - Note: video/generate/tests/ follows the same `*_tests_part1.rs` / `*_tests_part2.rs` pattern
  - Analyze current structure and split into two files by test group
  - Create `tests/merge_budget_tests_part1.rs` (≈405 lines) with first half of merge budget tests
  - Create `tests/merge_budget_tests_part2.rs` (≈405 lines) with second half of merge budget tests
  - Update `tests/mod.rs` to declare both; remove or keep `mod merge_budget_tests;` as barrel
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib production::workbench::video::generate`
  - Verify all files are ≤800 lines
  - Commit: `refactor(backend): split tests/merge_budget_tests.rs into part1/part2 (809→≤800 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 20. Refactor backend/src/production/workbench/meta/generate/tests/memory_trim_part1.rs (804 lines → split following existing pattern)
  - Note: memory_trim_part1.rs already exists alongside memory_trim_part2.rs — this file itself has grown too large
  - Analyze current structure and extract the largest test groups
  - Create `tests/memory_trim_part1a.rs` (≈400 lines) with first subset of part1 tests
  - Rename existing memory_trim_part1.rs → `tests/memory_trim_part1b.rs` (≈400 lines) with remaining tests
  - Update `tests/mod.rs` to declare both `mod memory_trim_part1a;` and `mod memory_trim_part1b;`
  - Run gate check: `cd backend && cargo fmt --check && cargo clippy -- -D warnings && cargo test -p backend --lib production::workbench::meta::generate`
  - Verify all files are ≤800 lines
  - Commit: `refactor(backend): split tests/memory_trim_part1.rs into part1a/part1b (804→≤800 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.2, 8.1, 11.7_

- [~] 21. Refactor frontend/lib/rust_api/project/overview.dart (978 lines → 3 modules)
  - Note: rust_api/project/ already has overview.dart, publish.dart, manuals.dart, visual_manual.dart — follow same flat naming, split into sibling files
  - Create `rust_api/project/overview_models.dart` (≈400 lines) with all data classes and fromJson/toJson
  - Create `rust_api/project/overview_api.dart` (≈500 lines) with all API call functions
  - Update `overview.dart` (≈100 lines) to export both: `export 'overview_models.dart'; export 'overview_api.dart';`
  - Run gate check: `cd frontend && flutter pub get && flutter analyze && flutter test`
  - Verify all files are ≤800 lines
  - Commit: `refactor(frontend): split rust_api/project/overview.dart into overview_models + overview_api (978→100 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.3, 8.1, 11.7_

- [~] 22. Refactor frontend/lib/rust_api/project/publish.dart (969 lines → 3 modules)
  - Note: follow same pattern as Task 21 — sibling files with barrel export
  - Create `rust_api/project/publish_models.dart` (≈400 lines) with all data classes and fromJson/toJson
  - Create `rust_api/project/publish_api.dart` (≈500 lines) with all API call functions
  - Update `publish.dart` (≈100 lines) to export both: `export 'publish_models.dart'; export 'publish_api.dart';`
  - Run gate check: `cd frontend && flutter pub get && flutter analyze && flutter test`
  - Verify all files are ≤800 lines
  - Commit: `refactor(frontend): split rust_api/project/publish.dart into publish_models + publish_api (969→100 lines)`
  - _Requirements: 1.1, 1.2, 2.1, 3.1, 5.1, 5.2, 6.3, 8.1, 11.7_

- [~] 23. Checkpoint - Phase 3 complete
  - Ensure all Phase 3 tests pass, ask the user if questions arise.

### Final Verification

- [~] 24. Final gate check and verification
  - Run full refactor gate check: `bash scripts/refactor-check.sh` from repository root
  - Verify all 20 files are now ≤800 lines
  - Verify OpenAPI specification is still valid: `cd backend && cargo run --bin export-openapi`
  - Verify all backend tests pass: `cd backend && cargo test`
  - Verify all frontend tests pass: `cd frontend && flutter test`
  - Generate final refactoring report with: total files refactored (20), total lines reduced, commit hashes
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Each task follows the pattern: analyze → split → update imports → gate check → commit
- Gate checks are tailored to file type: backend files use cargo checks, frontend files use flutter checks
- All public APIs must be preserved through re-exports in the original file path
- Each commit is atomic and independently revertable
- Tasks are ordered by priority: critical frontend (Phase 1) → critical backend (Phase 2) → medium priority (Phase 3)
- Checkpoints ensure incremental validation at phase boundaries
- Final verification ensures the entire refactoring maintains system integrity
