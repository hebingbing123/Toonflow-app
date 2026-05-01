// Feature: ai-drama-quality-optimization
//! 技能包加载与完整性校验（需求 9.4, 13.7, 26.1, 26.2, 27.2, 28.2）
//!
//! - 画风技能包（ArtStyle）：`art_skills/{style}/`
//! - 故事风格技能包（StoryStyle）：`story_skills/{genre}/`

use std::collections::HashMap;

use super::storage::{read_skill_markdown, SkillReadError};

// ─── 画风技能包必需文件（需求 13.7, 28.1）────────────────────────────────────

/// 画风技能包 `art_prompt/` 目录下必需的 7 个文件
pub const ART_PROMPT_REQUIRED: &[&str] = &[
    "art_character.md",
    "art_character_derivative.md",
    "art_scene.md",
    "art_scene_derivative.md",
    "art_prop.md",
    "art_prop_derivative.md",
    "art_storyboard_video.md",
];

/// 画风技能包 `driector_skills/` 目录下必需的 3 个文件
pub const ART_DIRECTOR_REQUIRED: &[&str] = &[
    "director_planning_style.md",
    "director_storyboard_table_style.md",
    "director_storyboard.md",
];

/// 故事风格技能包 `driector_skills/` 目录下必需的 2 个文件（需求 27.3）
pub const STORY_DIRECTOR_REQUIRED: &[&str] = &[
    "director_planning_narrative.md",
    "director_storyboard_table_narrative.md",
];

// ─── 加载结果 ────────────────────────────────────────────────────────────────

/// 单个技能文件的加载结果
#[derive(Debug, Clone)]
pub enum SkillFileResult {
    /// 文件加载成功，包含内容
    Loaded(String),
    /// 文件缺失，已降级使用通用规范（画风包）
    FallbackUsed { file_name: String },
    /// 文件缺失，需要向用户提示（故事风格包）
    MissingRequiresNotice { file_name: String },
}

/// 画风技能包加载结果
#[derive(Debug)]
pub struct ArtPackLoadResult {
    /// 技能包路径（如 `art_skills/realpeople_ancient_chinese`）
    pub pack_path: String,
    /// art_prompt/ 下各文件的加载结果（key = 文件名）
    pub art_prompt_files: HashMap<String, SkillFileResult>,
    /// driector_skills/ 下各文件的加载结果（key = 文件名）
    pub director_files: HashMap<String, SkillFileResult>,
    /// 缺失的必需文件列表（用于工作台提示）
    pub missing_files: Vec<String>,
}

/// 故事风格技能包加载结果
#[derive(Debug)]
pub struct StoryPackLoadResult {
    /// 技能包路径（如 `story_skills/Sweet_romance_novel`）
    pub pack_path: String,
    /// driector_skills/ 下各文件的加载结果（key = 文件名）
    pub director_files: HashMap<String, SkillFileResult>,
    /// 缺失的必需文件列表（需要向用户提示，不静默降级）
    pub missing_files: Vec<String>,
}

// ─── 画风技能包加载（需求 9.4, 26.1, 26.2, 28.2）────────────────────────────

/// 加载画风技能包的所有必需文件。
///
/// 文件缺失时：记录 WARN 日志并降级使用通用规范（不中断流程）。
/// 返回加载结果，调用方可根据 `missing_files` 向用户展示提示。
pub fn load_art_pack(pack_path: &str) -> ArtPackLoadResult {
    let mut art_prompt_files = HashMap::new();
    let mut director_files = HashMap::new();
    let mut missing_files = Vec::new();

    // 加载 art_prompt/ 下的 7 个必需文件
    for &file_name in ART_PROMPT_REQUIRED {
        let rel_path = format!("{}/art_prompt/{}", pack_path, file_name);
        match read_skill_markdown(&rel_path) {
            Ok(doc) => {
                art_prompt_files.insert(file_name.to_string(), SkillFileResult::Loaded(doc.content));
            }
            Err(SkillReadError::NotFound) | Err(SkillReadError::BadPath(_)) => {
                tracing::warn!(
                    pack = %pack_path,
                    file = %file_name,
                    "画风技能包 art_prompt 文件缺失，降级使用通用规范"
                );
                missing_files.push(format!("art_prompt/{}", file_name));
                art_prompt_files.insert(
                    file_name.to_string(),
                    SkillFileResult::FallbackUsed {
                        file_name: file_name.to_string(),
                    },
                );
            }
            Err(e) => {
                tracing::warn!(
                    pack = %pack_path,
                    file = %file_name,
                    error = ?e,
                    "画风技能包 art_prompt 文件读取失败，降级使用通用规范"
                );
                missing_files.push(format!("art_prompt/{}", file_name));
                art_prompt_files.insert(
                    file_name.to_string(),
                    SkillFileResult::FallbackUsed {
                        file_name: file_name.to_string(),
                    },
                );
            }
        }
    }

    // 加载 driector_skills/ 下的 3 个必需文件
    for &file_name in ART_DIRECTOR_REQUIRED {
        let rel_path = format!("{}/driector_skills/{}", pack_path, file_name);
        match read_skill_markdown(&rel_path) {
            Ok(doc) => {
                director_files.insert(file_name.to_string(), SkillFileResult::Loaded(doc.content));
            }
            Err(SkillReadError::NotFound) | Err(SkillReadError::BadPath(_)) => {
                tracing::warn!(
                    pack = %pack_path,
                    file = %file_name,
                    "画风技能包 driector_skills 文件缺失，降级使用通用规范"
                );
                missing_files.push(format!("driector_skills/{}", file_name));
                director_files.insert(
                    file_name.to_string(),
                    SkillFileResult::FallbackUsed {
                        file_name: file_name.to_string(),
                    },
                );
            }
            Err(e) => {
                tracing::warn!(
                    pack = %pack_path,
                    file = %file_name,
                    error = ?e,
                    "画风技能包 driector_skills 文件读取失败，降级使用通用规范"
                );
                missing_files.push(format!("driector_skills/{}", file_name));
                director_files.insert(
                    file_name.to_string(),
                    SkillFileResult::FallbackUsed {
                        file_name: file_name.to_string(),
                    },
                );
            }
        }
    }

    ArtPackLoadResult {
        pack_path: pack_path.to_string(),
        art_prompt_files,
        director_files,
        missing_files,
    }
}

// ─── 故事风格技能包加载（需求 27.2）─────────────────────────────────────────

/// 加载故事风格技能包的必需文件。
///
/// 文件缺失时：**不静默降级**，将缺失文件记录到 `missing_files`，
/// 调用方必须向用户展示提示（需求 27.2）。
pub fn load_story_pack(pack_path: &str) -> StoryPackLoadResult {
    let mut director_files = HashMap::new();
    let mut missing_files = Vec::new();

    for &file_name in STORY_DIRECTOR_REQUIRED {
        let rel_path = format!("{}/driector_skills/{}", pack_path, file_name);
        match read_skill_markdown(&rel_path) {
            Ok(doc) => {
                director_files.insert(file_name.to_string(), SkillFileResult::Loaded(doc.content));
            }
            Err(SkillReadError::NotFound) | Err(SkillReadError::BadPath(_)) => {
                // 故事风格包：不静默降级，记录缺失并要求通知用户
                tracing::warn!(
                    pack = %pack_path,
                    file = %file_name,
                    "故事风格技能包导演技能文件缺失，需通知用户"
                );
                missing_files.push(file_name.to_string());
                director_files.insert(
                    file_name.to_string(),
                    SkillFileResult::MissingRequiresNotice {
                        file_name: file_name.to_string(),
                    },
                );
            }
            Err(e) => {
                tracing::warn!(
                    pack = %pack_path,
                    file = %file_name,
                    error = ?e,
                    "故事风格技能包文件读取失败，需通知用户"
                );
                missing_files.push(file_name.to_string());
                director_files.insert(
                    file_name.to_string(),
                    SkillFileResult::MissingRequiresNotice {
                        file_name: file_name.to_string(),
                    },
                );
            }
        }
    }

    StoryPackLoadResult {
        pack_path: pack_path.to_string(),
        director_files,
        missing_files,
    }
}

// ─── 技能包完整性校验（需求 13.7, 28.2）─────────────────────────────────────

/// 画风技能包完整性校验结果
#[derive(Debug)]
pub struct ArtPackValidation {
    pub pack_path: String,
    pub is_complete: bool,
    /// 缺失的 art_prompt/ 文件
    pub missing_art_prompt: Vec<String>,
    /// 缺失的 driector_skills/ 文件
    pub missing_director: Vec<String>,
}

/// 故事风格技能包完整性校验结果
#[derive(Debug)]
pub struct StoryPackValidation {
    pub pack_path: String,
    pub is_complete: bool,
    /// 缺失的 driector_skills/ 文件
    pub missing_director: Vec<String>,
}

/// 校验画风技能包完整性：检查必需的 7 个 art_prompt 文件和 3 个 driector_skills 文件（需求 13.7, 28.2）
pub fn validate_art_pack(pack_path: &str) -> ArtPackValidation {
    let root = super::storage::skills_root();

    let missing_art_prompt: Vec<String> = ART_PROMPT_REQUIRED
        .iter()
        .filter(|&&file_name| {
            let path = root.join(pack_path).join("art_prompt").join(file_name);
            !path.exists()
        })
        .map(|&s| s.to_string())
        .collect();

    let missing_director: Vec<String> = ART_DIRECTOR_REQUIRED
        .iter()
        .filter(|&&file_name| {
            let path = root
                .join(pack_path)
                .join("driector_skills")
                .join(file_name);
            !path.exists()
        })
        .map(|&s| s.to_string())
        .collect();

    let is_complete = missing_art_prompt.is_empty() && missing_director.is_empty();

    if !is_complete {
        tracing::warn!(
            pack = %pack_path,
            missing_art_prompt = ?missing_art_prompt,
            missing_director = ?missing_director,
            "画风技能包不完整，缺失必需文件"
        );
    }

    ArtPackValidation {
        pack_path: pack_path.to_string(),
        is_complete,
        missing_art_prompt,
        missing_director,
    }
}

/// 校验故事风格技能包完整性：检查必需的 2 个 driector_skills 文件（需求 27.3）
pub fn validate_story_pack(pack_path: &str) -> StoryPackValidation {
    let root = super::storage::skills_root();

    let missing_director: Vec<String> = STORY_DIRECTOR_REQUIRED
        .iter()
        .filter(|&&file_name| {
            let path = root
                .join(pack_path)
                .join("driector_skills")
                .join(file_name);
            !path.exists()
        })
        .map(|&s| s.to_string())
        .collect();

    let is_complete = missing_director.is_empty();

    if !is_complete {
        tracing::warn!(
            pack = %pack_path,
            missing_director = ?missing_director,
            "故事风格技能包不完整，缺失必需文件"
        );
    }

    StoryPackValidation {
        pack_path: pack_path.to_string(),
        is_complete,
        missing_director,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn art_prompt_required_has_seven_files() {
        assert_eq!(ART_PROMPT_REQUIRED.len(), 7);
    }

    #[test]
    fn art_director_required_has_three_files() {
        assert_eq!(ART_DIRECTOR_REQUIRED.len(), 3);
    }

    #[test]
    fn story_director_required_has_two_files() {
        assert_eq!(STORY_DIRECTOR_REQUIRED.len(), 2);
    }

    #[test]
    fn validate_art_pack_nonexistent_pack_reports_all_missing() {
        let result = validate_art_pack("art_skills/__nonexistent_test_pack__");
        assert!(!result.is_complete);
        assert_eq!(result.missing_art_prompt.len(), ART_PROMPT_REQUIRED.len());
        assert_eq!(result.missing_director.len(), ART_DIRECTOR_REQUIRED.len());
    }

    #[test]
    fn validate_story_pack_nonexistent_pack_reports_all_missing() {
        let result = validate_story_pack("story_skills/__nonexistent_test_genre__");
        assert!(!result.is_complete);
        assert_eq!(result.missing_director.len(), STORY_DIRECTOR_REQUIRED.len());
    }

    #[test]
    fn load_art_pack_nonexistent_returns_fallbacks() {
        let result = load_art_pack("art_skills/__nonexistent_test_pack__");
        // 所有文件都应该是 FallbackUsed
        for (_, v) in &result.art_prompt_files {
            assert!(matches!(v, SkillFileResult::FallbackUsed { .. }));
        }
        for (_, v) in &result.director_files {
            assert!(matches!(v, SkillFileResult::FallbackUsed { .. }));
        }
        assert_eq!(
            result.missing_files.len(),
            ART_PROMPT_REQUIRED.len() + ART_DIRECTOR_REQUIRED.len()
        );
    }

    #[test]
    fn load_story_pack_nonexistent_returns_missing_notices() {
        let result = load_story_pack("story_skills/__nonexistent_test_genre__");
        for (_, v) in &result.director_files {
            assert!(matches!(v, SkillFileResult::MissingRequiresNotice { .. }));
        }
        assert_eq!(result.missing_files.len(), STORY_DIRECTOR_REQUIRED.len());
    }
}
