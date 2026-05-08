//! Harness 代理的多轮 OpenAI 工具调用循环（非流式补全）。

mod client;
mod emit;
mod run;
mod schemas;
mod stream_run;

#[cfg(test)]
mod tests;

pub use run::harness_agent_run;
pub use stream_run::harness_agent_run_streaming_tools;
