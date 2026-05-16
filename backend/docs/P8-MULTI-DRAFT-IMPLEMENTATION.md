# P8: 发布面板支持多草稿主流程 Implementation Plan

## Current State Analysis

### Already Implemented ✅
1. **Draft Selector**: Dropdown UI exists in `frontend/lib/short_video_space/view.dart`
   - Shows when `publishDraftOptions.length > 1`
   - Allows selecting active draft via `onSelectPublishDraft`
   
2. **Multiple Drafts Data Model**: Backend supports multiple drafts per project
   - `app_publish_draft` table with `project_id` foreign key
   - API returns list of drafts: `GET /api/v1/projects/{id}/publish/drafts`

3. **Single Draft Operations**: 
   - `onBootstrapPublishDraft` - create new draft
   - `onEnqueuePublishJob` - publish single draft
   - `onScheduleFirstDraft` - schedule single draft

### Missing for P8 ✅

#### 1. Backend: Batch Operations API

**Required Endpoints**:

```rust
// Batch schedule multiple drafts
POST /api/v1/projects/{project_id}/publish/drafts/batch-schedule
{
  "draft_ids": ["uuid1", "uuid2", ...],
  "scheduled_at": "2024-05-10T10:00:00Z"  // or per-draft times
}

// Batch publish (enqueue jobs for multiple drafts)
POST /api/v1/projects/{project_id}/publish/drafts/batch-publish
{
  "draft_ids": ["uuid1", "uuid2", ...],
  "immediate": true  // or use scheduled_at from drafts
}

// Batch archive drafts
POST /api/v1/projects/{project_id}/publish/drafts/batch-archive
{
  "draft_ids": ["uuid1", "uuid2", ...]
}

// Batch blocking summary (validation check before batch operation)
POST /api/v1/projects/{project_id}/publish/drafts/batch-validate
{
  "draft_ids": ["uuid1", "uuid2", ...]
}
Response: {
  "ready_count": 5,
  "blocked_count": 2,
  "blocked_drafts": [
    {
      "draft_id": "uuid",
      "title": "...",
      "blocking_reasons": [
        {"code": "missing_video", "message": "..."},
        {"code": "missing_cover", "message": "..."}
      ]
    }
  ]
}
```

**Implementation Files**:
- `backend/src/publish/handlers.rs` - add batch operation handlers
- `backend/src/publish/types.rs` - add request/response types
- `backend/src/publish/store.rs` - add batch query functions
- `backend/src/publish/openapi.rs` - register new endpoints

#### 2. Frontend: Batch Selection UI

**Required Components**:

```dart
// Multi-select draft list with checkboxes
class PublishDraftMultiSelector extends StatefulWidget {
  final List<PublishDraftRow> drafts;
  final Set<String> selectedDraftIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  
  // Shows:
  // - Checkbox for each draft
  // - Draft title, status, platform count
  // - "Select All" / "Clear All" buttons
  // - Selected count indicator
}

// Batch operation toolbar
class PublishBatchOperationToolbar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onBatchSchedule;
  final VoidCallback? onBatchPublish;
  final VoidCallback? onBatchArchive;
  final bool busy;
  
  // Shows:
  // - "Schedule {count} drafts"
  // - "Publish {count} drafts"
  // - "Archive {count} drafts"
  // - Disabled when selectedCount == 0
}
```

**Integration Points**:
- `frontend/lib/short_video_space/view.dart` - add multi-select mode toggle
- `frontend/lib/short_video_space/support.dart` - add batch operation callbacks
- `frontend/lib/short_video_space/state.dart` - track selected draft IDs

#### 3. Frontend: Batch Blocking Summary

**Required Components**:

```dart
class PublishBatchBlockingSummary extends StatelessWidget {
  final PublishBatchValidationResponse validation;
  
  // Shows:
  // - "X drafts ready, Y drafts blocked"
  // - Expandable list of blocked drafts with reasons
  // - Link to fix each blocking issue
  // - "Proceed with ready drafts only" option
}
```

**Flow**:
1. User selects multiple drafts
2. User clicks "Publish" or "Schedule"
3. Frontend calls batch-validate API
4. If blocked_count > 0, show blocking summary dialog
5. User can:
   - Cancel and fix issues
   - Proceed with only ready drafts
   - Force publish (if allowed by policy)

#### 4. Frontend: Draft Comparison View

**Required Components**:

```dart
class PublishDraftComparisonView extends StatelessWidget {
  final List<PublishDraftRow> drafts;
  
  // Shows side-by-side comparison:
  // - Title
  // - Description
  // - Tags
  // - Platform targets
  // - Scheduled time
  // - Status
  // - Video/cover assets
  
  // Allows:
  // - Select 2-4 drafts to compare
  // - Highlight differences
  // - Copy settings from one draft to another
}
```

**Integration**:
- Add "Compare" button when 2+ drafts selected
- Open in modal or side panel
- Useful for reviewing platform-specific variations

#### 5. State Management Updates

**Required State**:

```dart
class ShortVideoSpaceState {
  // ... existing fields ...
  
  // P8 additions:
  Set<String> selectedPublishDraftIds = {};
  bool publishMultiSelectMode = false;
  PublishBatchValidationResponse? batchValidation;
  bool batchOperationBusy = false;
}
```

**Required Actions**:

```dart
// Toggle multi-select mode
void togglePublishMultiSelectMode();

// Select/deselect draft
void togglePublishDraftSelection(String draftId);

// Select all / clear all
void selectAllPublishDrafts();
void clearPublishDraftSelection();

// Batch operations
Future<void> batchSchedulePublishDrafts(Set<String> draftIds, DateTime scheduledAt);
Future<void> batchPublishDrafts(Set<String> draftIds);
Future<void> batchArchivePublishDrafts(Set<String> draftIds);

// Validation
Future<void> validateBatchPublishDrafts(Set<String> draftIds);
```

## Implementation Steps

### Phase 1: Backend Batch APIs (2-3 days)

1. **Add batch validation endpoint**
   - Query draft readiness for multiple drafts
   - Return structured blocking reasons
   - Test with 1, 5, 10 drafts

2. **Add batch schedule endpoint**
   - Update `scheduled_at` for multiple drafts
   - Support same time or per-draft times
   - Validate all drafts exist and belong to project

3. **Add batch publish endpoint**
   - Create publish jobs for multiple drafts
   - Respect automation_mode per platform
   - Handle partial failures gracefully

4. **Add batch archive endpoint**
   - Update `draft_status` to 'archived' for multiple drafts
   - Prevent archiving drafts with active jobs

5. **Update OpenAPI spec**
   - Export new endpoints
   - Generate Dart client code

### Phase 2: Frontend Multi-Select UI (2-3 days)

1. **Add multi-select mode toggle**
   - Button in publish panel header
   - Shows checkbox column when enabled

2. **Implement draft multi-selector**
   - Checkbox for each draft
   - Select all / clear all
   - Show selected count

3. **Add batch operation toolbar**
   - Schedule, Publish, Archive buttons
   - Enabled only when drafts selected
   - Show confirmation dialogs

4. **Integrate with state management**
   - Track selected draft IDs
   - Handle selection changes
   - Clear selection after operation

### Phase 3: Batch Validation & Blocking Summary (1-2 days)

1. **Call batch-validate before operations**
   - On batch publish click
   - On batch schedule click

2. **Show blocking summary dialog**
   - List blocked drafts with reasons
   - Offer "proceed with ready only" option
   - Link to fix issues

3. **Handle partial success**
   - Show which drafts succeeded/failed
   - Allow retry for failed drafts

### Phase 4: Draft Comparison View (2-3 days)

1. **Add comparison button**
   - Enabled when 2-4 drafts selected
   - Opens comparison modal

2. **Implement comparison table**
   - Side-by-side columns
   - Highlight differences
   - Responsive layout

3. **Add copy settings action**
   - Copy title/description/tags from one draft to another
   - Confirm before overwriting

### Phase 5: Testing & Polish (1-2 days)

1. **Backend tests**
   - Batch operation unit tests
   - Validation logic tests
   - Error handling tests

2. **Frontend tests**
   - Multi-select widget tests
   - Batch operation flow tests
   - Comparison view tests

3. **Integration tests**
   - End-to-end batch publish flow
   - Blocking summary flow
   - Draft comparison flow

## Acceptance Criteria

- [ ] User can select multiple drafts via checkboxes
- [ ] User can schedule multiple drafts to same or different times
- [ ] User can publish multiple drafts in one action
- [ ] User can archive multiple drafts in one action
- [ ] System validates all drafts before batch operation
- [ ] System shows blocking summary if any drafts are not ready
- [ ] User can proceed with only ready drafts
- [ ] User can compare 2-4 drafts side-by-side
- [ ] User can copy settings between drafts
- [ ] Batch operations handle partial failures gracefully
- [ ] UI shows progress during batch operations
- [ ] All batch operations are audited in publish_attempts

## Estimated Effort

- Backend: 3-4 days
- Frontend: 4-5 days
- Testing: 1-2 days
- **Total: 8-11 days** (1.5-2 weeks)

## Dependencies

- None (can be implemented independently)
- Recommended after P7 (quality gate) for better validation

## Notes

- Batch operations should be atomic where possible (all succeed or all fail)
- For publish jobs, partial success is acceptable (some platforms may fail)
- Consider adding batch operation history/audit log
- Consider adding "draft templates" for easier multi-draft creation
- Consider adding "duplicate draft" action for creating variations

