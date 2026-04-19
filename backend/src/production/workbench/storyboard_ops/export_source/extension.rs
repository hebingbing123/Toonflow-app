use std::borrow::Cow;
use std::path::Path;

use super::mime::mime_to_extension;

pub(in crate::production::workbench::storyboard_ops) fn infer_export_extension(
    file_path: &str,
    content_type: Option<&str>,
) -> Cow<'static, str> {
    if let Some(ext) = Path::new(file_path)
        .extension()
        .and_then(|s| s.to_str())
        .filter(|s| !s.is_empty())
    {
        return Cow::Owned(ext.to_ascii_lowercase());
    }

    if let Some(content_type) = content_type {
        if let Some(ext) = mime_to_extension(content_type) {
            return Cow::Borrowed(ext);
        }
    }

    Cow::Borrowed("png")
}
