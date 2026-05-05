# Standardized Error Response Format

## Overview

All API error responses follow a consistent JSON structure to improve debugging, monitoring, and client error handling. This standardization was implemented as part of Phase K - Reliability / Observability / Contract Governance.

## Error Response Structure

### Standard Format

```json
{
  "status": 409,
  "code": "version_conflict",
  "message": "Timeline has been modified by another user",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "details": {
    "expected_version": "2025-01-15 10:30:45.123456+00",
    "current_version": "2025-01-15 10:35:12.789012+00",
    "conflict_type": "version_mismatch"
  }
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | number | Yes | HTTP status code (e.g., 400, 404, 409, 500) |
| `code` | string | Yes | Machine-readable error code for programmatic handling |
| `message` | string | Yes | Human-readable error message |
| `request_id` | string | Yes* | Unique request identifier for tracing (*injected by middleware) |
| `details` | object | No | Additional context specific to the error type |
| `retry_after_ms` | number | No | Milliseconds until retry (only present on 429 responses) |

## Request ID Tracking

### How Request IDs Work

1. **Client-Provided ID**: Clients can supply a custom request ID via the `X-Request-ID` header
2. **Server-Generated ID**: If not provided, the server automatically generates a UUID
3. **Propagation**: The request ID is included in:
   - Response header: `X-Request-ID`
   - Error response body: `request_id` field
   - Server logs: All log entries for the request include the ID

### Using Request IDs

**Client Example:**
```typescript
const response = await fetch('/api/v1/production/save-flow-data', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-Request-ID': 'client-trace-12345' // Optional custom ID
  },
  body: JSON.stringify(data)
});

if (!response.ok) {
  const error = await response.json();
  console.error('Request failed:', {
    requestId: error.request_id,
    code: error.code,
    message: error.message,
    details: error.details
  });
  
  // Report to monitoring system
  reportError({
    requestId: error.request_id,
    endpoint: '/api/v1/production/save-flow-data',
    errorCode: error.code
  });
}
```

**Server Logs:**
```
2025-01-15T10:35:12.789Z INFO [request_id=550e8400-e29b-41d4-a716-446655440000] POST /api/v1/production/save-flow-data
2025-01-15T10:35:12.791Z ERROR [request_id=550e8400-e29b-41d4-a716-446655440000] Version conflict detected
```

## Error Codes

### Standard Error Codes

| Code | Status | Description |
|------|--------|-------------|
| `unauthorized` | 401 | Missing or invalid Authorization header |
| `invalid_token` | 401 | JWT verification failed |
| `forbidden` | 403 | Authenticated but not allowed |
| `not_found` | 404 | Resource not found |
| `conflict` | 409 | Resource conflict (e.g., version mismatch) |
| `bad_request` | 400 | Invalid request parameters |
| `quota_exceeded` | 429 | Rate limit or quota exceeded |
| `internal_error` | 500 | Internal server error |
| `database_error` | 503 | Database unavailable |
| `auth_not_configured` | 503 | Authentication not configured |
| `llm_not_configured` | 503 | LLM service not configured |
| `webhook_not_configured` | 503 | Webhook service not configured |
| `invalid_webhook_signature` | 401 | Webhook signature verification failed |
| `not_implemented` | 501 | Feature not implemented |

## Error Details Field

The optional `details` field provides additional context specific to the error type.

### Version Conflict Details

```json
{
  "status": 409,
  "code": "conflict",
  "message": "Timeline has been modified by another user",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "details": {
    "expected_version": "2025-01-15 10:30:45.123456+00",
    "current_version": "2025-01-15 10:35:12.789012+00",
    "conflict_type": "version_mismatch"
  }
}
```

### Validation Error Details (Future)

```json
{
  "status": 400,
  "code": "validation_error",
  "message": "Request validation failed",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "details": {
    "fields": {
      "email": "Invalid email format",
      "age": "Must be between 0 and 120"
    }
  }
}
```

### Rate Limit Details

```json
{
  "status": 429,
  "code": "quota_exceeded",
  "message": "Daily job limit exceeded for Free tier",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "retry_after_ms": 43200000
}
```

## Client Implementation Guide

### Error Handling Pattern

```typescript
interface ErrorResponse {
  status: number;
  code: string;
  message: string;
  request_id: string;
  details?: Record<string, any>;
  retry_after_ms?: number;
}

async function handleApiError(response: Response): Promise<never> {
  const error: ErrorResponse = await response.json();
  
  // Log for debugging
  console.error('API Error:', {
    requestId: error.request_id,
    code: error.code,
    status: error.status,
    message: error.message,
    details: error.details
  });
  
  // Handle specific error types
  switch (error.code) {
    case 'conflict':
      if (error.details?.conflict_type === 'version_mismatch') {
        throw new VersionConflictError(error);
      }
      break;
      
    case 'quota_exceeded':
      if (error.retry_after_ms) {
        throw new QuotaExceededError(error, error.retry_after_ms);
      }
      break;
      
    case 'unauthorized':
    case 'invalid_token':
      // Redirect to login
      redirectToLogin();
      break;
      
    default:
      throw new ApiError(error);
  }
  
  throw new ApiError(error);
}
```

### Retry Logic with Request ID

```typescript
async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3
): Promise<T> {
  let lastError: ErrorResponse | null = null;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (error instanceof ApiError) {
        lastError = error.response;
        
        // Don't retry client errors (4xx) except 429
        if (error.response.status >= 400 && 
            error.response.status < 500 && 
            error.response.status !== 429) {
          throw error;
        }
        
        // Use retry_after_ms if provided
        const delay = error.response.retry_after_ms || 
                     Math.pow(2, attempt) * 1000;
        
        console.log(`Retry attempt ${attempt + 1}/${maxRetries}`, {
          requestId: error.response.request_id,
          delay
        });
        
        await sleep(delay);
      } else {
        throw error;
      }
    }
  }
  
  throw new MaxRetriesExceededError(lastError);
}
```

## Monitoring and Alerting

### Key Metrics to Track

1. **Error Rate by Code**: Track frequency of each error code
2. **Request ID Correlation**: Link errors across services using request ID
3. **Error Details Analysis**: Analyze `details` field for patterns
4. **Retry Success Rate**: Track how often retries succeed after 429/503

### Example Monitoring Query

```sql
-- Count errors by code in the last hour
SELECT 
  error_code,
  COUNT(*) as error_count,
  COUNT(DISTINCT request_id) as unique_requests
FROM error_logs
WHERE timestamp > NOW() - INTERVAL '1 hour'
GROUP BY error_code
ORDER BY error_count DESC;
```

## OpenAPI Schema

The error response schema is documented in the OpenAPI specification:

```yaml
components:
  schemas:
    ErrorBody:
      type: object
      required:
        - status
        - code
        - message
      properties:
        status:
          type: integer
          description: HTTP status code
          example: 409
        code:
          type: string
          description: Machine-readable error code
          example: "version_conflict"
        message:
          type: string
          description: Human-readable error message
          example: "Timeline has been modified by another user"
        request_id:
          type: string
          format: uuid
          description: Request ID for tracing
          example: "550e8400-e29b-41d4-a716-446655440000"
        details:
          type: object
          description: Additional error context
          additionalProperties: true
        retry_after_ms:
          type: integer
          description: Milliseconds until retry (429 only)
          example: 43200000
```

## Migration Notes

### Backward Compatibility

The standardized format is backward compatible:
- All existing error responses now include `status` and `request_id` fields
- Clients that don't check these fields will continue to work
- The `code` and `message` fields remain unchanged

### Frontend Migration Checklist

1. ✅ Update error handling to read `status` field
2. ✅ Store and log `request_id` for debugging
3. ✅ Handle `details` field for specific error types
4. ✅ Update error display components to show request ID
5. ✅ Integrate request ID into monitoring/logging systems

## Testing

### Unit Tests

```rust
#[test]
fn error_body_includes_all_required_fields() {
    let resp = ApiError::BadRequest("invalid input".into()).into_response();
    let body = decode_error_body(resp);
    
    assert_eq!(body["status"], 400);
    assert_eq!(body["code"], "bad_request");
    assert_eq!(body["message"], "invalid input");
    // request_id is injected by middleware in integration tests
}

#[test]
fn conflict_with_details_includes_details_field() {
    let resp = ApiError::ConflictWithDetails {
        message: "Version conflict".to_string(),
        details: json!({
            "expected_version": "v1",
            "current_version": "v2"
        }),
    }.into_response();
    
    let body = decode_error_body(resp);
    assert_eq!(body["status"], 409);
    assert!(body["details"].is_object());
}
```

### Integration Tests

See `backend/src/http_kit/request_id_mw.rs` for middleware tests that verify request ID injection.

## Related Documentation

- [Timeline Version Conflict Detection](./timeline-version-conflict-detection.md)
- [Request Deduplication](./request-deduplication.md)
- OpenAPI Specification: `/api/v1/openapi.yaml`
