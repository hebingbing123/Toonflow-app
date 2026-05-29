//! Handler ↔ scope function audit matrix (rebuild plan P0-2).
//!
//! Contract tests in `app/pg_contract_tests/workspace_suite/` should stay aligned
//! with entries here when adding REST handlers that touch project-domain rows.

/// Documented scope entry for workspace isolation audits.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ScopeAuditEntry {
    pub domain: &'static str,
    pub http_helper: &'static str,
    pub sql_scope: &'static str,
    pub workspace_member: bool,
}

/// Canonical registry of project-domain HTTP scope helpers.
pub const PROJECT_DOMAIN_SCOPE_AUDIT: &[ScopeAuditEntry] = &[
    ScopeAuditEntry {
        domain: "project_read",
        http_helper: "scope::http::require_project_read_scope",
        sql_scope: "owned_project_id_by_numeric + workspace_member",
        workspace_member: true,
    },
    ScopeAuditEntry {
        domain: "project_write",
        http_helper: "scope::http::require_project_write_scope_ref",
        sql_scope: "require_project_write_scope",
        workspace_member: true,
    },
    ScopeAuditEntry {
        domain: "script_read",
        http_helper: "scope::http::require_script_read_scope",
        sql_scope: "owned_script_scope + workspace_member",
        workspace_member: true,
    },
    ScopeAuditEntry {
        domain: "script_write",
        http_helper: "scope::http::require_script_write_scope",
        sql_scope: "owned_script_scope + require_project_write_scope",
        workspace_member: true,
    },
    ScopeAuditEntry {
        domain: "storyboard_read",
        http_helper: "scope::http::require_storyboard_read_scope",
        sql_scope: "owned_storyboard_in_script_scope + workspace_member",
        workspace_member: true,
    },
    ScopeAuditEntry {
        domain: "asset_read",
        http_helper: "assets::crud::require_asset_project_read_scope",
        sql_scope: "project workspace member",
        workspace_member: true,
    },
    ScopeAuditEntry {
        domain: "job_create",
        http_helper: "jobs::handlers::mutate::create::create_job",
        sql_scope: "normalize_project_scope_in_job_payload",
        workspace_member: true,
    },
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn project_domain_scope_audit_is_non_empty() {
        assert!(!PROJECT_DOMAIN_SCOPE_AUDIT.is_empty());
        for entry in PROJECT_DOMAIN_SCOPE_AUDIT {
            assert!(
                entry.workspace_member,
                "missing workspace gate: {}",
                entry.domain
            );
        }
    }
}
