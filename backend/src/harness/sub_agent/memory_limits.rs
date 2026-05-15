//! Runtime limits for harness auto-memory injection (DB fetch, truncation, pruning, notes).
//!
//! **Local / dev tuning:** set optional `TOONFLOW_*` env vars and restart the process. Unset
//! variables use the same defaults as the historical `scope` / `memory` constants. Invalid
//! values log a warning and fall back to defaults.
//!
//! | Variable | Default | Notes |
//! |----------|---------|-------|
//! | `TOONFLOW_AUTO_MEMORY_MAX_CHARS` | `320` | Per-line truncate in injection + snapshot cap; rework total char budget; non-rework budget = max_chars × rework_limit |
//! | `TOONFLOW_AUTO_MEMORY_KEEP_ROWS` | `8` | Retain this many newest `auto_scope_memory` rows after persist |
//! | `TOONFLOW_AUTO_MEMORY_FETCH_LIMIT` | same as keep | SQL `LIMIT` when loading recent auto-memory rows |
//! | `TOONFLOW_AUTO_MEMORY_REWORK_LIMIT` | `2` | Non-rework char budget multiplier; rework-mode row caps in scope selection (see `scope/project.rs`) |
//! | `TOONFLOW_AUTO_MEMORY_STYLE_BIBLE_NOTE_MAX_CHARS` | `420` | Cap on filtered style-bible injection block |
//! | `TOONFLOW_AUTO_MEMORY_STAGE_SUMMARY_NOTE_MAX_CHARS` | `220` | Cap on injected stage-summary line |

use std::sync::OnceLock;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) struct AutoMemoryLimits {
    pub max_chars: usize,
    pub keep_rows: i64,
    pub fetch_limit: i64,
    /// Upper bound on rows taken in some rework paths; multiplier for non-rework char budget.
    pub rework_limit: usize,
    pub style_bible_note_max_chars: usize,
    pub stage_summary_note_max_chars: usize,
}

const DEFAULT_MAX_CHARS: usize = 320;
const DEFAULT_KEEP_ROWS: i64 = 8;
const DEFAULT_REWORK_LIMIT: usize = 2;
const DEFAULT_STYLE_BIBLE_NOTE_MAX_CHARS: usize = 420;
const DEFAULT_STAGE_SUMMARY_NOTE_MAX_CHARS: usize = 220;

static LIMITS: OnceLock<AutoMemoryLimits> = OnceLock::new();

pub(super) fn auto_memory_limits() -> &'static AutoMemoryLimits {
    LIMITS.get_or_init(resolve_from_env)
}

#[inline]
pub(super) fn auto_memory_max_chars() -> usize {
    auto_memory_limits().max_chars
}

#[inline]
pub(super) fn auto_memory_keep_rows() -> i64 {
    auto_memory_limits().keep_rows
}

#[inline]
pub(super) fn auto_memory_fetch_limit() -> i64 {
    auto_memory_limits().fetch_limit
}

#[inline]
pub(super) fn auto_memory_rework_limit() -> usize {
    auto_memory_limits().rework_limit
}

#[inline]
pub(super) fn style_bible_note_max_chars() -> usize {
    auto_memory_limits().style_bible_note_max_chars
}

#[inline]
pub(super) fn stage_summary_note_max_chars() -> usize {
    auto_memory_limits().stage_summary_note_max_chars
}

fn resolve_from_env() -> AutoMemoryLimits {
    let keep_rows = parse_env_i64_positive(
        "TOONFLOW_AUTO_MEMORY_KEEP_ROWS",
        DEFAULT_KEEP_ROWS,
        DEFAULT_KEEP_ROWS,
    );
    let max_chars = parse_env_usize_positive(
        "TOONFLOW_AUTO_MEMORY_MAX_CHARS",
        DEFAULT_MAX_CHARS,
        DEFAULT_MAX_CHARS,
    );
    let rework_limit = parse_env_usize_positive(
        "TOONFLOW_AUTO_MEMORY_REWORK_LIMIT",
        DEFAULT_REWORK_LIMIT,
        DEFAULT_REWORK_LIMIT,
    )
    .max(1);
    let fetch_limit = match std::env::var("TOONFLOW_AUTO_MEMORY_FETCH_LIMIT") {
        Ok(raw) => parse_i64_positive_trimmed(&raw, keep_rows).unwrap_or_else(|| {
            tracing::warn!(
                env = "TOONFLOW_AUTO_MEMORY_FETCH_LIMIT",
                value = %raw,
                "invalid value; using TOONFLOW_AUTO_MEMORY_KEEP_ROWS (or default)"
            );
            keep_rows
        }),
        Err(_) => keep_rows,
    };
    let style_bible_note_max_chars = parse_env_usize_positive(
        "TOONFLOW_AUTO_MEMORY_STYLE_BIBLE_NOTE_MAX_CHARS",
        DEFAULT_STYLE_BIBLE_NOTE_MAX_CHARS,
        DEFAULT_STYLE_BIBLE_NOTE_MAX_CHARS,
    );
    let stage_summary_note_max_chars = parse_env_usize_positive(
        "TOONFLOW_AUTO_MEMORY_STAGE_SUMMARY_NOTE_MAX_CHARS",
        DEFAULT_STAGE_SUMMARY_NOTE_MAX_CHARS,
        DEFAULT_STAGE_SUMMARY_NOTE_MAX_CHARS,
    );
    AutoMemoryLimits {
        max_chars,
        keep_rows,
        fetch_limit,
        rework_limit,
        style_bible_note_max_chars,
        stage_summary_note_max_chars,
    }
}

fn parse_env_usize_positive(name: &str, default: usize, fallback: usize) -> usize {
    match std::env::var(name) {
        Ok(raw) => parse_usize_positive_trimmed(&raw, default).unwrap_or_else(|| {
            tracing::warn!(env = name, value = %raw, "invalid value; using default");
            fallback
        }),
        Err(_) => default,
    }
}

fn parse_env_i64_positive(name: &str, default: i64, fallback: i64) -> i64 {
    match std::env::var(name) {
        Ok(raw) => parse_i64_positive_trimmed(&raw, default).unwrap_or_else(|| {
            tracing::warn!(env = name, value = %raw, "invalid value; using default");
            fallback
        }),
        Err(_) => default,
    }
}

fn parse_usize_positive_trimmed(raw: &str, default: usize) -> Option<usize> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Some(default);
    }
    let parsed = trimmed.parse::<usize>().ok()?;
    (parsed > 0).then_some(parsed)
}

fn parse_i64_positive_trimmed(raw: &str, default: i64) -> Option<i64> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Some(default);
    }
    let parsed = trimmed.parse::<i64>().ok()?;
    (parsed > 0).then_some(parsed)
}

#[cfg(test)]
mod tests {
    use super::{parse_i64_positive_trimmed, parse_usize_positive_trimmed};

    #[test]
    fn parse_usize_accepts_positive_and_empty_means_default() {
        assert_eq!(parse_usize_positive_trimmed("480", 320), Some(480));
        assert_eq!(parse_usize_positive_trimmed("  1 ", 320), Some(1));
        assert_eq!(parse_usize_positive_trimmed("", 320), Some(320));
        assert_eq!(parse_usize_positive_trimmed("0", 320), None);
        assert_eq!(parse_usize_positive_trimmed("-1", 320), None);
        assert_eq!(parse_usize_positive_trimmed("nope", 320), None);
    }

    #[test]
    fn parse_i64_accepts_positive_and_empty_means_default() {
        assert_eq!(parse_i64_positive_trimmed("16", 8), Some(16));
        assert_eq!(parse_i64_positive_trimmed("", 8), Some(8));
        assert_eq!(parse_i64_positive_trimmed("0", 8), None);
    }
}
