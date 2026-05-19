//! Image document primitives for Openflow's native asset editing flow.

use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImageDocument {
    pub id: Uuid,
    pub width: u32,
    pub height: u32,
    pub layers: Vec<ImageLayer>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImageLayer {
    pub id: Uuid,
    pub name: String,
    pub visible: bool,
    pub opacity: f32,
    pub transform: LayerTransform,
    pub kind: ImageLayerKind,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum ImageLayerKind {
    RasterAsset { asset_id: Uuid },
    Text { content: String },
    Mask { asset_id: Uuid },
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct LayerTransform {
    pub translate_x: f32,
    pub translate_y: f32,
    pub scale_x: f32,
    pub scale_y: f32,
    pub rotation_deg: f32,
}

impl Default for LayerTransform {
    fn default() -> Self {
        Self {
            translate_x: 0.0,
            translate_y: 0.0,
            scale_x: 1.0,
            scale_y: 1.0,
            rotation_deg: 0.0,
        }
    }
}

impl ImageDocument {
    pub fn new(width: u32, height: u32) -> Self {
        Self {
            id: Uuid::new_v4(),
            width,
            height,
            layers: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_document_starts_empty() {
        let doc = ImageDocument::new(1920, 1080);
        assert_eq!(doc.width, 1920);
        assert_eq!(doc.height, 1080);
        assert!(doc.layers.is_empty());
    }
}
