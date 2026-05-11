//! 内容合规告警同步的纯函数（与 Postgres / WebSocket 无关），供单元测试覆盖（Phase2 C1.7）。

use serde_json::{json, Value};

use super::types::ContentComplianceAlertSyncItem;

pub(crate) fn normalize_compliance_stage(stage: &str) -> String {
    stage.trim().to_ascii_lowercase()
}

pub(crate) fn normalize_compliance_template_id(id: &str) -> String {
    id.trim().to_ascii_lowercase()
}

pub(crate) fn normalize_template_ids_preserve_order(ids: &[String]) -> Vec<String> {
    let mut seen = std::collections::HashSet::<String>::new();
    let mut out = Vec::<String>::new();
    for id in ids {
        let normalized = normalize_compliance_template_id(id);
        if normalized.is_empty() || !seen.insert(normalized.clone()) {
            continue;
        }
        out.push(normalized);
    }
    out
}

/// 与 `sync_content_compliance_alert_notifications` 写入的 `payload` 形状一致。
pub(crate) fn build_content_compliance_alert_payload(
    stage: &str,
    level: &str,
    count: i64,
) -> Value {
    let level = level.trim();
    json!({
        "source": "content_compliance",
        "stage": stage,
        "level": level,
        "count": count,
        "severity": level,
    })
}

/// 与同步逻辑中「活跃告警未变化则跳过 UPDATE」的判断一致。
pub(crate) fn content_compliance_alert_unchanged(
    prev_title: &str,
    prev_message: &str,
    prev_link_path: &Option<String>,
    payload_level: &str,
    payload_count: i64,
    alert: &ContentComplianceAlertSyncItem,
) -> bool {
    prev_title == alert.title.as_str()
        && prev_message == alert.message.as_str()
        && prev_link_path == &alert.link_path
        && payload_level == alert.level.as_str()
        && payload_count == alert.count
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_stage_trims_and_lowercases() {
        assert_eq!(
            normalize_compliance_stage("  Over_Capacity  "),
            "over_capacity"
        );
    }

    #[test]
    fn normalize_template_ids_dedupes_preserving_first_occurrence() {
        let ids = vec![
            "A".to_string(),
            "a".to_string(),
            "b".to_string(),
            " B ".to_string(),
        ];
        assert_eq!(normalize_template_ids_preserve_order(&ids), vec!["a", "b"]);
    }

    #[test]
    fn payload_contains_expected_keys() {
        let v = build_content_compliance_alert_payload("escalated_72h", " warn ", 3);
        assert_eq!(v["source"], "content_compliance");
        assert_eq!(v["stage"], "escalated_72h");
        assert_eq!(v["level"], "warn");
        assert_eq!(v["severity"], "warn");
        assert_eq!(v["count"], 3);
    }

    #[test]
    fn unchanged_true_when_all_fields_match() {
        let alert = ContentComplianceAlertSyncItem {
            stage: "x".into(),
            level: "high".into(),
            count: 2,
            title: "t".into(),
            message: "m".into(),
            link_path: Some("/p".into()),
        };
        assert!(content_compliance_alert_unchanged(
            "t",
            "m",
            &Some("/p".into()),
            "high",
            2,
            &alert
        ));
    }

    #[test]
    fn unchanged_false_when_count_differs() {
        let alert = ContentComplianceAlertSyncItem {
            stage: "x".into(),
            level: "high".into(),
            count: 2,
            title: "t".into(),
            message: "m".into(),
            link_path: None,
        };
        assert!(!content_compliance_alert_unchanged(
            "t", "m", &None, "high", 9, &alert
        ));
    }

    #[test]
    fn unchanged_false_when_link_path_differs() {
        let alert = ContentComplianceAlertSyncItem {
            stage: "x".into(),
            level: "high".into(),
            count: 1,
            title: "t".into(),
            message: "m".into(),
            link_path: Some("/a".into()),
        };
        assert!(!content_compliance_alert_unchanged(
            "t",
            "m",
            &Some("/b".into()),
            "high",
            1,
            &alert
        ));
    }
}
