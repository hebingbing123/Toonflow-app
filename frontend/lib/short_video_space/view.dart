import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import 'publish_copy_editor.dart';
import 'publish_schedule_calendar.dart';

// Part files for extracted widget components
part 'view_project_selector.dart';
part 'view_production_panel.dart';
part 'view_candidate_compare.dart';
part 'view_publish_drafts.dart';
part 'view_publish_calendar.dart';
part 'view_publish_jobs.dart';
part 'view_publish_audit.dart';

enum ShortVideoMode { animated, liveAction }

/// Display order for publish platform chips (full matrix; ids match backend).
const List<String> kShortVideoPublishPlatformIdsInDisplayOrder = <String>[
  'douyin',
  'bilibili',
  'xiaohongshu',
  'weixin_channels',
  'kuaishou',
  'tiktok',
  'youtube_shorts',
  'instagram_reels',
  'facebook_reels',
];

String shortVideoPublishPlatformLabel(AppLocalizations l10n, String platformId) {
  switch (platformId) {
    case 'douyin':
      return l10n.shortVideoPublishPlatformDouyin;
    case 'bilibili':
      return l10n.shortVideoPublishPlatformBilibili;
    case 'xiaohongshu':
      return l10n.shortVideoPublishPlatformXiaohongshu;
    case 'weixin_channels':
      return l10n.shortVideoPublishPlatformWeixinChannels;
    case 'kuaishou':
      return l10n.shortVideoPublishPlatformKuaishou;
    case 'tiktok':
      return l10n.shortVideoPublishPlatformTiktok;
    case 'youtube_shorts':
      return l10n.shortVideoPublishPlatformYoutubeShorts;
    case 'instagram_reels':
      return l10n.shortVideoPublishPlatformInstagramReels;
    case 'facebook_reels':
      return l10n.shortVideoPublishPlatformFacebookReels;
    default:
      return platformId;
  }
}

String shortVideoPublishPlatformLabelWithMatrixFallback(
  AppLocalizations l10n,
  String platformId,
  String? labelZhFromMatrix,
) {
  final localized = shortVideoPublishPlatformLabel(l10n, platformId);
  if (localized != platformId) {
    return localized;
  }
  final f = labelZhFromMatrix?.trim() ?? '';
  if (f.isNotEmpty) {
    return f;
  }
  return platformId;
}

String shortVideoPublishDraftStatusLabel(
  AppLocalizations l10n,
  String draftStatus,
) {
  switch (draftStatus.trim()) {
    case 'editing':
      return l10n.shortVideoPublishDraftStatusEditing;
    case 'ready':
      return l10n.shortVideoPublishDraftStatusReady;
    case 'archived':
      return l10n.shortVideoPublishDraftStatusArchived;
    case 'draft':
      return l10n.shortVideoPublishDraftStatusDraft;
    default:
      final s = draftStatus.trim();
      return s.isEmpty
          ? l10n.shortVideoPublishDraftStatusUnknown
          : l10n.shortVideoPublishDraftStatusRaw(s);
  }
}

String shortVideoPublishAutomationModeLabel(
  AppLocalizations l10n,
  String mode,
) {
  switch (mode.trim()) {
    case 'full_auto':
      return l10n.shortVideoPublishAutomationFullAuto;
    case 'semi_auto':
      return l10n.shortVideoPublishAutomationSemiAuto;
    case 'manual_assisted':
      return l10n.shortVideoPublishAutomationManualAssisted;
    default:
      final m = mode.trim();
      return m.isEmpty
          ? l10n.shortVideoPublishAutomationModeUnknown
          : l10n.shortVideoPublishAutomationModeRaw(m);
  }
}

class ShortVideoProjectOption {
  const ShortVideoProjectOption({required this.id, required this.label});

  final String id;
  final String label;
}

class ShortVideoMetricData {
  const ShortVideoMetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class ShortVideoReadinessItem {
  const ShortVideoReadinessItem({
    required this.label,
    required this.ready,
    required this.detail,
  });

  final String label;
  final bool ready;
  final String detail;
}

/// Candidate asset confirmation summary (**`GET …/assets-overview`** `candidate_counts`; 旧版列表聚合已废弃)。
class ShortVideoCandidateCardUi {
  const ShortVideoCandidateCardUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.pending = 0,
    this.linked = 0,
    this.ignored = 0,
    this.unset = 0,
    this.headline = '',
    this.detail = '',
    this.onBatchGenerateCandidateClips,
    this.batchGenerateCandidateClipsBusy = false,
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final int pending;
  final int linked;
  final int ignored;
  /// `candidate_status` 为空或非 pending/linked/ignored（与后端 `unset` 一致）。
  final int unset;
  final String headline;
  final String detail;
  final VoidCallback? onBatchGenerateCandidateClips;
  final bool batchGenerateCandidateClipsBusy;
}

/// Space 内嵌 **统一资产总览**（C9）：按类型分组 + 关联剧本号摘要。
class ShortVideoAssetsOverviewPanelUi {
  const ShortVideoAssetsOverviewPanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.typeLines = const <String>[],
    this.detail = '',
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final List<String> typeLines;
  final String detail;
}

/// D4：**成片装配**快照（**`GET …/short-video-assembly`**）。
class ShortVideoAssemblyPanelUi {
  const ShortVideoAssemblyPanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.defaultsLine = '',
    this.qualityLines = const <String>[],
    this.scriptLines = const <String>[],
    this.multiTrackDecisionLines = const <String>[],
    this.detail = '',
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final String defaultsLine;
  /// L3：质量验收摘要行（与 **`candidate_quality_summary`** 对齐）。
  final List<String> qualityLines;
  final List<String> scriptLines;
  final List<String> multiTrackDecisionLines;
  final String detail;
}

/// D4：**导出前检查**摘要（**`GET …/short-video-export-check`**）。
class ShortVideoExportCheckPanelUi {
  const ShortVideoExportCheckPanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.metrics = const <ShortVideoMetricData>[],
    this.qualityGateLine = '',
    this.qualityGateBlockingLines = const <String>[],
    this.blockingLines = const <String>[],
    this.warningLines = const <String>[],
    this.detail = '',
    this.exportReady = false,
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final List<ShortVideoMetricData> metrics;
  final String qualityGateLine;
  final List<String> qualityGateBlockingLines;
  final List<String> blockingLines;
  final List<String> warningLines;
  final String detail;
  final bool exportReady;
}

class ShortVideoCandidateCompareItemUi {
  const ShortVideoCandidateCompareItemUi({
    required this.storyboardNumericId,
    this.scriptNumericId,
    this.referenceImageUrl,
    this.selectedVideoUrl,
    this.liveActionReferenceShotUrls = const <String>[],
    required this.readinessLine,
    required this.qualityLine,
    this.onSetCurrent,
    this.onOpenRework,
  });

  final int storyboardNumericId;
  final int? scriptNumericId;
  final String? referenceImageUrl;
  final String? selectedVideoUrl;
  final List<String> liveActionReferenceShotUrls;
  final String readinessLine;
  final String qualityLine;
  final VoidCallback? onSetCurrent;
  final VoidCallback? onOpenRework;
}

class ShortVideoCandidateComparePanelUi {
  const ShortVideoCandidateComparePanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.detail = '',
    this.items = const <ShortVideoCandidateCompareItemUi>[],
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final String detail;
  final List<ShortVideoCandidateCompareItemUi> items;
}

/// **E10–E13**：发布准备清单、平台矩阵、草稿与作业（**`/publish/*`**）。
class ShortVideoPublishPanelUi {
  const ShortVideoPublishPanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.exportGateHint = '',
    this.exportReady = true,
    this.detail = '',
    this.matrixDomesticLines = const <String>[],
    this.matrixOverseasLines = const <String>[],
    this.prepareLines = const <String>[],
    this.publishOverviewLines = const <String>[],
    this.draftLines = const <String>[],
    this.jobLines = const <String>[],
    this.onRefreshPublish,
    this.publishBusy = false,
    this.onBootstrapPublishDraft,
    this.onEnqueuePublishJob,
    this.awaitingSemiAutoJobId,
    this.onConfirmSemiAuto,
    this.onSuggestPublishCopy,
    this.onClearPublishSchedule,
    this.publishPrimaryDraftId = '',
    this.publishDomesticTargetIds = const <String>[],
    this.publishOverseasTargetIds = const <String>[],
    this.publishPlatformLabels = const <String, String>{},
    this.publishPlatformCopySnapshot = const <String, dynamic>{},
    this.publishCopyEditorRevision = 0,
    this.onCommitPublishPlatformCopy,
    this.onScheduleFirstDraft,
    this.onScheduleAllDraftsSameTime,
    this.onEnqueueAllDrafts,
    this.onRetryFailedPublishJobs,
    this.publishBatchResultLines = const <String>[],
    this.publishAutomationModesByPlatform = const <String, String>{},
    this.onChangePublishAutomationMode,
    this.publishDraftOptions = const <PublishDraftRow>[],
    this.selectedPublishDraftId,
    this.onSelectPublishDraft,
    this.publishScheduleCalendarDrafts,
    this.onPublishCalendarDayBulkSchedule,
    this.onOpenPublishTroubleshooting,
    // P8: Multi-select
    this.multiSelectMode = false,
    this.selectedDraftIds = const <String>{},
    this.onToggleMultiSelectMode,
    this.onToggleDraftSelection,
    this.onSelectAllDrafts,
    this.onClearDraftSelection,
    this.onBatchScheduleDrafts,
    this.onBatchPublishDrafts,
    this.onBatchArchiveDrafts,
    this.onCompareDrafts,
    this.batchValidation,
    this.onResetConfirmationDontShowAgain,
    // P11: Delivery mode breakdown
    this.jobsByDeliveryMode = const <String, int>{},
    this.deliveryModeFilter,
    this.onDeliveryModeFilterChanged,
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final String exportGateHint;
  final bool exportReady;
  final String detail;
  final List<String> matrixDomesticLines;
  final List<String> matrixOverseasLines;
  final List<String> prepareLines;
  final List<String> publishOverviewLines;
  final List<String> draftLines;
  final List<String> jobLines;
  final VoidCallback? onRefreshPublish;
  final bool publishBusy;
  final VoidCallback? onBootstrapPublishDraft;
  final VoidCallback? onEnqueuePublishJob;
  final String? awaitingSemiAutoJobId;
  final VoidCallback? onConfirmSemiAuto;
  final VoidCallback? onSuggestPublishCopy;
  final VoidCallback? onClearPublishSchedule;
  final String publishPrimaryDraftId;
  final List<String> publishDomesticTargetIds;
  final List<String> publishOverseasTargetIds;
  final Map<String, String> publishPlatformLabels;
  final Map<String, dynamic> publishPlatformCopySnapshot;
  final int publishCopyEditorRevision;
  final PublishPlatformCopyCommit? onCommitPublishPlatformCopy;
  final void Function(BuildContext context)? onScheduleFirstDraft;
  final void Function(BuildContext context)? onScheduleAllDraftsSameTime;
  final VoidCallback? onEnqueueAllDrafts;
  final VoidCallback? onRetryFailedPublishJobs;
  final List<String> publishBatchResultLines;
  final Map<String, String> publishAutomationModesByPlatform;
  final void Function(String platformId, String automationMode)?
      onChangePublishAutomationMode;
  final List<PublishDraftRow> publishDraftOptions;
  final String? selectedPublishDraftId;
  final ValueChanged<String>? onSelectPublishDraft;
  /// When null, treat as no drafts for calendar (keeps panel `const` paths valid).
  final List<PublishDraftRow>? publishScheduleCalendarDrafts;
  final PublishCalendarDayCallback? onPublishCalendarDayBulkSchedule;
  final VoidCallback? onOpenPublishTroubleshooting;
  
  // P8: Multi-select fields
  final bool multiSelectMode;
  final Set<String> selectedDraftIds;
  final VoidCallback? onToggleMultiSelectMode;
  final ValueChanged<String>? onToggleDraftSelection;
  final VoidCallback? onSelectAllDrafts;
  final VoidCallback? onClearDraftSelection;
  final void Function(BuildContext context)? onBatchScheduleDrafts;
  final VoidCallback? onBatchPublishDrafts;
  final VoidCallback? onBatchArchiveDrafts;
  final VoidCallback? onCompareDrafts;
  final PublishBatchValidationResponse? batchValidation;
  /// Clears local SharedPreferences for all short-video destructive confirms.
  final void Function(BuildContext context)? onResetConfirmationDontShowAgain;
  
  // P11: Delivery mode breakdown
  final Map<String, int> jobsByDeliveryMode;
  final String? deliveryModeFilter;
  final ValueChanged<String>? onDeliveryModeFilterChanged;
}

/// Server-backed shot readiness slice for Space (see **`GET …/short-video-readiness`**).
class ShotReadinessUi {
  const ShotReadinessUi({
    this.loading = false,
    this.unavailable = false,
    this.headline,
    this.reasonLines = const <String>[],
    this.shotDetailLines = const <String>[],
  });

  final bool loading;
  final bool unavailable;
  final String? headline;
  final List<String> reasonLines;
  final List<String> shotDetailLines;
}

class ShortVideoStageCardData {
  const ShortVideoStageCardData({
    required this.title,
    required this.status,
    required this.detail,
  });

  final String title;
  final String status;
  final String detail;
}

/// P11: Delivery Mode Badge widget
class DeliveryModeBadge extends StatelessWidget {
  const DeliveryModeBadge({
    super.key,
    required this.deliveryMode,
    this.small = false,
  });

  final String deliveryMode;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (deliveryMode.toLowerCase()) {
      case 'live':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.check_circle;
        label = l10n.shortVideoDeliveryModeLive;
        break;
      case 'sandbox':
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
        icon = Icons.warning_amber;
        label = l10n.shortVideoDeliveryModeSandbox;
        break;
      case 'manual_bridge':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        icon = Icons.person;
        label = l10n.shortVideoDeliveryModeManualBridge;
        break;
      default:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        icon = Icons.help_outline;
        label = deliveryMode.isEmpty
            ? l10n.shortVideoDeliveryModeUnknown
            : deliveryMode;
    }
    
    if (small) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColor,
            fontSize: 10,
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ShortVideoSpaceView extends StatelessWidget {
  const ShortVideoSpaceView({
    super.key,
    required this.mode,
    required this.modeTitle,
    required this.modeSummary,
    required this.modeAdvice,
    required this.onModeChanged,
    required this.loadingProjects,
    required this.projectOptions,
    required this.selectedProjectId,
    required this.onProjectChanged,
    required this.onRefreshProjects,
    required this.videoRatio,
    required this.onVideoRatioChanged,
    required this.targetMarket,
    required this.onTargetMarketChanged,
    required this.targetPlatforms,
    required this.onPublishPlatformTapped,
    required this.durationStrategy,
    required this.onDurationStrategyChanged,
    required this.voiceProfile,
    required this.onVoiceProfileChanged,
    required this.subtitleStyle,
    required this.onSubtitleStyleChanged,
    required this.bgmStrategy,
    required this.onBgmStrategyChanged,
    required this.creatingProject,
    required this.onCreateProject,
    required this.savingProjectConfig,
    required this.onSaveProjectConfig,
    required this.onOpenProjects,
    required this.projectConfigLine,
    required this.operationFeedbackIsSuccess,
    required this.loadingProjectOverview,
    required this.projectReadinessSummary,
    required this.visualLabel,
    required this.directionLabel,
    required this.projectMetrics,
    required this.spaceOverviewSummary,
    required this.overviewMetrics,
    required this.qualitySummaryLine,
    required this.badCaseMetrics,
    required this.recentTaskLines,
    required this.assetsOverviewPanelUi,
    required this.assemblyPanelUi,
    required this.exportCheckPanelUi,
    this.onStartExport,
    this.onOpenExportHistory,
    this.exportActionBusy = false,
    required this.publishPanelUi,
    this.onOpenProductionForAssemblyExport,
    this.onOpenAssemblyClipDeskOps,
    this.onOpenAssemblyDefaultsEditor,
    this.assemblyVersionManagerPanel,
    required this.candidateCardUi,
    required this.candidateComparePanelUi,
    this.onOpenProjectsForCandidateAssets,
    required this.readinessIntro,
    required this.readinessCountLabel,
    required this.readinessGapSummary,
    required this.readinessItems,
    required this.shotReadinessUi,
    this.onOpenProductionForShotReadiness,
    required this.nextStepTitle,
    required this.nextStepDetail,
    required this.onNextStep,
    required this.nextStepButtonLabel,
    required this.stageCards,
    required this.migrationSummary,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
    this.onResetConfirmationDontShowAgain,
  });

  final String targetMarket;
  final ValueChanged<String> onTargetMarketChanged;
  final List<String> targetPlatforms;
  final ValueChanged<String> onPublishPlatformTapped;
  final String durationStrategy;
  final ValueChanged<String> onDurationStrategyChanged;
  final String voiceProfile;
  final ValueChanged<String> onVoiceProfileChanged;
  final String subtitleStyle;
  final ValueChanged<String> onSubtitleStyleChanged;
  final String bgmStrategy;
  final ValueChanged<String> onBgmStrategyChanged;

  final ShortVideoMode mode;
  final String modeTitle;
  final String modeSummary;
  final String modeAdvice;
  final ValueChanged<ShortVideoMode> onModeChanged;
  final bool loadingProjects;
  final List<ShortVideoProjectOption> projectOptions;
  final String? selectedProjectId;
  final ValueChanged<String?> onProjectChanged;
  final VoidCallback onRefreshProjects;
  final String videoRatio;
  final ValueChanged<String> onVideoRatioChanged;
  final bool creatingProject;
  final VoidCallback onCreateProject;
  final bool savingProjectConfig;
  final VoidCallback onSaveProjectConfig;
  final VoidCallback onOpenProjects;
  final String? projectConfigLine;
  final bool? operationFeedbackIsSuccess;
  final bool loadingProjectOverview;
  final String projectReadinessSummary;
  final String? visualLabel;
  final String? directionLabel;
  final List<ShortVideoMetricData> projectMetrics;
  final String spaceOverviewSummary;
  final List<ShortVideoMetricData> overviewMetrics;
  final String qualitySummaryLine;
  final List<ShortVideoMetricData> badCaseMetrics;
  final List<String> recentTaskLines;
  final ShortVideoAssetsOverviewPanelUi assetsOverviewPanelUi;
  final ShortVideoAssemblyPanelUi assemblyPanelUi;
  final ShortVideoExportCheckPanelUi exportCheckPanelUi;
  final VoidCallback? onStartExport;
  final VoidCallback? onOpenExportHistory;
  final bool exportActionBusy;
  final ShortVideoPublishPanelUi publishPanelUi;
  final VoidCallback? onOpenProductionForAssemblyExport;
  final VoidCallback? onOpenAssemblyClipDeskOps;
  final VoidCallback? onOpenAssemblyDefaultsEditor;
  final Widget? assemblyVersionManagerPanel;
  final ShortVideoCandidateCardUi candidateCardUi;
  final ShortVideoCandidateComparePanelUi candidateComparePanelUi;
  final VoidCallback? onOpenProjectsForCandidateAssets;
  final String readinessIntro;
  final String readinessCountLabel;
  final String readinessGapSummary;
  final List<ShortVideoReadinessItem> readinessItems;
  final ShotReadinessUi shotReadinessUi;
  final VoidCallback? onOpenProductionForShotReadiness;
  final String nextStepTitle;
  final String nextStepDetail;
  final VoidCallback onNextStep;
  final String nextStepButtonLabel;
  final List<ShortVideoStageCardData> stageCards;
  final String migrationSummary;
  final VoidCallback onOpenScriptWorkspace;
  final VoidCallback onOpenProductionWorkspace;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenQuality;
  /// Clears local destructive-confirm "don't show again" prefs (always available).
  final void Function(BuildContext context)? onResetConfirmationDontShowAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l10n.shortVideoSpacePageTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: l10n.notificationsRiskyPrefsTooltip,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.shortVideoSpacePageSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: outline),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shortVideoSpaceSectionCreativeMode,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _ModeSegmentedButton(mode: mode, onChanged: onModeChanged),
              const SizedBox(height: 12),
              Text(modeTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                modeSummary,
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Text(modeAdvice, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ProjectSelectorPanel(
          mode: mode,
          onModeChanged: onModeChanged,
          loadingProjects: loadingProjects,
          projectOptions: projectOptions,
          selectedProjectId: selectedProjectId,
          onProjectChanged: onProjectChanged,
          onRefreshProjects: onRefreshProjects,
          videoRatio: videoRatio,
          onVideoRatioChanged: onVideoRatioChanged,
          targetMarket: targetMarket,
          onTargetMarketChanged: onTargetMarketChanged,
          targetPlatforms: targetPlatforms,
          onPublishPlatformTapped: onPublishPlatformTapped,
          durationStrategy: durationStrategy,
          onDurationStrategyChanged: onDurationStrategyChanged,
          voiceProfile: voiceProfile,
          onVoiceProfileChanged: onVoiceProfileChanged,
          subtitleStyle: subtitleStyle,
          onSubtitleStyleChanged: onSubtitleStyleChanged,
          bgmStrategy: bgmStrategy,
          onBgmStrategyChanged: onBgmStrategyChanged,
          creatingProject: creatingProject,
          onCreateProject: onCreateProject,
          savingProjectConfig: savingProjectConfig,
          onSaveProjectConfig: onSaveProjectConfig,
          onOpenProjects: onOpenProjects,
          projectConfigLine: projectConfigLine,
          operationFeedbackIsSuccess: operationFeedbackIsSuccess,
          loadingProjectOverview: loadingProjectOverview,
          projectReadinessSummary: projectReadinessSummary,
          visualLabel: visualLabel,
          directionLabel: directionLabel,
          projectMetrics: projectMetrics,
          onResetConfirmationDontShowAgain: onResetConfirmationDontShowAgain,
        ),
        const SizedBox(height: 16),
        _ProductionPanel(
          spaceOverviewSummary: spaceOverviewSummary,
          overviewMetrics: overviewMetrics,
          qualitySummaryLine: qualitySummaryLine,
          badCaseMetrics: badCaseMetrics,
          recentTaskLines: recentTaskLines,
          assetsOverviewPanelUi: assetsOverviewPanelUi,
          assemblyPanelUi: assemblyPanelUi,
          exportCheckPanelUi: exportCheckPanelUi,
          onStartExport: onStartExport,
          onOpenExportHistory: onOpenExportHistory,
          exportActionBusy: exportActionBusy,
          onOpenProductionForAssemblyExport: onOpenProductionForAssemblyExport,
          onOpenAssemblyClipDeskOps: onOpenAssemblyClipDeskOps,
          onOpenAssemblyDefaultsEditor: onOpenAssemblyDefaultsEditor,
          assemblyVersionManagerPanel: assemblyVersionManagerPanel,
        ),
        _PublishDraftsPanel(publishPanelUi: publishPanelUi),
        _PublishCalendarPanel(publishPanelUi: publishPanelUi),
        _PublishJobsPanel(publishPanelUi: publishPanelUi),
        _PublishAuditPanel(publishPanelUi: publishPanelUi),
        _CandidateComparePanel(
          candidateCardUi: candidateCardUi,
          candidateComparePanelUi: candidateComparePanelUi,
          onOpenProjectsForCandidateAssets: onOpenProjectsForCandidateAssets,
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shortVideoSpaceSectionModeReadiness,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                readinessIntro,
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(
                    label: l10n.shortVideoSpaceReadinessReadyChip,
                    value: readinessCountLabel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                readinessGapSummary,
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              for (final item in readinessItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReadinessRow(item: item),
                ),
              const SizedBox(height: 16),
              Text(
                l10n.shortVideoSpaceSectionShotReadinessServer,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (shotReadinessUi.loading)
                Text(
                  l10n.shortVideoSpaceShotReadinessLoading,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                )
              else if (shotReadinessUi.unavailable)
                Text(
                  l10n.shortVideoSpaceShotReadinessUnavailableHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                )
              else ...[
                if (shotReadinessUi.headline != null)
                  Text(
                    shotReadinessUi.headline!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                if (shotReadinessUi.reasonLines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final line in shotReadinessUi.reasonLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              line,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (shotReadinessUi.shotDetailLines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.shortVideoSpaceShotReadinessPriorityShots,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  for (final line in shotReadinessUi.shotDetailLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.movie_filter_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(line, style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                ],
                if (onOpenProductionForShotReadiness != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onOpenProductionForShotReadiness,
                    icon: const Icon(Icons.movie_creation_outlined),
                    label: Text(l10n.shortVideoSpaceOpenProductionBoardButton),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shortVideoSpaceSectionSuggestedNext,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(nextStepTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                nextStepDetail,
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onNextStep,
                icon: const Icon(Icons.arrow_forward_outlined),
                label: Text(nextStepButtonLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stageCards
              .map(
                (item) => _StageCard(
                  title: item.title,
                  status: item.status,
                  detail: item.detail,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shortVideoSpaceSectionMigrationOrder,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(migrationSummary, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onOpenProjects,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(l10n.shortVideoSpaceNavProjects),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenScriptWorkspace,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: Text(l10n.shortVideoSpaceNavScriptWorkspace),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenProductionWorkspace,
                    icon: const Icon(Icons.movie_creation_outlined),
                    label: Text(l10n.shortVideoSpaceNavProductionWorkspace),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenTasks,
                    icon: const Icon(Icons.checklist_outlined),
                    label: Text(l10n.shortVideoSpaceNavTaskCenter),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenQuality,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(l10n.shortVideoSpaceNavQualityReviews),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _ModeSegmentedButton extends StatelessWidget {
  const _ModeSegmentedButton({required this.mode, required this.onChanged});

  final ShortVideoMode mode;
  final ValueChanged<ShortVideoMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<ShortVideoMode>(
      segments: [
        ButtonSegment(
          value: ShortVideoMode.animated,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(l10n.shortVideoSpaceModeTitleAnimated),
        ),
        ButtonSegment(
          value: ShortVideoMode.liveAction,
          icon: const Icon(Icons.person_outline),
          label: Text(l10n.shortVideoSpaceModeTitleLive),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }
        onChanged(selection.first);
      },
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.title,
    required this.status,
    required this.detail,
  });

  final String title;
  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              status,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(detail, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CandidateCompareCard extends StatelessWidget {
  const _CandidateCompareCard({required this.item});

  final ShortVideoCandidateCompareItemUi item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final l10n = AppLocalizations.of(context)!;
    final header = item.scriptNumericId != null
        ? l10n.shortVideoCandidateCompareStoryboardWithScript(
            item.storyboardNumericId,
            item.scriptNumericId!,
          )
        : l10n.shortVideoCandidateCompareStoryboardOnly(
            item.storyboardNumericId,
          );
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              header,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(item.readinessLine, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              item.qualityLine,
              style: theme.textTheme.bodySmall?.copyWith(color: outline),
            ),
            if ((item.referenceImageUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.referenceImageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text(l10n.shortVideoCandidateReferenceImageNotPreviewable),
                  ),
                ),
              ),
            ],
            if (item.liveActionReferenceShotUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.shortVideoCandidateLiveRefShotCount(
                  item.liveActionReferenceShotUrls.length,
                ),
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                item.liveActionReferenceShotUrls.take(2).join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
            ],
            if ((item.selectedVideoUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.shortVideoCandidateCurrentVideo,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              SelectableText(
                item.selectedVideoUrl!,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.onSetCurrent != null)
                  FilledButton.tonal(
                    onPressed: item.onSetCurrent,
                    child: Text(l10n.shortVideoCandidateSetCurrent),
                  ),
                if (item.onOpenRework != null)
                  OutlinedButton(
                    onPressed: item.onOpenRework,
                    child: Text(l10n.shortVideoCandidatePartialRework),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label $value', style: theme.textTheme.labelMedium),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({required this.item});

  final ShortVideoReadinessItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.ready
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          item.ready
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                item.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
