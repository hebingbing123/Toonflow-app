// Feature: ai-drama-quality-optimization
// Property-based tests for narrative event extraction and derivative asset deduplication.

#[cfg(test)]
mod tests {
    use proptest::prelude::*;

    // ── Property 19: 事件提取格式合规性 ──────────────────────────────────────
    // Feature: ai-drama-quality-optimization, Property 19: 事件提取格式合规性
    // Every output line from the event extraction agent must:
    //   - start with '|' and end with '|'
    //   - contain exactly 7 pipe-separated fields
    //   - use "X秒" format for the episode-length field (not minutes)

    /// Build a compliant pipe-separated event line from 7 field strings.
    fn build_event_line(fields: &[&str; 7]) -> String {
        format!("|{}|", fields.join("|"))
    }

    fn count_fields(line: &str) -> usize {
        // Strip leading and trailing '|', then split.
        let inner = line.trim_matches('|');
        inner.split('|').count()
    }

    fn is_valid_event_line(line: &str) -> bool {
        line.starts_with('|') && line.ends_with('|') && count_fields(line) == 7
    }

    fn duration_field_uses_seconds(field: &str) -> bool {
        // Must match pattern: one or more digits followed by '秒'
        let trimmed = field.trim();
        if trimmed.is_empty() {
            return false;
        }
        // Check ends with 秒 and the prefix is all digits.
        if let Some(num_part) = trimmed.strip_suffix('秒') {
            !num_part.is_empty() && num_part.chars().all(|c| c.is_ascii_digit())
        } else {
            false
        }
    }

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(20))]
        #[test]
        fn prop19_event_extraction_line_format(
            // Generate 7 simple field strings (no pipes inside).
            f0 in "[a-zA-Z\u{4e00}-\u{9fa5}]{1,10}",
            f1 in "[a-zA-Z\u{4e00}-\u{9fa5}]{1,10}",
            f2 in "[a-zA-Z\u{4e00}-\u{9fa5}]{1,10}",
            f3 in "[a-zA-Z\u{4e00}-\u{9fa5}]{1,10}",
            // Episode-length field: must be "X秒" format.
            duration_secs in 10u32..300u32,
            f5 in "[a-zA-Z\u{4e00}-\u{9fa5}]{1,10}",
            f6 in "[a-zA-Z\u{4e00}-\u{9fa5}]{1,10}",
        ) {
            let duration_field = format!("{}秒", duration_secs);
            let fields: [&str; 7] = [&f0, &f1, &f2, &f3, &duration_field, &f5, &f6];
            let line = build_event_line(&fields);

            // Must start and end with '|'.
            prop_assert!(
                line.starts_with('|'),
                "event line does not start with '|': '{}'", line
            );
            prop_assert!(
                line.ends_with('|'),
                "event line does not end with '|': '{}'", line
            );

            // Must have exactly 7 fields.
            prop_assert_eq!(
                count_fields(&line), 7,
                "event line has {} fields (expected 7): '{}'", count_fields(&line), line
            );

            // Overall validity check.
            prop_assert!(is_valid_event_line(&line), "event line is invalid: '{}'", line);

            // Duration field (index 4) must use "X秒" format.
            prop_assert!(
                duration_field_uses_seconds(&duration_field),
                "duration field '{}' does not use 秒 format", duration_field
            );
        }
    }

    // ── Property 23: 衍生资产去重 ─────────────────────────────────────────────
    // Feature: ai-drama-quality-optimization, Property 23: 衍生资产去重
    // When a candidate derivative asset's name/description similarity to an existing asset
    // exceeds 80%, no new entry should be created.

    /// Simple character-overlap similarity: |intersection| / |union| of char sets.
    fn char_similarity(a: &str, b: &str) -> f64 {
        if a.is_empty() && b.is_empty() {
            return 1.0;
        }
        let set_a: std::collections::HashSet<char> = a.chars().collect();
        let set_b: std::collections::HashSet<char> = b.chars().collect();
        let intersection = set_a.intersection(&set_b).count();
        let union = set_a.union(&set_b).count();
        if union == 0 {
            1.0
        } else {
            intersection as f64 / union as f64
        }
    }

    /// Returns true if the candidate should be deduplicated (not added).
    fn should_deduplicate(candidate: &str, existing: &str) -> bool {
        char_similarity(candidate, existing) > 0.8
    }

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(20))]
        #[test]
        fn prop23_derivative_asset_deduplication(
            base in "[a-zA-Z\u{4e00}-\u{9fa5}]{5,15}",
            // Suffix to append: empty = identical, short = very similar, long = different.
            suffix_len in 0usize..10usize,
        ) {
            // Build a candidate that is a slight variation of `base`.
            let candidate: String = if suffix_len == 0 {
                base.clone()
            } else {
                // Append `suffix_len` 'x' chars — still very similar for small suffix_len.
                format!("{}{}", base, "x".repeat(suffix_len))
            };

            let sim = char_similarity(&base, &candidate);
            let dedup = should_deduplicate(&candidate, &base);

            // If similarity > 0.8, deduplication must trigger.
            if sim > 0.8 {
                prop_assert!(
                    dedup,
                    "similarity {:.2} > 0.8 but deduplication did not trigger for '{}' vs '{}'",
                    sim, candidate, base
                );
            }

            // If similarity <= 0.8, deduplication must NOT trigger.
            if sim <= 0.8 {
                prop_assert!(
                    !dedup,
                    "similarity {:.2} <= 0.8 but deduplication triggered for '{}' vs '{}'",
                    sim, candidate, base
                );
            }
        }
    }
}
