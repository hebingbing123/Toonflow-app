use crate::error::ApiError;
use crate::state::AppState;

pub(crate) fn require_pool(state: &AppState) -> Result<&sqlx::PgPool, ApiError> {
    state.require_pool()
}
