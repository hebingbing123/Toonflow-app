use crate::http_kit::json_patch::FieldPatch;

/// Stable key for `pg_advisory_xact_lock` when allocating `app_project.numeric_id` (global uniqueness).
pub(super) const ADV_LOCK_PROJECT_NUMERIC_ID: i64 = 884_422_001;

pub(super) fn trim_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

pub(super) fn merge_text_patch(
    current: &Option<String>,
    patch: FieldPatch<String>,
) -> Option<String> {
    match patch {
        FieldPatch::Absent => current.clone(),
        FieldPatch::Set(v) => v,
    }
}
