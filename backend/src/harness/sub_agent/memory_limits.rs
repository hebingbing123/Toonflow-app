//! Runtime limits for harness auto-memory injection (DB fetch, truncation, pruning, notes).
//!
//! **Local / dev tuning:** set optional `OPENFLOW_*` env vars and restart the process. Unset
//! variables use the same defaults as the historical `scope` / `memory` constants. Invalid
//! values log a warning and fall back to defaults; out-of-range values are **clamped** to safe
//! bounds to avoid pathological memory use.
//!
//! | Variable | Default | Notes |
//! |----------|---------|-------|
//! | `OPENFLOW_AUTO_MEMORY_MAX_CHARS` | `320` | Per-line truncate in injection + snapshot cap; rework total char budget; non-rework budget = max_chars × rework_limit |
//! | `OPENFLOW_AUTO_MEMORY_KEEP_ROWS` | `8` | Retain this many newest `auto_scope_memory` rows after persist |
//! | `OPENFLOW_AUTO_MEMORY_FETCH_LIMIT` | same as keep | SQL `LIMIT` when loading recent auto-memory rows |
//! | `OPENFLOW_AUTO_MEMORY_REWORK_LIMIT` | `2` | Non-rework char budget multiplier; rework-mode row caps in scope selection (see `scope/project.rs`) |
//! | `OPENFLOW_STYLE_BIBLE_NOTE_MAX_CHARS` | `420` | Cap on filtered style-bible injection block |
//! | `OPENFLOW_STAGE_SUMMARY_NOTE_MAX_CHARS` | `220` | Cap on injected stage-summary line |
//!
//! **Legacy aliases** (still read if the canonical name is unset):
//! `OPENFLOW_AUTO_MEMORY_STYLE_BIBLE_NOTE_MAX_CHARS`, `OPENFLOW_AUTO_MEMORY_STAGE_SUMMARY_NOTE_MAX_CHARS`.

// Env names (canonical): OPENFLOW_AUTO_MEMORY_MAX_CHARS, OPENFLOW_AUTO_MEMORY_KEEP_ROWS,
// OPENFLOW_AUTO_MEMORY_FETCH_LIMIT, OPENFLOW_AUTO_MEMORY_REWORK_LIMIT,
// OPENFLOW_STYLE_BIBLE_NOTE_MAX_CHARS, OPENFLOW_STAGE_SUMMARY_NOTE_MAX_CHARS.

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

/// Per-line / snapshot text caps (characters).
const MIN_MAX_CHARS: usize = 32;
const MAX_MAX_CHARS: usize = 200_000;

/// Row retention / SQL LIMIT (positive i64 for sqlx).
const MIN_ROW_COUNT: i64 = 1;
const MAX_ROW_COUNT: i64 = 10_000;

/// Non-rework char budget multiplier and rework row caps in scope selection.
const MIN_REWORK_LIMIT: usize = 1;
const MAX_REWORK_LIMIT: usize = 100;

/// Injected note blocks (style bible / stage summary).
const MIN_STYLE_BIBLE_NOTE_CHARS: usize = 64;
const MAX_STYLE_BIBLE_NOTE_CHARS: usize = 100_000;
const MIN_STAGE_SUMMARY_NOTE_CHARS: usize = 32;
const MAX_STAGE_SUMMARY_NOTE_CHARS: usize = 100_000;

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
    let keep_rows = parse_env_i64_bounded(
        "OPENFLOW_AUTO_MEMORY_KEEP_ROWS",
        DEFAULT_KEEP_ROWS,
        MIN_ROW_COUNT,
        MAX_ROW_COUNT,
    );
    let max_chars = parse_env_usize_bounded(
        "OPENFLOW_AUTO_MEMORY_MAX_CHARS",
        DEFAULT_MAX_CHARS,
        MIN_MAX_CHARS,
        MAX_MAX_CHARS,
    );
    let rework_limit = parse_env_usize_bounded(
        "OPENFLOW_AUTO_MEMORY_REWORK_LIMIT",
        DEFAULT_REWORK_LIMIT,
        MIN_REWORK_LIMIT,
        MAX_REWORK_LIMIT,
    );
    let fetch_limit = match std::env::var("OPENFLOW_AUTO_MEMORY_FETCH_LIMIT") {
        Ok(raw) => match parse_i64_bounded_trimmed(&raw, keep_rows, MIN_ROW_COUNT, MAX_ROW_COUNT) {
            Ok(v) => v,
            Err(()) => {
                tracing::warn!(
                    env = "OPENFLOW_AUTO_MEMORY_FETCH_LIMIT",
                    value = %raw,
                    "invalid value; using OPENFLOW_AUTO_MEMORY_KEEP_ROWS (or default)"
                );
                keep_rows
            }
        },
        Err(_) => keep_rows,
    };
    let style_bible_note_max_chars = parse_style_bible_note_max_chars();
    let stage_summary_note_max_chars = parse_stage_summary_note_max_chars();
    AutoMemoryLimits {
        max_chars,
        keep_rows,
        fetch_limit,
        rework_limit,
        style_bible_note_max_chars,
        stage_summary_note_max_chars,
    }
}

fn parse_style_bible_note_max_chars() -> usize {
    if let Ok(raw) = std::env::var("OPENFLOW_STYLE_BIBLE_NOTE_MAX_CHARS") {
        return parse_usize_env_raw_bounded(
            "OPENFLOW_STYLE_BIBLE_NOTE_MAX_CHARS",
            &raw,
            DEFAULT_STYLE_BIBLE_NOTE_MAX_CHARS,
            MIN_STYLE_BIBLE_NOTE_CHARS,
            MAX_STYLE_BIBLE_NOTE_CHARS,
        );
    }
    parse_env_usize_bounded(
        "OPENFLOW_AUTO_MEMORY_STYLE_BIBLE_NOTE_MAX_CHARS",
        DEFAULT_STYLE_BIBLE_NOTE_MAX_CHARS,
        MIN_STYLE_BIBLE_NOTE_CHARS,
        MAX_STYLE_BIBLE_NOTE_CHARS,
    )
}

fn parse_stage_summary_note_max_chars() -> usize {
    if let Ok(raw) = std::env::var("OPENFLOW_STAGE_SUMMARY_NOTE_MAX_CHARS") {
        return parse_usize_env_raw_bounded(
            "OPENFLOW_STAGE_SUMMARY_NOTE_MAX_CHARS",
            &raw,
            DEFAULT_STAGE_SUMMARY_NOTE_MAX_CHARS,
            MIN_STAGE_SUMMARY_NOTE_CHARS,
            MAX_STAGE_SUMMARY_NOTE_CHARS,
        );
    }
    parse_env_usize_bounded(
        "OPENFLOW_AUTO_MEMORY_STAGE_SUMMARY_NOTE_MAX_CHARS",
        DEFAULT_STAGE_SUMMARY_NOTE_MAX_CHARS,
        MIN_STAGE_SUMMARY_NOTE_CHARS,
        MAX_STAGE_SUMMARY_NOTE_CHARS,
    )
}

fn parse_usize_env_raw_bounded(
    name: &str,
    raw: &str,
    default: usize,
    lo: usize,
    hi: usize,
) -> usize {
    match parse_usize_bounded_trimmed(raw, default, lo, hi) {
        Ok(v) => v,
        Err(()) => {
            tracing::warn!(env = name, value = %raw, "invalid value; using default");
            default
        }
    }
}

fn parse_env_usize_bounded(name: &str, default: usize, lo: usize, hi: usize) -> usize {
    match std::env::var(name) {
        Ok(raw) => parse_usize_env_raw_bounded(name, &raw, default, lo, hi),
        Err(_) => default,
    }
}

fn parse_env_i64_bounded(name: &str, default: i64, lo: i64, hi: i64) -> i64 {
    match std::env::var(name) {
        Ok(raw) => match parse_i64_bounded_trimmed(&raw, default, lo, hi) {
            Ok(v) => v,
            Err(()) => {
                tracing::warn!(env = name, value = %raw, "invalid value; using default");
                default
            }
        },
        Err(_) => default,
    }
}

fn parse_usize_bounded_trimmed(
    raw: &str,
    default: usize,
    lo: usize,
    hi: usize,
) -> Result<usize, ()> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Ok(default.clamp(lo, hi));
    }
    let parsed = trimmed.parse::<usize>().map_err(|_| ())?;
    if parsed == 0 {
        return Err(());
    }
    Ok(parsed.clamp(lo, hi))
}

fn parse_i64_bounded_trimmed(raw: &str, default: i64, lo: i64, hi: i64) -> Result<i64, ()> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Ok(default.clamp(lo, hi));
    }
    let parsed = trimmed.parse::<i64>().map_err(|_| ())?;
    if parsed <= 0 {
        return Err(());
    }
    Ok(parsed.clamp(lo, hi))
}

#[cfg(test)]
mod tests {
    use super::{
        parse_i64_bounded_trimmed, parse_usize_bounded_trimmed, DEFAULT_KEEP_ROWS, MAX_MAX_CHARS,
        MAX_ROW_COUNT, MIN_MAX_CHARS, MIN_ROW_COUNT,
    };

    #[test]
    fn parse_usize_accepts_positive_clamps_and_empty_means_default() {
        assert_eq!(
            parse_usize_bounded_trimmed("480", 320, MIN_MAX_CHARS, MAX_MAX_CHARS).unwrap(),
            480
        );
        assert_eq!(
            parse_usize_bounded_trimmed("  1 ", 320, MIN_MAX_CHARS, MAX_MAX_CHARS).unwrap(),
            MIN_MAX_CHARS
        );
        assert_eq!(
            parse_usize_bounded_trimmed("", 320, MIN_MAX_CHARS, MAX_MAX_CHARS).unwrap(),
            320
        );
        assert!(parse_usize_bounded_trimmed("0", 320, MIN_MAX_CHARS, MAX_MAX_CHARS).is_err());
        assert!(parse_usize_bounded_trimmed("-1", 320, MIN_MAX_CHARS, MAX_MAX_CHARS).is_err());
        assert!(parse_usize_bounded_trimmed("nope", 320, MIN_MAX_CHARS, MAX_MAX_CHARS).is_err());
        assert_eq!(
            parse_usize_bounded_trimmed("999999999", 320, MIN_MAX_CHARS, MAX_MAX_CHARS).unwrap(),
            MAX_MAX_CHARS
        );
    }

    #[test]
    fn parse_i64_accepts_positive_clamps_and_empty_means_default() {
        assert_eq!(
            parse_i64_bounded_trimmed("16", 8, MIN_ROW_COUNT, MAX_ROW_COUNT).unwrap(),
            16
        );
        assert_eq!(
            parse_i64_bounded_trimmed("", 8, MIN_ROW_COUNT, MAX_ROW_COUNT).unwrap(),
            DEFAULT_KEEP_ROWS
        );
        assert!(parse_i64_bounded_trimmed("0", 8, MIN_ROW_COUNT, MAX_ROW_COUNT).is_err());
        assert_eq!(
            parse_i64_bounded_trimmed("999999", 8, MIN_ROW_COUNT, MAX_ROW_COUNT).unwrap(),
            MAX_ROW_COUNT
        );
    }

    #[test]
    fn parse_i64_empty_uses_passed_default_not_module_constant() {
        assert_eq!(
            parse_i64_bounded_trimmed("", 3, MIN_ROW_COUNT, MAX_ROW_COUNT).unwrap(),
            3
        );
    }

    #[test]
    fn parse_usize_empty_uses_passed_default() {
        assert_eq!(parse_usize_bounded_trimmed("", 400, 100, 500).unwrap(), 400);
    }
}
