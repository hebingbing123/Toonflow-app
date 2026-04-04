//! Harness-oriented runtime boundaries (tools, permissions, observation).
//! Agent/model orchestration will plug in here; this module stays dependency-light.

pub mod invoke;
pub mod isolate;
pub mod observe;
pub mod permissions;
pub mod tools;
pub(crate) mod wasm_runtime;

use uuid::Uuid;

#[derive(Clone, Debug)]
pub struct HarnessContext {
    pub user_id: Uuid,
}

impl HarnessContext {
    pub fn new(user_id: Uuid) -> Self {
        Self { user_id }
    }
}
