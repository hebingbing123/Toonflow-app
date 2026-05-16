use super::memory::{
    build_auto_memory_snapshot, build_stage_summary_content, filter_auto_scope_memory_rows,
    parse_review_summary, parse_tag_attributes, AutoMemoryRow,
};
use super::scope::{
    build_rework_context_note, compact_auto_memory_entry_for_scope, dedupe_auto_memory_entries,
    parse_scope_signature, parse_storyboard_prompt_seed_scope, scope_signature_from_args,
    scope_signature_json, select_auto_memory_entries,
};
use super::spec::{stage_label_for_tool, stage_summary_name_for_tool};
use super::{project_mode_note_from_value, sub_agent_prompt_from_args};
use crate::harness::invoke::InvokeError;
use proptest::prelude::*;
use serde_json::json;

const STAGE_SUMMARY_TOOLS: &[&str] = &[
    "run_sub_agent_storySkeleton",
    "run_sub_agent_adaptationStrategy",
    "run_sub_agent_script",
    "run_supervision_agent",
    "run_sub_agent_derive_assets",
    "run_sub_agent_generate_assets",
    "run_sub_agent_director_plan",
    "run_sub_agent_storyboard_gen",
    "run_sub_agent_storyboard_panel",
    "run_sub_agent_storyboard_table",
    "run_sub_agent_production_supervision",
];

#[test]
fn parse_tag_attributes_reads_xml_style_summary_line() {
    let attrs = parse_tag_attributes(
        r#"<reviewSummary target="storyboardTable" grade="C" severeCount="1" summary="需要先修复表结构" />"#,
        "reviewSummary",
    )
    .expect("attrs");
    assert_eq!(
        attrs.get("target").and_then(|v| v.as_str()),
        Some("storyboardTable")
    );
    assert_eq!(attrs.get("grade").and_then(|v| v.as_str()), Some("C"));
    assert_eq!(
        attrs.get("summary").and_then(|v| v.as_str()),
        Some("需要先修复表结构")
    );
}

#[test]
fn parse_review_summary_uses_first_summary_line() {
    let review = parse_review_summary(
        r#"
<reviewSummary target="scriptPlan" grade="B" severeCount="0" mediumCount="2" minorCount="1" nextAction="check_assets" summary="导演规划可用但资产还需对齐" assetIds="7,3,7" storyboardIds="9,3,9" />

# 审核报告：导演规划
"#,
    )
    .expect("review");
    assert_eq!(review["target"].as_str(), Some("scriptPlan"));
    assert_eq!(review["nextAction"].as_str(), Some("check_assets"));
    assert_eq!(review["assetIds"].as_str(), Some("7,3,7"));
    assert_eq!(review["storyboardIds"].as_str(), Some("9,3,9"));
}

#[test]
fn parse_review_summary_preserves_asset_types_scope() {
    let review = parse_review_summary(
        r#"
<reviewSummary target="scriptPlan" grade="B" severeCount="0" mediumCount="1" minorCount="0" nextAction="check_assets" summary="先核对角色场景资产" assetTypes="role,scene" />
"#,
    )
    .expect("review");
    assert_eq!(review["assetTypes"].as_str(), Some("role,scene"));
}

#[test]
fn parse_review_summary_supports_script_supervision_payload() {
    let review = parse_review_summary(
        r#"
<reviewSummary target="script" grade="C" severeCount="1" mediumCount="1" minorCount="0" nextAction="revise_script" summary="人物动机衔接还需要补强" />

# 审核报告：剧本正文
"#,
    )
    .expect("review");
    assert_eq!(review["target"].as_str(), Some("script"));
    assert_eq!(review["grade"].as_str(), Some("C"));
    assert_eq!(review["nextAction"].as_str(), Some("revise_script"));
}

proptest! {
    // Feature: drama-platform-completion, Property 2: 阶段摘要唯一性
    // 验证：需求 6.4
    #[test]
    fn prop_stage_summary_mapping_stays_unique_and_aligned(
        tool_a_idx in 0usize..STAGE_SUMMARY_TOOLS.len(),
        tool_b_idx in 0usize..STAGE_SUMMARY_TOOLS.len(),
    ) {
        let tool_a = STAGE_SUMMARY_TOOLS[tool_a_idx];
        let tool_b = STAGE_SUMMARY_TOOLS[tool_b_idx];
        let summary_a = stage_summary_name_for_tool(tool_a).expect("summary name");
        let label_a = stage_label_for_tool(tool_a).expect("stage label");
        let suffix_a = summary_a.strip_prefix("stage_summary:").expect("summary prefix");
        prop_assert_eq!(suffix_a, label_a);
        let summary_b = stage_summary_name_for_tool(tool_b).expect("summary name");
        let label_b = stage_label_for_tool(tool_b).expect("stage label");
        let suffix_b = summary_b.strip_prefix("stage_summary:").expect("summary prefix");
        prop_assert_eq!(suffix_b, label_b);
        if tool_a == tool_b {
            prop_assert_eq!(summary_a, summary_b);
            prop_assert_eq!(label_a, label_b);
        } else {
            prop_assert_ne!(summary_a, summary_b);
            prop_assert_ne!(label_a, label_b);
        }
    }
}

#[test]
fn sub_agent_prompt_from_args_appends_compact_scope_for_production_tools() {
    let prompt = sub_agent_prompt_from_args(
        "run_sub_agent_storyboard_gen",
        &json!({
            "prompt": "请继续推进 storyboard。",
            "storyboardIds": [9, 3, 9, 1],
            "assetIds": [7, 0, 5, 7],
            "assetTypes": ["scene", "role", "scene"]
        }),
    )
    .expect("prompt");
    assert!(prompt.contains("请继续推进 storyboard。"));
    assert!(prompt
        .contains(r#"<scope storyboardIds="1,3,9" assetIds="5,7" assetTypes="role,scene" />"#));
}

#[test]
fn sub_agent_prompt_from_args_appends_compact_scope_for_script_tools() {
    let prompt = sub_agent_prompt_from_args(
        "run_sub_agent_script",
        &json!({
            "prompt": "继续写剧本。",
            "focusSections": ["adaptationStrategy", "storySkeleton", "storySkeleton"],
            "novelIds": [12, 7, 12],
            "relativeScriptOffset": -1
        }),
    )
    .expect("prompt");
    assert!(prompt.contains("继续写剧本。"));
    assert!(prompt.contains(
        r#"<scope focusSections="adaptationStrategy,storySkeleton" novelIds="7,12" relativeScriptOffset="-1" />"#
    ));
}

#[test]
fn project_mode_note_from_value_supports_live_action_short_drama() {
    let note = project_mode_note_from_value(Some("live_action.short_drama")).expect("note");
    assert!(note.contains("Project mode: live_action.short_drama"));
    assert!(note.contains("natural spoken dialogue"));
    assert!(note.contains("Avoid anime-styled exaggeration"));
}

#[test]
fn project_mode_note_from_value_supports_animated_short_drama_aliases() {
    let note = project_mode_note_from_value(Some("Animated")).expect("note");
    assert!(note.contains("Project mode: animated.short_drama"));
    assert!(note.contains("animation-friendly visual action"));
    assert!(note.contains("Avoid overly documentary live-action realism"));
}

#[test]
fn project_mode_note_from_value_ignores_unknown_modes() {
    assert_eq!(project_mode_note_from_value(Some("novel.long_form")), None);
    assert_eq!(project_mode_note_from_value(None), None);
}

#[test]
fn build_auto_memory_snapshot_prefers_review_fields() {
    let snapshot = build_auto_memory_snapshot(
        "run_sub_agent_production_supervision",
        &json!({"assetTypes": ["scene", "role"], "storyboardIds": [9, 3]}),
        "unused",
        Some(&json!({
            "target": "scriptPlan",
            "grade": "B",
            "nextAction": "check_assets",
            "summary": "导演规划可用但资产还需对齐",
            "assetIds": "7,8"
        })),
        None,
    )
    .expect("snapshot");
    assert!(snapshot.contains("tool=run_sub_agent_production_supervision"));
    assert!(snapshot.contains("scope=storyboardIds=3,9; assetTypes=role,scene"));
    assert!(snapshot.contains("review=target=scriptPlan; grade=B; next=check_assets"));
    assert!(snapshot.contains("summary=导演规划可用但资产还需对齐"));
}

#[test]
fn build_auto_memory_snapshot_truncates_plain_result() {
    let snapshot = build_auto_memory_snapshot(
        "run_sub_agent_storyboard_table",
        &json!({"assetIds": [5, 1, 5]}),
        "  第一行结果  \n\n第二行结果  ",
        None,
        None,
    )
    .expect("snapshot");
    assert!(snapshot.contains("tool=run_sub_agent_storyboard_table"));
    assert!(snapshot.contains("scope=assetIds=1,5"));
    assert!(snapshot.contains("result=第一行结果 第二行结果"));
    assert!(snapshot.chars().count() <= 320);
}

#[test]
fn format_storyboard_prompt_seed_scope_uses_single_prompt_seed_for_single_storyboard() {
    use super::memory::format_storyboard_prompt_seed_scope;
    assert_eq!(
        format_storyboard_prompt_seed_scope(&[(12, "seed-12-current".to_string())]),
        Some("promptSeed=seed-12-current".to_string())
    );
}

#[test]
fn build_auto_memory_snapshot_includes_multi_storyboard_prompt_seed_scope() {
    let snapshot = build_auto_memory_snapshot(
        "run_sub_agent_storyboard_gen",
        &json!({"storyboardIds": [12, 14]}),
        "补齐分镜连续性",
        None,
        Some("storyboardPromptSeeds=12:seed-12-current,14:seed-14-current"),
    )
    .expect("snapshot");
    assert!(snapshot.contains("scope=storyboardIds=12,14"));
    assert!(snapshot.contains("storyboardPromptSeeds=12:seed-12-current,14:seed-14-current"));
}

#[test]
fn scope_signature_from_args_keeps_compact_sorted_scope() {
    let signature = scope_signature_from_args(
        &json!({
            "storyboardIds": [9, 1, 9],
            "assetIds": [5, 2, 5],
            "assetTypes": ["scene", "role", "scene"],
            "focusSections": ["script", "storySkeleton", "script"],
            "novelIds": [8, 3, 8],
            "relativeScriptOffset": -1
        }),
        None,
    );
    assert_eq!(signature.storyboard_ids, vec![1, 9]);
    assert!(signature.storyboard_prompt_seeds.is_empty());
    assert_eq!(signature.asset_ids, vec![2, 5]);
    assert_eq!(signature.asset_types, vec!["role", "scene"]);
    assert_eq!(signature.focus_sections, vec!["script", "storySkeleton"]);
    assert_eq!(signature.novel_ids, vec![3, 8]);
    assert_eq!(signature.relative_script_offset, Some(-1));
}

#[test]
fn parse_scope_signature_reads_snapshot_scope_segment() {
    let signature = parse_scope_signature(
        "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=3,9; assetIds=5,7; assetTypes=role,scene | storyboardPromptSeeds=3:seed-3,9:seed-9 | result=done",
    );
    assert_eq!(signature.storyboard_ids, vec![3, 9]);
    assert_eq!(
        signature.storyboard_prompt_seeds,
        vec![(3, "seed-3".to_string()), (9, "seed-9".to_string())]
    );
    assert_eq!(signature.asset_ids, vec![5, 7]);
    assert_eq!(signature.asset_types, vec!["role", "scene"]);
}

#[test]
fn parse_storyboard_prompt_seed_scope_reads_multi_storyboard_seed_map() {
    assert_eq!(
        parse_storyboard_prompt_seed_scope(Some(
            "storyboardPromptSeeds=14:seed-14-current,12:seed-12-current"
        )),
        vec![
            (12, "seed-12-current".to_string()),
            (14, "seed-14-current".to_string())
        ]
    );
}

#[test]
fn select_auto_memory_entries_prefers_overlapping_scope() {
    let rows = select_auto_memory_entries(
        &json!({"storyboardIds": [9], "assetIds": [7], "assetTypes": ["scene"]}),
        None,
        vec![
            "tool=a | scope=storyboardIds=1; assetIds=2 | result=older".to_string(),
            "tool=b | scope=storyboardIds=9; assetIds=7; assetTypes=scene | result=best"
                .to_string(),
            "tool=c | scope=storyboardIds=9 | result=good".to_string(),
        ],
    );
    assert_eq!(rows.len(), 2);
    assert!(rows[0].contains("result=best"));
    assert!(rows[1].contains("result=good"));
}

#[test]
fn select_auto_memory_entries_falls_back_to_latest_when_scope_missing() {
    let rows = select_auto_memory_entries(
        &json!({}),
        None,
        vec![
            "tool=a | scope=storyboardIds=1 | result=latest".to_string(),
            "tool=b | scope=storyboardIds=9 | result=older".to_string(),
        ],
    );
    assert_eq!(rows.len(), 1);
    assert!(rows[0].contains("result=latest"));
}

#[test]
fn select_auto_memory_entries_prefers_matching_prompt_seed_over_stale_same_storyboard() {
    let rows = select_auto_memory_entries(
        &json!({"storyboardIds": [12]}),
        Some("promptSeed=seed-12-current"),
        vec![
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-stale | summary=旧版镜头走位".to_string(),
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位".to_string(),
        ],
    );
    assert_eq!(rows.len(), 1);
    assert!(rows[0].contains("promptSeed=seed-12-current"));
}

#[test]
fn filter_auto_scope_memory_rows_skips_other_summary_types_and_blank_content() {
    let rows = filter_auto_scope_memory_rows(vec![
        AutoMemoryRow {
            name: "selected_video_memory".to_string(),
            content: "storyboardIds=12 | promptSeed=seed-12-current | style=镜头近景".to_string(),
        },
        AutoMemoryRow {
            name: "auto_scope_memory".to_string(),
            content: " tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位 ".to_string(),
        },
        AutoMemoryRow {
            name: "auto_scope_memory".to_string(),
            content: "   ".to_string(),
        },
    ]);
    assert_eq!(rows.len(), 1);
    assert_eq!(
        rows[0],
        "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位"
    );
}

#[test]
fn select_auto_memory_entries_keeps_older_matching_scope_when_newer_rows_are_noise() {
    let rows = select_auto_memory_entries(
        &json!({"storyboardIds": [12]}),
        Some("promptSeed=seed-12-current"),
        vec![
            "tool=noise_a | scope=storyboardIds=31 | promptSeed=seed-31 | summary=别的镜头31".to_string(),
            "tool=noise_b | scope=storyboardIds=32 | promptSeed=seed-32 | summary=别的镜头32".to_string(),
            "tool=noise_c | scope=storyboardIds=33 | promptSeed=seed-33 | summary=别的镜头33".to_string(),
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位".to_string(),
        ],
    );
    assert_eq!(rows.len(), 1);
    assert!(rows[0].contains("storyboardIds=12"));
    assert!(rows[0].contains("promptSeed=seed-12-current"));
}

#[test]
fn compact_auto_memory_entry_for_scope_drops_redundant_scope_and_seed_prefix() {
    let current_scope = scope_signature_from_args(
        &json!({"storyboardIds": [12]}),
        Some("promptSeed=seed-12-current"),
    );
    let compacted = compact_auto_memory_entry_for_scope(
        "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位",
        &current_scope,
    );
    assert_eq!(compacted, "panel: 角色站位");
}

#[test]
fn compact_auto_memory_entry_for_scope_keeps_scope_when_candidate_differs() {
    let current_scope = scope_signature_from_args(
        &json!({"storyboardIds": [12]}),
        Some("promptSeed=seed-12-current"),
    );
    let compacted = compact_auto_memory_entry_for_scope(
        "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12,14 | storyboardPromptSeeds=12:seed-12-current,14:seed-14-current | summary=保持当前镜头角色站位",
        &current_scope,
    );
    assert_eq!(
        compacted,
        "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12,14 | storyboardPromptSeeds=12:seed-12-current,14:seed-14-current | summary=保持当前镜头角色站位"
    );
}

#[test]
fn compact_auto_memory_entry_for_scope_prefers_review_summary_over_metadata() {
    let current_scope = scope_signature_from_args(
        &json!({"storyboardIds": [12]}),
        Some("promptSeed=seed-12-current"),
    );
    let compacted = compact_auto_memory_entry_for_scope(
        "tool=run_sub_agent_production_supervision | scope=storyboardIds=12 | promptSeed=seed-12-current | review=target=storyboardTable; grade=B; next=refresh; summary=当前镜头角色站位不要跳轴",
        &current_scope,
    );
    assert_eq!(compacted, "supervision: 角色站位不要跳轴");
}

#[test]
fn build_rework_context_note_compacts_reason_and_scope() {
    let note = build_rework_context_note(&json!({
        "storyboardIds": [12, 13],
        "reason": "人物有点像念稿，情绪递进也不够，镜头还稍微有点重复，需要只修这两条分镜。"
    }))
    .expect("note");
    assert!(note.contains("failure_reason="));
    assert!(note.contains("fix_goal=补强情绪表达与台词表演"));
    assert!(note.contains("storyboardIds=12,13"));
}

#[test]
fn select_auto_memory_entries_rework_mode_keeps_compact_top_two_matches() {
    let rows = select_auto_memory_entries(
        &json!({"storyboardIds": [12], "reason": "情绪不够"}),
        Some("promptSeed=seed-12-current"),
        vec![
            "tool=a | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=匹配1"
                .to_string(),
            "tool=b | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=匹配2"
                .to_string(),
            "tool=c | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=匹配3"
                .to_string(),
        ],
    );
    assert_eq!(rows.len(), 2);
    assert!(rows.iter().all(|row| row.contains("storyboardIds=12")));
}

#[test]
fn select_auto_memory_entries_rework_reason_alias_also_enables_tighter_limit() {
    let rows = select_auto_memory_entries(
        &json!({"storyboardIds": [12], "reworkReason": "情绪不够"}),
        Some("promptSeed=seed-12-current"),
        vec![
            "tool=a | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=匹配1"
                .to_string(),
            "tool=b | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=匹配2"
                .to_string(),
            "tool=c | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=匹配3"
                .to_string(),
        ],
    );
    assert_eq!(rows.len(), 2);
}

#[test]
fn compact_auto_memory_entry_for_scope_falls_back_to_review_target_and_next() {
    let current_scope = scope_signature_from_args(
        &json!({"storyboardIds": [12]}),
        Some("promptSeed=seed-12-current"),
    );
    let compacted = compact_auto_memory_entry_for_scope(
        "tool=run_sub_agent_production_supervision | scope=storyboardIds=12 | promptSeed=seed-12-current | review=target=storyboardTable; grade=C; next=refresh",
        &current_scope,
    );
    assert_eq!(compacted, "supervision: storyboardTable refresh");
}

#[test]
fn dedupe_auto_memory_entries_drops_scope_compaction_duplicates() {
    let rows = dedupe_auto_memory_entries(vec![
        "panel: 角色站位".to_string(),
        "panel: 角色站位".to_string(),
        "panel: 补充环境光位".to_string(),
    ]);
    assert_eq!(
        rows,
        vec![
            "panel: 角色站位".to_string(),
            "panel: 补充环境光位".to_string()
        ]
    );
}

#[test]
fn build_auto_memory_snapshot_drops_low_signal_plain_result() {
    let snapshot = build_auto_memory_snapshot(
        "run_sub_agent_storyboard_gen",
        &json!({"storyboardIds": [12]}),
        "本轮执行完成。已读取 flow。已写入工作区。",
        None,
        None,
    );
    assert!(snapshot.is_none());
}

#[test]
fn build_auto_memory_snapshot_strips_generic_result_prefix_and_keeps_constraint() {
    let snapshot = build_auto_memory_snapshot(
        "run_sub_agent_storyboard_gen",
        &json!({"storyboardIds": [12]}),
        "已生成主角冲向巷口，保持镜头方向连续。",
        None,
        None,
    )
    .expect("snapshot");
    assert!(snapshot.contains("result=主角冲向巷口，保持镜头方向连续"));
    assert!(!snapshot.contains("已生成"));
}

#[test]
fn build_auto_memory_snapshot_drops_low_signal_result_tail_clause() {
    let snapshot = build_auto_memory_snapshot(
        "run_sub_agent_storyboard_gen",
        &json!({"storyboardIds": [12]}),
        "主角冲向巷口，保持镜头方向连续，已写入工作区。",
        None,
        None,
    )
    .expect("snapshot");
    assert!(snapshot.contains("result=主角冲向巷口，保持镜头方向连续"));
    assert!(!snapshot.contains("已写入工作区"));
}

#[test]
fn build_auto_memory_snapshot_compacts_review_summary_before_persisting() {
    let snapshot = build_auto_memory_snapshot(
        "run_sub_agent_production_supervision",
        &json!({"storyboardIds": [12]}),
        "unused",
        Some(&json!({
            "target": "storyboardTable",
            "grade": "B",
            "nextAction": "check_storyboard",
            "summary": "当前镜头角色站位不要跳轴"
        })),
        Some("promptSeed=seed-12-current"),
    )
    .expect("snapshot");
    assert!(snapshot.contains("summary=角色站位不要跳轴"));
    assert!(!snapshot.contains("当前镜头"));
}

#[test]
fn build_auto_memory_snapshot_drops_generic_review_summary_placeholder() {
    let snapshot = build_auto_memory_snapshot(
        "run_sub_agent_production_supervision",
        &json!({"storyboardIds": [12]}),
        "unused",
        Some(&json!({
            "target": "storyboardTable",
            "grade": "B",
            "nextAction": "check_storyboard",
            "summary": "当前镜头风格统一，情绪延续"
        })),
        Some("promptSeed=seed-12-current"),
    )
    .expect("snapshot");
    assert!(!snapshot.contains("summary="));
    assert!(!snapshot.contains("风格统一"));
    assert!(!snapshot.contains("情绪延续"));
}

#[test]
fn build_auto_memory_snapshot_keeps_specific_review_constraint_while_dropping_generic_prefix() {
    let snapshot = build_auto_memory_snapshot(
        "run_sub_agent_production_supervision",
        &json!({"storyboardIds": [12]}),
        "unused",
        Some(&json!({
            "target": "storyboardTable",
            "grade": "B",
            "nextAction": "check_storyboard",
            "summary": "当前镜头风格统一，人物站位不要跳轴"
        })),
        Some("promptSeed=seed-12-current"),
    )
    .expect("snapshot");
    assert!(snapshot.contains("summary=人物站位不要跳轴"));
    assert!(!snapshot.contains("风格统一"));
}

#[test]
fn build_stage_summary_content_uses_review_summary_for_success() {
    let summary = build_stage_summary_content(
        "run_sub_agent_production_supervision",
        Some(&json!({
            "target": "storyboardTable",
            "grade": "B",
            "nextAction": "refresh",
            "summary": "当前镜头角色站位不要跳轴"
        })),
        Some("unused"),
        None,
    )
    .expect("summary");
    assert!(summary.contains("stage=production_supervision"));
    assert!(summary.contains("status=completed"));
    assert!(summary.contains("target=storyboardTable"));
    assert!(summary.contains("grade=B"));
    assert!(summary.contains("角色站位不要跳轴"));
    assert!(summary.chars().count() <= 320);
}

#[test]
fn build_stage_summary_content_records_failure_reason() {
    let error = InvokeError::LlmError(" upstream timeout while generating ".to_string());
    let summary =
        build_stage_summary_content("run_sub_agent_storyboard_panel", None, None, Some(&error))
            .expect("summary");
    assert!(summary.contains("stage=storyboard_panel"));
    assert!(summary.contains("status=failed"));
    assert!(summary.contains("reason=upstream timeout while generating"));
    assert!(summary.chars().count() <= 320);
}

#[test]
fn scope_signature_json_keeps_required_scope_dimensions() {
    let scope = scope_signature_json(
        Some(7),
        &scope_signature_from_args(
            &json!({
                "storyboardIds": [9, 3, 9],
                "focusSections": ["script", "storySkeleton", "script"]
            }),
            None,
        ),
    )
    .expect("scope");
    assert_eq!(scope["episodeId"].as_i64(), Some(7));
    assert_eq!(scope["storyboardIds"], json!([3, 9]));
    assert_eq!(scope["focusSections"], json!(["script", "storySkeleton"]));
}
