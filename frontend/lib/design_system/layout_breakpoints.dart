/// Shared width gates for studio / product-shell responsive layout.
///
/// Use [LayoutBuilder] `constraints.maxWidth`, not [MediaQuery] full viewport,
/// so sidebars and pane padding do not trigger overly aggressive side-by-side rows.
const double kStudioTwoColumnMinWidth = 1100;

/// Title badge + pipeline chips on one row (aligned with desktop min width 960).
const double kStudioPipelineInlineMinWidth = 760;

/// Inline secondary header rows (intro + chip, etc.).
const double kStudioCompactHeaderMinWidth = 720;

/// Project-studio [CreatorJourneyCompactBar]: icon-only prev/next/setup.
const double kStudioJourneyCompactBarIconOnlyMinWidth = 720;

/// Collapse expand + more-steps into one overflow menu beside next/setup icons.
const double kStudioJourneyCompactBarCollapseToolsMinWidth = 520;
