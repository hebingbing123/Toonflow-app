//! 核心 HTTP 处理器。
//!
//! 由 [`super::router::build_router`] 挂载，提供健康检查、版本信息、
//! 就绪状态和用户信息服务。

mod me;
pub mod metrics;
mod system;
mod types;

#[allow(unused_imports)]
pub(crate) use me::{__path_me, me};
#[allow(unused_imports)]
pub(crate) use metrics::{
    __path_get_metrics, __path_get_sli_definitions, __path_get_sli_status, get_metrics,
    get_sli_definitions, get_sli_status,
};
#[allow(unused_imports)]
pub(crate) use system::{__path_health, __path_ping, __path_ready, __path_version};
pub(crate) use system::{health, ping, ready, version};
pub(crate) use types::{HealthResponse, MeResponse, PingResponse, ReadyResponse, VersionResponse};
