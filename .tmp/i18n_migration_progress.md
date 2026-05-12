# i18n Migration Progress Report

## Task: Complete i18n Migration for All Remaining Hardcoded Strings

### Status: IN PROGRESS (Phase 1 Complete; short_video_space l10n plumbing + tests green)

## Latest automated batch (session)

- **Short video publish API**: `buildShortVideoAssemblyPanelUi`, `buildShortVideoExportCheckPanelUi`, `buildShortVideoCandidateCardUi`, and `buildShortVideoPublishPanelUi` now take `required AppLocalizations l10n` instead of `BuildContext`, so unit tests can use `AppLocalizationsZh()` without a widget tree.
- **Pure label helpers**: `shortVideoExportIssueLabel` / `shortVideoQualityStageLabel` take `AppLocalizations`; `*LabelZh(BuildContext)` delegates for widget callers.
- **Export history UI**: `ExportTaskStatus.displayName(l10n)` wired correctly in list tile.
- **Tests**: All short-video export + quality gate + space support + TTS tests updated; `VoiceoverSettingsDialog` tests use `MaterialApp` with `AppLocalizations.localizationsDelegates` and `locale: zh`; cancel test initializes `result` as null.
- **Analyzer**: `flutter analyze` on `frontend/` reports **no issues**.

## Completed Work

### 1. ARB Files Updated
- Added 50+ new i18n keys to both `app_en.arb` and `app_zh.arb`
- All keys follow the naming convention: `projectEditor*`
- Keys cover:
  - Asset History Workbench (corner_scape_view)
  - Asset Generation Workbench (dialog_view)
  - Scripts Batch Add Dialog
  - HTTP Probes (tasks, projects, scripts)
  - Asset Summary Functions

### 2. Files Migrated (Fully Complete)
1. **frontend/lib/project_editor/assets/corner_scape_view.dart**
   - ✅ All hardcoded Chinese strings replaced with l10n keys
   - ✅ Import added for AppLocalizations
   - ✅ All Text widgets updated

2. **frontend/lib/project_editor/assets/generation/dialog_view.dart**
   - ✅ Title and description migrated
   - ✅ Close button migrated

3. **frontend/lib/project_editor/assets/generation/support_summary.dart**
   - ✅ All summary functions refactored to accept AppLocalizations parameter
   - ✅ All hardcoded strings replaced with l10n function calls

4. **frontend/lib/project_editor/assets/generation/support.dart**
   - ✅ Import added for AppLocalizations

5. **frontend/lib/project_editor/assets/generation/dialog_view_status_panel.dart**
   - ✅ All summary function calls updated with l10n parameter
   - ✅ ActionChip labels migrated

### 3. ARB Keys Added

#### Asset History Workbench
- projectEditorAssetHistoryTitle
- projectEditorAssetHistoryTypeFilterLabel
- projectEditorAssetHistoryTypeFilterHelper
- projectEditorAssetHistoryLoading
- projectEditorAssetHistoryQueryButton
- projectEditorAssetHistoryClearFilter
- projectEditorAssetHistoryLoadingAssets
- projectEditorAssetHistoryEmptyState
- projectEditorAssetHistoryImageDropdownLabel
- projectEditorAssetHistoryNoImages
- projectEditorAssetHistoryCurrentImage (with placeholders)
- projectEditorAssetHistoryNoPreview
- projectEditorAssetHistoryClose

#### Asset Generation Workbench
- projectEditorAssetGenerationTitle
- projectEditorAssetGenerationDescription
- projectEditorAssetGenerationClose

#### Scripts Batch Add
- projectEditorScriptsBatchAddTitle
- projectEditorScriptsBatchAddCountLabel
- projectEditorScriptsBatchAddCountHelper
- projectEditorScriptsBatchAddNamePrefixLabel
- projectEditorScriptsBatchAddContentLabel
- projectEditorScriptsBatchAddCancel
- projectEditorScriptsBatchAddCreate
- projectEditorScriptsBatchAddCountError
- projectEditorScriptsBatchAddDefaultPrefix
- projectEditorScriptsBatchAddDefaultContent
- projectEditorScriptsBatchAddSuccess (with count placeholder)

#### HTTP Probes
- projectEditorProbeTasksZeroItems
- projectEditorProbeTasksZeroClasses
- projectEditorProbeTasksCompatGetTaskApi (with placeholders)
- projectEditorProbeProjectsZeroItems
- projectEditorProbeProjectsCompatList (with placeholder)
- projectEditorProbeScriptsZeroItems
- projectEditorProbeScriptsEmpty
- projectEditorProbeScriptsGetFirstScript
- projectEditorProbeScriptsLoading
- projectEditorProbeScriptsPostGetScriptApi (with placeholders)

#### Asset Summary Functions
- projectEditorAssetSummaryProductionEmpty
- projectEditorAssetSummaryProductionLine (with placeholders)
- projectEditorAssetSummaryTypeCount (with placeholders)
- projectEditorAssetSummaryPollingEmpty
- projectEditorAssetSummaryPollingLine (with placeholders)
- projectEditorAssetSummaryStateCount (with placeholders)
- projectEditorAssetSummaryImageCount (with placeholders)
- projectEditorAssetSummaryMaterialContext (with placeholders)
- projectEditorAssetSummaryBatchEmpty
- projectEditorAssetSummaryBatchLine (with placeholders)
- projectEditorAssetSummaryPromptEmpty
- projectEditorAssetSummaryPromptLine (with placeholders)
- projectEditorAssetSummarySelectionNone
- projectEditorAssetSummarySelectionSingle (with placeholders)
- projectEditorAssetSummarySelectionMultiple (with placeholders)

## Remaining Work

### Priority 1: project_editor (Remaining Files)

#### Files with Hardcoded Chinese Strings Still to Migrate:

1. **frontend/lib/project_editor/scripts/dialogs/batch_add.dart**
   - ✅ Already uses `AppLocalizations` for all dialog UI and snackbars

2. **frontend/lib/project_editor/http_probes/tasks_probe.dart**
   - ✅ Snackbar copy + button labels moved to ARB (`projectEditorProbeTasks*`)

3. **frontend/lib/project_editor/http_probes/project_probe.dart**
   - ✅ Snackbar copy + button labels moved to ARB (`projectEditorProbeProject*`)

4. **frontend/lib/project_editor/scripts/probe/actions.dart**
   - ✅ Script probe snackbars + buttons moved to ARB (`projectEditorProbeScripts*`)

5. **frontend/lib/project_editor/assets/generation/dialog_state.dart**
   - ✅ Already passes `l10n` into summary helpers

6. **frontend/lib/project_editor/assets/generation/dialog_state_snapshot_helpers.dart**
   - ✅ Already passes `l10n`

7. **frontend/lib/project_editor/assets/generation/dialog_state_mutation_helpers.dart**
   - ✅ Already passes `l10n`

8. **Other project_editor files**
   - Need to scan for additional hardcoded strings in:
     - novels/workbench_launcher.dart
     - novels/events/workbench_view.dart
     - Any other dialog or workbench files

### Priority 2: Other Areas

#### script_editor
- ❌ Not yet scanned for hardcoded strings
- Need comprehensive grep search

#### short_video_space
- ❌ Not yet scanned for hardcoded strings
- Need comprehensive grep search

#### content_compliance
- ❌ Not yet scanned for hardcoded strings
- Need comprehensive grep search

#### skills_harness
- ❌ Not yet scanned for hardcoded strings
- Need comprehensive grep search

### Task I2.10: Date/Time/Number Formatting
- ❌ Not yet implemented
- Need to use `intl` package for locale-aware formatting
- Apply to all date, time, and number displays

### Task I2.12: Refactor Check
- ❌ Not yet run
- Must run `yarn refactor:check` after all migrations complete

## Next Steps

1. **Complete remaining project_editor files** (Priority 1)
   - Update batch_add.dart with l10n
   - Update all probe files with l10n
   - Update dialog_state*.dart files to pass l10n to summary functions
   - Scan and migrate novels workbench files

2. **Scan and migrate other areas** (Priority 2)
   - script_editor
   - short_video_space
   - content_compliance
   - skills_harness

3. **Implement date/time/number formatting** (I2.10)

4. **Run refactor check** (I2.12)
   - `yarn refactor:check`
   - Fix any issues that arise

## Estimated Remaining Effort

- Priority 1 (project_editor remaining): ~40 string replacements + function updates
- Priority 2 (other areas): Unknown until scanned (estimated 100-200 strings)
- Date/time/number formatting: Medium complexity
- Total estimated time: 4-6 hours of focused work

## Notes

- All ARB keys use consistent naming: `projectEditor*`, `scriptEditor*`, etc.
- Placeholder syntax is working correctly for parameterized strings
- Chinese quotes in strings must use 「」 instead of "" to avoid JSON parsing errors
- Summary functions now require AppLocalizations parameter - all callers must be updated
