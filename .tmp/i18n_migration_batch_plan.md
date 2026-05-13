# i18n Full Migration Batch Plan

## Execution Strategy: Module-by-Module with Incremental Commits

### Module Priority Order (by user visibility and impact)

1. **Phase 1: Core User Experience** (Highest Priority)
   - auth (4 files) - Login/signup flows
   - home_page.dart, main.dart, navigation (3 files) - App entry points
   - overview (3 files) - Dashboard
   - platform_status, status_page.dart (2 files) - System status

2. **Phase 2: Primary Workflows** (High Priority)
   - short_video_space (43 files) - Video creation workflow
   - script_editor (19 files) - Script editing
   - storyboard_editor (18 files) - Storyboard creation
   - projects (17 files) - Project management

3. **Phase 3: Project Editor** (High Priority)
   - project_editor (108 files) - Largest module, needs systematic approach

4. **Phase 4: Agent & Workspaces** (Medium Priority)
   - agent_workspaces (48 files) - Agent interaction
   - system_probes (11 files) - System diagnostics

5. **Phase 5: Supporting Features** (Medium Priority)
   - task_center (7 files) - Task management
   - jobs (4 files) - Job monitoring
   - quality_reviews (12 files) - Quality control
   - global_search (6 files) - Search functionality

6. **Phase 6: Settings & Admin** (Lower Priority)
   - account (5 files) - Account settings
   - team_workspaces (3 files) - Team management
   - notifications (6 files) - Notification center
   - api_keys (2 files) - API key management
   - admin_console (2 files) - Admin features

7. **Phase 7: Specialized Features** (Lower Priority)
   - skills_harness (4 files) - Skills management
   - content_compliance (2 files) - Compliance tools
   - benchmark (2 files) - Performance testing

8. **Phase 8: Infrastructure** (Lowest Priority)
   - rust_api (115 files) - API client code (mostly generated, may have error messages)
   - shell (13 files) - Shell integration
   - utils (2 files) - Utility functions
   - config.dart, locale, local_prefs (3 files) - Configuration

## Execution Rules

1. **Per-Module Process:**
   - Extract all Chinese strings from module files
   - Generate ARB keys following naming convention: `{moduleName}{Feature}{Action}`
   - Update both app_en.arb and app_zh.arb
   - Migrate Dart files to use AppLocalizations
   - Run `flutter analyze` on the module
   - Commit progress with message: "i18n: Migrate {module_name} module"

2. **Batch Size:**
   - Small modules (<10 files): Complete in one batch
   - Medium modules (10-50 files): Split into 2-3 batches
   - Large modules (>50 files): Split into 5-10 batches

3. **Quality Checks:**
   - After each module: `flutter analyze frontend/lib/{module}`
   - After each phase: `yarn refactor:quick`
   - After all phases: `yarn refactor:check`

4. **Progress Tracking:**
   - Update this file after each module completion
   - Mark completed modules with ✅
   - Track estimated vs actual time

## Progress Tracking

### Phase 1: Core User Experience (0/12 files)
- [ ] auth (4 files)
- [ ] home_page.dart, main.dart, navigation (3 files)
- [ ] overview (3 files)
- [ ] platform_status, status_page.dart (2 files)

### Phase 2: Primary Workflows (0/97 files)
- [ ] short_video_space (43 files)
- [ ] script_editor (19 files)
- [ ] storyboard_editor (18 files)
- [ ] projects (17 files)

### Phase 3: Project Editor (0/108 files)
- [ ] project_editor - Batch 1: assets/* (30 files)
- [ ] project_editor - Batch 2: scripts/* (25 files)
- [ ] project_editor - Batch 3: novels/* (20 files)
- [ ] project_editor - Batch 4: http_probes/* (15 files)
- [ ] project_editor - Batch 5: remaining (18 files)

### Phase 4: Agent & Workspaces (0/59 files)
- [ ] agent_workspaces (48 files)
- [ ] system_probes (11 files)

### Phase 5: Supporting Features (0/29 files)
- [ ] task_center (7 files)
- [ ] jobs (4 files)
- [ ] quality_reviews (12 files)
- [ ] global_search (6 files)

### Phase 6: Settings & Admin (0/18 files)
- [ ] account (5 files)
- [ ] team_workspaces (3 files)
- [ ] notifications (6 files)
- [ ] api_keys (2 files)
- [ ] admin_console (2 files)

### Phase 7: Specialized Features (0/8 files)
- [ ] skills_harness (4 files)
- [ ] content_compliance (2 files)
- [ ] benchmark (2 files)

### Phase 8: Infrastructure (0/133 files)
- [ ] rust_api (115 files) - May skip if mostly generated
- [ ] shell (13 files)
- [ ] utils (2 files)
- [ ] config/locale/prefs (3 files)

## Total: 0/469 files completed

## Time Estimates
- Phase 1: 2-3 hours
- Phase 2: 8-12 hours
- Phase 3: 10-15 hours
- Phase 4: 6-8 hours
- Phase 5: 4-6 hours
- Phase 6: 3-4 hours
- Phase 7: 2-3 hours
- Phase 8: 8-12 hours (or skip rust_api if generated)

**Total Estimated Time: 43-63 hours**
