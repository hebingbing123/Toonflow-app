import '../l10n/app_localizations.dart';
import '../l10n/studio_code_labels.dart';

/// Matches `backend/src/prompting/quality/validate.rs` `VALID_TARGET_TYPES`.
const List<String> qualityTargetTypeOptions = <String>[
  'storyboard',
  'script',
  'video',
  'asset',
  'output',
];

const List<String> qualityTargetTypeFilterOptions = <String>[
  '',
  ...qualityTargetTypeOptions,
];

const List<String> qualitySourceOptions = <String>['manual', 'auto'];

const List<String> qualityCreateStageOptions = <String>[
  'story_skeleton',
  'adaptation_strategy',
  'director_planning',
  'storyboard_table',
  'storyboard_panel',
  'video_prompt',
];

const List<String> qualityCreateGradeOptions = <String>['A', 'B', 'C', 'D'];

const List<String> qualityBadCaseCategoryOptions = <String>[
  'plot_hole',
  'character_break',
  'storyboard_mismatch',
  'dialogue_issue',
  'visual_error',
  'pacing_issue',
  'other',
];

const List<String> qualityBadCaseCategoryCreateOptions = <String>[
  '',
  ...qualityBadCaseCategoryOptions,
];

String qualityTargetTypeLabel(String targetType, AppLocalizations l10n) {
  switch (targetType) {
    case 'storyboard':
      return l10n.qualityReviewsTargetTypeStoryboard;
    case 'script':
      return l10n.qualityReviewsTargetTypeScript;
    case 'video':
      return l10n.qualityReviewsTargetTypeVideo;
    case 'asset':
      return l10n.qualityReviewsTargetTypeAsset;
    case 'output':
      return l10n.qualityReviewsTargetTypeOutput;
    default:
      return studioUnknownCodeLabel(l10n, targetType);
  }
}

String qualityTargetTypeFilterLabel(String targetType, AppLocalizations l10n) {
  if (targetType.isEmpty) {
    return l10n.qualityReviewsAll;
  }
  return qualityTargetTypeLabel(targetType, l10n);
}

String qualitySourceLabel(String source, AppLocalizations l10n) {
  switch (source) {
    case 'manual':
      return l10n.qualityReviewsSourceManual;
    case 'auto':
      return l10n.qualityReviewsSourceAuto;
    default:
      return studioUnknownCodeLabel(l10n, source);
  }
}

String qualityStageLabel(String stage, AppLocalizations l10n) {
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
      return studioUnknownCodeLabel(l10n, stage);
  }
}

String? qualitySuggestedActionRepairHint(String action, AppLocalizations l10n) {
  switch (action.trim()) {
    case 'rollback_to_director_planning':
      return l10n.qualityReviewsSuggestedActionRepairRollbackDirector;
    case 'update_character_anchor':
      return l10n.qualityReviewsSuggestedActionRepairUpdateAnchor;
    case 'patch_storyboard_items':
      return l10n.qualityReviewsSuggestedActionRepairPatchStoryboard;
    case 'adjust_video_prompt':
      return l10n.qualityReviewsSuggestedActionRepairAdjustPrompt;
    case 'retry_video_generation':
      return l10n.qualityReviewsSuggestedActionRepairRetryVideo;
    case 'regenerate_storyboard':
      return l10n.qualityReviewsSuggestedActionRepairRegenStoryboard;
    case 'manual_review':
      return l10n.qualityReviewsSuggestedActionRepairManualReview;
    default:
      return null;
  }
}

String qualitySuggestedActionLabel(String action, AppLocalizations l10n) {
  switch (action) {
    case 'all':
      return l10n.qualityReviewsAll;
    case 'rollback_to_director_planning':
      return l10n.qualityReviewsSuggestedActionRollbackDirector;
    case 'update_character_anchor':
      return l10n.qualityReviewsSuggestedActionUpdateAnchor;
    case 'patch_storyboard_items':
      return l10n.qualityReviewsSuggestedActionPatchStoryboard;
    case 'adjust_video_prompt':
      return l10n.qualityReviewsSuggestedActionAdjustPrompt;
    case 'retry_video_generation':
      return l10n.qualityReviewsSuggestedActionRetryVideo;
    case 'regenerate_storyboard':
      return l10n.qualityReviewsSuggestedActionRegenStoryboard;
    case 'manual_review':
      return l10n.qualityReviewsSuggestedActionManualReview;
    default:
      return studioUnknownCodeLabel(l10n, action);
  }
}

String qualityBadCaseCategoryLabel(String category, AppLocalizations l10n) {
  switch (category) {
    case '':
      return l10n.qualityReviewsBadCaseCategoryNone;
    case 'plot_hole':
      return l10n.qualityReviewsBadCaseCategoryPlotHole;
    case 'character_break':
      return l10n.qualityReviewsBadCaseCategoryCharacterBreak;
    case 'storyboard_mismatch':
      return l10n.qualityReviewsBadCaseCategoryStoryboardMismatch;
    case 'dialogue_issue':
      return l10n.qualityReviewsBadCaseCategoryDialogueIssue;
    case 'visual_error':
      return l10n.qualityReviewsBadCaseCategoryVisualError;
    case 'pacing_issue':
      return l10n.qualityReviewsBadCaseCategoryPacingIssue;
    case 'other':
      return l10n.qualityReviewsBadCaseCategoryOther;
    default:
      return studioUnknownCodeLabel(l10n, category);
  }
}
