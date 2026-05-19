/// Shared width gates for studio / product-shell responsive layout.
///
/// Use [LayoutBuilder] `constraints.maxWidth`, not [MediaQuery] full viewport,
/// so sidebars and pane padding do not trigger overly aggressive side-by-side rows.
const double kStudioTwoColumnMinWidth = 1100;

/// Title + subtitle + pipeline chips on one row (needs ample horizontal space).
const double kStudioPipelineInlineMinWidth = 1100;

/// Inline secondary header rows (intro + chip, etc.).
const double kStudioCompactHeaderMinWidth = 720;
