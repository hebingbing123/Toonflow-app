/// Registered tool **names** for the Harness agent loop (dispatch still WIP).
#[derive(Debug, Clone, Copy)]
pub struct ToolRegistry {
    names: &'static [&'static str],
}

impl Default for ToolRegistry {
    fn default() -> Self {
        Self {
            names: &["echo", "skills.read"],
        }
    }
}

impl ToolRegistry {
    pub fn names(&self) -> &'static [&'static str] {
        self.names
    }
}
