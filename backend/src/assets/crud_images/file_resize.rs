//! Optional downscale for locally served asset image bytes (`?max_edge=`).

use image::imageops::FilterType;
use image::GenericImageView;

use crate::error::{bad_request_i18n, ApiError};

const MIN_MAX_EDGE: u32 = 64;
const MAX_MAX_EDGE: u32 = 4096;

/// Downscales [input] so its longest edge is at most [max_edge], preserving format when possible.
pub fn downscale_image_bytes(input: &[u8], max_edge: u32) -> Result<Vec<u8>, ApiError> {
    let max_edge = max_edge.clamp(MIN_MAX_EDGE, MAX_MAX_EDGE);
    let img = image::load_from_memory(input).map_err(|_| {
        bad_request_i18n(
            "asset image bytes are not a supported raster format",
            "资产图片不是支持的栅格格式",
        )
    })?;
    let (w, h) = img.dimensions();
    if w <= max_edge && h <= max_edge {
        return Ok(input.to_vec());
    }
    let resized = img.resize(max_edge, max_edge, FilterType::Lanczos3);
    let mut out = Vec::new();
    let mut cursor = std::io::Cursor::new(&mut out);
    // PNG keeps alpha; local asset dir stores `.png` today.
    resized
        .write_to(&mut cursor, image::ImageFormat::Png)
        .map_err(|_| ApiError::Internal)?;
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{ImageBuffer, Rgba};

    #[test]
    fn downscale_skips_when_already_small() {
        let img: ImageBuffer<Rgba<u8>, Vec<u8>> =
            ImageBuffer::from_pixel(32, 32, Rgba([1, 2, 3, 255]));
        let mut bytes = Vec::new();
        img.write_to(
            &mut std::io::Cursor::new(&mut bytes),
            image::ImageFormat::Png,
        )
        .unwrap();
        let out = downscale_image_bytes(&bytes, 512).unwrap();
        assert_eq!(out, bytes);
    }

    #[test]
    fn downscale_reduces_large_png() {
        let img: ImageBuffer<Rgba<u8>, Vec<u8>> =
            ImageBuffer::from_pixel(800, 600, Rgba([10, 20, 30, 255]));
        let mut bytes = Vec::new();
        img.write_to(
            &mut std::io::Cursor::new(&mut bytes),
            image::ImageFormat::Png,
        )
        .unwrap();
        let out = downscale_image_bytes(&bytes, 256).unwrap();
        let decoded = image::load_from_memory(&out).unwrap();
        assert!(decoded.width() <= 256);
        assert!(decoded.height() <= 256);
    }
}
