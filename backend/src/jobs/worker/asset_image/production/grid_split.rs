//! Split a storyboard grid image into equal cells (row-major).

use image::GenericImageView;

use crate::jobs::worker::common::JobRunError;

const MAX_GRID_CELLS: u32 = 12;

pub(crate) fn validate_grid_dimensions(
    rows: u32,
    cols: u32,
    shot_count: usize,
) -> Result<(), JobRunError> {
    if rows == 0 || cols == 0 {
        return Err(JobRunError::Failed("rows and cols must be positive".into()));
    }
    let cells = rows
        .checked_mul(cols)
        .ok_or_else(|| JobRunError::Failed("rows * cols overflow".into()))?;
    if cells > MAX_GRID_CELLS {
        return Err(JobRunError::Failed(format!(
            "grid cannot exceed {MAX_GRID_CELLS} cells (got {cells})"
        )));
    }
    if shot_count != cells as usize {
        return Err(JobRunError::Failed(format!(
            "storyboard count ({shot_count}) must equal rows * cols ({cells})"
        )));
    }
    Ok(())
}

pub(crate) fn split_grid_image_bytes(
    bytes: &[u8],
    rows: u32,
    cols: u32,
) -> Result<Vec<Vec<u8>>, JobRunError> {
    validate_grid_dimensions(rows, cols, (rows * cols) as usize)?;

    let img = image::load_from_memory(bytes)
        .map_err(|e| JobRunError::Failed(format!("decode grid image: {e}")))?;
    let (width, height) = img.dimensions();
    if width < cols || height < rows {
        return Err(JobRunError::Failed(format!(
            "grid image {width}x{height} too small for {cols}x{rows} split"
        )));
    }

    let cell_w = width / cols;
    let cell_h = height / rows;
    if cell_w == 0 || cell_h == 0 {
        return Err(JobRunError::Failed("grid cell size is zero".into()));
    }

    let mut out = Vec::with_capacity((rows * cols) as usize);
    for row in 0..rows {
        for col in 0..cols {
            let x = col * cell_w;
            let y = row * cell_h;
            let cell = img.crop_imm(x, y, cell_w, cell_h);
            let mut buf = Vec::new();
            cell.write_to(&mut std::io::Cursor::new(&mut buf), image::ImageFormat::Png)
                .map_err(|e| JobRunError::Failed(format!("encode grid cell: {e}")))?;
            out.push(buf);
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::{split_grid_image_bytes, validate_grid_dimensions};
    use image::{ImageBuffer, Rgb};

    #[test]
    fn validate_grid_dimensions_rejects_mismatch() {
        assert!(validate_grid_dimensions(2, 2, 3).is_err());
    }

    #[test]
    fn split_grid_image_bytes_produces_expected_cell_count() {
        let mut img = ImageBuffer::new(4, 4);
        for pixel in img.pixels_mut() {
            *pixel = Rgb([40, 80, 120]);
        }
        let mut full = Vec::new();
        image::DynamicImage::ImageRgb8(img)
            .write_to(
                &mut std::io::Cursor::new(&mut full),
                image::ImageFormat::Png,
            )
            .expect("encode png");

        let cells = match split_grid_image_bytes(&full, 2, 2) {
            Ok(cells) => cells,
            Err(_) => panic!("split failed"),
        };
        assert_eq!(cells.len(), 4);
        for cell in cells {
            assert!(!cell.is_empty());
        }
    }
}
