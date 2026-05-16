# ADR: `/me` API Version Negotiation Strategy

**Status**: Accepted  
**Date**: 2025-01-XX  
**Related Documents**:
- [Workspace-Scope Billing Spec](../../.kiro/specs/workspace-scope-billing/)
- [Workspace Billing Migration Notice](./workspace-billing-migration-notice.md)
- [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md)
- [ADR: Workspace Billing Storage Model](./adr-workspace-billing-storage-model.md)

**Boundary**: this ADR defines a versioning strategy for a future `/me` v2 response shape. It should not be read as evidence that v2 or workspace-scope billing is already active in current production.

---

## Context

**Task 5.2** of the workspace-scope billing specification requires implementing version negotiation for the `GET /api/v1/me` endpoint to support both v1 (flat, backward-compatible) and v2 (nested with `billing_scope` and `current_workspace_billing`) responses.

Two standard approaches exist for API versioning:

1. **Query Parameter**: `GET /api/v1/me?v=2`
2. **Accept Header Negotiation**: `Accept: application/vnd.toonflow.me+json; version=2`

This ADR documents the chosen approach for Toonflow's `/me` endpoint versioning.

---

## Decision

**We will use QUERY PARAMETER versioning (`?v=2`) as the primary and recommended method for `/me` API version negotiation.**

### Implementation

```rust
// Query parameter struct
#[derive(Debug, Deserialize)]
pub struct MeQueryParams {
    /// API version: "2" for v2 response, omit or "1" for v1 (default).
    pub v: Option<String>,
}

// Handler signature
pub(crate) async fn me(
    State(state): State<AppState>,
    Query(params): Query<MeQueryParams>,
    headers: HeaderMap,
) -> Result<Json<serde_json::Value>, ApiError> {
    // ...
    let is_v2 = params.v.as_deref() == Some("2");
    // ...
}
```

### Client Usage

**Flutter/Dart:**
```dart
// V1 (default, backward-compatible)
final response = await api.get('/api/v1/me');

// V2 (opt-in)
final response = await api.get('/api/v1/me?v=2');
```

**cURL:**
```bash
# V1 (default)
curl -H "Authorization: Bearer $TOKEN" https://api.toonflow.com/api/v1/me

# V2 (opt-in)
curl -H "Authorization: Bearer $TOKEN" https://api.toonflow.com/api/v1/me?v=2
```

---

## Rationale

### Why Query Parameter?

1. **Simplicity**: Query parameters are universally supported by all HTTP clients without special header parsing
2. **Visibility**: Version is explicit in URLs, logs, and browser dev tools
3. **Caching**: CDN/proxy caching can easily distinguish versions by URL
4. **Testing**: Easier to test in browsers, Postman, cURL without header manipulation
5. **Documentation**: OpenAPI/Swagger UI natively supports query parameters with dropdowns
6. **Existing Pattern**: Toonflow already uses query parameters for other optional behaviors
7. **Client Simplicity**: No need for custom header construction in Flutter/Dart clients
8. **Migration Path**: Clients can gradually add `?v=2` without changing HTTP client configuration

### Why NOT Accept Header?

**Disadvantages of Accept header negotiation:**

1. **Complexity**: Requires parsing `Accept` header with media type and version parameter
2. **Client Burden**: Flutter/Dart clients must construct custom `Accept` headers
3. **Debugging**: Headers are less visible in logs and browser dev tools
4. **Caching**: More complex cache key generation for CDN/proxies
5. **Testing**: Harder to test manually (requires header manipulation in every tool)
6. **OpenAPI Limitations**: Swagger UI doesn't provide native UI for Accept header versioning
7. **Error Prone**: Easy to forget or misconfigure Accept headers in client code
8. **Overkill**: Accept negotiation is designed for content-type negotiation (JSON vs XML), not API versioning

### Industry Precedent

**Query parameter versioning is widely used:**
- **Stripe API**: Uses `?version=2023-10-16` for API versioning
- **GitHub API**: Uses `?per_page=100&page=2` for pagination (similar pattern)
- **Google APIs**: Many use query parameters for version/format selection
- **Twilio API**: Uses query parameters for optional response formats

**Accept header versioning is less common** and typically used for:
- Content negotiation (JSON vs XML vs Protobuf)
- Vendor-specific media types in large enterprise APIs
- APIs with complex content-type requirements

---

## Consequences

### Immediate

✅ **Implementation Complete**: Query parameter routing (`?v=2`) is already implemented in `backend/src/app/handlers/me.rs`

✅ **OpenAPI Documentation**: Parameter is documented in `#[utoipa::path]` annotation

✅ **Client Migration**: Flutter clients can opt-in by appending `?v=2` to existing `/me` calls

✅ **Backward Compatibility**: Omitting `?v` or using `?v=1` returns v1 response (default)

### Future

**If Accept header support is needed later** (e.g., for enterprise clients with strict API standards):

```rust
// Fallback logic (not implemented now, but possible)
let is_v2 = params.v.as_deref() == Some("2") 
    || headers.get("accept")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.contains("version=2"))
        .unwrap_or(false);
```

**Priority**: Query parameter takes precedence if both are present (explicit > implicit).

---

## Alternatives Considered

### Alternative 1: Accept Header Only

**Rejected** because:
- Higher implementation complexity (header parsing, media type validation)
- Worse developer experience (harder to test, debug, document)
- No clear benefit over query parameters for this use case
- Inconsistent with Toonflow's existing API patterns

### Alternative 2: URL Path Versioning (`/api/v2/me`)

**Rejected** because:
- Requires new route registration and duplication
- Breaks semantic versioning (v1 and v2 are same endpoint, different response shapes)
- Harder to deprecate v1 (must maintain two routes indefinitely)
- Inconsistent with existing `/api/v1/*` namespace (which is product version, not response version)

### Alternative 3: Both Query Parameter AND Accept Header

**Rejected** because:
- Adds complexity without clear benefit
- Ambiguity when both are present (which takes precedence?)
- Harder to document and test
- Clients will naturally converge on one method, making the other unused

---

## Implementation Checklist

- [x] **Query parameter struct** (`MeQueryParams`) defined
- [x] **Handler logic** checks `params.v == "2"` and routes to v2 response
- [x] **OpenAPI annotation** documents `v` parameter
- [x] **ADR documented** (this file) — **Task 5.2 completion**
- [x] **Migration notice** updated with query parameter examples
- [x] **Tests** cover v1 (default) and v2 (`?v=2`) responses

---

## References

- **Implementation**: `backend/src/app/handlers/me.rs` (lines 14-16, 88-90)
- **OpenAPI Schema**: `backend/src/app/handlers/types.rs` (MeV2Response)
- **Migration Notice**: `docs/plans/workspace-billing-migration-notice.md` §2.2
- **Spec Task**: `.kiro/specs/workspace-scope-billing/tasks.md` Task 5.2
- **Requirements**: `.kiro/specs/workspace-scope-billing/requirements.md` Requirement 3.2

---

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2025-01-XX | Kiro (AI Agent) | Initial ADR creation for Task 5.2 |
