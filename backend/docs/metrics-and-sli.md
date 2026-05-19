# Metrics and SLI for Critical Paths

## Overview

This document describes the metrics collection and Service Level Indicator (SLI) tracking infrastructure implemented for Phase K.5 - Reliability / Observability / Contract Governance.

The system provides:
- **Request-level metrics**: Latency, success rate, error categorization
- **SLI definitions**: Target performance for critical user paths
- **Real-time monitoring**: Aggregated metrics and SLI health status
- **Observability endpoints**: APIs for monitoring systems to consume

## Architecture

### Components

1. **MetricsRegistry** (`backend/src/http_kit/metrics/registry.rs`)
   - In-memory storage for recent request metrics
   - Aggregation engine for computing percentiles and rates
   - Ring buffer design (keeps last 10,000 requests)

2. **MetricsMiddleware** (`backend/src/http_kit/metrics/middleware.rs`)
   - Axum middleware that intercepts all requests
   - Captures: method, path, status, duration, error code, user ID
   - Normalizes paths (replaces IDs with `{id}` placeholders)

3. **SLI Definitions** (`backend/src/http_kit/metrics/sli.rs`)
   - Defines 5 critical paths with performance targets
   - Maps endpoints to critical paths
   - Computes SLI health (meets/misses targets)

4. **Metrics API** (`backend/src/app/handlers/metrics.rs`)
   - `GET /api/v1/metrics` - Aggregated endpoint metrics
   - `GET /api/v1/metrics/sli` - SLI status for all critical paths
   - `GET /api/v1/metrics/sli/definitions` - SLI target definitions

## Critical Paths and SLIs

### 1. Video Generation Workflow

**Endpoints:**
- `POST /api/v1/production/workbench/generate-video`
- `POST /api/v1/production/workbench/batch-generate-candidate-clips`
- `POST /api/v1/production/workbench/generate-video-prompt`
- `POST /api/v1/production/workbench/get-video-list`

**SLI Targets:**
- **p95 Latency**: ≤ 60,000ms (60 seconds)
- **Success Rate**: ≥ 95%
- **Availability**: ≥ 99%

**Rationale**: Video generation is compute-intensive and may take up to a minute. 95% success rate accounts for occasional vendor API failures.

### 2. Publish Workflow

**Endpoints:**
- `POST /api/v1/projects/{project_id}/publish/drafts`
- `GET/POST /api/v1/projects/{project_id}/publish/drafts/{draft_id}/targets`
- `POST /api/v1/projects/{project_id}/publish/drafts/{draft_id}/jobs`
- `GET /api/v1/projects/{project_id}/publish/drafts/{draft_id}/prepare-check`

**SLI Targets:**
- **p95 Latency**: ≤ 5,000ms (5 seconds)
- **Success Rate**: ≥ 99%
- **Availability**: ≥ 99.5%

**Rationale**: Publish operations are critical for revenue. High success rate and availability targets ensure reliable delivery.

### 3. Quality Review Workflow

**Endpoints:**
- `GET /api/v1/projects/{project_id}/production-overview`
- `GET /api/v1/projects/{project_id}/short-video-export-check`

**SLI Targets:**
- **p95 Latency**: ≤ 2,000ms (2 seconds)
- **Success Rate**: ≥ 98%
- **Availability**: ≥ 99%

**Rationale**: Quality checks involve database aggregations. 2-second target ensures responsive UI.

### 4. Project Overview Loading

**Endpoints:**
- `GET /api/v1/projects/{project_id}/production-overview`
- `GET /api/v1/projects/{project_id}/short-video-assembly`
- `GET /api/v1/projects/{project_id}/assets-overview`

**SLI Targets:**
- **p95 Latency**: ≤ 500ms
- **Success Rate**: ≥ 99%
- **Availability**: ≥ 99.5%

**Rationale**: Dashboard loading is the first user interaction. Sub-second latency is critical for perceived performance.

### 5. Asset Management Operations

**Endpoints:**
- `POST /api/v1/production/assets/batch-generate-assets-image`
- `POST /api/v1/production/assets/delete-assets-derivative`
- `POST /api/v1/production/assets/get-assets-data`
- `POST /api/v1/production/assets/update-assets-url`

**SLI Targets:**
- **p95 Latency**: ≤ 10,000ms (10 seconds)
- **Success Rate**: ≥ 97%
- **Availability**: ≥ 99%

**Rationale**: Asset operations involve external image generation APIs. 10-second target accounts for generation time.

## API Usage

### Get Aggregated Metrics

```bash
GET /api/v1/metrics?window_minutes=60
```

**Response:**
```json
{
  "endpoints": {
    "/api/v1/projects/{id}/production-overview": {
      "path": "/api/v1/projects/{id}/production-overview",
      "totalRequests": 1250,
      "successCount": 1235,
      "clientErrorCount": 10,
      "serverErrorCount": 5,
      "successRate": 0.988,
      "p50LatencyMs": 320,
      "p95LatencyMs": 480,
      "p99LatencyMs": 650,
      "avgLatencyMs": 340,
      "errorBreakdown": {
        "not_found": 8,
        "internal_error": 5,
        "unauthorized": 2
      },
      "windowStart": "2025-01-15T10:00:00Z",
      "windowEnd": "2025-01-15T11:00:00Z"
    }
  },
  "windowMinutes": 60
}
```

### Get SLI Status

```bash
GET /api/v1/metrics/sli?window_minutes=60
```

**Response:**
```json
{
  "slis": [
    {
      "path": "video_generation",
      "definition": {
        "path": "video_generation",
        "name": "Video Generation Workflow",
        "description": "Storyboard to video generation including prompt generation and video job creation",
        "endpoints": [
          "/api/v1/production/workbench/generate-video",
          "/api/v1/production/workbench/batch-generate-candidate-clips"
        ],
        "targetP95LatencyMs": 60000,
        "targetSuccessRate": 0.95,
        "targetAvailability": 0.99
      },
      "currentP95LatencyMs": 45000,
      "currentSuccessRate": 0.97,
      "currentAvailability": 0.995,
      "latencyMeetsTarget": true,
      "successRateMeetsTarget": true,
      "availabilityMeetsTarget": true,
      "healthy": true,
      "totalRequests": 450
    }
  ],
  "healthy": true,
  "windowMinutes": 60
}
```

### Get SLI Definitions

```bash
GET /api/v1/metrics/sli/definitions
```

**Response:**
```json
[
  {
    "path": "video_generation",
    "name": "Video Generation Workflow",
    "description": "Storyboard to video generation including prompt generation and video job creation",
    "endpoints": [
      "/api/v1/production/workbench/generate-video",
      "/api/v1/production/workbench/batch-generate-candidate-clips",
      "/api/v1/production/workbench/generate-video-prompt",
      "/api/v1/production/workbench/get-video-list"
    ],
    "targetP95LatencyMs": 60000,
    "targetSuccessRate": 0.95,
    "targetAvailability": 0.99
  }
]
```

## Monitoring and Alerting

### Recommended Alerts

1. **SLI Health Alert**
   - **Condition**: `GET /api/v1/metrics/sli` returns `healthy: false`
   - **Severity**: Warning
   - **Action**: Investigate which SLI is failing and why

2. **High Error Rate**
   - **Condition**: Any endpoint has `successRate < 0.90` over 5 minutes
   - **Severity**: Critical
   - **Action**: Check error breakdown, investigate root cause

3. **High Latency**
   - **Condition**: Any critical path has `p95LatencyMs > target * 1.5`
   - **Severity**: Warning
   - **Action**: Check database performance, external API latency

4. **Availability Drop**
   - **Condition**: Any critical path has `availability < 0.95`
   - **Severity**: Critical
   - **Action**: Check for service outages, database issues

### Integration with Monitoring Systems

#### Prometheus

The metrics endpoints can be scraped by Prometheus using a custom exporter or by polling the JSON endpoints:

```yaml
scrape_configs:
  - job_name: 'openflow-sli'
    metrics_path: '/api/v1/metrics/sli'
    params:
      window_minutes: ['5']
    static_configs:
      - targets: ['api.openflow.com']
    scrape_interval: 60s
```

#### Grafana Dashboard

Example queries for Grafana:

1. **SLI Health Overview**
   - Query: `GET /api/v1/metrics/sli?window_minutes=60`
   - Visualization: Stat panel showing `healthy` status

2. **Endpoint Latency Heatmap**
   - Query: `GET /api/v1/metrics?window_minutes=60`
   - Visualization: Heatmap of p95 latencies by endpoint

3. **Error Rate by Endpoint**
   - Query: `GET /api/v1/metrics?window_minutes=60`
   - Visualization: Bar chart of error rates

#### CloudWatch (AWS)

For AWS deployments, metrics can be pushed to CloudWatch:

```bash
# Example: Push SLI status to CloudWatch
curl -s https://api.openflow.com/api/v1/metrics/sli?window_minutes=5 | \
  jq -r '.slis[] | select(.healthy == false) | .path' | \
  xargs -I {} aws cloudwatch put-metric-data \
    --namespace Openflow/SLI \
    --metric-name UnhealthySLI \
    --value 1 \
    --dimensions Path={}
```

## Performance Considerations

### Memory Usage

- **Ring Buffer**: Stores last 10,000 requests (~1-2 MB)
- **Aggregation**: Computed on-demand, no persistent storage
- **Overhead**: Minimal (<1ms per request)

### Scalability

- **Single Instance**: Metrics are per-instance, not global
- **Load Balancer**: Aggregate metrics across instances externally
- **Future**: Consider centralized metrics store (Redis, Prometheus)

### Limitations

1. **No Persistence**: Metrics are lost on restart
2. **No Historical Data**: Only recent requests are kept
3. **No Cross-Instance Aggregation**: Each instance has its own metrics

## Testing

### Unit Tests

Run metrics tests:

```bash
cd backend
cargo test --lib http_kit::metrics
```

### Integration Tests

Test metrics collection:

```bash
# Make some requests
curl -X GET http://localhost:8080/api/v1/projects/123/production-overview

# Check metrics
curl -X GET http://localhost:8080/api/v1/metrics?window_minutes=5

# Check SLI status
curl -X GET http://localhost:8080/api/v1/metrics/sli?window_minutes=5
```

### Load Testing

Verify metrics under load:

```bash
# Generate load
ab -n 1000 -c 10 http://localhost:8080/api/v1/health

# Check metrics accuracy
curl -X GET http://localhost:8080/api/v1/metrics?window_minutes=5
```

## Future Enhancements

1. **Persistent Storage**: Store metrics in TimescaleDB or InfluxDB
2. **Distributed Tracing**: Integrate with OpenTelemetry for request tracing
3. **Custom Metrics**: Allow endpoints to emit custom business metrics
4. **Alerting**: Built-in alerting based on SLI thresholds
5. **Dashboards**: Embedded Grafana dashboards in admin UI
6. **Cost Tracking**: Track LLM token usage and costs per endpoint
7. **User Segmentation**: Metrics by user tier (free, pro, enterprise)

## Related Documentation

- [Standardized Error Format](./standardized-error-format.md) (K.3)
- [Request Deduplication](./request-deduplication.md) (J.6)
- [Timeline Version Conflict Detection](./timeline-version-conflict-detection.md) (K.1)

## Changelog

- **2025-01-15**: Initial implementation (K.5)
  - Added MetricsRegistry, MetricsMiddleware, SLI definitions
  - Added metrics API endpoints
  - Defined 5 critical paths with SLI targets
