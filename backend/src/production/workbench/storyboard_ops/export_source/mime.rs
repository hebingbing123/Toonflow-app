pub(super) fn mime_to_extension(mime: &str) -> Option<&'static str> {
    let bare = mime.split(';').next()?.trim().to_ascii_lowercase();
    match bare.as_str() {
        "image/png" => Some("png"),
        "image/jpeg" => Some("jpg"),
        "image/webp" => Some("webp"),
        "image/gif" => Some("gif"),
        "image/svg+xml" => Some("svg"),
        _ => None,
    }
}
