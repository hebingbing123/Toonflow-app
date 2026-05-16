pub mod completion;
pub mod parse;
pub mod stream;

pub use completion::{
    chat_completion_assistant_text, chat_completion_with_usage, ChatCompletionResult,
};
pub use parse::TokenUsage;
pub use stream::stream_chat_turn;

// Internal helpers, not exported from crate root
#[cfg(test)]
pub(crate) use parse::{parse_assistant_content, parse_sse_data_line};
