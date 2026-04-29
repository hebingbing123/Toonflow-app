//! Director manual parsing, cue matching, and anchor selection.

use super::*;

pub(super) struct ArtStyleDirectorProfile {
    pub(super) aliases: &'static [&'static str],
    pub(super) director_storyboard: &'static str,
    pub(super) director_storyboard_table_style: &'static str,
}

#[derive(Debug, Clone)]
pub(super) struct DirectorEmotionCue {
    pub(super) emotion_terms: Vec<String>,
    pub(super) face: String,
    pub(super) eyes: String,
    pub(super) micro_expression: String,
}

#[derive(Debug, Clone)]
pub(super) struct DirectorEnvironmentTextureCue {
    pub(super) cue: String,
    pub(super) match_terms: Vec<String>,
}

pub(super) const ART_STYLE_DIRECTOR_PROFILES: &[ArtStyleDirectorProfile] = &[
    ArtStyleDirectorProfile {
        aliases: &[
            "2d_90s_japanese_anime",
            "90年代日式动画",
            "日式动画",
            "怀旧日漫",
        ],
        director_storyboard: include_str!("../../../../../data/skills/art_skills/2D_90s_japanese_anime/driector_skills/director_storyboard.md"),
        director_storyboard_table_style: include_str!("../../../../../data/skills/art_skills/2D_90s_japanese_anime/driector_skills/director_storyboard_table_style.md"),
    },
    ArtStyleDirectorProfile {
        aliases: &["2d_chinese_guofeng", "国风二次元", "新国潮", "国风动画"],
        director_storyboard: include_str!("../../../../../data/skills/art_skills/2D_chinese_guofeng/driector_skills/director_storyboard.md"),
        director_storyboard_table_style: include_str!("../../../../../data/skills/art_skills/2D_chinese_guofeng/driector_skills/director_storyboard_table_style.md"),
    },
    ArtStyleDirectorProfile {
        aliases: &["2d_flat_design", "flat design", "2d扁平", "扁平风"],
        director_storyboard: include_str!("../../../../../data/skills/art_skills/2D_flat_design/driector_skills/director_storyboard.md"),
        director_storyboard_table_style: include_str!("../../../../../data/skills/art_skills/2D_flat_design/driector_skills/director_storyboard_table_style.md"),
    },
    ArtStyleDirectorProfile {
        aliases: &[
            "2d_mature_urban_romance",
            "成熟都市言情二次元动画",
            "成熟都市言情",
            "都市言情动画",
        ],
        director_storyboard: include_str!("../../../../../data/skills/art_skills/2D_mature_urban_romance/driector_skills/director_storyboard.md"),
        director_storyboard_table_style: include_str!("../../../../../data/skills/art_skills/2D_mature_urban_romance/driector_skills/director_storyboard_table_style.md"),
    },
    ArtStyleDirectorProfile {
        aliases: &["3d_anime_render", "3d动画渲染", "3d 动画渲染"],
        director_storyboard: include_str!("../../../../../data/skills/art_skills/3D_anime_render/driector_skills/director_storyboard.md"),
        director_storyboard_table_style: include_str!("../../../../../data/skills/art_skills/3D_anime_render/driector_skills/director_storyboard_table_style.md"),
    },
    ArtStyleDirectorProfile {
        aliases: &["3d_chinese_traditional", "国风3d", "国风 3d"],
        director_storyboard: include_str!("../../../../../data/skills/art_skills/3D_chinese_traditional/driector_skills/director_storyboard.md"),
        director_storyboard_table_style: include_str!("../../../../../data/skills/art_skills/3D_chinese_traditional/driector_skills/director_storyboard_table_style.md"),
    },
    ArtStyleDirectorProfile {
        aliases: &["3d_clay_stopmotion", "定格动画黏土", "黏土", "黏土风"],
        director_storyboard: include_str!("../../../../../data/skills/art_skills/3D_clay_stopmotion/driector_skills/director_storyboard.md"),
        director_storyboard_table_style: include_str!("../../../../../data/skills/art_skills/3D_clay_stopmotion/driector_skills/director_storyboard_table_style.md"),
    },
    ArtStyleDirectorProfile {
        aliases: &[
            "realpeople_ancient_chinese",
            "真人古风写实",
            "古风写实",
            "古风真人",
        ],
        director_storyboard: include_str!("../../../../../data/skills/art_skills/realpeople_ancient_chinese/driector_skills/director_storyboard.md"),
        director_storyboard_table_style: include_str!("../../../../../data/skills/art_skills/realpeople_ancient_chinese/driector_skills/director_storyboard_table_style.md"),
    },
    ArtStyleDirectorProfile {
        aliases: &[
            "realpeople_urban_modern",
            "真人都市写实",
            "都市写实",
            "现代都市写实",
            "真人现代",
        ],
        director_storyboard: include_str!("../../../../../data/skills/art_skills/realpeople_urban_modern/driector_skills/director_storyboard.md"),
        director_storyboard_table_style: include_str!("../../../../../data/skills/art_skills/realpeople_urban_modern/driector_skills/director_storyboard_table_style.md"),
    },
];

impl GenerateVideoPromptDiagnostics {
    pub(super) fn with_runtime_notes(
        mut self,
        selection: Option<&AutoNegativePromptSelection>,
        observation_note: Option<&str>,
    ) -> Self {
        let negative_prompt = selection.and_then(|value| value.prompt.as_deref());
        let negative_constraint_count = selection.map(|value| value.fragment_count).unwrap_or(0);
        let negative_budget_tier = selection.map(|value| value.budget_tier);
        let auto_negative_source = selection
            .and_then(AutoNegativePromptSelection::source_label)
            .map(str::to_string)
            .or_else(|| {
                observation_note
                    .filter(|note| !normalize_prompt_text(note).is_empty())
                    .map(|_| "pending_observation_note".to_string())
            });
        let auto_negative_review_fragment_count = selection
            .map(|value| value.review_fragment_count)
            .unwrap_or(0);
        let auto_negative_memory_fragment_count = selection
            .map(|value| value.rejected_memory_fragment_count)
            .unwrap_or(0);
        self.negative_prompt_chars = negative_prompt
            .map(normalize_prompt_text)
            .map(|value| value.chars().count())
            .unwrap_or(0);
        self.negative_constraint_count = negative_constraint_count;
        self.negative_budget_tier = negative_budget_tier.unwrap_or("lean").to_string();
        self.auto_negative_source = auto_negative_source;
        self.auto_negative_review_fragment_count = auto_negative_review_fragment_count;
        self.auto_negative_memory_fragment_count = auto_negative_memory_fragment_count;
        self.observation_note_chars = observation_note
            .map(normalize_prompt_text)
            .map(|value: String| value.chars().count())
            .unwrap_or(0);
        self
    }

    pub(super) fn with_memory_optimization(
        mut self,
        result: Option<
            &crate::production::workbench::video_prompt_memory::VideoMemoryOptimizationResult,
        >,
    ) -> Self {
        let Some(result) = result else {
            return self;
        };
        self.memory_optimization_applied = result.removed_rows > 0;
        self.memory_optimization_removed_rows = result.removed_rows;
        self.memory_optimization_removed_chars = result.removed_chars;
        self.memory_optimization_removed_visual_rows = result.removed_visual_rows;
        self.memory_optimization_removed_duplicate_rows = result.removed_duplicate_rows;
        self
    }
}

pub(super) fn art_style_director_profile(
    project_art_style: &str,
) -> Option<&'static ArtStyleDirectorProfile> {
    let normalized = normalize_prompt_text(project_art_style).to_lowercase();
    if normalized.is_empty() {
        return None;
    }

    ART_STYLE_DIRECTOR_PROFILES.iter().find(|profile| {
        profile.aliases.iter().any(|alias| {
            let alias = normalize_prompt_text(alias).to_lowercase();
            !alias.is_empty() && normalized.contains(&alias)
        })
    })
}

pub(super) fn parse_director_emotion_cues(markdown: &str) -> Vec<DirectorEmotionCue> {
    let mut cues = Vec::new();
    let mut in_emotion_table = false;

    for raw_line in markdown.lines() {
        let line = raw_line.trim();
        if !in_emotion_table {
            if line.contains("情绪") && line.contains("面容") && line.contains("眼神") {
                in_emotion_table = true;
            }
            continue;
        }

        if line.starts_with("## ") && !line.contains("情绪") {
            break;
        }
        if !line.starts_with('|') || line.contains("---") || line.contains("情绪输入") {
            continue;
        }

        let cells = line
            .trim_matches('|')
            .split('|')
            .map(normalize_prompt_text)
            .collect::<Vec<_>>();
        if cells.len() < 4 {
            continue;
        }

        let emotion_terms = cells[0]
            .split(['/', '／'])
            .map(normalize_prompt_text)
            .filter(|term| !term.is_empty())
            .collect::<Vec<_>>();
        if emotion_terms.is_empty() {
            continue;
        }

        cues.push(DirectorEmotionCue {
            emotion_terms,
            face: cells[1].clone(),
            eyes: cells[2].clone(),
            micro_expression: cells[3].clone(),
        });
    }

    cues
}

pub(super) fn score_director_emotion_cue_match(
    fields: &StructuredStoryboardDescription,
    cue: &DirectorEmotionCue,
) -> usize {
    let mood = normalize_prompt_text(&fields.mood);
    if mood.is_empty() {
        return 0;
    }

    let mut score = cue
        .emotion_terms
        .iter()
        .map(|term| {
            if term.is_empty() {
                return 0;
            }
            if mood == *term {
                return 8;
            }
            if mood.contains(term) || term.contains(&mood) {
                return 6;
            }
            let mood_chars = mood.chars().collect::<Vec<_>>();
            let term_chars = term.chars().collect::<Vec<_>>();
            let overlap = mood_chars
                .iter()
                .filter(|ch| term_chars.contains(ch))
                .count();
            if overlap >= 2 {
                3 + overlap
            } else if overlap == 1 {
                1
            } else {
                0
            }
        })
        .max()
        .unwrap_or(0) as i32;

    if current_storyboard_is_fragile_emotional_turn(fields) {
        score += fragile_turn_director_emotion_cue_bonus(cue);
    }

    score.max(0) as usize
}

pub(super) fn fragile_turn_director_emotion_cue_bonus(cue: &DirectorEmotionCue) -> i32 {
    let mut bonus = 0;

    if cue.emotion_terms.iter().any(|term| {
        ["悲伤", "失落", "压抑", "哀伤", "哀戚"]
            .iter()
            .any(|keyword| term.contains(keyword))
    }) {
        bonus += 7;
    }
    if cue.emotion_terms.iter().any(|term| {
        ["隐忍", "克制", "冷漠", "坚定", "愤怒", "压迫"]
            .iter()
            .any(|keyword| term.contains(keyword))
    }) {
        bonus -= 7;
    }

    let combined_fragments = [
        cue.face.as_str(),
        cue.eyes.as_str(),
        cue.micro_expression.as_str(),
    ]
    .join(" ");
    if [
        "低落",
        "哀戚",
        "眼眶微红",
        "眼神低垂",
        "眉头轻锁",
        "眉心轻蹙",
        "黯淡",
        "泪",
    ]
    .iter()
    .any(|keyword| combined_fragments.contains(keyword))
    {
        bonus += 4;
    }
    if [
        "神情内敛",
        "眼神深沉",
        "眼底有情绪压抑",
        "唇线收紧",
        "喉结微动",
    ]
    .iter()
    .any(|keyword| combined_fragments.contains(keyword))
    {
        bonus -= 4;
    }

    bonus
}

pub(super) fn parse_director_motion_cue(markdown: &str) -> Option<String> {
    let mut in_motion_section = false;

    for raw_line in markdown.lines() {
        let line = raw_line.trim();
        if !in_motion_section {
            if line.starts_with("## ") && line.contains("动作节奏") {
                in_motion_section = true;
            }
            continue;
        }

        if line.starts_with("## ") {
            break;
        }
        if !line.starts_with("- **") || !line.contains("动作") {
            continue;
        }

        let title = line
            .strip_prefix("- **")
            .and_then(|value| value.split("**").next())
            .map(normalize_prompt_text)
            .unwrap_or_default();
        let body = line
            .split_once('—')
            .or_else(|| line.split_once("——"))
            .map(|(_, value)| normalize_prompt_text(value))
            .unwrap_or_default();
        let quoted = body
            .split('"')
            .enumerate()
            .filter(|(idx, _)| idx % 2 == 1)
            .map(|(_, value)| normalize_prompt_text(value))
            .find(|value| !value.is_empty());

        let cue = if let Some(quoted) = quoted {
            format!("动作{}", quoted.replace('/', ""))
        } else if title.contains("自然") {
            "动作自然".to_string()
        } else if title.contains("克制") {
            "动作从容克制".to_string()
        } else if title.contains("优雅") {
            "动作缓慢优雅".to_string()
        } else if title.contains("简洁") {
            "动作简洁平滑".to_string()
        } else if title.contains("慢") || title.contains("缓") {
            "动作缓慢".to_string()
        } else {
            String::new()
        };

        let cue = normalize_prompt_text(&cue);
        if !cue.is_empty() {
            return Some(cue);
        }
    }

    None
}

pub(super) fn parse_director_environment_cues(markdown: &str) -> Vec<String> {
    let mut cues = Vec::new();
    let mut in_environment_section = false;

    for raw_line in markdown.lines() {
        let line = raw_line.trim();
        if !in_environment_section {
            if line.starts_with("## ") && (line.contains("环境动态") || line.contains("色块动态"))
            {
                in_environment_section = true;
            }
            continue;
        }

        if line.starts_with("## ") {
            break;
        }
        if !line.starts_with("- **") || !(line.contains("画面呼吸感") || line.contains("元素优先"))
        {
            continue;
        }

        let body = line
            .split_once('—')
            .or_else(|| line.split_once("——"))
            .map(|(_, value)| normalize_prompt_text(value))
            .unwrap_or_default();
        let Some((_, tail)) = body.split_once('：') else {
            continue;
        };
        let trimmed_tail = tail
            .split("。每")
            .next()
            .unwrap_or(tail)
            .split("，禁止")
            .next()
            .unwrap_or(tail);

        for cue in trimmed_tail
            .split(['、', '，', ',', '/', '／'])
            .map(normalize_prompt_text)
            .filter(|cue| cue.chars().count() >= 2)
        {
            if !cues.iter().any(|existing| existing == &cue) {
                cues.push(cue);
            }
        }
    }

    cues
}

pub(super) fn parse_director_environment_texture_cues(
    markdown: &str,
) -> Vec<DirectorEnvironmentTextureCue> {
    let mut cues: Vec<DirectorEnvironmentTextureCue> = Vec::new();
    let mut in_environment_section = false;

    for raw_line in markdown.lines() {
        let line = raw_line.trim();
        if !in_environment_section {
            if line.starts_with("## ") && (line.contains("环境动态") || line.contains("色块动态"))
            {
                in_environment_section = true;
            }
            continue;
        }

        if line.starts_with("## ") {
            break;
        }
        if !line.starts_with("- **") || !(line.contains("动态表现") || line.contains("动态质感"))
        {
            continue;
        }

        let body = line
            .split_once('—')
            .or_else(|| line.split_once("——"))
            .map(|(_, value)| normalize_prompt_text(value))
            .unwrap_or_default();
        let tail = body
            .split_once('：')
            .map(|(_, value)| value)
            .unwrap_or(body.as_str());

        for fragment in tail
            .split(['、', '，', ',', '；', ';'])
            .map(normalize_prompt_text)
            .filter(|value| !value.is_empty())
        {
            let cue = if fragment.contains("光影斑驳") || fragment.contains("手绘质感") {
                "手绘光影斑驳"
            } else if fragment.contains("线条美感") || fragment.contains("细腻线条") {
                "细腻线条动态"
            } else if fragment.contains("赛璐璐渲染效果") || fragment.contains("赛璐璐平涂质感")
            {
                "赛璐璐动态质感"
            } else {
                continue;
            };

            if cues.iter().any(|existing| existing.cue == cue) {
                continue;
            }

            let match_terms = DIRECTOR_ENVIRONMENT_TEXTURE_MATCH_TOKENS
                .iter()
                .filter(|token| fragment.contains(**token))
                .map(|token| (*token).to_string())
                .collect::<Vec<_>>();

            cues.push(DirectorEnvironmentTextureCue {
                cue: cue.to_string(),
                match_terms,
            });
        }
    }

    cues
}

pub(super) fn score_director_environment_cue_match(
    fields: &StructuredStoryboardDescription,
    cue: &str,
) -> usize {
    let cue = normalize_prompt_text(cue);
    if cue.is_empty() {
        return 0;
    }

    let context = normalize_prompt_text(
        &[
            fields.setting.as_str(),
            fields.action.as_str(),
            fields.sound.as_str(),
            fields.lighting.as_str(),
        ]
        .into_iter()
        .filter(|part| !part.trim().is_empty())
        .collect::<Vec<_>>()
        .join(" "),
    );

    if context.is_empty() {
        return 0;
    }
    if context.contains(&cue) {
        return 12;
    }

    let mut score = 0;
    for token in DIRECTOR_ENVIRONMENT_PRIMARY_TOKENS {
        if cue.contains(token) && context.contains(token) {
            score += 3;
        }
    }
    for token in DIRECTOR_ENVIRONMENT_SECONDARY_TOKENS {
        if cue.contains(token) && context.contains(token) {
            score += 1;
        }
    }
    score
}

pub(super) fn score_director_environment_texture_cue_match(
    fields: &StructuredStoryboardDescription,
    cue: &DirectorEnvironmentTextureCue,
) -> usize {
    let context = normalize_prompt_text(
        &[
            fields.setting.as_str(),
            fields.action.as_str(),
            fields.sound.as_str(),
            fields.lighting.as_str(),
        ]
        .into_iter()
        .filter(|part| !part.trim().is_empty())
        .collect::<Vec<_>>()
        .join(" "),
    );
    if context.is_empty() {
        return 0;
    }

    let score = cue
        .match_terms
        .iter()
        .filter(|term| context.contains(term.as_str()))
        .count()
        * 3;

    score
}

pub(super) fn storyboard_environment_dynamic_density(
    fields: &StructuredStoryboardDescription,
) -> usize {
    let context = normalize_prompt_text(
        &[
            fields.setting.as_str(),
            fields.action.as_str(),
            fields.sound.as_str(),
            fields.lighting.as_str(),
        ]
        .into_iter()
        .filter(|part| !part.trim().is_empty())
        .collect::<Vec<_>>()
        .join(" "),
    );
    if context.is_empty() {
        return 0;
    }

    STORYBOARD_ENVIRONMENT_DYNAMIC_TOKENS
        .iter()
        .filter(|token| context.contains(**token))
        .count()
}

pub(super) fn resolve_performance_style_anchor(
    project_art_style: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let fields = structured_fields?;
    if fields.subject.trim().is_empty() || fields.mood.trim().is_empty() {
        return None;
    }

    let profile = art_style_director_profile(project_art_style?)?;
    let cue = parse_director_emotion_cues(profile.director_storyboard)
        .into_iter()
        .filter_map(|cue| {
            let score = score_director_emotion_cue_match(fields, &cue);
            (score > 0).then_some((score, cue))
        })
        .max_by(|(left_score, left_cue), (right_score, right_cue)| {
            left_score.cmp(right_score).then_with(|| {
                right_cue
                    .emotion_terms
                    .len()
                    .cmp(&left_cue.emotion_terms.len())
            })
        })?
        .1;

    let mut fragments = Vec::new();
    for (group, fragment) in [
        (DirectorEmotionFragmentGroup::Face, cue.face.as_str()),
        (DirectorEmotionFragmentGroup::Eyes, cue.eyes.as_str()),
        (
            DirectorEmotionFragmentGroup::MicroExpression,
            cue.micro_expression.as_str(),
        ),
    ] {
        let Some(fragment) = compact_director_emotion_fragment_group(fragment, group) else {
            continue;
        };
        let Some(fragment) = trim_director_performance_fragment_against_storyboard_fields(
            &fragment,
            &[fields.action.as_str(), fields.dialogue.as_str()],
        ) else {
            continue;
        };
        if prompt_fragment_is_covered(&fragment, prompt_coverage)
            || fragments.iter().any(|existing| existing == &fragment)
        {
            continue;
        }
        fragments.push(fragment);
    }

    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join(", "),
        VIDEO_PROMPT_PERFORMANCE_ANCHOR_MAX_CHARS,
    ))
}

#[derive(Clone, Copy)]
pub(super) enum DirectorEmotionFragmentGroup {
    Face,
    Eyes,
    MicroExpression,
}

pub(super) fn compact_director_emotion_fragment_group(
    fragment: &str,
    group: DirectorEmotionFragmentGroup,
) -> Option<String> {
    let candidates = split_prompt_note_fragments(fragment).collect::<Vec<_>>();
    if candidates.is_empty() {
        return None;
    }
    if candidates.len() == 1 {
        return candidates.into_iter().next();
    }

    candidates.into_iter().max_by(|left, right| {
        score_director_emotion_fragment(group, left)
            .cmp(&score_director_emotion_fragment(group, right))
            .then_with(|| right.chars().count().cmp(&left.chars().count()))
            .then_with(|| left.cmp(right))
    })
}

pub(super) fn score_director_emotion_fragment(
    group: DirectorEmotionFragmentGroup,
    fragment: &str,
) -> i32 {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return i32::MIN;
    }

    let mut score = normalized.chars().count().min(10) as i32;
    let preferred_prefixes: &[&str] = match group {
        DirectorEmotionFragmentGroup::Face => &["神情", "眉眼", "面容", "面色", "表情", "神态"],
        DirectorEmotionFragmentGroup::Eyes => &["眼神", "目光", "眼底", "眼尾", "眼眶", "视线"],
        DirectorEmotionFragmentGroup::MicroExpression => {
            &["唇线", "喉结", "嘴角", "眉心", "眉头", "眉梢", "唇形"]
        }
    };
    for (idx, prefix) in preferred_prefixes.iter().enumerate() {
        if normalized.starts_with(prefix) {
            score += 12 - idx as i32;
            break;
        }
    }

    for keyword in [
        "唇线", "喉结", "嘴角", "眉心", "眉头", "眉梢", "唇形", "眼底", "眼尾", "眼眶",
    ] {
        if normalized.contains(keyword) {
            score += 4;
        }
    }
    for keyword in ["情绪", "气质", "表情", "神态"] {
        if normalized.contains(keyword) {
            score -= match group {
                DirectorEmotionFragmentGroup::MicroExpression if keyword == "表情" => 1,
                _ => 3,
            };
        }
    }
    if normalized.contains("有") {
        score -= 1;
    }

    score
}

pub(super) fn resolve_environment_style_anchor(
    project_art_style: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let fields = structured_fields?;
    if fields.setting.trim().is_empty() {
        return None;
    }
    if storyboard_environment_dynamic_density(fields) >= 3 {
        return None;
    }

    let profile = art_style_director_profile(project_art_style?)?;
    let cue = parse_director_environment_cues(profile.director_storyboard_table_style)
        .into_iter()
        .filter_map(|cue| {
            let score = score_director_environment_cue_match(fields, &cue);
            (score > 0).then_some((score, cue))
        })
        .max_by(|(left_score, left_cue), (right_score, right_cue)| {
            left_score
                .cmp(right_score)
                .then_with(|| right_cue.chars().count().cmp(&left_cue.chars().count()))
        })?
        .1;

    if prompt_fragment_is_covered(&cue, prompt_coverage)
        || fields.setting.contains(&cue)
        || fields.action.contains(&cue)
        || fields.sound.contains(&cue)
    {
        return None;
    }

    Some(clip_prompt_fragment(
        &cue,
        VIDEO_PROMPT_ENVIRONMENT_ANCHOR_MAX_CHARS,
    ))
}

pub(super) fn resolve_guardrail_performance_anchor(
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let fields = structured_fields?;
    let pressure = constraint_pressure.filter(|pressure| {
        pressure.has_dialogue_guardrail
            || pressure.has_emotion_guardrail
            || pressure.has_identity_guardrail
    });
    let has_fragile_turn = current_storyboard_is_fragile_emotional_turn(fields);
    let has_visible_dialogue_risk = storyboard_has_visible_speech_performance_risk(fields, None);
    let should_add_proactive_anchor = has_visible_dialogue_risk
        || (has_fragile_turn && video_prompt_scene_needs_identity_memory(fields));

    if pressure.is_none() && !should_add_proactive_anchor {
        return None;
    }

    let normalized_coverage = prompt_coverage
        .iter()
        .map(|fragment| normalize_prompt_text(fragment))
        .collect::<Vec<_>>();
    let has_face_signal = normalized_coverage.iter().any(|fragment| {
        ["眼神", "目光", "眼底", "眼尾", "喉结", "嘴角", "唇线"]
            .iter()
            .any(|keyword| fragment.contains(keyword))
    });
    let has_delivery_signal = normalized_coverage.iter().any(|fragment| {
        ["气息", "换气", "尾音", "发颤"]
            .iter()
            .any(|keyword| fragment.contains(keyword))
    });

    let mut fragments = Vec::new();
    if !storyboard_dialogue_is_empty(&fields.dialogue)
        && pressure.is_some_and(|pressure| pressure.has_dialogue_guardrail)
    {
        if !has_face_signal {
            fragments.push(if has_fragile_turn {
                "开口前先压住气息".to_string()
            } else {
                "眼神先动再开口".to_string()
            });
        }
        if !has_delivery_signal {
            fragments.push(if has_fragile_turn {
                "尾音带轻颤".to_string()
            } else {
                "气息带情绪起伏".to_string()
            });
        }
    } else if pressure.is_some_and(|pressure| {
        pressure.has_emotion_guardrail
            || (pressure.has_identity_guardrail && video_prompt_scene_needs_identity_memory(fields))
    }) {
        if has_face_signal {
            return None;
        }
        fragments.push("眼神嘴角细微递进".to_string());
    } else if has_visible_dialogue_risk {
        if !has_face_signal {
            fragments.push(if has_fragile_turn {
                "开口前先压住气息".to_string()
            } else {
                "眼神先动再开口".to_string()
            });
        } else if !has_delivery_signal && has_fragile_turn {
            fragments.push("尾音带轻颤".to_string());
        }
    } else if has_fragile_turn && video_prompt_scene_needs_identity_memory(fields) {
        if has_face_signal {
            return None;
        }
        fragments.push("眼神嘴角细微递进".to_string());
    }

    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join(", "),
        VIDEO_PROMPT_GUARDRAIL_PERFORMANCE_ANCHOR_MAX_CHARS,
    ))
}

pub(super) fn resolve_environment_texture_style_anchor(
    project_art_style: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let fields = structured_fields?;
    if fields.setting.trim().is_empty() {
        return None;
    }

    let profile = art_style_director_profile(project_art_style?)?;
    let cue = parse_director_environment_texture_cues(profile.director_storyboard_table_style)
        .into_iter()
        .filter_map(|cue| {
            let score = score_director_environment_texture_cue_match(fields, &cue);
            (score > 0).then_some((score, cue))
        })
        .max_by(|(left_score, left_cue), (right_score, right_cue)| {
            left_score.cmp(right_score).then_with(|| {
                right_cue
                    .cue
                    .chars()
                    .count()
                    .cmp(&left_cue.cue.chars().count())
            })
        })?
        .1
        .cue;

    if prompt_fragment_is_covered(&cue, prompt_coverage)
        || fields.setting.contains(&cue)
        || fields.action.contains(&cue)
        || fields.sound.contains(&cue)
    {
        return None;
    }

    Some(clip_prompt_fragment(
        &cue,
        VIDEO_PROMPT_ENVIRONMENT_TEXTURE_ANCHOR_MAX_CHARS,
    ))
}

pub(super) fn resolve_motion_style_anchor(
    project_art_style: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let fields = structured_fields?;
    if fields.subject.trim().is_empty() || fields.action.trim().is_empty() {
        return None;
    }

    let profile = art_style_director_profile(project_art_style?)?;
    let cue = parse_director_motion_cue(profile.director_storyboard_table_style)?;
    if motion_style_anchor_lags_fragile_emotional_turn(&cue, fields) {
        return None;
    }
    if prompt_fragment_is_covered(&cue, prompt_coverage) || fields.action.contains(&cue) {
        return None;
    }

    Some(clip_prompt_fragment(
        &cue,
        VIDEO_PROMPT_MOTION_ANCHOR_MAX_CHARS,
    ))
}

pub(super) fn motion_style_anchor_lags_fragile_emotional_turn(
    cue: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    current_storyboard_is_fragile_emotional_turn(fields)
        && ["动作缓慢", "动作缓慢优雅", "动作自然", "动作克制自然"]
            .iter()
            .any(|keyword| cue.contains(keyword))
        && [
            fields.action.as_str(),
            fields.dialogue.as_str(),
            fields.mood.as_str(),
        ]
        .into_iter()
        .any(|field| {
            [
                "哽咽",
                "失声",
                "抽气",
                "发颤",
                "颤声",
                "强忍泪意",
                "含泪",
                "鼻音",
                "哭",
            ]
            .iter()
            .any(|keyword| field.contains(keyword))
        })
}
