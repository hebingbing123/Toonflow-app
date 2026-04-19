//! 队列抽象层，支持 PostgreSQL（默认）和 Redis（可选）后端。
#![allow(dead_code)]
//!
//! 提供统一的任务队列接口，自动回退：
//! - 如果设置了 `REDIS_URL` 且 Redis 可用，使用 Redis 进行更快的队列操作
//! - 否则回退到 PostgreSQL `FOR UPDATE SKIP LOCKED`（现有行为）

mod factory;
mod pg;
mod types;

pub use factory::create_queue;
pub use pg::PgQueue;
pub use types::{JobPayload, Queue, QueueStats, QueuedJob};
