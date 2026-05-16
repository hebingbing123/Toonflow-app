use std::path::PathBuf;

#[derive(Debug)]
pub(in crate::production::workbench::storyboard_ops) enum StoryboardExportSource {
    DataUri {
        extension: &'static str,
        bytes: Vec<u8>,
    },
    RemoteUrl {
        url: String,
    },
    AbsolutePath {
        path: PathBuf,
    },
    LocalStorage {
        relative_path: PathBuf,
    },
}
