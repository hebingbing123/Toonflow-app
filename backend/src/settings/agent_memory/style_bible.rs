use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

use super::replace_named_summary_memory_with_scope;

const STYLE_BIBLE_AGENT_TYPE: &str = "productionAgent";
const STYLE_BIBLE_NAME: &str = "style_bible:project";
const STYLE_BIBLE_MAX_CHARS: usize = 800;
const STYLE_BIBLE_MAX_CHARACTERS: usize = 4;

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct StyleBibleCharacterAnchor {
    pub(crate) name: String,
    pub(crate) fixed_appearance: String,
    pub(crate) default_temperament: String,
    pub(crate) emotion_expression: String,
    pub(crate) relationship_positioning: String,
    pub(crate) body_habits: Vec<String>,
}

#[derive(Debug, Clone)]
struct StyleBibleRoleSeed {
    name: String,
    description: Option<String>,
    prompt: Option<String>,
}

fn empty_style_bible_value() -> Value {
    json!({
        "characters": [],
        "visual_taboos": [],
        "narrative_taboos": [],
        "world_constraints": [],
        "platform_rhythm": "",
        "core_relationships": "",
        "emotion_baseline": ""
    })
}

fn style_bible_scope_signature(project_id: i32) -> Value {
    json!({ "projectId": project_id })
}

fn normalize_text(value: &str) -> String {
    value.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn truncate_chars(value: &str, max_chars: usize) -> String {
    if value.chars().count() <= max_chars {
        return value.to_string();
    }
    let trimmed = value
        .chars()
        .take(max_chars.saturating_sub(1))
        .collect::<String>();
    format!("{trimmed}…")
}

fn first_meaningful_fragment(text: &str, max_chars: usize) -> Option<String> {
    let normalized = normalize_text(text);
    let fragment = normalized
        .split(['。', '！', '？', '.', '!', '?', ';', '；', '\n'])
        .map(str::trim)
        .find(|segment| !segment.is_empty())?;
    Some(truncate_chars(fragment, max_chars))
}

fn detect_temperament(text: &str) -> Option<&'static str> {
    const KEYWORDS: [(&str, &str); 12] = [
        ("冷", "冷峻克制"),
        ("克制", "克制隐忍"),
        ("隐忍", "克制隐忍"),
        ("温柔", "温柔细腻"),
        ("强势", "强势果断"),
        ("沉稳", "沉稳压场"),
        ("锐利", "锐利警觉"),
        ("紧张", "紧张压迫"),
        ("热烈", "热烈外放"),
        ("轻快", "轻快灵动"),
        ("倔强", "倔强硬撑"),
        ("脆弱", "脆弱敏感"),
    ];
    KEYWORDS
        .iter()
        .find_map(|(needle, label)| text.contains(needle).then_some(*label))
}

fn detect_emotion_expression(text: &str) -> Option<&'static str> {
    const KEYWORDS: [(&str, &str); 10] = [
        ("低声", "多用低声压情绪"),
        ("哽咽", "情绪上来时容易哽咽"),
        ("抿唇", "先抿唇再开口"),
        ("停顿", "情绪变化前会短暂停顿"),
        ("含泪", "情绪堆积时会含泪压住"),
        ("强忍", "习惯强忍情绪不外露"),
        ("冷笑", "情绪对抗时带冷笑"),
        ("怒", "愤怒时外放明显"),
        ("轻声", "习惯轻声表达"),
        ("沉默", "常以沉默代替正面表达"),
    ];
    KEYWORDS
        .iter()
        .find_map(|(needle, label)| text.contains(needle).then_some(*label))
}

fn detect_emotion_baseline(project_intro: Option<&str>, roles: &[Value]) -> String {
    let mut signals = Vec::new();
    if let Some(intro) = project_intro {
        if let Some(tag) = detect_temperament(intro) {
            signals.push(tag.to_string());
        }
    }
    for role in roles {
        if let Some(tag) = role
            .get("default_temperament")
            .and_then(Value::as_str)
            .filter(|value| !value.trim().is_empty())
        {
            if !signals.iter().any(|existing| existing == tag) {
                signals.push(tag.to_string());
            }
        }
    }
    truncate_chars(
        &signals.into_iter().take(2).collect::<Vec<_>>().join("、"),
        48,
    )
}

fn role_seed_to_character(seed: &StyleBibleRoleSeed) -> Option<Value> {
    let source = [
        seed.description.as_deref().unwrap_or_default(),
        seed.prompt.as_deref().unwrap_or_default(),
    ]
    .join(" ");
    let source = normalize_text(&source);
    let fixed_appearance = first_meaningful_fragment(&source, 28)?;
    let default_temperament = detect_temperament(&source).unwrap_or("气质待补全");
    let emotion_expression = detect_emotion_expression(&source).unwrap_or("");
    Some(json!({
        "name": truncate_chars(&seed.name, 20),
        "fixed_appearance": fixed_appearance,
        "default_temperament": default_temperament,
        "emotion_expression": emotion_expression,
        "body_habits": []
    }))
}

fn style_bible_has_meaningful_content(value: &Value) -> bool {
    let Some(obj) = value.as_object() else {
        return false;
    };
    obj.iter().any(|(key, value)| match value {
        Value::String(text) => !text.trim().is_empty(),
        Value::Array(items) => {
            if key == "characters" {
                items.iter().any(|item| {
                    item.get("name")
                        .and_then(Value::as_str)
                        .map(|text| !text.trim().is_empty())
                        .unwrap_or(false)
                        || item
                            .get("fixed_appearance")
                            .and_then(Value::as_str)
                            .map(|text| !text.trim().is_empty())
                            .unwrap_or(false)
                })
            } else {
                !items.is_empty()
            }
        }
        _ => false,
    })
}

fn parse_string_array(value: Option<&Value>) -> Vec<String> {
    value
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(normalize_text)
        .filter(|value| !value.is_empty())
        .collect()
}

fn parse_style_bible_character_anchors(value: &Value) -> Vec<StyleBibleCharacterAnchor> {
    let relationship_positioning = value
        .get("core_relationships")
        .and_then(Value::as_str)
        .map(normalize_text)
        .unwrap_or_default();
    value
        .get("characters")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|character| {
            let name = character
                .get("name")
                .and_then(Value::as_str)
                .map(normalize_text)
                .unwrap_or_default();
            let fixed_appearance = character
                .get("fixed_appearance")
                .and_then(Value::as_str)
                .map(normalize_text)
                .unwrap_or_default();
            let default_temperament = character
                .get("default_temperament")
                .and_then(Value::as_str)
                .map(normalize_text)
                .unwrap_or_default();
            let emotion_expression = character
                .get("emotion_expression")
                .and_then(Value::as_str)
                .map(normalize_text)
                .unwrap_or_default();
            if name.is_empty()
                && fixed_appearance.is_empty()
                && default_temperament.is_empty()
                && emotion_expression.is_empty()
            {
                return None;
            }
            Some(StyleBibleCharacterAnchor {
                name,
                fixed_appearance,
                default_temperament,
                emotion_expression,
                relationship_positioning: relationship_positioning.clone(),
                body_habits: parse_string_array(character.get("body_habits")),
            })
        })
        .collect()
}

fn build_style_bible_fill(
    project_intro: Option<&str>,
    roles: &[StyleBibleRoleSeed],
) -> Option<String> {
    let mut characters = roles
        .iter()
        .filter_map(role_seed_to_character)
        .take(STYLE_BIBLE_MAX_CHARACTERS)
        .collect::<Vec<_>>();
    if characters.is_empty() {
        return None;
    }

    loop {
        let value = json!({
            "characters": characters,
            "visual_taboos": [],
            "narrative_taboos": [],
            "world_constraints": [],
            "platform_rhythm": "",
            "core_relationships": "",
            "emotion_baseline": detect_emotion_baseline(project_intro, &characters)
        });
        let serialized = serde_json::to_string(&value).ok()?;
        if serialized.chars().count() <= STYLE_BIBLE_MAX_CHARS {
            return Some(serialized);
        }
        if characters.len() <= 1 {
            return Some(truncate_chars(&serialized, STYLE_BIBLE_MAX_CHARS));
        }
        characters.pop();
    }
}

async fn fetch_existing_style_bible(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
) -> Result<Option<String>, ApiError> {
    sqlx::query_scalar(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NULL
          AND agent_type = $3
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(STYLE_BIBLE_AGENT_TYPE)
    .bind(STYLE_BIBLE_NAME)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn load_project_style_bible_character_anchors(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
) -> Result<Vec<StyleBibleCharacterAnchor>, ApiError> {
    let Some(content) = fetch_existing_style_bible(pool, user_id, project_id).await? else {
        return Ok(Vec::new());
    };
    let anchors = serde_json::from_str::<Value>(&content)
        .ok()
        .map(|value| parse_style_bible_character_anchors(&value))
        .unwrap_or_default();
    Ok(anchors)
}

pub(crate) async fn ensure_project_style_bible_template(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
) -> Result<(), ApiError> {
    if fetch_existing_style_bible(pool, user_id, project_id)
        .await?
        .is_some()
    {
        return Ok(());
    }
    let content = serde_json::to_string(&empty_style_bible_value())
        .map_err(|e| ApiError::BadRequest(e.to_string()))?;
    let scope_signature = style_bible_scope_signature(project_id);
    replace_named_summary_memory_with_scope(
        pool,
        user_id,
        project_id,
        None,
        STYLE_BIBLE_AGENT_TYPE,
        "assistant",
        STYLE_BIBLE_NAME,
        &content,
        "style_bible",
        Some(&scope_signature),
        None,
    )
    .await
}

pub(crate) async fn maybe_fill_project_style_bible_from_assets(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
) -> Result<(), ApiError> {
    if let Some(existing) = fetch_existing_style_bible(pool, user_id, project_id).await? {
        if serde_json::from_str::<Value>(&existing)
            .ok()
            .map(|value| style_bible_has_meaningful_content(&value))
            .unwrap_or(true)
        {
            return Ok(());
        }
    }

    let project_intro: Option<String> = sqlx::query_scalar(
        r#"
        SELECT intro
        FROM app_project
        WHERE owner_user_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .flatten();

    let role_rows: Vec<(String, Option<String>, Option<String>)> = sqlx::query_as(
        r#"
        SELECT
          a.name,
          a.description,
          a.metadata->>'prompt' AS prompt
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND a.asset_type = 'role'
        ORDER BY a.numeric_id ASC
        LIMIT 8
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let seeds = role_rows
        .into_iter()
        .filter_map(|(name, description, prompt)| {
            let name = name.trim().to_string();
            if name.is_empty() {
                return None;
            }
            Some(StyleBibleRoleSeed {
                name,
                description,
                prompt,
            })
        })
        .collect::<Vec<_>>();
    let Some(content) = build_style_bible_fill(project_intro.as_deref(), &seeds) else {
        return Ok(());
    };
    let scope_signature = style_bible_scope_signature(project_id);
    replace_named_summary_memory_with_scope(
        pool,
        user_id,
        project_id,
        None,
        STYLE_BIBLE_AGENT_TYPE,
        "assistant",
        STYLE_BIBLE_NAME,
        &content,
        "style_bible",
        Some(&scope_signature),
        None,
    )
    .await
}

#[cfg(test)]
mod tests {
    use super::{
        build_style_bible_fill, empty_style_bible_value, parse_style_bible_character_anchors,
        style_bible_has_meaningful_content, style_bible_scope_signature, StyleBibleRoleSeed,
    };
    use serde_json::json;

    #[test]
    fn empty_style_bible_contains_required_fields() {
        let value = empty_style_bible_value();
        assert_eq!(value["characters"], json!([]));
        assert_eq!(value["visual_taboos"], json!([]));
        assert_eq!(value["narrative_taboos"], json!([]));
        assert_eq!(value["world_constraints"], json!([]));
        assert_eq!(value["platform_rhythm"], json!(""));
        assert_eq!(value["core_relationships"], json!(""));
        assert_eq!(value["emotion_baseline"], json!(""));
    }

    #[test]
    fn style_bible_fill_keeps_role_anchors_and_budget() {
        let content = build_style_bible_fill(
            Some("都市情感故事，整体克制压抑。"),
            &[
                StyleBibleRoleSeed {
                    name: "林晚".to_string(),
                    description: Some("黑长发，穿米白风衣，强忍情绪，低声说话。".to_string()),
                    prompt: Some("眼神冷静克制，门厅暖光。".to_string()),
                },
                StyleBibleRoleSeed {
                    name: "顾承泽".to_string(),
                    description: Some("深色西装，气场沉稳，压着火气开口。".to_string()),
                    prompt: None,
                },
            ],
        )
        .expect("content");

        assert!(content.chars().count() <= 800);
        assert!(content.contains("林晚"));
        assert!(content.contains("黑长发"));
        assert!(content.contains("克制隐忍"));
        assert!(content.contains("emotion_baseline"));
    }

    #[test]
    fn style_bible_non_empty_detection_respects_template_vs_user_content() {
        assert!(!style_bible_has_meaningful_content(
            &empty_style_bible_value()
        ));
        assert!(style_bible_has_meaningful_content(&json!({
            "characters": [
                {
                    "name": "林晚",
                    "fixed_appearance": "黑长发",
                    "default_temperament": "克制隐忍",
                    "emotion_expression": "",
                    "body_habits": []
                }
            ],
            "visual_taboos": [],
            "narrative_taboos": [],
            "world_constraints": [],
            "platform_rhythm": "",
            "core_relationships": "",
            "emotion_baseline": ""
        })));
    }

    #[test]
    fn style_bible_scope_signature_marks_project_scope() {
        assert_eq!(style_bible_scope_signature(12), json!({ "projectId": 12 }));
    }

    #[test]
    fn style_bible_character_anchor_parser_keeps_relationship_and_habits() {
        let anchors = parse_style_bible_character_anchors(&json!({
            "characters": [
                {
                    "name": "林晚",
                    "fixed_appearance": "黑长发，米白风衣",
                    "default_temperament": "克制隐忍",
                    "emotion_expression": "先抿唇再低声开口",
                    "body_habits": ["抿唇", "指尖收紧"]
                }
            ],
            "core_relationships": "林晚与顾承泽长期对抗又彼此试探"
        }));
        assert_eq!(anchors.len(), 1);
        assert_eq!(anchors[0].name, "林晚");
        assert_eq!(
            anchors[0].relationship_positioning,
            "林晚与顾承泽长期对抗又彼此试探"
        );
        assert_eq!(anchors[0].body_habits, vec!["抿唇", "指尖收紧"]);
    }
}
