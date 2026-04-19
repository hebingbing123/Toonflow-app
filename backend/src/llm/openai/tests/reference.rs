use super::super::*;

#[test]
fn parse_reference_image_upload_accepts_raw_base64() {
    let parsed = parse_reference_image_upload("AA==").expect("parse raw");
    assert_eq!(parsed.mime, "image/jpeg");
    assert_eq!(parsed.file_name, "reference.jpg");
    assert_eq!(parsed.bytes, vec![0u8]);
}

#[test]
fn parse_reference_image_upload_accepts_data_uri_png() {
    let parsed = parse_reference_image_upload("data:image/png;base64,AA==").expect("png uri");
    assert_eq!(parsed.mime, "image/png");
    assert_eq!(parsed.file_name, "reference.png");
    assert_eq!(parsed.bytes, vec![0u8]);
}

#[test]
fn parse_reference_image_upload_rejects_non_image_mime() {
    let err = parse_reference_image_upload("data:text/plain;base64,AA==").expect_err("bad mime");
    assert!(err.contains("unsupported reference image mime"));
}
