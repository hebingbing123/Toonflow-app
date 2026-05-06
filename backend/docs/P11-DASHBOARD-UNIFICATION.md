# P11: 发布/表现数据看板口径统一 Implementation Plan

## Objective
Ensure that publish and performance data dashboards clearly distinguish between:
- Real publish vs sandbox publish
- Real metrics vs mock metrics

## Backend Status: ✅ COMPLETE

The backend already provides all necessary data:

### 1. Delivery Mode in Attempts
- `app_publish_attempt.detail` contains `delivery_mode` field
- Values: `sandbox`, `live`, `manual_bridge`
- Audit API supports filtering by `delivery_mode`

### 2. Metrics Source Tracking
- `PublishMetricsSnapshot.raw_payload` contains `source` and `delivery_mode`
- Sources: `sandbox_metrics_mock`, `live_platform_api`, `manual_bridge_receipt`
- Performance sync stores `delivery_mode` in metadata

### 3. API Endpoints Already Support Filtering
- `GET /api/v1/projects/{id}/publish/audit?delivery_mode=live`
- `GET /api/v1/projects/{id}/publish/performance-alerts` includes delivery_mode in metadata

## Frontend Requirements

### 1. Space Overview Panel

**Current State**: Shows aggregate counts without delivery_mode distinction

**Required Changes**:

```dart
class ProjectPublishOverview {
  // Existing fields...
  
  // Add delivery_mode breakdown
  final Map<String, int> jobsByDeliveryMode; // {"sandbox": 5, "live": 3, "manual_bridge": 2}
  final Map<String, int> successfulJobsByDeliveryMode;
  final Map<String, int> failedJobsByDeliveryMode;
}
```

**UI Display**:
```
发布概览
├─ 总作业数: 10
│  ├─ 真实发布 (live): 3
│  ├─ 人工桥接 (manual_bridge): 2
│  └─ 沙盒测试 (sandbox): 5
├─ 成功: 8
│  ├─ 真实: 2
│  └─ 沙盒: 6
└─ 失败: 2
   └─ 真实: 1
```

### 2. Task Center Filtering

**Current State**: Shows all publish jobs without delivery_mode filter

**Required Changes**:

```dart
// Add delivery_mode filter to task center
enum PublishDeliveryModeFilter {
  all,
  liveOnly,      // 仅真实发布
  sandboxOnly,   // 仅沙盒测试
  manualOnly,    // 仅人工桥接
}

class TaskCenterFilters {
  // Existing filters...
  PublishDeliveryModeFilter deliveryModeFilter;
}
```

**UI Display**:
- Add chip filter: "全部 | 真实发布 | 沙盒测试 | 人工桥接"
- Show delivery_mode badge on each job card
- Color coding:
  - `live`: Green badge "真实"
  - `sandbox`: Gray badge "沙盒"
  - `manual_bridge`: Blue badge "人工"

### 3. Performance Alerts Panel

**Current State**: Shows alerts without indicating metric source

**Required Changes**:

```dart
class PublishPerformanceAlert {
  // Existing fields...
  
  // Add metric source indicator
  final String metricSource; // "live_platform_api" | "sandbox_metrics_mock" | "manual_bridge_receipt"
  final String deliveryMode; // "live" | "sandbox" | "manual_bridge"
}
```

**UI Display**:
```
低表现预警
├─ 视频 A (抖音)
│  ├─ 完播率: 15% (阈值: 30%)
│  └─ 数据来源: 真实平台 API ✓
└─ 视频 B (哔哩哔哩)
   ├─ 播放量: 500 (阈值: 1000)
   └─ 数据来源: 沙盒模拟 ⚠️
```

### 4. Publish Job Detail View

**Current State**: Shows job status and attempts without delivery_mode

**Required Changes**:

```dart
class PublishJobDetailView extends StatelessWidget {
  // Show delivery_mode prominently
  // Show all attempts with their delivery_mode
  // Distinguish real vs sandbox results
}
```

**UI Display**:
```
作业详情
├─ 状态: 成功
├─ 发布模式: 真实发布 (live) ✓
├─ 平台: 抖音
└─ 尝试记录:
   ├─ 尝试 1 (live): 成功
   │  ├─ 请求ID: req_douyin_xxx
   │  └─ 回调ID: cb_douyin_xxx
   └─ 尝试 2 (sandbox): 成功
      └─ 请求ID: req_douyin_yyy
```

### 5. Performance Data Dashboard

**Current State**: Shows metrics without source indication

**Required Changes**:

```dart
class PerformanceMetricsCard extends StatelessWidget {
  final String metricSource;
  final String deliveryMode;
  
  // Show warning icon if sandbox data
  // Show checkmark if live data
}
```

**UI Display**:
```
表现数据
├─ 播放量: 10,000 ✓ (真实数据)
├─ 点赞数: 500 ✓ (真实数据)
├─ 评论数: 50 ⚠️ (沙盒数据)
└─ 完播率: 45% ✓ (真实数据)
```

## Implementation Steps

### Phase 1: Backend API Enhancement (✅ DONE)
- [x] delivery_mode in attempts
- [x] delivery_mode in metrics
- [x] Audit API filtering
- [x] Performance alerts include source

### Phase 2: Frontend Data Models (1 day)
1. Update `PublishJobRow` to include `delivery_mode`
2. Update `PublishAttemptAuditRow` to expose `delivery_mode`
3. Update `PublishPerformanceAlertRow` to include `metric_source` and `delivery_mode`
4. Update `ProjectPublishOverview` to include delivery_mode breakdown

### Phase 3: UI Components (2-3 days)
1. **Delivery Mode Badge Component**
   ```dart
   class DeliveryModeBadge extends StatelessWidget {
     final String deliveryMode;
     // Returns colored chip with icon
   }
   ```

2. **Metric Source Indicator Component**
   ```dart
   class MetricSourceIndicator extends StatelessWidget {
     final String source;
     final bool isLive;
     // Returns icon with tooltip
   }
   ```

3. **Delivery Mode Filter Component**
   ```dart
   class DeliveryModeFilter extends StatelessWidget {
     final PublishDeliveryModeFilter selected;
     final ValueChanged<PublishDeliveryModeFilter> onChanged;
     // Returns chip filter row
   }
   ```

### Phase 4: Integration (2 days)
1. Update Space overview to show delivery_mode breakdown
2. Add delivery_mode filter to task center
3. Add metric source indicators to performance alerts
4. Update job detail view to show delivery_mode
5. Add warnings for sandbox data in dashboards

### Phase 5: Testing (1 day)
1. Test with mixed sandbox/live jobs
2. Test filtering by delivery_mode
3. Test metric source indicators
4. Verify warnings appear for sandbox data

## Visual Design

### Color Scheme
- **Live (真实)**: Green (#4CAF50) - indicates real platform data
- **Sandbox (沙盒)**: Gray (#9E9E9E) - indicates test/mock data
- **Manual Bridge (人工)**: Blue (#2196F3) - indicates manual-assisted

### Icons
- **Live**: ✓ (checkmark) or 🌐 (globe)
- **Sandbox**: ⚠️ (warning) or 🧪 (test tube)
- **Manual Bridge**: 👤 (person) or 🔗 (link)

### Tooltips
- Live: "真实平台发布 - 数据来自平台 API"
- Sandbox: "沙盒测试 - 数据为模拟数据，仅供测试"
- Manual Bridge: "人工辅助发布 - 需要人工确认"

## Acceptance Criteria

- [ ] Space overview shows delivery_mode breakdown for jobs
- [ ] Task center can filter by delivery_mode
- [ ] Each job card shows delivery_mode badge
- [ ] Performance alerts indicate metric source (real vs mock)
- [ ] Job detail view clearly shows delivery_mode
- [ ] Sandbox data has visual warning indicators
- [ ] Real data has visual confirmation indicators
- [ ] Tooltips explain what each delivery_mode means
- [ ] Color coding is consistent across all views
- [ ] User can easily distinguish real vs test data at a glance

## Estimated Effort

- Backend: 0 days (already complete)
- Frontend data models: 1 day
- UI components: 2-3 days
- Integration: 2 days
- Testing: 1 day
- **Total: 6-7 days** (1-1.5 weeks)

## Dependencies

- P1 (delivery_mode layering) - ✅ Complete
- P2 (delivery_mode in attempts) - ✅ Complete

## Notes

- This is primarily a UI/UX task
- Backend already provides all necessary data
- Focus on clear visual distinction between real and test data
- Consider adding user preferences for default filter (e.g., "hide sandbox by default")
- Consider adding analytics to track sandbox vs live usage

