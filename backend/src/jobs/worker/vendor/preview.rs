pub(super) const VENDOR_MODEL_TEST_PREVIEW_CHARS: usize = 160;

pub(super) fn clip_preview(text: &str, max_chars: usize) -> String {
    let trimmed = text.trim();
    if trimmed.chars().count() <= max_chars {
        return trimmed.to_string();
    }
    let mut clipped = trimmed.chars().take(max_chars).collect::<String>();
    clipped.push_str("...");
    clipped
}
