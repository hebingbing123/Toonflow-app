//! Project generation profile (**draft / standard / premium**) for cost–quality tradeoffs.

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum GenerationProfileTier {
    Draft,
    Standard,
    Premium,
}

impl GenerationProfileTier {
    fn parse(raw: &str) -> Self {
        match raw.trim().to_lowercase().as_str() {
            "draft" | "lean" => Self::Draft,
            "premium" | "expanded" => Self::Premium,
            _ => Self::Standard,
        }
    }

    #[must_use]
    pub(crate) fn default_memory_budget_tier(self) -> &'static str {
        match self {
            Self::Draft => "lean",
            Self::Standard => "lean",
            Self::Premium => "expanded",
        }
    }

    #[must_use]
    pub(crate) fn max_batch_candidate_clips(self) -> usize {
        match self {
            Self::Draft => 1,
            Self::Standard => 2,
            Self::Premium => 4,
        }
    }
}

#[derive(Debug, Clone)]
pub(crate) struct GenerationProfile {
    pub(crate) tier: GenerationProfileTier,
}

impl GenerationProfile {
    #[must_use]
    pub(crate) fn from_env_or_default() -> Self {
        let tier = std::env::var("OPENFLOW_GENERATION_PROFILE")
            .ok()
            .map(|v| GenerationProfileTier::parse(&v))
            .unwrap_or(GenerationProfileTier::Standard);
        Self { tier }
    }
}

pub(crate) async fn load_project_generation_profile(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<GenerationProfile, ApiError> {
    let metadata: Option<serde_json::Value> = sqlx::query_scalar(
        r#"
        SELECT metadata
        FROM app_project
        WHERE id = $1
        "#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let tier = metadata
        .as_ref()
        .and_then(|m| m.get("shortVideo"))
        .and_then(|sv| sv.get("generationProfile"))
        .and_then(|v| v.as_str())
        .map(GenerationProfileTier::parse)
        .unwrap_or_else(|| GenerationProfile::from_env_or_default().tier);
    Ok(GenerationProfile { tier })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn profile_tier_parsing() {
        assert_eq!(
            GenerationProfileTier::parse("premium"),
            GenerationProfileTier::Premium
        );
        assert_eq!(
            GenerationProfileTier::parse("DRAFT"),
            GenerationProfileTier::Draft
        );
        assert_eq!(
            GenerationProfileTier::parse("unknown"),
            GenerationProfileTier::Standard
        );
    }

    #[test]
    fn batch_caps_scale_with_tier() {
        assert_eq!(GenerationProfileTier::Draft.max_batch_candidate_clips(), 1);
        assert!(
            GenerationProfileTier::Premium.max_batch_candidate_clips()
                > GenerationProfileTier::Standard.max_batch_candidate_clips()
        );
    }
}
