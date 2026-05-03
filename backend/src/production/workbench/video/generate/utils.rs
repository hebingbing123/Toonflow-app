pub(super) fn infer_video_provider(model: &str) -> &'static str {
    let normalized = model.trim().to_ascii_lowercase();
    if normalized.contains("kling") || normalized.contains("可灵") {
        "kling"
    } else if normalized.contains("pika") {
        "pika"
    } else {
        "runway"
    }
}
