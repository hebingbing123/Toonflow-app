use crate::harness::tools::ToolRegistry;

use super::schemas::harness_openai_tools;

#[test]
fn openai_tools_match_catalog_size() {
    assert_eq!(
        harness_openai_tools().len(),
        ToolRegistry::catalog().len(),
        "keep tool schemas in sync with GET /api/v1/harness/tools"
    );
}
