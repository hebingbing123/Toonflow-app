//! Anti-AI artifact detection: anchor drift, emotion progression, gaze consistency.
//!
//! Provides `check_anti_ai_artifacts` — a focused pass over structured storyboard
//! fields that flags the most common "one-glance AI" problems before high-cost stages.

use crate::production::workbench::video_prompt_memory::StructuredStoryboardDescription;

use super::{
    contains_any, issue, rework_suggestion,
    rules::{
        dialogue_emotion_mismatch, emotion_intensity_score, has_emotional_peak,
        prompt_has_conflict_pair, prompt_has_monotone_delivery_risk,
        prompt_has_repetitive_action_risk, storyboard_dialogue_is_empty,
    },
    QualityGateIssue, QualityGateSeverity, GAZE_CONFLICT_PAIRS, HIGH_EMOTION_CUES,
    LIMB_CONFLICT_PAIRS, PHYSICAL_RELATION_CONFLICT_PAIRS,
};

/// Run anti-AI artifact checks on a single storyboard's structured fields.
///
/// Returns a list of issues. Severe issues should trigger patch/dispatch rework.
#[allow(dead_code)]
pub(crate) fn check_anti_ai_artifacts(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
    scope: &str,
) -> Vec<QualityGateIssue> {
    let mut issues = Vec::new();
    let full_text = [
        fields.subject.as_str(),
        fields.action.as_str(),
        fields.mood.as_str(),
        fields.setting.as_str(),
        fields.dialogue.as_str(),
        prompt.unwrap_or_default(),
    ]
    .join(" ");

    // 1. 视线方向冲突（对话场景双方视线必须相对）
    if prompt_has_conflict_pair(&full_text, &GAZE_CONFLICT_PAIRS) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "gaze_direction_conflict",
            &rework_suggestion("对话场景中双方视线方向冲突，先统一视线朝向再生成。"),
            scope,
        ));
    }

    // 2. 肢体动作不连贯
    if prompt_has_conflict_pair(&full_text, &LIMB_CONFLICT_PAIRS) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "limb_incoherence",
            &rework_suggestion("肢体动作描述互相矛盾，先统一人物姿态再生成。"),
            scope,
        ));
    }

    // 3. 场景物理关系错乱
    if prompt_has_conflict_pair(&full_text, &PHYSICAL_RELATION_CONFLICT_PAIRS) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "physical_relation_conflict",
            &rework_suggestion("人物空间关系描述矛盾，先统一场景物理位置再生成。"),
            scope,
        ));
    }

    // 4. 无意义重复动作（AI 痕迹）
    if prompt_has_repetitive_action_risk(&full_text) {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "repetitive_action",
            "动作描述存在无意义重复，压缩成一个具体动作，避免 AI 机械循环感。",
            scope,
        ));
    }

    // 5. 情绪不匹配台词（台词强烈但情绪描述平淡）
    if dialogue_emotion_mismatch(fields, prompt) {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "emotion_dialogue_mismatch",
            "台词情绪强度与镜头情绪描述不匹配，补充情绪动作细节或调整台词强度。",
            scope,
        ));
    }

    // 6. 高情绪场景缺少情绪峰值表现
    let intensity = emotion_intensity_score(fields);
    if intensity >= 2
        && contains_any(&full_text, &HIGH_EMOTION_CUES)
        && !has_emotional_peak(fields, prompt)
    {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "missing_emotion_peak",
            "高情绪场景缺少可感知的情绪峰值（眼神、呼吸、肢体），补充至少一个具体情绪锚点。",
            scope,
        ));
    }

    // 7. 含台词镜头缺少表演线索（读文章风险）
    if !storyboard_dialogue_is_empty(&fields.dialogue)
        && prompt_has_monotone_delivery_risk(&full_text)
    {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "monotone_delivery_risk",
            "台词表演缺少语速/停顿/情绪意图线索，容易生成机械朗读感。",
            scope,
        ));
    }

    issues
}

/// Returns true if any severe anti-AI issue was found — caller should trigger patch rework.
#[allow(dead_code)]
pub(crate) fn has_severe_anti_ai_issue(issues: &[QualityGateIssue]) -> bool {
    issues
        .iter()
        .any(|issue| issue.severity == QualityGateSeverity::Severe)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::production::workbench::video_prompt_memory::parse_structured_storyboard_description;

    #[test]
    fn gaze_conflict_detected() {
        let fields = parse_structured_storyboard_description(
            "（林晚、走廊、林晚、4秒、近景、固定、对视着陈默、平静、冷光、你敢再说一遍！、脚步声、A01）",
        )
        .unwrap();
        let issues = check_anti_ai_artifacts(&fields, Some("林晚背对陈默站着"), "storyboardId=1");
        assert!(issues
            .iter()
            .any(|i| i.issue_type == "gaze_direction_conflict"));
        assert!(has_severe_anti_ai_issue(&issues));
    }

    #[test]
    fn high_emotion_missing_peak_flagged() {
        let fields = parse_structured_storyboard_description(
            "（林晚、雨夜、林晚、5秒、近景、推进、崩溃大哭、情绪爆发、冷光、别碰我！、雨声、A02）",
        )
        .unwrap();
        // No peak cues in prompt
        let issues = check_anti_ai_artifacts(&fields, Some("林晚站着说话"), "storyboardId=2");
        assert!(issues
            .iter()
            .any(|i| i.issue_type == "missing_emotion_peak"));
    }

    #[test]
    fn clean_scene_has_no_severe_issues() {
        let fields = parse_structured_storyboard_description(
            "（林晚、咖啡厅、林晚、3秒、中景、固定、低头喝咖啡、平静、暖光、无台词、环境音、A03）",
        )
        .unwrap();
        let issues = check_anti_ai_artifacts(&fields, None, "storyboardId=3");
        assert!(!has_severe_anti_ai_issue(&issues));
    }
}
