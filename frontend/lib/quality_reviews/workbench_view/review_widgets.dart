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

String _qualityStageLabel(String stage, AppLocalizations l10n) {
  switch (stage) {
    case 'all':
      return l10n.qualityReviewsAll;
    case 'story_skeleton':
      return l10n.qualityReviewsStageStorySkeleton;
    case 'adaptation_strategy':
      return l10n.qualityReviewsStageAdaptationStrategy;
    case 'director_planning':
      return l10n.qualityReviewsStageDirectorPlanning;
    case 'storyboard_table':
      return l10n.qualityReviewsStageStoryboardTable;
    case 'storyboard_panel':
      return l10n.qualityReviewsStageStoryboardPanel;
    case 'video_prompt':
      return l10n.qualityReviewsStageVideoPrompt;
    default:
      return stage;
  }
}

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
