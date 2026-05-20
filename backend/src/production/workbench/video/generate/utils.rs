use crate::vendor::catalog::protocol::resolve_video_provider_slug;

/// Provider slug for [`VideoProvider`] job payload (`runway`, `doubao`, …).
pub(super) fn infer_video_provider(model: &str) -> &'static str {
    let trimmed = model.trim();
    if let Some((vid, model_name)) = trimmed.split_once(':') {
        if let Some(slug) = resolve_video_provider_slug(vid, model_name) {
            return slug.as_str();
        }
    }
    if let Some(slug) = resolve_video_provider_slug(trimmed, trimmed) {
        return slug.as_str();
    }

    let normalized = trimmed.to_ascii_lowercase();
    if normalized.contains("kling") || normalized.contains("可灵") {
        "kling"
    } else if normalized.contains("pika") {
        "pika"
    } else if normalized.contains("doubao")
        || normalized.contains("seedance")
        || normalized.contains("volcengine")
    {
        "doubao"
    } else if normalized.contains("hunyuan") || normalized.contains("混元") {
        "hunyuan"
    } else if normalized.contains("minimax") || normalized.contains("hailuo") {
        "minimax"
    } else if normalized.contains("sora") || normalized.contains("openai") {
        "openai"
    } else {
        "runway"
    }
}

/// API model name sent to vendor HTTP (strips catalog composite id prefix).
pub(super) fn video_api_model_name(model: &str) -> String {
    let trimmed = model.trim();
    if let Some((vid, model_name)) = trimmed.split_once(':') {
        if vid.parse::<i32>().is_ok() {
            return model_name.trim().to_string();
        }
    }
    trimmed.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn infer_from_catalog_composite_id() {
        assert_eq!(infer_video_provider("20:doubao-seedance-1-0-pro"), "doubao");
        assert_eq!(infer_video_provider("21:hunyuan-video"), "hunyuan");
        assert_eq!(infer_video_provider("4:kling-v1"), "kling");
    }

    #[test]
    fn api_model_strips_vendor_prefix() {
        assert_eq!(
            video_api_model_name("20:doubao-seedance-1-0-pro"),
            "doubao-seedance-1-0-pro"
        );
        assert_eq!(video_api_model_name("kling-v1"), "kling-v1");
    }
}
