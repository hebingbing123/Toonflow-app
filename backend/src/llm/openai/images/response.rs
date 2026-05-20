use serde_json::Value;

pub(super) fn parse_images_response(v: &Value) -> Result<(String, Option<String>), String> {
    if let Some(url) = v
        .pointer("/output/results/0/url")
        .and_then(|x| x.as_str())
    {
        return Ok((url.to_string(), None));
    }

    let data0 = v
        .get("data")
        .and_then(|d| d.as_array())
        .and_then(|a| a.first())
        .ok_or_else(|| "missing data[0]".to_string())?;
    let url_str = data0
        .get("url")
        .and_then(|u| u.as_str())
        .ok_or_else(|| "missing data[0].url".to_string())?;
    let revised = data0
        .get("revised_prompt")
        .and_then(|x| x.as_str())
        .map(str::to_string);
    Ok((url_str.to_string(), revised))
}
