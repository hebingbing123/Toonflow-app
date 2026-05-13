use serde_json::json;

use crate::error::ApiError;
use crate::jobs::payload_project::{
    payload_project_numeric_id, payload_project_uuid, payload_workspace_id,
};
use crate::settings::notifications::{record_notification, NotificationRecordPayload};
use crate::state::AppState;

use super::dto::JobRow;

pub(crate) async fn record_job_notification(
    state: &AppState,
    row: &JobRow,
) -> Result<(), ApiError> {
    // Keep notification_type aligned with docs/websocket-events.md producer list.
    let status = row.status.trim();
    if status != "succeeded" && status != "failed" && status != "cancelled" {
        return Ok(());
    }
    let title = job_notification_title(row);
    let message = job_notification_message(row);
    let workspace_id = payload_workspace_id(&row.payload);
    let project_id = payload_project_uuid(&row.payload);
    let project_numeric_id = payload_project_numeric_id(&row.payload);
    let link_path = format!("/product/jobs?jobId={}", row.id);
    let _ = record_notification(
        state.require_pool()?,
        Some(&state.notify),
        NotificationRecordPayload {
            user_id: row.owner_user_id,
            workspace_id,
            project_id,
            project_numeric_id,
            job_id: Some(row.id),
            notification_type: format!("job_{status}"),
            title,
            message,
            link_path: Some(link_path),
            payload: json!({
                "jobId": row.id,
                "numericTaskId": row.numeric_task_id,
                "kind": row.kind,
                "status": row.status,
                "jobSubKind": row.job_sub_kind,
                "productionPhase": row.production_phase,
                "projectId": project_id,
                "projectUuid": project_id,
                "projectNumericId": project_numeric_id,
                "workspaceId": workspace_id,
            }),
            file_path: None,
            changed_at: None,
        },
    )
    .await?;
    Ok(())
}

fn job_notification_title(row: &JobRow) -> String {
    match row.status.as_str() {
        "succeeded" => format!("任务完成 · {}", row.kind),
        "failed" => format!("任务失败 · {}", row.kind),
        "cancelled" => format!("任务已取消 · {}", row.kind),
        _ => format!("任务状态更新 · {}", row.kind),
    }
}

fn job_notification_message(row: &JobRow) -> String {
    let phase = row
        .production_phase
        .as_deref()
        .filter(|value| !value.trim().is_empty())
        .map(|value| format!("，阶段 {value}"))
        .unwrap_or_default();
    match row.status.as_str() {
        "succeeded" => format!(
            "任务 #{}（{}）已完成{}，可进入作业面板查看结果。",
            row.numeric_task_id, row.kind, phase
        ),
        "failed" => {
            let detail = row
                .error_message
                .as_deref()
                .filter(|value| !value.trim().is_empty())
                .map(|value| format!("失败原因：{value}"))
                .unwrap_or_else(|| "请在作业面板查看失败详情。".to_string());
            format!(
                "任务 #{}（{}）执行失败{}。{}",
                row.numeric_task_id, row.kind, phase, detail
            )
        }
        "cancelled" => format!(
            "任务 #{}（{}）已取消{}。",
            row.numeric_task_id, row.kind, phase
        ),
        _ => format!("任务 #{}（{}）状态已更新。", row.numeric_task_id, row.kind),
    }
}
