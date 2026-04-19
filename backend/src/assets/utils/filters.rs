use crate::error::ApiError;

pub(in crate::assets) fn normalize_optional_trimmed_text(raw: Option<String>) -> Option<String> {
    raw.map(|s| s.trim().to_string()).filter(|s| !s.is_empty())
}

pub(in crate::assets) fn normalize_list_asset_type_filter(
    raw: Option<String>,
) -> Result<Option<String>, ApiError> {
    let Some(s) = raw else {
        return Ok(None);
    };
    let t = s.trim().to_lowercase();
    if t.is_empty() {
        return Ok(None);
    }
    if t != "role" && t != "tool" && t != "scene" {
        return Err(ApiError::BadRequest(
            "asset_type must be role, tool, or scene".into(),
        ));
    }
    Ok(Some(t))
}

pub(in crate::assets) fn normalize_name_ilike(raw: Option<String>) -> Option<String> {
    raw.and_then(|s| {
        let t = s.trim();
        if t.is_empty() {
            None
        } else {
            Some(format!("%{t}%"))
        }
    })
}

pub(in crate::assets) fn normalize_corner_types_filter(
    raw: Option<Vec<String>>,
) -> Result<Option<Vec<String>>, ApiError> {
    let Some(list) = raw else {
        return Ok(None);
    };
    if list.is_empty() {
        return Ok(None);
    }
    let mut out = Vec::new();
    for s in list {
        let t = s.trim().to_lowercase();
        if t.is_empty() {
            continue;
        }
        if t != "role" && t != "scene" && t != "tool" {
            return Err(ApiError::BadRequest(format!(
                "types entries must be role, scene, or tool (got {s:?})"
            )));
        }
        if !out.iter().any(|v| v == &t) {
            out.push(t);
        }
    }
    if out.is_empty() {
        Ok(None)
    } else {
        Ok(Some(out))
    }
}
