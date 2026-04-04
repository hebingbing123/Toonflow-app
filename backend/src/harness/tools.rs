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
        name: "isolated.echo",
        description: "Same JSON echo as `echo`, but executed in a child process (address-space isolation; Harness hard-boundary MVP).",
    },
    HarnessToolInfo {
        name: "skills.read",
        description:
            "Read one Markdown skill under backend/data/skills; WS/args: { \"path\": \"relative/path.md\" } (same rules as GET /api/v1/skills/content).",
    },
    HarnessToolInfo {
        name: "wasm.probe",
        description:
            "Runs an embedded WebAssembly module via the wasmi interpreter (sandbox MVP); returns JSON like { \"ok\": true, \"value\": 42 }.",
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
