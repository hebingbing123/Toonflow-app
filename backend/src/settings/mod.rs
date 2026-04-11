//! Settings / legacy **`/api/setting/*`** HTTP surface (about, vendors, dev switch, danger, memory, agent deploy).
//! Also includes **`/api/v1/agents/memory/*`** (Postgres **`app_agent_memory`**).

pub mod about;
pub mod agent_deploy;
pub mod agent_memory;
pub mod danger;
pub mod dev;
pub mod memory_config;
pub mod vendors;
