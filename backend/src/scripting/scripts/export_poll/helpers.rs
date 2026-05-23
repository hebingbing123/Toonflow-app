use crate::error::ApiError;

pub(in crate::scripting::scripts) fn normalize_numeric_id_list(
    mut ids: Vec<i32>,
    max_len: usize,
) -> Result<Vec<i32>, ApiError> {
    ids.retain(|id| *id > 0);
    ids.sort_unstable();
    ids.dedup();
    if ids.is_empty() {
        return Err(ApiError::BadRequest(
            "numeric_ids must be non-empty (positive integers)".into(),
        ));
    }
    if ids.len() > max_len {
        return Err(ApiError::BadRequest(format!(
            "at most {max_len} numeric_ids per request"
        )));
    }
    Ok(ids)
}

pub(in crate::scripting::scripts) fn zip_entry_name(numeric_id: i32, name: Option<&str>) -> String {
    let base_raw = name
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or("script");
    let safe: String = base_raw
        .chars()
        .map(|c| match c {
            '/' | '\\' | ':' | '\0' | '\r' | '\n' => '_',
            c if c.is_control() => '_',
            c => c,
        })
        .take(180)
        .collect();
    let base = if safe.is_empty() {
        "script"
    } else {
        safe.as_str()
    };
    format!("{numeric_id}_{base}.txt")
}

pub(in crate::scripting::scripts) fn build_scripts_zip(
    rows: Vec<(i32, Option<String>, Option<String>)>,
) -> Result<Vec<u8>, zip::result::ZipError> {
    use std::io::Write;
    use zip::write::FileOptions;
    use zip::{CompressionMethod, ZipWriter};

    let mut cursor = std::io::Cursor::new(Vec::new());
    {
        let mut zip = ZipWriter::new(&mut cursor);
        let options = FileOptions::default().compression_method(CompressionMethod::Deflated);
        for (numeric_id, name, content) in rows {
            let path = zip_entry_name(numeric_id, name.as_deref());
            zip.start_file(path, options)?;
            zip.write_all(content.unwrap_or_default().as_bytes())?;
        }
        zip.finish()?;
    }
    Ok(cursor.into_inner())
}

#[cfg(test)]
mod tests {
    use super::normalize_numeric_id_list;

    #[test]
    fn normalize_rejects_empty_after_filter() {
        let err = normalize_numeric_id_list(vec![], 8).unwrap_err();
        assert!(matches!(err, crate::error::ApiError::BadRequest(_)));
        let err = normalize_numeric_id_list(vec![0, -1], 8).unwrap_err();
        assert!(matches!(err, crate::error::ApiError::BadRequest(_)));
    }
}
