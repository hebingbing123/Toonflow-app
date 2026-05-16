//! OpenAPI fragment for the versioned WebSocket upgrade route.

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(paths(crate::harness::ws::upgrade::ws_upgrade))]
pub struct WsUpgradeOpenApi;
