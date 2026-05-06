# Cross-Panel Snapshot Versioning

## Overview

Cross-panel snapshot versioning provides consistency checking across different UI panels (storyboard, video, publish, etc.) to detect and alert when panels are viewing different versions of the same underlying data. This prevents operations on stale data and improves user awareness of data freshness.

## How It Works

### Version Field

All panel data endpoints now return a `dataVersion` field in their responses:

- `GET /api/v1/projects/{project_id}/production-overview`
- `GET /api/v1/projects/{project_id}/assets-overview`
- `GET /api/v1/projects/{project_id}/short-video-assembly`
- `GET /api/v1/projects/{project_id}/short-video-export-check`

```json
{
  "schema_version": 1,
  "dataVersion": "2025-01-15 10:30:45.123456+00",
  "ready_storyboard_count": 10,
  ...
}
```

The `dataVersion` is an ISO 8601 timestamp representing the latest update time across all relevant data sources for that panel.

### Version Computation

Each endpoint computes its `dataVersion` by taking the maximum `updated_at` timestamp from all tables that contribute to that panel's data:

**Production Overview:**
- `app_storyboard.updated_at` (via scripts in project)
- `app_generation_job.updated_at` (queued/running jobs for project)
- `app_quality_review.updated_at` (bad cases for project)

**Assets Overview:**
- `app_asset.updated_at` (all assets in project)

**Short Video Assembly:**
- `app_storyboard.updated_at` (via scripts in project)
- `app_voiceover.updated_at` (voiceover assets for storyboards)

**Export Check:**
- Same as Short Video Assembly (shares underlying data)

### Consistency Checking

The frontend can detect inconsistencies by:

1. **Storing versions per panel**: When loading data for each panel, store the `dataVersion`
2. **Comparing versions**: When switching panels or before operations, compare versions
3. **Detecting staleness**: If Panel A has version `v1` and Panel B has version `v2` where `v2 > v1`, Panel A is stale

## Frontend Implementation Guide

### Step 1: Store Panel Versions

```typescript
interface PanelSnapshot {
  dataVersion: string | null;
  loadedAt: Date;
}

class ShortVideoSpaceState {
  private panelVersions: Map<string, PanelSnapshot> = new Map();

  async loadProductionOverview() {
    const response = await fetch('/api/v1/projects/{id}/production-overview');
    const data = await response.json();
    
    this.panelVersions.set('production', {
      dataVersion: data.dataVersion,
      loadedAt: new Date()
    });
    
    this.checkCrossPanelConsistency();
  }
}
```

### Step 2: Detect Inconsistencies

```typescript
checkCrossPanelConsistency(): ConsistencyStatus {
  const versions = Array.from(this.panelVersions.entries())
    .filter(([_, snap]) => snap.dataVersion !== null)
    .map(([panel, snap]) => ({
      panel,
      version: new Date(snap.dataVersion!),
      loadedAt: snap.loadedAt
    }));

  if (versions.length < 2) {
    return { consistent: true };
  }

  // Find latest and oldest versions
  const sorted = versions.sort((a, b) => 
    b.version.getTime() - a.version.getTime()
  );
  const latest = sorted[0];
  const oldest = sorted[sorted.length - 1];

  const stalePanels = versions.filter(v => 
    v.version.getTime() < latest.version.getTime()
  );

  if (stalePanels.length > 0) {
    return {
      consistent: false,
      latestPanel: latest.panel,
      latestVersion: latest.version,
      stalePanels: stalePanels.map(p => ({
        panel: p.panel,
        version: p.version,
        ageSeconds: (latest.version.getTime() - p.version.getTime()) / 1000
      }))
    };
  }

  return { consistent: true };
}
```

### Step 3: Display Alerts

```typescript
renderConsistencyAlert(status: ConsistencyStatus) {
  if (status.consistent) {
    return null;
  }

  return (
    <Alert severity="warning">
      <AlertTitle>Data Inconsistency Detected</AlertTitle>
      <Typography>
        Some panels are viewing older data. Latest update: {status.latestVersion.toLocaleString()}
      </Typography>
      <List>
        {status.stalePanels.map(p => (
          <ListItem key={p.panel}>
            {p.panel}: {p.ageSeconds}s behind
          </ListItem>
        ))}
      </List>
      <Button onClick={() => this.refreshAllPanels()}>
        Refresh All Panels
      </Button>
    </Alert>
  );
}
```

### Step 4: Prevent Operations on Stale Data

```typescript
async performCriticalOperation() {
  const status = this.checkCrossPanelConsistency();
  
  if (!status.consistent) {
    const userChoice = await showDialog({
      title: 'Stale Data Detected',
      message: 'Some panels have outdated data. Refresh before proceeding?',
      buttons: ['Refresh & Continue', 'Cancel']
    });

    if (userChoice === 'Refresh & Continue') {
      await this.refreshAllPanels();
    } else {
      return; // Cancel operation
    }
  }

  // Proceed with operation
  await this.executeOperation();
}
```

## UI Patterns

### Visual Indicators

1. **Timestamp Display**: Show "Last updated: X seconds ago" for each panel
2. **Staleness Badge**: Display a warning badge on stale panels
3. **Refresh Button**: Provide manual refresh for each panel
4. **Auto-refresh**: Optionally refresh on window focus/visibility

### Alert Levels

- **Info**: Data is fresh (< 30 seconds old)
- **Warning**: Data is moderately stale (30s - 5 minutes)
- **Error**: Data is very stale (> 5 minutes) or inconsistent before critical operations

### Refresh Strategies

1. **Manual Refresh**: User clicks refresh button
2. **Auto-refresh on Focus**: Refresh when window/tab gains focus
3. **Periodic Refresh**: Refresh every N seconds (configurable)
4. **Event-driven Refresh**: Refresh after mutations (save, delete, etc.)

## Best Practices

1. **Always check consistency before critical operations** (publish, export, delete)
2. **Store versions per panel** to enable granular staleness detection
3. **Provide clear refresh mechanisms** - don't force automatic refresh
4. **Show relative timestamps** ("5 seconds ago") for better UX
5. **Consider auto-refresh on visibility change** to reduce stale data in multi-tab scenarios
6. **Log version mismatches** for debugging and monitoring

## Testing Scenarios

1. **Single panel refresh**: Load one panel, verify version is stored
2. **Multi-panel consistency**: Load multiple panels, verify versions match
3. **Stale detection**: Load Panel A, modify data, load Panel B, verify Panel A is marked stale
4. **Refresh flow**: Detect staleness, refresh, verify versions now match
5. **Critical operation blocking**: Attempt operation with stale data, verify warning/block
6. **Multi-tab scenario**: Open same project in two tabs, modify in one, verify other detects staleness

## Comparison with Timeline Version Conflict Detection

| Feature | Timeline Version Conflict (K.1) | Cross-Panel Snapshot Versioning (K.4) |
|---------|--------------------------------|--------------------------------------|
| **Scope** | Single timeline save operation | All panel data reads |
| **Purpose** | Prevent concurrent write conflicts | Detect stale read data |
| **Mechanism** | Optimistic locking with version check | Timestamp comparison across panels |
| **Failure Mode** | 409 Conflict on save | Warning/alert on inconsistency |
| **User Action** | Must refresh before retry | Can choose to refresh or continue |
| **Implementation** | Server-side version validation | Client-side version comparison |

Both features work together:
- **K.1** prevents data loss from concurrent writes
- **K.4** prevents operations on stale reads

## API Reference

### Response Fields (New)

All panel endpoints now include:

```typescript
interface PanelResponse {
  schema_version: number;
  dataVersion?: string; // ISO 8601 timestamp, optional
  // ... other fields
}
```

### Version Format

- **Type**: ISO 8601 timestamp string
- **Example**: `"2025-01-15 10:30:45.123456+00"`
- **Null handling**: `dataVersion` may be `null` if no data exists yet
- **Comparison**: Use standard timestamp comparison (newer > older)

## Related Documentation

- [Timeline Version Conflict Detection](./timeline-version-conflict-detection.md) (K.1)
- [Standardized Error Format](./standardized-error-format.md) (K.3)
- [Request Deduplication](./request-deduplication.md) (J.6)

## Migration Notes

### Backward Compatibility

The `dataVersion` field is optional and backward compatible:
- Old clients that don't check `dataVersion` will continue to work
- New clients can progressively adopt version checking
- No breaking changes to existing API contracts

### Frontend Migration Checklist

1. ✅ Update API client types to include `dataVersion` field
2. ✅ Add version storage per panel in state management
3. ✅ Implement cross-panel consistency checking logic
4. ✅ Add UI components for staleness alerts
5. ✅ Add refresh mechanisms (manual + auto)
6. ✅ Add consistency checks before critical operations
7. ✅ Add logging/monitoring for version mismatches
8. ✅ Test multi-tab and concurrent modification scenarios

## Future Enhancements

1. **WebSocket notifications**: Push version updates to clients in real-time
2. **Granular versioning**: Track versions per entity (project, script, storyboard)
3. **Version history**: Store version history for debugging
4. **Conflict resolution UI**: Show diffs and allow manual merge
5. **Optimistic UI updates**: Update local version immediately after mutations
