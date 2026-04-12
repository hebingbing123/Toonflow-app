//! 脚本 REST 路由（`GET`/`POST /api/v1/scripts/*` 与项目段脚本 API）。
//!
//! 脚本 CRUD、导出/抽取轮询、**`POST …/projects/{project_id}/scripts/get-script-api`** 列表等。

mod crud;
mod export_poll;
mod get_script_api;
mod types;

#[allow(unused_imports)]
pub use types::ScriptRow;

use axum::routing::{get, post};
use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/scripts/export",
            post(export_poll::export_scripts_zip),
        )
        .route(
            "/api/v1/scripts/extract-state/poll",
            post(export_poll::poll_script_extract_state),
        )
        .route(
            "/api/v1/projects/{project_id}/scripts",
            post(crud::create_script_under_project_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/scripts/batch-add",
            post(crud::post_scripts_batch_add_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/scripts/{script_numeric_id}",
            get(crud::get_script_for_project)
                .patch(crud::patch_script_for_project)
                .delete(crud::delete_script_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/scripts/get-script-api",
            post(get_script_api::post_get_script_api_for_project),
        )
}

#[cfg(test)]
mod tests {
    use super::export_poll::{build_scripts_zip, zip_entry_name};
    use super::types::{
        BatchAddScriptDataBody, CreateScriptBody, ExportScriptsBody, PatchScriptBody,
    };

    #[test]
    fn patch_script_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<PatchScriptBody>(r#"{"name":"a","extra":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn create_script_body_accepts_empty() {
        let b: CreateScriptBody = serde_json::from_str("{}").unwrap();
        assert!(b.name.is_none());
    }

    #[test]
    fn create_script_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<CreateScriptBody>(r#"{"name":"a","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn batch_add_script_data_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<BatchAddScriptDataBody>(r#"{"data":[],"extra":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn export_scripts_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<ExportScriptsBody>(r#"{"numeric_ids":[1],"x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn zip_entry_name_sanitizes_path_chars() {
        assert_eq!(zip_entry_name(3, Some("a/b")), "3_a_b.txt");
        assert_eq!(zip_entry_name(1, None), "1_script.txt");
    }

    #[test]
    fn build_scripts_zip_roundtrip() {
        let rows = vec![(1, Some("n".into()), Some("hello".into())), (2, None, None)];
        let zip_bytes = build_scripts_zip(rows).expect("zip");
        assert!(zip_bytes.len() > 20);
    }
}
