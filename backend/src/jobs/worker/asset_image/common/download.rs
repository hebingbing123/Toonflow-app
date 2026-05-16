//! 下载生成图字节（带大小上限）。

use futures_util::StreamExt;

use crate::jobs::worker::common::JobRunError;

/// Cap for `images/generations` URL download when persisting under local asset dir.
const MAX_DOWNLOADED_ASSET_IMAGE_BYTES: u64 = 32 * 1024 * 1024;

pub(crate) async fn download_image_bytes_capped(
    client: &reqwest::Client,
    url: &str,
) -> Result<Vec<u8>, JobRunError> {
    let resp = client
        .get(url)
        .send()
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))?;
    if !resp.status().is_success() {
        return Err(JobRunError::Failed(format!(
            "image download HTTP {}",
            resp.status()
        )));
    }
    let max = MAX_DOWNLOADED_ASSET_IMAGE_BYTES as usize;
    if let Some(cl) = resp.content_length() {
        if cl > max as u64 {
            return Err(JobRunError::Failed("image Content-Length too large".into()));
        }
    }
    let mut stream = resp.bytes_stream();
    let mut out = Vec::new();
    while let Some(item) = stream.next().await {
        let chunk = item.map_err(|e| JobRunError::Failed(e.to_string()))?;
        if out.len().saturating_add(chunk.len()) > max {
            return Err(JobRunError::Failed("image body too large".into()));
        }
        out.extend_from_slice(&chunk);
    }
    Ok(out)
}
