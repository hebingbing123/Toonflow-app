use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

pub(crate) const MAX_PINNED_PROJECTS: usize = 8;

#[derive(Debug, Clone, Default, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StudioUiPrefsResponse {
    #[serde(default)]
    pub pinned_project_ids: Vec<String>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct PutStudioUiPrefsBody {
    #[serde(default)]
    pub pinned_project_ids: Vec<String>,
}

pub(crate) fn normalize_pinned_project_ids(raw: Vec<String>) -> Result<Vec<String>, String> {
    let mut out = Vec::new();
    for id in raw {
        let trimmed = id.trim();
        if trimmed.is_empty() {
            continue;
        }
        let parsed =
            Uuid::parse_str(trimmed).map_err(|_| format!("invalid project uuid: {trimmed}"))?;
        let canonical = parsed.to_string();
        if !out.iter().any(|existing| existing == &canonical) {
            out.push(canonical);
        }
        if out.len() > MAX_PINNED_PROJECTS {
            return Err(format!(
                "pinned_project_ids exceeds max {MAX_PINNED_PROJECTS}"
            ));
        }
    }
    Ok(out)
}
