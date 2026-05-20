/// DALL-E 3 **`prompt`** cap (characters).
pub(super) const DALLE3_MAX_PROMPT_CHARS: usize = 4_000;

pub(super) fn clip_prompt_chars(s: &str, max_chars: usize) -> String {
    let n = s.chars().count();
    if n <= max_chars {
        return s.to_string();
    }
    s.chars().take(max_chars).collect()
}

/// API model id for image generation (strips catalog composite prefix when present).
pub fn resolve_openai_image_model(request_model: &str) -> String {
    let bare = request_model
        .split_once(':')
        .map(|(_, name)| name)
        .unwrap_or(request_model)
        .trim();
    let lower = bare.to_lowercase();
    if lower.contains("dall-e-2") || lower.contains("dalle-2") {
        return "dall-e-2".into();
    }
    if lower.contains("dall-e-3") || lower.contains("dalle-3") {
        return "dall-e-3".into();
    }
    if lower.contains("seedream")
        || lower.contains("wanx")
        || lower.contains("imagen")
        || lower.contains("cogview")
    {
        return bare.to_string();
    }
    if !bare.is_empty() && bare.contains('-') {
        return bare.to_string();
    }
    std::env::var("OPENFLOW_IMAGE_MODEL")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "dall-e-3".into())
}

/// Maps Electron-era **`resolution`** (e.g. **`1024x1024`**) to an OpenAI **`size`** for the chosen model.
pub fn resolve_openai_image_size(model: &str, resolution: &str) -> &'static str {
    let m = model.to_lowercase();
    let r = resolution.to_lowercase().replace('×', "x").replace(' ', "");
    if m.contains("dall-e-3") || m.contains("dalle-3") {
        return match r.as_str() {
            "1792x1024" => "1792x1024",
            "1024x1792" => "1024x1792",
            _ => "1024x1024",
        };
    }
    match r.as_str() {
        "256x256" => "256x256",
        "512x512" => "512x512",
        "1024x1024" => "1024x1024",
        _ => "1024x1024",
    }
}
