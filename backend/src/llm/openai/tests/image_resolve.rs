use super::super::*;

#[test]
fn image_size_maps_dalle3() {
    assert_eq!(
        resolve_openai_image_size("dall-e-3", "1792x1024"),
        "1792x1024"
    );
    assert_eq!(
        resolve_openai_image_size("dall-e-3", "1024 × 1792"),
        "1024x1792"
    );
    assert_eq!(
        resolve_openai_image_size("dall-e-3", "unknown"),
        "1024x1024"
    );
}

#[test]
fn image_size_maps_dalle2() {
    assert_eq!(resolve_openai_image_size("dall-e-2", "512x512"), "512x512");
    assert_eq!(resolve_openai_image_size("dall-e-2", "bad"), "1024x1024");
}

#[test]
fn image_model_from_catalog_string() {
    assert_eq!(
        resolve_openai_image_model("1:dall-e-3").as_str(),
        "dall-e-3"
    );
    assert_eq!(resolve_openai_image_model("dall-e-2").as_str(), "dall-e-2");
    assert_eq!(
        resolve_openai_image_model("unknown-catalog-id").as_str(),
        "dall-e-3"
    );
}
