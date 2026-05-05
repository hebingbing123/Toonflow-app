# Publish Overview Aggregation (J.4)

## Overview

Task J.4 implements an aggregated endpoint for short-video-space publish data to reduce API fanout and improve performance.

## Problem

The short-video-space UI previously made 6 separate API calls to fetch publish-related data:

1. `GET /api/v1/projects/{project_id}/publish/platform-matrix` - Platform capabilities
2. `GET /api/v1/projects/{project_id}/publish/drafts` - List of drafts
3. `GET /api/v1/projects/{project_id}/publish/jobs` - List of jobs
4. `GET /api/v1/projects/{project_id}/publish/performance-alerts` - Performance alerts
5. `GET /api/v1/projects/{project_id}/publish/audit` - Audit logs
6. `GET /api/v1/projects/{project_id}/publish/drafts/{draft_id}/prepare-check` - Prepare check (conditional)

This resulted in:
- High network overhead (6 round trips)
- Increased latency
- More complex frontend state management
- Higher server load

## Solution

Created a new aggregated endpoint:

```
GET /api/v1/projects/{project_id}/publish/overview
```

### Query Parameters

- `draft_id` (optional): UUID of draft to fetch prepare check for
- `audit_limit` (optional): Number of audit records to return (default: 30)

### Response Structure

```json
{
  "matrix": {
    "platforms": [...]
  },
  "drafts": [...],
  "prepare_check": {...} | null,
  "jobs": [...],
  "performance_alerts": [...],
  "audit": [...]
}
```

### Implementation Details

1. **Backend Changes**:
   - Added `PublishOverviewResponse` and `PublishOverviewQuery` types in `backend/src/publish/types.rs`
   - Added `publish_overview` handler in `backend/src/publish/handlers.rs`
   - Uses `tokio::try_join!` to fetch all data in parallel for optimal performance
   - Updated OpenAPI schema in `backend/src/publish/openapi.rs`

2. **Performance Optimization**:
   - All database queries run in parallel using `tokio::try_join!`
   - Reduces total latency from sum of all requests to max of slowest request
   - Single HTTP round trip instead of 6

3. **Backward Compatibility**:
   - Old endpoints remain available
   - Frontend can migrate incrementally
   - No breaking changes to existing API

## Benefits

1. **Reduced API Fanout**: 6 requests → 1 request (83% reduction)
2. **Lower Latency**: Parallel execution + single round trip
3. **Simpler Frontend Code**: Single fetch instead of coordinating multiple requests
4. **Better Performance**: Reduced server load and network overhead
5. **Improved User Experience**: Faster page loads in short-video-space

## Frontend Migration

To use the new endpoint, replace the `_capturePublishSlice` method in `frontend/lib/short_video_space/section.dart`:

```dart
Future<PublishOverviewResponse> _fetchPublishOverview(
  ProjectRow project,
  String token,
  String? preferredDraftId,
) async {
  final queryParams = <String, String>{};
  if (preferredDraftId != null && preferredDraftId.trim().isNotEmpty) {
    queryParams['draft_id'] = preferredDraftId;
  }
  queryParams['audit_limit'] = '30';
  
  return await fetchPublishOverview(token, project.id, queryParams);
}
```

## Testing

The endpoint has been tested with:
- ✅ Backend compilation (cargo clippy)
- ✅ OpenAPI schema generation
- ✅ Full refactor-check gate

## Related Tasks

- J.1: Input hash cache for publish copy generation
- J.2: Incremental publish copy mode
- J.3: LLM usage logging for publish copy
- J.5: Reduce loadProjectOverview fanout (next)
- J.6: Request deduplication for high-frequency refresh (next)
