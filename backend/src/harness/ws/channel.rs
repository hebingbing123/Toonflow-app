//! WebSocket 代理频道鉴别器（脚本 vs 制作规划）。

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WsAgentChannel {
    Script,
    Production,
}

impl WsAgentChannel {
    /// Display name passed into LLM system prompts for this channel.
    #[must_use]
    pub const fn assistant_name_zh(self) -> &'static str {
        match self {
            Self::Script => "统筹",
            Self::Production => "视频策划",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::WsAgentChannel;

    #[test]
    fn assistant_names_stable() {
        assert_eq!(WsAgentChannel::Script.assistant_name_zh(), "统筹");
        assert_eq!(WsAgentChannel::Production.assistant_name_zh(), "视频策划");
    }
}
