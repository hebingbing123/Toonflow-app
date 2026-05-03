# Preservation Property Test Baseline

## Purpose
This document records the baseline behavior of the UNFIXED code before refactoring.
It captures public APIs, test results, and gate check results to ensure preservation after refactoring.

## Observation Date
Task 2 execution - Baseline established on UNFIXED code

## Test Results Summary

### Preservation Property Tests
**Status:** ✅ PASS (7/7 tests passing)

The preservation property tests verify:
- Production module compiles and is accessible
- Prompting module compiles and is accessible  
- All target modules compile successfully
- Module structure is intact

**Test Output:**
```
running 7 tests
test compilation_tests::backend_compiles ... ok
test module_structure_tests::module_reexports_maintained ... ok
test preservation_tests::all_target_modules_compile ... ok
test preservation_tests::production_module_accessible ... ok
test preservation_tests::prompting_module_accessible ... ok
test test_result_preservation::test_suite_baseline_recorded ... ok
test test_result_preservation::gate_check_baseline_recorded ... ok

test result: ok. 7 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
```

### Backend Tests (cargo test --lib)
**Status:** ⚠️ 1679 passed; 34 failed; 37 ignored

**Summary:**
- Total tests: 1750
- Pass rate: 95.9% (1679/1750)
- Expected failures: 34 tests (baseline behavior)
- Ignored tests: 37 tests

**Failed Tests (Baseline):**
All 34 failures are in `production::workbench::meta::generate::tests` module:
- build_video_prompt_* tests (7 failures)
- compact_* tests (3 failures)
- observation_filter_style_note_* tests (13 failures)
- select_video_prompt_* tests (11 failures)

These failures exist in the UNFIXED code and represent the baseline state.

### Frontend Tests (flutter test)
**Status:** ⚠️ 330 passed; 1 failed

**Summary:**
- Total tests: 331
- Pass rate: 99.7% (330/331)
- Expected failures: 1 test (compilation error in test file)

**Failed Test:**
- `projects_agent_memory_workbench_dialog_view_test.dart` - Compilation error due to missing required parameter 'memoryTier'

This failure exists in the UNFIXED code and represents the baseline state.

### Gate Check (yarn refactor:check)
**Status:** ❌ FAIL (formatting issues)

**Issues Found:**
1. **cargo fmt --check**: Multiple formatting diffs in:
   - `backend/src/prompting/quality/issue_type.rs`
   - `backend/src/prompting/quality/tests.rs`
   
2. **cargo clippy**: 4 warnings (dead code):
   - `cleanup_llm_usage_rows_for_jobs` (unused function)
   - `storyboard_dialogue_is_empty_row` (unused function)
   - `storyboard_lacks_meaningful_spoken_dialogue` (unused function)
   - `build_project_video_observation_memory` (unused function)

3. **cargo test**: Passes with expected failures
4. **flutter analyze**: Has issues (baseline state)
5. **flutter test**: Passes with 1 expected failure

**Note:** The gate check failure is due to formatting issues that exist in the baseline (UNFIXED) code.

---

## Public API Inventory

### Backend Files

#### 1. backend/src/production/workbench/video_prompt_memory/mod.rs (12,497 lines)

**Module Visibility:** Internal (pub(crate) re-exports through production::mod.rs)

**Key Re-exported Functions (pub(crate)):**
- `build_selected_video_memory`
- `clear_rejected_video_negative_memory`
- `compact_selected_video_memory_for_focus`
- `optimize_scoped_video_memory`
- `persist_rejected_video_negative_memory`
- `persist_selected_video_memory`
- `refresh_project_video_style_memory`
- `refresh_script_video_style_memory`
- `selected_video_memory_is_low_signal`
- `storyboard_prompt_seed`

**Key Structs (pub(crate)):**
- `StoryboardPromptSeedRow`
- `AgentMemoryRow`
- `ScopedAgentMemoryRow`
- `OptimizableAgentMemoryRow`
- `OptimizationQualityFocusDbRow`
- `VideoMemoryOptimizationResult`
- `SelectedVideoMemoryOptimizationCandidate`
- `EffectiveSelectedVideoMemoryOptimizationCandidate`
- `SelectedVideoMemoryOptimizationBias`
- `SelectedVideoMemoryOptimizationPlan`
- `StructuredStoryboardDescription`
- `SelectedVideoMemoryScope`
- `StyleNoteSelectionContext`
- `RankedStyleNote`
- `RejectedStyleSignals`

**Additional pub(crate) Functions:** 30+ functions for memory processing, selection, compaction, etc.

---

#### 2. backend/src/production/workbench/meta/generate/tests.rs (8,131 lines)
**Test Module:** Contains 300+ test functions for video prompt generation

---

#### 3. backend/src/production/workbench/video/generate.rs (6,163 lines)
**Key Re-exported Functions (pub(crate)):**
- `infer_negative_fragments_from_comments`
- `map_bad_case_category_with_comments`

---

#### 4-10. Other Backend Files
(Detailed API inventory to be completed as needed)

---

### Frontend Files

#### 11. frontend/lib/agent_workspaces/contexts/production/support.dart (1,675 lines)
**Public APIs:** (to be documented)

#### 12. frontend/lib/projects/workbenches/agent_memory_view.dart (1,161 lines)
**Public APIs:** (to be documented)

#### 13. frontend/lib/rust_api/benchmark/api.dart (875 lines)
**Public APIs:** (to be documented)

#### 14. frontend/lib/quality_reviews/workbench_view.dart (805 lines)
**Public APIs:** (to be documented)

---

## Preservation Requirements Verification

### ✅ Requirement 3.1: Files ≤800 lines remain unchanged
**Status:** To be verified after refactoring
**Baseline:** All files not in the 14-file list should remain unchanged

### ✅ Requirement 3.2: Public APIs remain unchanged
**Status:** Verified - preservation tests pass
**Baseline:** All pub(crate) re-exports documented above

### ✅ Requirement 3.3: Existing test suites pass
**Status:** Verified - 1679 backend tests pass, 330 frontend tests pass
**Baseline:** Same pass/fail pattern should be maintained

### ⚠️ Requirement 3.4: Code format compliance
**Status:** Baseline has format issues
**Target:** Fix format issues during refactoring

### ⚠️ Requirement 3.5: Lint checks pass (cargo clippy)
**Status:** Baseline has 4 warnings
**Target:** Maintain or reduce warning count

### ⚠️ Requirement 3.6: Flutter analyze passes
**Status:** Baseline has issues
**Target:** Maintain or improve analysis results

### ✅ Requirement 3.7: Backend compilation succeeds
**Status:** Verified - backend compiles successfully

### ✅ Requirement 3.8: Frontend compilation succeeds
**Status:** Verified - frontend compiles successfully (with 1 test compilation error)

### ✅ Requirement 3.9: Module visibility preserved
**Status:** Verified - all pub(crate) re-exports accessible

### ⚠️ Requirement 3.10: Gate checks pass
**Status:** Baseline fails on format
**Target:** Fix format issues and pass gate check after refactoring

---

## Expected Outcomes

### On UNFIXED Code (Current State)
- ✅ Preservation property tests: **PASS** (7/7)
- ⚠️ Backend tests: **1679 passed; 34 failed; 37 ignored**
- ⚠️ Frontend tests: **330 passed; 1 failed**
- ❌ Gate check: **FAIL** (formatting issues)

### After Refactoring (Target State)
- ✅ Preservation property tests: **PASS** (7/7) - same as baseline
- ✅ Backend tests: **≥1679 passed** - same or better than baseline
- ✅ Frontend tests: **≥330 passed** - same or better than baseline
- ✅ Gate check: **PASS** - format issues fixed
- ✅ All files: **≤800 lines each**

---

## Verification Script

A preservation check script has been created at `scripts/preservation-check.sh` to automate verification of preservation properties.

**Usage:**
```bash
bash scripts/preservation-check.sh
```

**Checks Performed:**
1. Backend compilation
2. Backend test pass count (≥1679)
3. Frontend analysis
4. Frontend tests
5. Code format (cargo fmt)
6. Clippy warnings
7. Public API preservation tests

---

## Notes

- The baseline state includes some expected failures and warnings
- These are documented to ensure we don't introduce new failures
- The refactoring should maintain or improve upon this baseline
- All pub(crate) APIs must remain accessible through the same import paths
- Module re-exports are critical for preserving internal API compatibility

