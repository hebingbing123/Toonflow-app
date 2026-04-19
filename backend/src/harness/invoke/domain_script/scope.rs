use super::super::{project_numeric_from_ctx, require_pool, InvokeError};
use crate::harness::HarnessContext;
use crate::scope::{OwnedScriptScope, ScopeError};

pub(crate) async fn require_owned_script_scope(
    ctx: &HarnessContext,
    script_numeric_id: i32,
) -> Result<OwnedScriptScope, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    crate::scope::owned_script_scope(pool, ctx.user_id, project_numeric_id, script_numeric_id)
        .await
        .map_err(|e| match e {
            ScopeError::NotFound => {
                InvokeError::MissingContext("script not found in attached project".into())
            }
            ScopeError::Database(msg) => InvokeError::DatabaseError(msg),
        })
}
