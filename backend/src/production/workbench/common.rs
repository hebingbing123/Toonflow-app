use crate::error::ApiError;
use crate::state::AppState;

pub(crate) fn require_pool(state: &AppState) -> Result<&sqlx::PgPool, ApiError> {
    state.require_pool()
}

pub(crate) fn require_positive_project_script(
    project_id: i32,
    script_id: i32,
) -> Result<(), ApiError> {
    if project_id <= 0 || script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    Ok(())
}
