use crate::prompting::skills::SkillReadError;

#[derive(Debug)]
pub enum InvokeError {
    UnknownTool(String),
    NotImplemented {
        tool: String,
        hint: String,
    },
    /// Tool-specific argument validation (maps to `invalid_payload` over WS).
    InvalidArgs(String),
    SkillNotFound,
    SkillBadRequest(String),
    SkillUnavailable,
    /// Child process / IPC failure for process-isolated tools (`isolated.echo`).
    IsolationFailed(String),
    /// WASM interpreter failure (`wasm.probe`).
    WasmFailed(String),
    /// User WASM wall-clock timeout (`wasm.user.probe`).
    WasmTimeout,
    /// Owner-scoped WASM row missing or revoked (`wasm.user.probe`).
    NotFound(String),
    /// Postgres-backed domain tools require a configured pool.
    DatabaseUnavailable,
    /// Domain tools require project/script context and/or arguments.
    MissingContext(String),
    DatabaseError(String),
    LlmNotConfigured,
    LlmError(String),
}

impl From<SkillReadError> for InvokeError {
    fn from(e: SkillReadError) -> Self {
        match e {
            SkillReadError::BadPath(m) => InvokeError::SkillBadRequest(m),
            SkillReadError::SkillsDirMissing => InvokeError::SkillUnavailable,
            SkillReadError::NotFound => InvokeError::SkillNotFound,
            SkillReadError::SectionNotFound(section) => {
                InvokeError::SkillBadRequest(format!("skill section not found: {section}"))
            }
            SkillReadError::TooLarge | SkillReadError::TooLargeBinary => {
                InvokeError::SkillBadRequest("skill file exceeds maximum allowed size".into())
            }
            SkillReadError::Io(m) => InvokeError::SkillBadRequest(m),
        }
    }
}

impl InvokeError {
    #[must_use]
    pub fn code(&self) -> &'static str {
        match self {
            InvokeError::UnknownTool(_) => "unknown_tool",
            InvokeError::NotImplemented { .. } => "tool_not_implemented",
            InvokeError::InvalidArgs(_) => "invalid_payload",
            InvokeError::SkillNotFound => "not_found",
            InvokeError::SkillBadRequest(_) => "invalid_payload",
            InvokeError::SkillUnavailable => "skill_unavailable",
            InvokeError::IsolationFailed(_) => "isolation_failed",
            InvokeError::WasmFailed(_) => "wasm_failed",
            InvokeError::WasmTimeout => "wasm_timeout",
            InvokeError::NotFound(_) => "not_found",
            InvokeError::DatabaseUnavailable => "database_error",
            InvokeError::MissingContext(_) => "invalid_state",
            InvokeError::DatabaseError(_) => "database_error",
            InvokeError::LlmNotConfigured => "llm_not_configured",
            InvokeError::LlmError(_) => "llm_error",
        }
    }

    #[must_use]
    pub fn message(&self) -> String {
        match self {
            InvokeError::UnknownTool(n) => format!("unknown or unregistered tool: {n}"),
            InvokeError::NotImplemented { tool, hint } => format!("{tool}: {hint}"),
            InvokeError::InvalidArgs(m) => m.clone(),
            InvokeError::SkillNotFound => "skill file not found".into(),
            InvokeError::SkillBadRequest(m) => m.clone(),
            InvokeError::SkillUnavailable => {
                "skills directory is not available on this server".into()
            }
            InvokeError::IsolationFailed(m) => m.clone(),
            InvokeError::WasmFailed(m) => m.clone(),
            InvokeError::WasmTimeout => "user wasm invoke timed out".into(),
            InvokeError::NotFound(m) => m.clone(),
            InvokeError::DatabaseUnavailable => "DATABASE_URL not configured".into(),
            InvokeError::MissingContext(m) => m.clone(),
            InvokeError::DatabaseError(m) => m.clone(),
            InvokeError::LlmNotConfigured => "set OPENAI_API_KEY or LLM_API_KEY".into(),
            InvokeError::LlmError(m) => m.clone(),
        }
    }
}
