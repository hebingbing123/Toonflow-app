//! 统一评测量表（JudgeRubric）。
//!
//! 为实验结果和人工复核提供统一的质量维度、问题等级和权重配置。
//!
//! 子模块：
//! - `types` — 评测量表数据模型
//! - `rubric` — 量表定义与权重配置
//! - `scorer` — 自动评分逻辑
//! - `handlers` — HTTP 处理器

mod handlers;
mod rubric;
mod scorer;
mod types;

pub use handlers::routes;
pub use rubric::{get_rubric_for_stage, RubricConfig};
pub use scorer::score_experiment_result;
pub use types::{
    AutoJudgeConfidence, ExperimentScoreSummary, IssueSeverity, QualityDimension,
    RubricDimensionScore, RubricIssue,
};

#[allow(unused_imports)]
pub(crate) use handlers::{__path_get_rubrics, __path_score_preview, get_rubrics, score_preview};
