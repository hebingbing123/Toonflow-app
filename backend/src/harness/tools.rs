//! Harness 工具静态目录。
//!
//! Harness 循环可能调度的工具目录（执行连接仍在开发中）。
//! 提供 `GET /api/v1/harness/tools` 端点返回的工具列表。

use serde::Serialize;

/// One entry in `GET /api/v1/harness/tools`.
#[derive(Debug, Clone, Copy, Serialize, utoipa::ToSchema)]
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
    HarnessToolInfo {
        name: "get_planData",
        description:
            "Script-agent parity read: returns project-scoped plan data; supports key/line/field filters to avoid loading the full workspace when not needed.",
    },
    HarnessToolInfo {
        name: "get_script_content",
        description:
            "Script-agent parity read: returns one script row by numeric script id, with optional line/char/field trimming.",
    },
    HarnessToolInfo {
        name: "get_novel_text",
        description:
            "Script-agent parity read: returns project novel rows, with optional novelId, paging, text windows, and field trimming.",
    },
    HarnessToolInfo {
        name: "get_novel_events",
        description:
            "Script-agent parity read: returns project novel-event rows, with optional novelId, paging, detail trimming, and field trimming.",
    },
    HarnessToolInfo {
        name: "get_flowData",
        description:
            "Production-agent parity read: returns one production flow field by key, with optional line windows, storyboard-table row/column windows, id/type filters, field subsets, and compact formats.",
    },
    HarnessToolInfo {
        name: "add_deriveAsset",
        description:
            "Production-agent parity write: add or update a derived asset under arguments.assetsId (optional arguments.id); parent numeric id must be linked to the active script (app_script_asset).",
    },
    HarnessToolInfo {
        name: "del_deriveAsset",
        description:
            "Production-agent write: deletes the derived **app_asset** row (arguments.id under arguments.assetsId, script-linked). This is **not** the same as REST delete-assets-derivative, which removes **app_asset_image** rows for parent numeric ids — do not confuse the two.",
    },
    HarnessToolInfo {
        name: "generate_deriveAsset",
        description:
            "Production-agent parity action: enqueue generation jobs for derived asset numeric ids in arguments.ids.",
    },
    HarnessToolInfo {
        name: "generate_storyboard",
        description:
            "Production-agent parity action: enqueue storyboard image generation jobs for storyboard numeric ids in arguments.ids.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_storySkeleton",
        description:
            "Script-agent orchestration parity: run story-skeleton sub-agent with arguments.prompt.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_adaptationStrategy",
        description:
            "Script-agent orchestration parity: run adaptation-strategy sub-agent with arguments.prompt.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_script",
        description:
            "Script-agent orchestration parity: run script-writing sub-agent with arguments.prompt.",
    },
    HarnessToolInfo {
        name: "run_supervision_agent",
        description:
            "Script-agent orchestration parity: run supervision sub-agent with arguments.prompt; returns concise text plus a parsed review summary when available.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_derive_assets",
        description:
            "Production-agent orchestration parity: run derive-assets sub-agent with arguments.prompt.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_generate_assets",
        description:
            "Production-agent orchestration parity: run generate-assets sub-agent with arguments.prompt.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_director_plan",
        description:
            "Production-agent orchestration parity: run director-plan sub-agent with arguments.prompt.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_storyboard_gen",
        description:
            "Production-agent orchestration parity: run storyboard-generation sub-agent with arguments.prompt.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_storyboard_panel",
        description:
            "Production-agent orchestration parity: run storyboard-panel sub-agent with arguments.prompt.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_storyboard_table",
        description:
            "Production-agent orchestration parity: run storyboard-table sub-agent with arguments.prompt.",
    },
    HarnessToolInfo {
        name: "run_sub_agent_production_supervision",
        description:
            "Production-agent orchestration parity: run production-supervision sub-agent with arguments.prompt; returns concise text plus a parsed review summary when available.",
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
