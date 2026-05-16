use super::dto::{
    CredentialResponse, EnableVendorBody, StoreCredentialBody, UpdateVendorBody,
    VendorModelTestBody,
};

#[test]
fn vendor_model_test_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<VendorModelTestBody>(
        r#"{"modelName":"gpt-4","type":"text","id":"1","extra":1}"#,
    );
    assert!(err.is_err());
}

#[test]
fn vendor_model_test_body_accepts_valid() {
    let b: VendorModelTestBody =
        serde_json::from_str(r#"{"modelName":"gpt-4","type":"text","id":"vendor-1"}"#).unwrap();
    assert_eq!(b.model_name, "gpt-4");
    assert_eq!(b.kind, "text");
    assert_eq!(b.id, "vendor-1");
}

#[test]
fn update_vendor_body_rejects_unknown_fields() {
    let err =
        serde_json::from_str::<UpdateVendorBody>(r#"{"id":"v1","displayName":"Test","extra":1}"#);
    assert!(err.is_err());
}

#[test]
fn update_vendor_body_accepts_minimal() {
    let b: UpdateVendorBody = serde_json::from_str(r#"{"id":"v1"}"#).unwrap();
    assert_eq!(b.id, "v1");
    assert_eq!(b.display_name, None);
    assert!(b.selected_models.is_empty());
    assert!(b.settings.is_empty());
}

#[test]
fn update_vendor_body_accepts_full() {
    let b: UpdateVendorBody = serde_json::from_str(
        r#"{"id":"v1","displayName":"My Vendor","selectedModels":["m1","m2"],"settings":{"k1":"v1"}}"#,
    )
    .unwrap();
    assert_eq!(b.id, "v1");
    assert_eq!(b.display_name, Some("My Vendor".to_string()));
    assert_eq!(b.selected_models, vec!["m1", "m2"]);
    assert_eq!(b.settings.get("k1"), Some(&"v1".to_string()));
}

#[test]
fn store_credential_body_rejects_unknown_fields() {
    let err =
        serde_json::from_str::<StoreCredentialBody>(r#"{"vendorId":"v1","apiKey":"k","extra":1}"#);
    assert!(err.is_err());
}

#[test]
fn store_credential_body_accepts_minimal() {
    let b: StoreCredentialBody = serde_json::from_str(r#"{"vendorId":"v1"}"#).unwrap();
    assert_eq!(b.vendor_id, "v1");
    assert_eq!(b.api_key, None);
    assert_eq!(b.api_secret, None);
    assert_eq!(b.api_token, None);
}

#[test]
fn store_credential_body_accepts_full() {
    let b: StoreCredentialBody = serde_json::from_str(
        r#"{"vendorId":"v1","apiKey":"key123","apiSecret":"secret456","apiToken":"token789"}"#,
    )
    .unwrap();
    assert_eq!(b.vendor_id, "v1");
    assert_eq!(b.api_key, Some("key123".to_string()));
    assert_eq!(b.api_secret, Some("secret456".to_string()));
    assert_eq!(b.api_token, Some("token789".to_string()));
}

#[test]
fn credential_response_serialize() {
    let resp = CredentialResponse {
        vendor_id: "v1".to_string(),
        key_hint: Some("k***3".to_string()),
        has_secret: true,
        has_token: false,
        message: "Test",
    };
    let json = serde_json::to_string(&resp).unwrap();
    assert!(json.contains("\"vendorId\":\"v1\""));
    assert!(json.contains("\"keyHint\":\"k***3\""));
    assert!(json.contains("\"hasSecret\":true"));
    assert!(json.contains("\"hasToken\":false"));
}

#[test]
fn enable_vendor_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<EnableVendorBody>(r#"{"id":"v1","enable":1,"extra":true}"#);
    assert!(err.is_err());
}

#[test]
fn enable_vendor_body_accepts_valid() {
    let b: EnableVendorBody = serde_json::from_str(r#"{"id":"v1","enable":1}"#).unwrap();
    assert_eq!(b.id, "v1");
    assert_eq!(b.enable, 1);
}
