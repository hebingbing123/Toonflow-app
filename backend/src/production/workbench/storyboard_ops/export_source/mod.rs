mod data_uri;
mod extension;
mod mime;
mod parse;
mod types;

pub(in crate::production::workbench::storyboard_ops) use extension::infer_export_extension;
pub(in crate::production::workbench::storyboard_ops) use parse::parse_storyboard_export_source;
pub(in crate::production::workbench::storyboard_ops) use types::StoryboardExportSource;

#[cfg(test)]
mod tests {
    use super::{infer_export_extension, parse_storyboard_export_source, StoryboardExportSource};
    use crate::error::ApiError;

    #[test]
    fn parse_storyboard_export_source_detects_data_uri() {
        let source = parse_storyboard_export_source("data:image/png;base64,Zm9v", 7)
            .expect("data uri source");

        match source {
            StoryboardExportSource::DataUri { extension, bytes } => {
                assert_eq!(extension, "png");
                assert_eq!(bytes, b"foo");
            }
            _ => panic!("expected data uri variant"),
        }
    }

    #[test]
    fn parse_storyboard_export_source_detects_remote_local_and_absolute_sources() {
        let remote =
            parse_storyboard_export_source("https://example.com/image", 8).expect("remote");
        assert!(matches!(remote, StoryboardExportSource::RemoteUrl { .. }));

        let local = parse_storyboard_export_source("/storyboard-local/user/file.webp", 8)
            .expect("local storage");
        match local {
            StoryboardExportSource::LocalStorage { relative_path } => {
                assert_eq!(relative_path, std::path::PathBuf::from("user/file.webp"));
            }
            _ => panic!("expected local storage variant"),
        }

        let absolute =
            parse_storyboard_export_source("/tmp/storyboard.png", 8).expect("absolute path");
        assert!(matches!(
            absolute,
            StoryboardExportSource::AbsolutePath { .. }
        ));
    }

    #[test]
    fn parse_storyboard_export_source_rejects_non_exportable_relative_path() {
        let err = parse_storyboard_export_source("relative/storyboard.png", 9).unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message)
                if message.contains("storyboard 9 file_path is not exportable")
        ));
    }

    #[test]
    fn infer_export_extension_prefers_path_then_content_type_then_png() {
        assert_eq!(
            infer_export_extension("https://example.com/file.JPEG", Some("image/png")),
            "jpeg"
        );
        assert_eq!(
            infer_export_extension("https://example.com/file", Some("image/webp")),
            "webp"
        );
        assert_eq!(
            infer_export_extension("https://example.com/file", None),
            "png"
        );
    }
}
