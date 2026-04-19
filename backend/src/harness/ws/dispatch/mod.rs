//! 认证的 WebSocket JSON 信封解析 + 路由到 Harness 处理器。

mod client_text;
mod envelope;

#[cfg(test)]
mod tests;

pub(crate) use client_text::dispatch_client_text;
