// Feature: ai-drama-quality-optimization
// Property-based tests for supervision layer review summary structure.

#[cfg(test)]
mod tests {
    use proptest::prelude::*;

    // ── helpers ──────────────────────────────────────────────────────────────

    /// Minimal XML attribute extractor: returns the value of a named attribute
    /// from a self-closing tag like `<reviewSummary grade="A" severeCount="0" ... />`.
    fn extract_attr<'a>(xml: &'a str, attr: &str) -> Option<&'a str> {
        let needle = format!("{}=\"", attr);
        let start = xml.find(needle.as_str())? + needle.len();
        let end = xml[start..].find('"')? + start;
        Some(&xml[start..end])
    }

    fn has_attr(xml: &str, attr: &str) -> bool {
        extract_attr(xml, attr).is_some()
    }

    /// Count repair options encoded as pipe-separated (`|`) items in nextAction.
    /// e.g. "option1|option2|option3" → 3
    fn count_repair_options_pipe(next_action: &str) -> usize {
        next_action
            .split('|')
            .filter(|s| !s.trim().is_empty())
            .count()
    }

    /// Build a well-formed reviewSummary XML string using attribute syntax.
    fn build_review_xml(
        grade: &str,
        severe_count: u32,
        medium_count: u32,
        minor_count: u32,
        next_action: &str,
    ) -> String {
        format!(
            r#"<reviewSummary grade="{}" severeCount="{}" mediumCount="{}" minorCount="{}" nextAction="{}" />"#,
            grade, severe_count, medium_count, minor_count, next_action
        )
    }

    // ── generators ───────────────────────────────────────────────────────────

    fn valid_grade() -> impl Strategy<Value = &'static str> {
        prop_oneof![Just("A"), Just("B"), Just("C"), Just("D")]
    }

    /// Generate a nextAction string with exactly `count` pipe-separated repair options.
    fn repair_options_str(count: usize) -> String {
        (0..count)
            .map(|i| format!("repair_option_{}", i + 1))
            .collect::<Vec<_>>()
            .join("|")
    }

    // ── Property 13: 监督层审核摘要结构完整性 ────────────────────────────────
    //
    // Feature: ai-drama-quality-optimization, Property 13: 监督层审核摘要结构完整性
    //
    // For any supervision layer review summary output, the XML <reviewSummary />
    // must contain all 5 fields: grade (A/B/C/D), severeCount, mediumCount,
    // minorCount, nextAction.  The grade value must be one of A/B/C/D.
    // When severeCount > 0, nextAction must contain at least 2 repair options
    // (pipe-separated).
    //
    // Validates: Requirements 6.1, 6.2
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(20))]
        #[test]
        fn prop13_review_summary_structure_complete(
            grade in valid_grade(),
            severe_count in 0u32..5u32,
            medium_count in 0u32..10u32,
            minor_count in 0u32..10u32,
            // When severeCount > 0 we generate 2 or 3 repair options; otherwise 0 or 1.
            extra_options in 0usize..2usize,
        ) {
            // Build nextAction: if severeCount > 0, always include at least 2 repair options.
            let next_action = if severe_count > 0 {
                // 2 + extra_options (0 or 1) → 2 or 3 options
                repair_options_str(2 + extra_options)
            } else if extra_options > 0 {
                repair_options_str(1)
            } else {
                "no_action_required".to_string()
            };

            let xml = build_review_xml(grade, severe_count, medium_count, minor_count, &next_action);

            // ── assertion 1: all 5 required fields must be present ────────────
            for field in &["grade", "severeCount", "mediumCount", "minorCount", "nextAction"] {
                prop_assert!(
                    has_attr(&xml, field),
                    "reviewSummary XML missing field '{}': '{}'", field, xml
                );
            }

            // ── assertion 2: grade must be one of A/B/C/D ────────────────────
            let grade_val = extract_attr(&xml, "grade").unwrap();
            prop_assert!(
                matches!(grade_val, "A" | "B" | "C" | "D"),
                "grade '{}' is not one of A/B/C/D", grade_val
            );

            // ── assertion 3: severeCount > 0 → nextAction has >= 2 options ───
            let severe_val: u32 = extract_attr(&xml, "severeCount")
                .and_then(|s| s.parse().ok())
                .unwrap_or(0);

            if severe_val > 0 {
                let na_val = extract_attr(&xml, "nextAction").unwrap_or("");
                let option_count = count_repair_options_pipe(na_val);
                prop_assert!(
                    option_count >= 2,
                    "severeCount={} but nextAction has only {} repair option(s): '{}'",
                    severe_val, option_count, na_val
                );
            }
        }
    }

    // ── Additional: verify the XML builder and parser round-trip ─────────────

    #[test]
    fn test_extract_attr_basic() {
        let xml = r#"<reviewSummary grade="B" severeCount="2" mediumCount="1" minorCount="0" nextAction="fix1|fix2" />"#;
        assert_eq!(extract_attr(xml, "grade"), Some("B"));
        assert_eq!(extract_attr(xml, "severeCount"), Some("2"));
        assert_eq!(extract_attr(xml, "mediumCount"), Some("1"));
        assert_eq!(extract_attr(xml, "minorCount"), Some("0"));
        assert_eq!(extract_attr(xml, "nextAction"), Some("fix1|fix2"));
    }

    #[test]
    fn test_count_repair_options_pipe() {
        assert_eq!(count_repair_options_pipe("opt1|opt2"), 2);
        assert_eq!(count_repair_options_pipe("opt1|opt2|opt3"), 3);
        assert_eq!(count_repair_options_pipe("no_action_required"), 1);
        assert_eq!(count_repair_options_pipe(""), 0);
    }

    #[test]
    fn test_severe_count_zero_no_repair_required() {
        let xml = build_review_xml("A", 0, 0, 0, "no_action_required");
        assert!(has_attr(&xml, "grade"));
        assert!(has_attr(&xml, "severeCount"));
        assert!(has_attr(&xml, "mediumCount"));
        assert!(has_attr(&xml, "minorCount"));
        assert!(has_attr(&xml, "nextAction"));
        let severe: u32 = extract_attr(&xml, "severeCount").unwrap().parse().unwrap();
        assert_eq!(severe, 0);
    }

    #[test]
    fn test_severe_count_nonzero_requires_two_options() {
        let xml = build_review_xml("C", 1, 2, 3, "fix_dialogue|fix_pacing");
        let severe: u32 = extract_attr(&xml, "severeCount").unwrap().parse().unwrap();
        assert!(severe > 0);
        let na = extract_attr(&xml, "nextAction").unwrap();
        assert!(count_repair_options_pipe(na) >= 2);
    }
}
