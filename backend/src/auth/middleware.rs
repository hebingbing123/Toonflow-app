use axum::{extract::State, http::Method, middleware::Next, response::Response};

use crate::error::ApiError;
use crate::state::AppState;

use super::api_keys::{
    bearer_or_api_key_token, inject_auth_headers, resolve_api_key_request, touch_api_key_usage,
    ApiKeyScope,
};
use super::maybe_authenticated_user_uuid;

fn is_safe_method(method: &Method) -> bool {
    matches!(*method, Method::GET | Method::HEAD | Method::OPTIONS)
}

pub async fn api_key_auth_middleware(
    State(state): State<AppState>,
    mut req: axum::extract::Request,
    next: Next,
) -> Result<Response, ApiError> {
    let Some(token) = bearer_or_api_key_token(req.headers()).map(str::to_string) else {
        return Ok(next.run(req).await);
    };
    let Some((api_key_id, user_id, scope)) = resolve_api_key_request(&state, &token).await? else {
        return Ok(next.run(req).await);
    };
    if scope == ApiKeyScope::ReadOnly && !is_safe_method(req.method()) {
        return Err(ApiError::Forbidden(
            "read_only api key cannot call mutating endpoints".into(),
        ));
    }
    inject_auth_headers(req.headers_mut(), user_id, api_key_id, scope)?;
    touch_api_key_usage(
        &state,
        api_key_id,
        req.method(),
        req.uri().path(),
        req.headers(),
    )
    .await?;
    Ok(next.run(req).await)
}

pub async fn user_governance_middleware(
    State(state): State<AppState>,
    req: axum::extract::Request,
    next: Next,
) -> Result<Response, ApiError> {
    let Some(user_id) = maybe_authenticated_user_uuid(&state, req.headers())? else {
        return Ok(next.run(req).await);
    };
    let Some(pool) = state.pool.as_ref() else {
        return Ok(next.run(req).await);
    };
    let row: Option<(String, Option<String>)> = sqlx::query_as(
        r#"
        SELECT operational_status, operational_status_reason
        FROM public.app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if let Some((status, reason)) = row {
        if status == "suspended" {
            let suffix = reason
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(|value| format!(" ({value})"))
                .unwrap_or_default();
            return Err(ApiError::Forbidden(format!(
                "user account is suspended{suffix}"
            )));
        }
    }
    Ok(next.run(req).await)
}
