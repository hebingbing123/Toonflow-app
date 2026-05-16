//! HTTP `Accept-Language` → API 响应语言偏好（用于 [`crate::error::ApiError`] 的 `message` 字段）。

use axum::http::HeaderMap;

/// 响应错误消息所用语言（当前仅区分简体展示 vs 英文）。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Default)]
pub enum ApiLocale {
    #[default]
    En,
    Zh,
}

tokio::task_local! {
    /// 若未设置（例如单元测试直接构造 `ApiError`），[`ApiError`](crate::error::ApiError) 回落到 [`ApiLocale::En`]。
    pub static REQUEST_LOCALE: ApiLocale;
}

/// 从 `Accept-Language` 解析优先级最高的语言（支持 `q=` 权重）。未提供或与中英文无关时返回 [`ApiLocale::En`]。
pub fn preferred_locale_from_headers(headers: &HeaderMap) -> ApiLocale {
    let Some(raw) = headers.get(axum::http::header::ACCEPT_LANGUAGE) else {
        return ApiLocale::En;
    };
    let Ok(s) = raw.to_str() else {
        return ApiLocale::En;
    };
    preferred_locale_from_accept_language_str(s)
}

pub fn preferred_locale_from_accept_language_str(s: &str) -> ApiLocale {
    let mut best_zh = -1.0_f32;
    let mut best_en = -1.0_f32;

    for part in s.split(',') {
        let part = part.trim();
        if part.is_empty() {
            continue;
        }
        let mut lang_q = part.split(';');
        let lang_tag = lang_q.next().unwrap_or("").trim();
        if lang_tag.is_empty() {
            continue;
        }
        let primary = lang_tag
            .split('-')
            .next()
            .unwrap_or("")
            .to_ascii_lowercase();
        let primary_zh = primary == "zh";
        let primary_en = primary == "en";

        let mut q = 1.0_f32;
        for param in lang_q {
            let param = param.trim();
            let Some(rest) = param.strip_prefix("q=") else {
                continue;
            };
            if let Ok(parsed) = rest.trim().parse::<f32>() {
                q = parsed.clamp(0.0, 1.0);
            }
        }

        if primary_zh {
            best_zh = best_zh.max(q);
        }
        if primary_en {
            best_en = best_en.max(q);
        }
    }

    if best_zh <= 0.0 && best_en <= 0.0 {
        return ApiLocale::En;
    }
    if best_zh > best_en {
        ApiLocale::Zh
    } else {
        ApiLocale::En
    }
}

/// 当前请求偏好语言；无 task-local 时默认英文。
pub(crate) fn current_locale() -> ApiLocale {
    REQUEST_LOCALE.try_with(|l| *l).unwrap_or(ApiLocale::En)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zh_beats_en_when_higher_q() {
        assert_eq!(
            preferred_locale_from_accept_language_str("en;q=0.8, zh-CN;q=0.9"),
            ApiLocale::Zh
        );
    }

    #[test]
    fn en_when_only_en() {
        assert_eq!(
            preferred_locale_from_accept_language_str("en-US, en;q=0.9"),
            ApiLocale::En
        );
    }

    #[test]
    fn empty_defaults_en() {
        assert_eq!(preferred_locale_from_accept_language_str(""), ApiLocale::En);
    }

    #[test]
    fn zh_hans_prefers_zh() {
        assert_eq!(
            preferred_locale_from_accept_language_str("zh-Hans-CN"),
            ApiLocale::Zh
        );
    }
}
