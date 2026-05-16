use serde_json::json;

use super::super::*;

#[test]
fn sse_parses_delta() {
    let line = r#"data: {"choices":[{"delta":{"content":"Hi"}}]}"#;
    assert_eq!(parse_sse_data_line(line).as_deref(), Some("Hi"));
}

#[test]
fn sse_done() {
    let line = "data: [DONE]";
    assert_eq!(parse_sse_data_line(line).as_deref(), Some(""));
}

#[test]
fn parses_assistant_string_content() {
    let v = json!({"choices":[{"message":{"content":"  hello  "}}]});
    assert_eq!(parse_assistant_content(&v).unwrap(), "hello");
}

#[test]
fn parses_assistant_text_parts() {
    let v = json!({"choices":[{"message":{"content":[
        {"type":"text","text":"ab"},
        {"type":"text","text":" cd "}
    ]}}]});
    assert_eq!(parse_assistant_content(&v).unwrap(), "ab cd");
}
