//! 记忆预算档与 ROI 证据 HTTP 处理器。

mod benchmark;
mod profile;

pub(crate) use benchmark::get_experiment_roi;
pub(crate) use profile::list_memory_profiles;

// Re-export utoipa path items for OpenAPI generation
pub(crate) use benchmark::__path_get_experiment_roi;
pub(crate) use profile::__path_list_memory_profiles;
