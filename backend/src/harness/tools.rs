//! Static catalog of tools the Harness loop may dispatch (execution wiring still WIP).

use serde::Serialize;

/// One entry in `GET /api/v1/harness/tools`.
#[derive(Debug, Clone, Copy, Serialize)]
pub struct HarnessToolInfo {
    pub name: &'static str,
    pub description: &'static str,
}

const CATALOG: &[HarnessToolInfo] = &[
    HarnessToolInfo {
        name: "echo",
        description: "Returns the provided payload unchanged; used to verify tool plumbing.",
    },
    HarnessToolInfo {
        name: "skills.read",
        description:
            "Read-only access to Markdown skills under backend/data/skills (via HTTP helpers).",
    },
];

/// Accessor for the registered tool catalog (names stable for clients).
pub struct ToolRegistry;

impl ToolRegistry {
    #[must_use]
    pub fn catalog() -> &'static [HarnessToolInfo] {
        CATALOG
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    #[test]
    fn catalog_names_unique_and_non_empty() {
        assert!(!CATALOG.is_empty());
        let mut seen = HashSet::new();
        for t in CATALOG {
            assert!(seen.insert(t.name), "duplicate tool name: {}", t.name);
        }
    }
}
