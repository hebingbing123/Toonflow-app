pub(in crate::production::workbench::storyboard) fn storyboard_numeric_ids_from_base(
    base_numeric_id: i32,
    count: usize,
) -> Vec<i32> {
    (0..count)
        .map(|idx| base_numeric_id + idx as i32 + 1)
        .collect()
}
