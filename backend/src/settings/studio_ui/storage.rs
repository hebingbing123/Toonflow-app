use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

use super::types::{normalize_pinned_project_ids, StudioUiPrefsResponse};

#[derive(Debug, Default, serde::Deserialize)]
struct StudioUiPrefsDoc {
    #[serde(default, rename = "pinnedProjectIds")]
    pinned_project_ids: Vec<String>,
    #[serde(default, rename = "pinned_project_ids")]
    pinned_project_ids_snake: Vec<String>,
}

impl StudioUiPrefsDoc {
    fn merged_ids(self) -> Vec<String> {
        if !self.pinned_project_ids.is_empty() {
            return self.pinned_project_ids;
        }
        self.pinned_project_ids_snake
    }
}

pub(crate) async fn load_studio_ui_prefs(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<StudioUiPrefsResponse, ApiError> {
    let raw: Option<serde_json::Value> = sqlx::query_scalar(
        r#"SELECT studio_ui_prefs FROM public.app_user_profile WHERE user_id = $1"#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let doc = raw
        .map(|value| serde_json::from_value::<StudioUiPrefsDoc>(value).unwrap_or_default())
        .unwrap_or_default();
    let ids = normalize_pinned_project_ids(doc.merged_ids()).map_err(ApiError::BadRequest)?;
    Ok(StudioUiPrefsResponse {
        pinned_project_ids: ids,
    })
}

pub(crate) async fn save_studio_ui_prefs(
    pool: &PgPool,
    user_id: Uuid,
    prefs: &StudioUiPrefsResponse,
) -> Result<(), ApiError> {
    let payload = serde_json::json!({
        "pinnedProjectIds": prefs.pinned_project_ids,
    });
    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, studio_ui_prefs, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          studio_ui_prefs = EXCLUDED.studio_ui_prefs,
          updated_at = NOW()
        "#,
    )
    .bind(user_id)
    .bind(payload)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
