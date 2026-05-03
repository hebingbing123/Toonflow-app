// Feature: ai-drama-quality-optimization
//! 最小修复范围判断（需求 35.2）

use super::models::{PatchRequest, PatchScope};

/// 根据返工粒度和原因，判断最小修复范围（需求 35.2）
pub fn resolve_minimal_scope(request: &PatchRequest) -> Result<Vec<i64>, String> {
    if request.ids.is_empty() {
        return Err(format!(
            "ids 不能为空：{} 粒度的返工需要至少一个目标 ID",
            request.scope.label()
        ));
    }
    let mut ids = request.ids.clone();
    ids.sort_unstable();
    ids.dedup();
    let max_ids = match request.scope {
        PatchScope::Episode => 3,
        PatchScope::Scene => 10,
        PatchScope::StoryboardItem => 20,
        PatchScope::VideoPrompt => 20,
        PatchScope::DeriveAsset => 10,
    };
    if ids.len() > max_ids {
        return Err(format!(
            "{} 粒度单次最多处理 {} 个对象，当前请求 {} 个。建议升级到更粗粒度或分批处理。",
            request.scope.label(),
            max_ids,
            ids.len()
        ));
    }
    Ok(ids)
}
