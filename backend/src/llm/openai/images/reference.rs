use base64::Engine;

const MAX_REFERENCE_IMAGE_BYTES: usize = 15 * 1024 * 1024;

#[derive(Debug)]
pub(crate) struct ReferenceImageUpload {
    pub(crate) bytes: Vec<u8>,
    pub(crate) mime: &'static str,
    pub(crate) file_name: &'static str,
}

pub(crate) fn parse_reference_image_upload(
    image_base64: &str,
) -> Result<ReferenceImageUpload, String> {
    let trimmed = image_base64.trim();
    if trimmed.is_empty() {
        return Err("reference image base64 is empty".into());
    }

    let (mime, file_name, b64) = match trimmed.strip_prefix("data:") {
        Some(rest) => {
            let (meta, b64) = rest
                .split_once(";base64,")
                .ok_or_else(|| "reference image data URI must be base64".to_string())?;
            let (mime, file_name) = match meta.trim().to_ascii_lowercase().as_str() {
                "image/png" => ("image/png", "reference.png"),
                "image/jpeg" | "image/jpg" => ("image/jpeg", "reference.jpg"),
                "image/webp" => ("image/webp", "reference.webp"),
                other => return Err(format!("unsupported reference image mime: {other}")),
            };
            (mime, file_name, b64.trim())
        }
        None => ("image/jpeg", "reference.jpg", trimmed),
    };

    let bytes = base64::engine::general_purpose::STANDARD
        .decode(b64.as_bytes())
        .map_err(|_| "reference image is not valid base64".to_string())?;
    if bytes.is_empty() {
        return Err("reference image decodes to empty bytes".into());
    }
    if bytes.len() > MAX_REFERENCE_IMAGE_BYTES {
        return Err(format!(
            "reference image exceeds max decoded size ({MAX_REFERENCE_IMAGE_BYTES} bytes)"
        ));
    }

    Ok(ReferenceImageUpload {
        bytes,
        mime,
        file_name,
    })
}
