part of '../workbench_view.dart';

const List<String> _qualityStageOptions = <String>[
  'all',
  'story_skeleton',
  'adaptation_strategy',
  'director_planning',
  'storyboard_table',
  'storyboard_panel',
  'video_prompt',
];

const List<String> _qualityGradeOptions = <String>['all', 'A', 'B', 'C', 'D'];
const List<String> _qualitySuggestedActionOptions = <String>[
  'all',
  'rollback_to_director_planning',
  'update_character_anchor',
  'patch_storyboard_items',
  'adjust_video_prompt',
  'retry_video_generation',
  'regenerate_storyboard',
  'manual_review',
];

String _qualityStageLabel(String stage, AppLocalizations l10n) =>
    qualityStageLabel(stage, l10n);

Color _qualityGradeColor(BuildContext context, String grade) {
  final scheme = Theme.of(context).colorScheme;
  switch (grade) {
    case 'A':
      return scheme.primaryContainer;
    case 'B':
      return scheme.secondaryContainer;
    case 'C':
      return scheme.tertiaryContainer;
    case 'D':
      return scheme.errorContainer;
    default:
      return scheme.surfaceContainerHighest;
  }
}

String _qualityGradeLabel(String grade, AppLocalizations l10n) {
  if (grade == 'all') {
    return l10n.qualityReviewsAll;
  }
  return grade;
}

String _qualitySuggestedActionLabel(String action, AppLocalizations l10n) =>
    qualitySuggestedActionLabel(action, l10n);
