/// DALL-E 3 **`prompt`** cap (characters).
pub(super) const DALLE3_MAX_PROMPT_CHARS: usize = 4_000;

pub(super) fn clip_prompt_chars(s: &str, max_chars: usize) -> String {
    let n = s.chars().count();
    if n <= max_chars {
        return s.to_string();
    }
    s.chars().take(max_chars).collect()
}

/// Picks an OpenAI **`images/generations`** model id from the vendor catalog string (e.g. **`1:dall-e-3`**) or **`OPENFLOW_IMAGE_MODEL`**, default **`dall-e-3`**.
pub fn resolve_openai_image_model(request_model: &str) -> String {
    let lower = request_model.to_lowercase();
    if lower.contains("dall-e-2") || lower.contains("dalle-2") {
        return "dall-e-2".into();
    }
    if lower.contains("dall-e-3") || lower.contains("dalle-3") {
        return "dall-e-3".into();
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
