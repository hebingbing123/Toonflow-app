use crate::harness::tools::ToolRegistry;
use serde_json::Value;

use super::schemas::harness_openai_tools;

#[test]
fn openai_tools_match_catalog_size() {
    assert_eq!(
        harness_openai_tools().len(),
        ToolRegistry::catalog().len(),
        "keep tool schemas in sync with GET /api/v1/harness/tools"
    );
}

#[test]
fn production_sub_agent_tools_allow_scope_ids() {
    let tools = harness_openai_tools();
    let storyboard_gen = tools
        .iter()
        .find(|tool| tool["function"]["name"].as_str() == Some("run_sub_agent_storyboard_gen"))
        .expect("storyboard gen tool");
    let properties = storyboard_gen["function"]["parameters"]["properties"]
        .as_object()
        .expect("schema properties");

    assert!(matches!(properties.get("assetIds"), Some(Value::Object(_))));
    assert!(matches!(
        properties.get("assetTypes"),
        Some(Value::Object(_))
    ));
    assert!(matches!(
        properties.get("storyboardIds"),
        Some(Value::Object(_))
    ));
}

#[test]
fn script_sub_agent_tools_allow_compact_script_scope() {
    let tools = harness_openai_tools();
    let script_tool = tools
        .iter()
        .find(|tool| tool["function"]["name"].as_str() == Some("run_sub_agent_script"))
        .expect("script sub-agent tool");
    let properties = script_tool["function"]["parameters"]["properties"]
        .as_object()
        .expect("schema properties");

    assert!(matches!(
        properties.get("focusSections"),
        Some(Value::Object(_))
    ));
    assert!(matches!(properties.get("novelIds"), Some(Value::Object(_))));
    assert!(matches!(
        properties.get("relativeScriptOffset"),
        Some(Value::Object(_))
    ));
}
