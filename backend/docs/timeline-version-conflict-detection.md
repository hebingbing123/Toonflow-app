# Timeline Version Conflict Detection

## Overview

The timeline reorder save operation now supports optimistic locking to prevent data loss when multiple users or sessions attempt to modify the timeline concurrently.

## How It Works

### Version Field

The `GET /api/v1/production/get-flow-data` endpoint now returns a `flowVersion` field in the response:

```json
{
  "flowVersion": "2025-01-15 10:30:45.123456+00",
  "script": "...",
  "storyboard": [...],
  ...
}
```

This version is a timestamp (ISO 8601 format) representing when the flow data was last updated.

### Saving with Version Check

When calling `POST /api/v1/production/save-flow-data`, you can optionally include the `flowVersion` field:

```json
{
  "projectId": 123,
  "episodesId": 456,
  "flowVersion": "2025-01-15 10:30:45.123456+00",
  "data": {
    "storyboard": [...],
    ...
  }
}
```

**Behavior:**

- **If `flowVersion` is provided:** The server checks if the current version matches. If it doesn't match (meaning someone else modified the timeline), the request fails with **409 Conflict**.
- **If `flowVersion` is omitted:** The save proceeds without version checking (backward compatibility).

### Handling Conflicts

When a **409 Conflict** response is received:

```json
{
  "code": "conflict",
  "message": "Timeline has been modified by another user or session. Expected version: 2025-01-15 10:30:45.123456+00, current version: 2025-01-15 10:35:12.789012+00. Please refresh and retry."
}
```

**Recommended client behavior:**

1. Show a user-friendly message: "The timeline has been modified by another user. Your changes cannot be saved."
2. Offer options:
   - **Refresh**: Reload the latest timeline data (discarding local changes)
   - **Review Changes**: Show a diff or allow the user to manually merge changes
3. After refreshing, the user can retry their operation with the new version.

## Implementation Guide for Frontend

### Step 1: Store the Version

When loading flow data, store the `flowVersion`:

```typescript
const response = await fetch('/api/v1/production/get-flow-data', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ projectId, episodesId })
});

const flowData = await response.json();
const currentVersion = flowData.flowVersion; // Store this
```

### Step 2: Include Version When Saving

When saving changes, include the stored version:

```typescript
const saveResponse = await fetch('/api/v1/production/save-flow-data', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    projectId,
    episodesId,
    flowVersion: currentVersion, // Include the version
    data: {
      storyboard: reorderedStoryboard,
      // ... other fields
    }
  })
});

if (saveResponse.status === 409) {
  // Handle conflict
  const error = await saveResponse.json();
  showConflictDialog(error.message);
} else if (saveResponse.ok) {
  // Success - update stored version
  const newFlowData = await loadFlowData();
  currentVersion = newFlowData.flowVersion;
}
```

### Step 3: Handle Conflicts Gracefully

```typescript
function showConflictDialog(message: string) {
  // Show modal or notification
  const userChoice = await showDialog({
    title: 'Timeline Modified',
    message: 'The timeline has been modified by another user. Your changes cannot be saved.',
    buttons: ['Refresh', 'Cancel']
  });

  if (userChoice === 'Refresh') {
    // Reload the latest data
    const freshData = await loadFlowData();
    updateUI(freshData);
    currentVersion = freshData.flowVersion;
  }
}
```

## Best Practices

1. **Always include `flowVersion`** when saving timeline changes to enable conflict detection.
2. **Update the stored version** after every successful save or refresh.
3. **Don't retry automatically** on 409 - always involve the user to prevent data loss.
4. **Consider auto-refresh** on focus/visibility change to reduce conflicts in multi-tab scenarios.
5. **Show visual indicators** when data is stale (e.g., "Last updated 5 minutes ago").

## Backward Compatibility

Clients that don't send `flowVersion` will continue to work as before (no version checking). However, this means they won't be protected from concurrent modifications.

**Migration path:**
1. Update frontend to read and store `flowVersion` from responses
2. Update save operations to include `flowVersion`
3. Add conflict handling UI
4. Test with multiple concurrent users

## Testing Scenarios

1. **Single user, sequential saves**: Should work normally
2. **Two users, no conflict**: User A saves, then User B refreshes and saves - should work
3. **Two users, conflict**: User A and B both load data, A saves, B tries to save - B gets 409
4. **Stale tab**: User opens tab, leaves it for hours, tries to save - gets 409 if timeline was modified
5. **No version sent**: Old clients without version field - saves succeed (no protection)

## API Reference

### GET /api/v1/production/get-flow-data

**Response fields (new):**
- `flowVersion` (string, optional): ISO 8601 timestamp of last update. Present if flow data exists.

### POST /api/v1/production/save-flow-data

**Request fields (new):**
- `flowVersion` (string, optional): Expected version timestamp. If provided, save fails with 409 if version doesn't match.

**Error responses:**
- **409 Conflict**: Version mismatch. Response body includes current version in error message.

## Database Schema

The version is derived from the `updated_at` column in the `app_production_flow` table:

```sql
CREATE TABLE app_production_flow (
  id UUID PRIMARY KEY,
  project_id UUID NOT NULL,
  script_id UUID NOT NULL,
  flow_data JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- Used as version
  UNIQUE (project_id, script_id)
);
```

The `updated_at` timestamp is automatically updated on every save via `SET updated_at = NOW()`.
