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

String _qualitySuggestedActionLabel(String action) {
  switch (action) {
    case 'rollback_to_director_planning':
      return 'rollback director';
    case 'update_character_anchor':
      return 'update anchor';
    case 'patch_storyboard_items':
      return 'patch storyboard';
    case 'adjust_video_prompt':
      return 'adjust prompt';
    case 'retry_video_generation':
      return 'retry video';
    case 'regenerate_storyboard':
      return 'regen storyboard';
    case 'manual_review':
      return 'manual review';
    default:
      return action;
  }
}
