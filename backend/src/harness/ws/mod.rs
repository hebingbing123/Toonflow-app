//! WebSocket stack for **`GET /api/v1/ws`**: upgrade → connection loop → auth → dispatch → tool/agent/chat/session handlers.

pub mod agent;
pub mod auth;
pub mod channel;
pub mod chat;
pub mod connection;
pub mod dispatch;
pub mod outbound;
pub mod session;
pub mod tool;
pub mod upgrade;
