use super::envelope::ClientEnvelope;

#[test]
fn envelope_roundtrip() {
    let raw = r#"{"type":"session.auth","schema_version":1,"payload":{"access_token":"x"}}"#;
    let e: ClientEnvelope = serde_json::from_str(raw).unwrap();
    assert_eq!(e.msg_type, "session.auth");
    assert_eq!(e.schema_version, 1);
}
