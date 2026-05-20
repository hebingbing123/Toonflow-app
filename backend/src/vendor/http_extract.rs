//! Small helpers to read URLs and ids from heterogeneous vendor JSON.

use serde_json::Value;

/// First non-empty string found at any of the dot-paths (e.g. `data.task_id`).
pub fn json_str(v: &Value, paths: &[&str]) -> Option<String> {
    paths
        .iter()
        .filter_map(|p| v.pointer(p))
        .find_map(|node| node.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
}

/// First URL string from a path, or the first element of a string / object array at that path.
pub fn json_url(v: &Value, paths: &[&str]) -> Option<String> {
    for p in paths {
        let Some(node) = v.pointer(p) else {
            continue;
        };
        if let Some(s) = node.as_str() {
            let t = s.trim();
            if !t.is_empty() {
                return Some(t.to_string());
            }
        }
        if let Some(arr) = node.as_array() {
            for item in arr {
                if let Some(s) = item.as_str() {
                    let t = s.trim();
                    if !t.is_empty() {
                        return Some(t.to_string());
                    }
                }
                if let Some(url) = item.get("url").and_then(|u| u.as_str()) {
                    let t = url.trim();
                    if !t.is_empty() {
                        return Some(t.to_string());
                    }
                }
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn json_str_follows_first_matching_path() {
        let v = json!({ "data": { "task_id": "abc" } });
        assert_eq!(
            json_str(&v, &["/missing", "/data/task_id"]).as_deref(),
            Some("abc")
        );
    }

    #[test]
    fn json_url_reads_array_of_strings() {
        let v = json!({ "output": ["https://cdn.example/v.mp4"] });
        assert_eq!(
            json_url(&v, &["/output"]).as_deref(),
            Some("https://cdn.example/v.mp4")
        );
    }
}
