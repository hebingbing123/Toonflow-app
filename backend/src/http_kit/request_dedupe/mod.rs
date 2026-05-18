//! **J.6** — Request deduplication and generation protection for high-frequency refresh.
//!
//! This module provides:
//! 1. Concurrent request deduplication (same user, same operation, same parameters)
//! 2. Generation locks to prevent redundant expensive operations
//! 3. In-memory cache for deduplication keys

use std::fmt;
use std::hash::Hash;
use std::sync::Arc;
use std::time::Duration;

use moka::future::Cache;
use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;
use uuid::Uuid;

use crate::error::ApiError;

/// Request deduplication key that uniquely identifies a request.
#[derive(Debug, Clone, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub struct RequestDedupeKey {
    pub operation: String,
    pub user_id: Uuid,
    pub params: Vec<String>,
}

impl RequestDedupeKey {
    /// Create a new deduplication key.
    pub fn new(operation: impl Into<String>, user_id: Uuid, params: &[String]) -> Self {
        let mut sorted_params = params.to_vec();
        sorted_params.sort(); // Ensure stable key regardless of param order
        Self {
            operation: operation.into(),
            user_id,
            params: sorted_params,
        }
    }

    /// Create a key for project overview requests.
    pub fn project_overview(user_id: Uuid, project_id: Uuid, query_flags: &[&str]) -> Self {
        let mut params = vec![project_id.to_string()];
        params.extend(query_flags.iter().map(|s| s.to_string()));
        Self::new("project_overview", user_id, &params)
    }

    /// Create a key for publish overview requests.
    pub fn publish_overview(
        user_id: Uuid,
        project_id: Uuid,
        draft_id: Option<Uuid>,
        audit_limit: i64,
    ) -> Self {
        let mut params = vec![
            project_id.to_string(),
            format!("audit_limit={}", audit_limit),
        ];
        if let Some(did) = draft_id {
            params.push(format!("draft_id={}", did));
        }
        Self::new("publish_overview", user_id, &params)
    }

    /// Create a key for platform copy generation requests.
    pub fn suggest_platform_copy(
        user_id: Uuid,
        project_id: Uuid,
        draft_id: Uuid,
        style_hint: Option<&str>,
    ) -> Self {
        let mut params = vec![project_id.to_string(), draft_id.to_string()];
        if let Some(hint) = style_hint {
            params.push(format!("style={}", hint));
        }
        Self::new("suggest_platform_copy", user_id, &params)
    }
}

impl fmt::Display for RequestDedupeKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}:{}:{}",
            self.operation,
            self.user_id,
            self.params.join(",")
        )
    }
}

/// Shared state for in-flight requests.
type InFlightRequest<T> = Arc<Mutex<Option<Arc<T>>>>;

/// Request deduplication cache.
pub struct RequestDedupeCache<T: Clone + Send + Sync + 'static> {
    /// In-flight requests (locked until completion)
    in_flight: Cache<RequestDedupeKey, InFlightRequest<T>>,
    /// Completed results (short TTL for refresh deduplication)
    results: Cache<RequestDedupeKey, Arc<T>>,
}

impl<T: Clone + Send + Sync + 'static> RequestDedupeCache<T> {
    /// Create a new deduplication cache.
    pub fn new(
        in_flight_ttl: Duration,
        result_ttl: Duration,
        max_capacity: u64,
    ) -> Arc<tokio::sync::RwLock<Self>> {
        Arc::new(tokio::sync::RwLock::new(Self {
            in_flight: Cache::builder()
                .time_to_live(in_flight_ttl)
                .max_capacity(max_capacity)
                .build(),
            results: Cache::builder()
                .time_to_live(result_ttl)
                .max_capacity(max_capacity)
                .build(),
        }))
    }

    /// Execute a request with deduplication.
    pub async fn dedupe<F, Fut>(&self, key: RequestDedupeKey, f: F) -> T
    where
        F: FnOnce() -> Fut,
        Fut: std::future::Future<Output = T>,
    {
        // Check if we have a recent cached result
        if let Some(cached_result) = self.results.get(&key).await {
            tracing::debug!(key = %key, "Request dedupe: cache hit");
            return (*cached_result).clone();
        }

        // Get or create in-flight lock for this key
        let in_flight_lock = self
            .in_flight
            .try_get_with(key.clone(), async {
                Ok::<_, std::convert::Infallible>(Arc::new(Mutex::new(None)))
            })
            .await
            .expect("Infallible");

        // Try to acquire the lock
        let mut guard = in_flight_lock.lock().await;

        // If another request already completed while we were waiting, return its result
        if let Some(result) = guard.as_ref() {
            tracing::debug!(key = %key, "Request dedupe: in-flight hit");
            return (**result).clone();
        }

        // We're the first request - execute the operation
        tracing::debug!(key = %key, "Request dedupe: executing");
        let result = f().await;
        let result_arc = Arc::new(result);

        // Store the result for other waiting requests
        *guard = Some(result_arc.clone());

        // Cache the result for future requests
        self.results.insert(key.clone(), result_arc.clone()).await;

        // Remove from in-flight (will be cleaned up by TTL anyway)
        self.in_flight.invalidate(&key).await;

        (*result_arc).clone()
    }
}

/// Global deduplication cache for project overview requests.
static PROJECT_OVERVIEW_CACHE: once_cell::sync::Lazy<
    Arc<tokio::sync::RwLock<RequestDedupeCache<serde_json::Value>>>,
> = once_cell::sync::Lazy::new(|| {
    RequestDedupeCache::new(
        Duration::from_secs(30), // in-flight TTL
        // Keep only near-zero reuse across sequential requests; freshness matters after writes.
        Duration::from_millis(1),
        1000, // max capacity
    )
});

/// Global deduplication cache for publish overview requests.
static PUBLISH_OVERVIEW_CACHE: once_cell::sync::Lazy<
    Arc<tokio::sync::RwLock<RequestDedupeCache<serde_json::Value>>>,
> = once_cell::sync::Lazy::new(|| {
    RequestDedupeCache::new(
        Duration::from_secs(30), // in-flight TTL
        Duration::from_secs(5),  // result TTL
        1000,                    // max capacity
    )
});

/// Global deduplication cache for platform copy generation requests.
static PLATFORM_COPY_CACHE: once_cell::sync::Lazy<
    Arc<tokio::sync::RwLock<RequestDedupeCache<serde_json::Value>>>,
> = once_cell::sync::Lazy::new(|| {
    RequestDedupeCache::new(
        Duration::from_secs(60), // in-flight TTL (generation can take longer)
        Duration::from_secs(10), // result TTL
        500,                     // max capacity
    )
});

/// Deduplicate a project overview request.
pub async fn dedupe_project_overview<F, Fut>(
    key: RequestDedupeKey,
    f: F,
) -> Result<serde_json::Value, ApiError>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = Result<serde_json::Value, ApiError>>,
{
    let cache = PROJECT_OVERVIEW_CACHE.read().await;
    let result = cache
        .dedupe(key.clone(), || async {
            match f().await {
                Ok(val) => val,
                Err(e) => {
                    // Return error as JSON value to cache it
                    serde_json::json!({ "error": format!("{:?}", e) })
                }
            }
        })
        .await;

    // Check if result is an error
    if let Some(err_str) = result.get("error").and_then(|v| v.as_str()) {
        return Err(ApiError::BadRequest(err_str.to_string()));
    }

    Ok(result)
}

/// Deduplicate a publish overview request.
pub async fn dedupe_publish_overview<F, Fut>(
    key: RequestDedupeKey,
    f: F,
) -> Result<serde_json::Value, ApiError>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = Result<serde_json::Value, ApiError>>,
{
    let cache = PUBLISH_OVERVIEW_CACHE.read().await;
    let result = cache
        .dedupe(key.clone(), || async {
            match f().await {
                Ok(val) => val,
                Err(e) => {
                    // Return error as JSON value to cache it
                    serde_json::json!({ "error": format!("{:?}", e) })
                }
            }
        })
        .await;

    // Check if result is an error
    if let Some(err_str) = result.get("error").and_then(|v| v.as_str()) {
        return Err(ApiError::BadRequest(err_str.to_string()));
    }

    Ok(result)
}

/// Deduplicate a platform copy generation request.
pub async fn dedupe_platform_copy<F, Fut>(
    key: RequestDedupeKey,
    f: F,
) -> Result<serde_json::Value, ApiError>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = Result<serde_json::Value, ApiError>>,
{
    let cache = PLATFORM_COPY_CACHE.read().await;
    let result = cache
        .dedupe(key.clone(), || async {
            match f().await {
                Ok(val) => val,
                Err(e) => {
                    // Return error as JSON value to cache it
                    serde_json::json!({ "error": format!("{:?}", e) })
                }
            }
        })
        .await;

    // Check if result is an error
    if let Some(err_str) = result.get("error").and_then(|v| v.as_str()) {
        return Err(ApiError::BadRequest(err_str.to_string()));
    }

    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_request_dedupe_key_stability() {
        let user_id = Uuid::new_v4();
        let project_id = Uuid::new_v4();

        // Keys with different param order should be equal
        let key1 = RequestDedupeKey::new(
            "test_op",
            user_id,
            &[project_id.to_string(), "param1".to_string()],
        );
        let key2 = RequestDedupeKey::new(
            "test_op",
            user_id,
            &["param1".to_string(), project_id.to_string()],
        );

        assert_eq!(key1, key2);
        assert_eq!(key1.to_string(), key2.to_string());
    }

    #[test]
    fn test_request_dedupe_key_uniqueness() {
        let user_id1 = Uuid::new_v4();
        let user_id2 = Uuid::new_v4();
        let project_id = Uuid::new_v4();

        let key1 = RequestDedupeKey::new("test_op", user_id1, &[project_id.to_string()]);
        let key2 = RequestDedupeKey::new("test_op", user_id2, &[project_id.to_string()]);

        assert_ne!(key1, key2);
    }

    #[test]
    fn test_project_overview_key() {
        let user_id = Uuid::new_v4();
        let project_id = Uuid::new_v4();

        let key = RequestDedupeKey::project_overview(
            user_id,
            project_id,
            &["include_quality", "include_tasks"],
        );

        assert_eq!(key.operation, "project_overview");
        assert_eq!(key.user_id, user_id);
        assert!(key.params.contains(&project_id.to_string()));
        assert!(key.params.contains(&"include_quality".to_string()));
        assert!(key.params.contains(&"include_tasks".to_string()));
    }

    #[test]
    fn test_publish_overview_key() {
        let user_id = Uuid::new_v4();
        let project_id = Uuid::new_v4();
        let draft_id = Uuid::new_v4();

        let key = RequestDedupeKey::publish_overview(user_id, project_id, Some(draft_id), 30);

        assert_eq!(key.operation, "publish_overview");
        assert_eq!(key.user_id, user_id);
        assert!(key.params.contains(&project_id.to_string()));
        assert!(key.params.contains(&format!("draft_id={}", draft_id)));
        assert!(key.params.contains(&"audit_limit=30".to_string()));
    }

    #[test]
    fn test_suggest_platform_copy_key() {
        let user_id = Uuid::new_v4();
        let project_id = Uuid::new_v4();
        let draft_id = Uuid::new_v4();

        let key1 =
            RequestDedupeKey::suggest_platform_copy(user_id, project_id, draft_id, Some("casual"));
        let key2 =
            RequestDedupeKey::suggest_platform_copy(user_id, project_id, draft_id, Some("formal"));

        assert_eq!(key1.operation, "suggest_platform_copy");
        assert_ne!(key1, key2); // Different style hints should produce different keys
    }

    #[tokio::test]
    async fn test_dedupe_cache_basic() {
        let cache =
            RequestDedupeCache::<i32>::new(Duration::from_secs(10), Duration::from_secs(5), 100);
        let cache = cache.read().await;

        let key = RequestDedupeKey::new("test", Uuid::new_v4(), &["param1".to_string()]);

        let mut call_count = 0;
        let result1 = cache
            .dedupe(key.clone(), || async {
                call_count += 1;
                42
            })
            .await;

        assert_eq!(result1, 42);
        assert_eq!(call_count, 1);

        // Second call should use cached result
        let result2 = cache
            .dedupe(key.clone(), || async {
                call_count += 1;
                99
            })
            .await;

        assert_eq!(result2, 42); // Should return cached result, not 99
        assert_eq!(call_count, 1); // Function should not be called again
    }

    #[tokio::test]
    async fn test_dedupe_cache_concurrent() {
        let cache =
            RequestDedupeCache::<i32>::new(Duration::from_secs(10), Duration::from_secs(5), 100);

        let key = RequestDedupeKey::new("test", Uuid::new_v4(), &["param1".to_string()]);

        let call_count = Arc::new(tokio::sync::Mutex::new(0));

        // Spawn 10 concurrent requests
        let mut handles = vec![];
        for _ in 0..10 {
            let cache = cache.clone();
            let key = key.clone();
            let call_count = call_count.clone();

            let handle = tokio::spawn(async move {
                let cache = cache.read().await;
                cache
                    .dedupe(key, || async {
                        let mut count = call_count.lock().await;
                        *count += 1;
                        tokio::time::sleep(Duration::from_millis(100)).await;
                        42
                    })
                    .await
            });
            handles.push(handle);
        }

        // Wait for all requests to complete
        let results: Vec<_> = futures::future::join_all(handles).await;

        // All requests should succeed with the same result
        for result in results {
            assert_eq!(result.unwrap(), 42);
        }

        // Function should only be called once despite 10 concurrent requests
        let final_count = *call_count.lock().await;
        assert_eq!(final_count, 1);
    }
}
