import 'package:flutter/material.dart';

import '../design_system/components/studio_dropdown_field.dart';
import '../design_system/layout_breakpoints.dart';
import '../design_system/studio_typography.dart';
import '../design_system/tokens.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_pane_header.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_decorative_icon.dart';
import '../design_system/components/studio_text_styles.dart';
import '../l10n/app_localizations.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import 'panels/assembly_input_panel.dart';
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

/// Panels visible when [ShortVideoSpaceSection] is embedded in Project Studio.
enum ShortVideoSpaceEmbedScope {
  /// Full short-video workspace (default pane).
  full,

  /// Assembly + export actions (Studio deliver「组装」tab).
  assembly,

  /// Publish drafts / calendar / jobs / audit (Studio deliver「发布」tab).
  publish,

  /// Quality overview + export gate (Studio deliver「质检」tab).
  quality,
}

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

String shortVideoPublishPlatformLabel(
  AppLocalizations l10n,
  String platformId,
) {
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

String shortVideoPublishJobStatusLabel(AppLocalizations l10n, String status) {
  switch (status.trim()) {
    case 'queued':
      return l10n.shortVideoPublishJobStatusQueued;
    case 'retrying':
      return l10n.shortVideoPublishJobStatusRetrying;
    case 'running':
      return l10n.shortVideoPublishJobStatusRunning;
    case 'validating':
      return l10n.shortVideoPublishJobStatusValidating;
    case 'uploading':
      return l10n.shortVideoPublishJobStatusUploading;
    case 'awaiting_confirmation':
      return l10n.shortVideoPublishJobStatusAwaitingConfirmation;
    case 'succeeded':
      return l10n.shortVideoPublishJobStatusSucceeded;
    case 'failed':
      return l10n.shortVideoPublishJobStatusFailed;
    case 'cancelled':
      return l10n.shortVideoPublishJobStatusCancelled;
    case 'partial_failed':
      return l10n.shortVideoPublishJobStatusPartialFailed;
    case 'platform_processing':
      return l10n.shortVideoPublishJobStatusPlatformProcessing;
    case 'idle':
      return l10n.shortVideoPublishJobStatusIdle;
    default:
      final s = status.trim();
      return s.isEmpty
          ? l10n.shortVideoPublishJobStatusUnknown
          : l10n.shortVideoPublishJobStatusRaw(s);
  }
}

String shortVideoPublishPrepareSeverityLabel(
  AppLocalizations l10n,
  String severity,
) {
  switch (severity.trim()) {
    case 'blocking':
      return l10n.shortVideoPublishPrepareSeverityBlocking;
    case 'warning':
      return l10n.shortVideoPublishPrepareSeverityWarning;
    default:
      final s = severity.trim();
      return s.isEmpty
          ? l10n.shortVideoPublishPrepareSeverityUnknown
          : l10n.shortVideoPublishPrepareSeverityRaw(s);
  }
}

/// Localized delivery mode for publish audit / overview strings (matches [DeliveryModeBadge]).
String shortVideoDeliveryModeLabel(AppLocalizations l10n, String deliveryMode) {
  switch (deliveryMode.toLowerCase()) {
    case 'live':
      return l10n.shortVideoDeliveryModeLive;
    case 'sandbox':
      return l10n.shortVideoDeliveryModeSandbox;
    case 'manual_bridge':
      return l10n.shortVideoDeliveryModeManualBridge;
    case 'unknown':
      return l10n.shortVideoDeliveryModeUnknown;
    default:
      final d = deliveryMode.trim();
      return d.isEmpty ? l10n.shortVideoDeliveryModeUnknown : d;
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

class ShortVideoLatestExportUi {
  const ShortVideoLatestExportUi({
    this.visible = false,
    this.isWarning = false,
    this.title = '',
    this.detail = '',
    this.statusLine,
    this.activeTaskTitle,
    this.activeTaskDetail,
    this.activeTaskRunning = false,
    this.activeTaskFailed = false,
    this.activeTaskError,
    this.recommendedAction = ShortVideoLatestExportAction.none,
    this.meta = const <String>[],
  });

  final bool visible;
  final bool isWarning;
  final String title;
  final String detail;
  final String? statusLine;
  final String? activeTaskTitle;
  final String? activeTaskDetail;
  final bool activeTaskRunning;
  final bool activeTaskFailed;
  final String? activeTaskError;
  final ShortVideoLatestExportAction recommendedAction;
  final List<String> meta;
}

enum ShortVideoLatestExportAction { none, retry, openProductionWorkspace }

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
    this.onConfirmStoryboardCandidates,
    this.confirmStoryboardCandidatesBusy = false,
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
  final VoidCallback? onConfirmStoryboardCandidates;
  final bool confirmStoryboardCandidatesBusy;
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

/// Where to send the user to fix an assembly input row.
enum AssemblyInputFixTarget { storyboard, production, clipDesk }

/// Per-shot assembly input row (merged assembly + export gaps).
class AssemblyInputShotRowUi {
  const AssemblyInputShotRowUi({
    required this.scriptNumericId,
    required this.storyboardNumericId,
    this.sbIndex,
    required this.ready,
    required this.gapLabels,
    required this.primaryFixTarget,
  });

  final int scriptNumericId;
  final int storyboardNumericId;
  final int? sbIndex;
  final bool ready;
  final List<String> gapLabels;
  final AssemblyInputFixTarget primaryFixTarget;
}

/// Unified gate for pre-assembly and export actions.
class AssemblyGateUi {
  const AssemblyGateUi({
    this.canPreAssembly = false,
    this.canExport = false,
    this.blockingShotCount = 0,
    this.blockingReasonLines = const <String>[],
  });

  final bool canPreAssembly;
  final bool canExport;
  final int blockingShotCount;
  final List<String> blockingReasonLines;
}

/// Inline active generation job (pre-assembly / export).
class AssemblyActiveJobUi {
  const AssemblyActiveJobUi({
    required this.jobId,
    required this.kind,
    required this.status,
    this.errorLine,
    this.manifestPath,
    this.canRetry = false,
    this.canCancel = false,
  });

  final String jobId;
  final String kind;
  final String status;
  final String? errorLine;
  final String? manifestPath;
  final bool canRetry;
  final bool canCancel;
}

/// Assembly input panel (storyboard + assets + assembly).
class AssemblyInputPanelUi {
  const AssemblyInputPanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.gate = const AssemblyGateUi(),
    this.rows = const <AssemblyInputShotRowUi>[],
    this.activeJob,
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final AssemblyGateUi gate;
  final List<AssemblyInputShotRowUi> rows;
  final AssemblyActiveJobUi? activeJob;
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

/// 单分镜导出缺口（Wave 6 **`storyboard_gaps`** UI）。
class ShortVideoExportCheckStoryboardGapUi {
  const ShortVideoExportCheckStoryboardGapUi({
    required this.title,
    required this.facetSummary,
    required this.hasBlocking,
    this.codeLabels = const <String>[],
  });

  final String title;
  final String facetSummary;
  final bool hasBlocking;
  final List<String> codeLabels;
}

/// 发布封面 / 平台 facet（**`publish_facets.platform_facets`**）。
class ShortVideoExportPublishPlatformGapUi {
  const ShortVideoExportPublishPlatformGapUi({
    required this.title,
    required this.facetSummary,
    required this.hasBlocking,
  });

  final String title;
  final String facetSummary;
  final bool hasBlocking;
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
    this.storyboardGapEntries = const <ShortVideoExportCheckStoryboardGapUi>[],
    this.publishPlatformGapEntries =
        const <ShortVideoExportPublishPlatformGapUi>[],
    this.publishBlockingLines = const <String>[],
    this.publishWarningLines = const <String>[],
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
  final List<ShortVideoExportCheckStoryboardGapUi> storyboardGapEntries;
  final List<ShortVideoExportPublishPlatformGapUi> publishPlatformGapEntries;
  final List<String> publishBlockingLines;
  final List<String> publishWarningLines;
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
    this.candidateVideoUrls = const <String>[],
    this.liveActionReferenceShotUrls = const <String>[],
    required this.readinessLine,
    required this.qualityLine,
    this.writebackLine,
    this.onSetCurrent,
    this.onSelectCandidateVideo,
    this.onOpenRework,
  });

  final int storyboardNumericId;
  final int? scriptNumericId;
  final String? referenceImageUrl;
  final String? selectedVideoUrl;
  final List<String> candidateVideoUrls;
  final List<String> liveActionReferenceShotUrls;
  final String readinessLine;
  final String qualityLine;
  final String? writebackLine;
  final VoidCallback? onSetCurrent;
  final void Function(String videoUrl)? onSelectCandidateVideo;
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
    final tokens = StudioTokens.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);

    Color bgColor;
    Color textColor;
    IconData icon;

    switch (deliveryMode.toLowerCase()) {
      case 'live':
        bgColor = tokens.success.withValues(alpha: 0.18);
        textColor = tokens.success;
        icon = Icons.check_circle;
        break;
      case 'sandbox':
        bgColor = tokens.bgInset;
        textColor = tokens.textMuted;
        icon = Icons.warning_amber;
        break;
      case 'manual_bridge':
        bgColor = tokens.primarySoft.withValues(alpha: 0.9);
        textColor = tokens.signal;
        icon = Icons.person;
        break;
      default:
        bgColor = tokens.warning.withValues(alpha: 0.18);
        textColor = tokens.warning;
        icon = Icons.help_outline;
    }
    final label = shortVideoDeliveryModeLabel(l10n, deliveryMode);

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
            fontSize: StudioTypography.of(context).meta,
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
    this.embedScope = ShortVideoSpaceEmbedScope.full,
    this.publishSectionKey,
    this.qualitySectionKey,
    this.desktopCapabilityPanel,
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
    required this.assemblyInputPanelUi,
    required this.exportCheckPanelUi,
    required this.latestExportUi,
    this.onStartExport,
    this.onStartPreAssembly,
    this.onOpenExportHistory,
    this.onDownloadLatestExport,
    this.onCancelLatestExportTask,
    this.onRetryLatestExportTask,
    this.exportActionBusy = false,
    this.preAssemblyActionBusy = false,
    this.localAssemblyBlockedHint,
    this.onFixAssemblyStoryboard,
    this.onFixAssemblyProduction,
    this.onFixAssemblyClipDesk,
    this.onOpenAssemblyTaskCenter,
    this.onCancelAssemblyJob,
    this.onRetryAssemblyJob,
    this.onCreateDraftFromAssemblyJob,
    this.preAssemblyBlockedTooltip,
    required this.publishPanelUi,
    this.onOpenProductionForAssemblyExport,
    this.onOpenDesktopDownloads,
    this.onOpenAssemblyClipDeskOps,
    this.onOpenAssemblyDefaultsEditor,
    this.onRefreshExportCheck,
    this.assemblyVersionManagerPanel,
    required this.candidateCardUi,
    required this.candidateComparePanelUi,
    this.projectCharactersPanel,
    this.shortVideoTimelinePanel,
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
    this.runningJobCount = 0,
    this.assemblyInputPanelKey,
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
  final Widget? desktopCapabilityPanel;

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
  final AssemblyInputPanelUi assemblyInputPanelUi;
  final ShortVideoExportCheckPanelUi exportCheckPanelUi;
  final ShortVideoLatestExportUi latestExportUi;
  final VoidCallback? onStartExport;
  final VoidCallback? onStartPreAssembly;
  final VoidCallback? onOpenExportHistory;
  final VoidCallback? onDownloadLatestExport;
  final VoidCallback? onCancelLatestExportTask;
  final VoidCallback? onRetryLatestExportTask;
  final bool exportActionBusy;
  final bool preAssemblyActionBusy;
  final String? localAssemblyBlockedHint;
  final VoidCallback? onFixAssemblyStoryboard;
  final VoidCallback? onFixAssemblyProduction;
  final VoidCallback? onFixAssemblyClipDesk;
  final VoidCallback? onOpenAssemblyTaskCenter;
  final VoidCallback? onCancelAssemblyJob;
  final VoidCallback? onRetryAssemblyJob;
  final VoidCallback? onCreateDraftFromAssemblyJob;
  final String? preAssemblyBlockedTooltip;
  final ShortVideoPublishPanelUi publishPanelUi;
  final VoidCallback? onOpenProductionForAssemblyExport;
  final VoidCallback? onOpenDesktopDownloads;
  final VoidCallback? onOpenAssemblyClipDeskOps;
  final VoidCallback? onOpenAssemblyDefaultsEditor;
  final VoidCallback? onRefreshExportCheck;
  final Widget? assemblyVersionManagerPanel;
  final ShortVideoCandidateCardUi candidateCardUi;
  final ShortVideoCandidateComparePanelUi candidateComparePanelUi;
  final Widget? projectCharactersPanel;
  final Widget? shortVideoTimelinePanel;
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
  final int runningJobCount;
  final Key? assemblyInputPanelKey;

  /// Clears local destructive-confirm "don't show again" prefs (always available).
  final void Function(BuildContext context)? onResetConfirmationDontShowAgain;

  final ShortVideoSpaceEmbedScope embedScope;
  final Key? publishSectionKey;
  final Key? qualitySectionKey;

  bool get _compactEmbed => embedScope != ShortVideoSpaceEmbedScope.full;

  bool get _showAssemblyPanels =>
      !_compactEmbed || embedScope == ShortVideoSpaceEmbedScope.assembly;

  bool get _showPublishPanels =>
      !_compactEmbed || embedScope == ShortVideoSpaceEmbedScope.publish;

  bool get _showQualityPanels =>
      !_compactEmbed || embedScope == ShortVideoSpaceEmbedScope.quality;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_compactEmbed) ...[
          const SizedBox(height: StudioLayoutSpacing.section),
          StudioPaneHeader(
            title: l10n.shortVideoSpacePageTitle,
            subtitle: l10n.shortVideoSpacePageSubtitle,
            showBack: false,
            titleStyle: studioProjectTitleStyle(context),
            trailing: RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: l10n.notificationsRiskyPrefsTooltip,
            ),
          ),
          if (desktopCapabilityPanel != null) ...[
            const SizedBox(height: StudioLayoutSpacing.section),
            desktopCapabilityPanel!,
          ],
          const SizedBox(height: StudioLayoutSpacing.section),
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
                const SizedBox(height: StudioSpacing.xs),
                Text(modeSummary, style: studioMutedBodyMedium(context)),
                const SizedBox(height: 8),
                Text(modeAdvice, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.section),
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
        ],
        if (_showQualityPanels) ...[
          KeyedSubtree(
            key: qualitySectionKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!_compactEmbed) const SizedBox(height: StudioLayoutSpacing.section),
                _Panel(
                  dense: _compactEmbed,
                  child: _OverviewMigrationPanel(
                    spaceOverviewSummary: spaceOverviewSummary,
                    overviewMetrics: overviewMetrics,
                    qualitySummaryLine: qualitySummaryLine,
                    badCaseMetrics: badCaseMetrics,
                    recentTaskLines: recentTaskLines,
                    migrationSummary: migrationSummary,
                    onOpenProjects: onOpenProjects,
                    onOpenScriptWorkspace: onOpenScriptWorkspace,
                    onOpenProductionWorkspace: onOpenProductionWorkspace,
                    onOpenTasks: onOpenTasks,
                    onOpenQuality: onOpenQuality,
                    runningJobCount: runningJobCount,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_showAssemblyPanels || _showQualityPanels) ...[
          if (!_compactEmbed || _showQualityPanels)
            const SizedBox(height: StudioLayoutSpacing.section),
          _ProductionPanel(
            dense: _compactEmbed,
            assetsOverviewPanelUi: assetsOverviewPanelUi,
            assemblyPanelUi: assemblyPanelUi,
            assemblyInputPanelUi: assemblyInputPanelUi,
            exportCheckPanelUi: exportCheckPanelUi,
            latestExportUi: latestExportUi,
            onStartExport: onStartExport,
            onStartPreAssembly: onStartPreAssembly,
            onOpenExportHistory: onOpenExportHistory,
            onDownloadLatestExport: onDownloadLatestExport,
            onCancelLatestExportTask: onCancelLatestExportTask,
            onRetryLatestExportTask: onRetryLatestExportTask,
            exportActionBusy: exportActionBusy,
            preAssemblyActionBusy: preAssemblyActionBusy,
            localAssemblyBlockedHint: localAssemblyBlockedHint,
            onFixAssemblyStoryboard: onFixAssemblyStoryboard,
            onFixAssemblyProduction: onFixAssemblyProduction,
            onFixAssemblyClipDesk: onFixAssemblyClipDesk,
            onOpenAssemblyTaskCenter: onOpenAssemblyTaskCenter,
            onCancelAssemblyJob: onCancelAssemblyJob,
            onRetryAssemblyJob: onRetryAssemblyJob,
            onCreateDraftFromAssemblyJob: onCreateDraftFromAssemblyJob,
            preAssemblyBlockedTooltip: preAssemblyBlockedTooltip,
            onOpenProductionForAssemblyExport:
                onOpenProductionForAssemblyExport,
            onOpenDesktopDownloads: onOpenDesktopDownloads,
            onOpenAssemblyClipDeskOps: onOpenAssemblyClipDeskOps,
            onOpenAssemblyDefaultsEditor: onOpenAssemblyDefaultsEditor,
            onRefreshExportCheck: onRefreshExportCheck,
            assemblyVersionManagerPanel: assemblyVersionManagerPanel,
            assemblyInputPanelKey: assemblyInputPanelKey,
          ),
        ],
        if (_showPublishPanels) ...[
          KeyedSubtree(
            key: publishSectionKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _PublishDraftsPanel(publishPanelUi: publishPanelUi),
                _PublishCalendarPanel(publishPanelUi: publishPanelUi),
                _PublishJobsPanel(publishPanelUi: publishPanelUi),
                _PublishAuditPanel(publishPanelUi: publishPanelUi),
              ],
            ),
          ),
        ],
        if (!_compactEmbed) ...[
          if (projectCharactersPanel != null) ...[
            projectCharactersPanel!,
            const SizedBox(height: StudioLayoutSpacing.section),
          ],
          if (shortVideoTimelinePanel != null) ...[
            shortVideoTimelinePanel!,
            const SizedBox(height: StudioLayoutSpacing.section),
          ],
          _CandidateComparePanel(
            candidateCardUi: candidateCardUi,
            candidateComparePanelUi: candidateComparePanelUi,
            onOpenProjectsForCandidateAssets: onOpenProjectsForCandidateAssets,
          ),
          const SizedBox(height: StudioLayoutSpacing.section),
          _Panel(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tokens = StudioTokens.of(context);
                final sideBySide =
                    constraints.maxWidth >= kStudioTwoColumnMinWidth;

                final modeReadinessBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.shortVideoSpaceSectionModeReadiness,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final inlineHeader =
                            innerConstraints.maxWidth >=
                            kStudioCompactHeaderMinWidth;
                        final intro = Text(
                          readinessIntro,
                          style: studioMutedBodyMedium(context),
                        );
                        final readyChip = _MetricChip(
                          label: l10n.shortVideoSpaceReadinessReadyChip,
                          value: readinessCountLabel,
                        );
                        if (inlineHeader) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: intro),
                              const SizedBox(width: 12),
                              readyChip,
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            intro,
                            const SizedBox(height: 8),
                            readyChip,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: StudioLayoutSpacing.inlineGap),
                    Text(
                      readinessGapSummary,
                      style: studioMutedBodySmall(context),
                    ),
                    const SizedBox(height: 16),
                    _ReadinessFlowStrip(items: readinessItems),
                  ],
                );

                final shotReadinessBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.shortVideoSpaceSectionShotReadinessServer,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (shotReadinessUi.loading)
                      Text(
                        l10n.shortVideoSpaceShotReadinessLoading,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      )
                    else if (shotReadinessUi.unavailable)
                      Text(
                        l10n.shortVideoSpaceShotReadinessUnavailableHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      )
                    else ...[
                      if (shotReadinessUi.headline != null)
                        Text(
                          shotReadinessUi.headline!,
                          style: studioMutedBodyMedium(context),
                        ),
                      if (shotReadinessUi.reasonLines.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final line in shotReadinessUi.reasonLines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: theme.colorScheme.tertiary,
                                ),
                                const SizedBox(width: StudioSpacing.xs),
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
                        const SizedBox(height: StudioSpacing.xs),
                        for (final line in shotReadinessUi.shotDetailLines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.movie_filter_outlined,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: StudioSpacing.xs),
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
                      if (onOpenProductionForShotReadiness != null) ...[
                        const SizedBox(height: StudioLayoutSpacing.inlineGap),
                        OutlinedButton.icon(
                          onPressed: onOpenProductionForShotReadiness,
                          icon: const Icon(Icons.movie_creation_outlined),
                          label: Text(
                            l10n.shortVideoSpaceOpenProductionBoardButton,
                          ),
                        ),
                      ],
                    ],
                  ],
                );

                if (sideBySide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 3, child: modeReadinessBlock),
                      const SizedBox(width: StudioLayoutSpacing.section + 4),
                      Expanded(flex: 2, child: shotReadinessBlock),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    modeReadinessBlock,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: StudioLayoutSpacing.section - 4,
                      ),
                      child: Divider(
                        height: 1,
                        color: tokens.borderSubtle,
                      ),
                    ),
                    shotReadinessBlock,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.section),
          _Panel(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tokens = StudioTokens.of(context);
                final sideBySide =
                    constraints.maxWidth >= kStudioTwoColumnMinWidth;
                final nextStepBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.shortVideoSpaceSectionSuggestedNext,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(nextStepTitle, style: theme.textTheme.titleMedium),
                    const SizedBox(height: StudioSpacing.xs),
                    Text(nextStepDetail, style: studioMutedBodyMedium(context)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onNextStep,
                      icon: const Icon(Icons.arrow_forward_outlined),
                      label: Text(nextStepButtonLabel),
                    ),
                  ],
                );
                final stageFlow = _StageFlowStrip(cards: stageCards);
                if (sideBySide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 4, child: nextStepBlock),
                      const SizedBox(width: StudioLayoutSpacing.section + 4),
                      Expanded(flex: 8, child: stageFlow),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    nextStepBlock,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: StudioLayoutSpacing.section - 4,
                      ),
                      child: Divider(
                        height: 1,
                        color: tokens.borderSubtle,
                      ),
                    ),
                    stageFlow,
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child, this.dense = false});

  final Widget child;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Container(
      padding: EdgeInsets.all(
        dense ? StudioLayoutSpacing.cardInner - 4 : StudioLayoutSpacing.cardInner,
      ),
      decoration: BoxDecoration(
        color: tokens.bgSurface.withValues(alpha: 0.96),
        border: Border.all(color: tokens.borderSubtle),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
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
    final l10n = resolveAppLocalizationsForErrors(context);
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

/// One node in a horizontal flow lane (node row + caption row stay column-aligned).
class _FlowLaneCell {
  const _FlowLaneCell({required this.node, required this.caption});

  final Widget node;
  final Widget caption;
}

/// Arrows align to the vertical center of [nodeMinHeight]; captions sit in a second row.
class _HorizontalFlowLane extends StatefulWidget {
  const _HorizontalFlowLane({
    required this.nodeWidth,
    required this.nodeMinHeight,
    required this.cells,
  });

  static const double _arrowSlotWidth = 36;

  final double nodeWidth;
  final double nodeMinHeight;
  final List<_FlowLaneCell> cells;

  @override
  State<_HorizontalFlowLane> createState() => _HorizontalFlowLaneState();
}

class _HorizontalFlowLaneState extends State<_HorizontalFlowLane> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cells.isEmpty) return const SizedBox.shrink();
    final nodeChildren = <Widget>[];
    final captionChildren = <Widget>[];
    for (var i = 0; i < widget.cells.length; i++) {
      if (i > 0) {
        nodeChildren.add(
          SizedBox(
            width: _HorizontalFlowLane._arrowSlotWidth,
            height: widget.nodeMinHeight,
            child: const Center(child: _FlowArrowIcon()),
          ),
        );
        captionChildren.add(
          const SizedBox(width: _HorizontalFlowLane._arrowSlotWidth),
        );
      }
      nodeChildren.add(
        SizedBox(
          width: widget.nodeWidth,
          height: widget.nodeMinHeight,
          child: widget.cells[i].node,
        ),
      );
      captionChildren.add(
        SizedBox(width: widget.nodeWidth, child: widget.cells[i].caption),
      );
    }
    final lane = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: nodeChildren,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: captionChildren,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final showScrollHint = viewportWidth < 720;
        return SizedBox(
          width: viewportWidth,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: showScrollHint,
            interactive: true,
            notificationPredicate: (ScrollNotification notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(bottom: 4, right: 8),
              child: lane,
            ),
          ),
        );
      },
    );
  }
}

class _FlowArrowIcon extends StatelessWidget {
  const _FlowArrowIcon();

  @override
  Widget build(BuildContext context) {
    final muted = studioMutedTextColor(context);
    return studioDecorativeIcon(
      Icons.arrow_forward_rounded,
      size: 18,
      color: muted.withValues(alpha: 0.78),
    );
  }
}

/// Linear onboarding stages (立项 → 剧本 → 素材 → 出片).
class _StageFlowStrip extends StatelessWidget {
  const _StageFlowStrip({required this.cards});

  static const double _nodeWidth = 208;
  /// Must fit [_FlowNodeShell] vertical padding plus two label lines (see layout).
  static const double _nodeMinHeight = 68;

  final List<ShortVideoStageCardData> cards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final muted = studioMutedTextColor(context);
    return _HorizontalFlowLane(
      nodeWidth: _nodeWidth,
      nodeMinHeight: _nodeMinHeight,
      cells: cards
          .map(
            (card) => _FlowLaneCell(
              node: _FlowNodeShell(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(card.title, style: studioControlLabelStyle(context)),
                    const SizedBox(height: 4),
                    Text(
                      card.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              caption: Text(
                card.detail,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.35,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _FlowNodeShell extends StatelessWidget {
  const _FlowNodeShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgInset.withValues(alpha: 0.88),
          border: Border.all(color: tokens.borderSubtle),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.inlineGap, vertical: StudioSpacing.xs),
          child: Align(alignment: Alignment.centerLeft, child: child),
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
    final tokens = StudioTokens.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
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
          color: tokens.bgSurface.withValues(alpha: 0.96),
          border: Border.all(color: tokens.borderSubtle),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(header, style: studioCardTitleStyle(context)),
            const SizedBox(height: 8),
            Text(item.readinessLine, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              item.qualityLine,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            if ((item.writebackLine ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: StudioSpacing.xs),
              _WritebackStatusChip(line: item.writebackLine!),
            ],
            if ((item.referenceImageUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
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
                    child: Text(
                      l10n.shortVideoCandidateReferenceImageNotPreviewable,
                    ),
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
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
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
            if (item.candidateVideoUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.shortVideoCandidateVideoListTitle,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              ...item.candidateVideoUrls.map((url) {
                final isCurrent =
                    url.trim() == (item.selectedVideoUrl ?? '').trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          url,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isCurrent ? theme.colorScheme.primary : null,
                          ),
                        ),
                      ),
                      if (item.onSelectCandidateVideo != null && !isCurrent)
                        TextButton(
                          onPressed: () => item.onSelectCandidateVideo!(url),
                          child: Text(l10n.shortVideoCandidateSelectVideo),
                        ),
                    ],
                  ),
                );
              }),
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
    final tokens = StudioTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.xs + 2,
        vertical: StudioSpacing.xs / 2 + 2,
      ),
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.72),
        border: Border.all(color: tokens.borderSubtle),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
      ),
      child: Text(
        resolveAppLocalizationsForErrors(
          context,
        ).shortVideoMetricChipLine(label, value),
        style: theme.textTheme.labelMedium?.copyWith(color: tokens.textSecondary),
      ),
    );
  }
}

/// Horizontal pipeline for mode readiness (script → assets → storyboard …).
class _ReadinessFlowStrip extends StatelessWidget {
  const _ReadinessFlowStrip({required this.items});

  static const double _nodeWidth = 132;
  static const double _nodeMinHeight = 40;

  final List<ShortVideoReadinessItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = studioMutedTextColor(context);
    return _HorizontalFlowLane(
      nodeWidth: _nodeWidth,
      nodeMinHeight: _nodeMinHeight,
      cells: items
          .map(
            (item) => _FlowLaneCell(
              node: _ReadinessFlowNode(item: item),
              caption: Text(
                item.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.35,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ReadinessFlowNode extends StatelessWidget {
  const _ReadinessFlowNode({required this.item});

  final ShortVideoReadinessItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final muted = studioMutedTextColor(context);
    final accent = item.ready ? tokens.primary : muted;
    final border = item.ready
        ? tokens.primary.withValues(alpha: 0.45)
        : tokens.borderSubtle;
    final fill = item.ready
        ? tokens.primarySoft.withValues(alpha: 0.85)
        : tokens.bgInset.withValues(alpha: 0.88);
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: <Widget>[
                Icon(
                  item.ready
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: StudioSpacing.xs),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: item.ready ? tokens.textPrimary : tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WritebackStatusChip extends StatelessWidget {
  const _WritebackStatusChip({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incomplete =
        line.contains('incomplete') ||
        line.contains('失败') ||
        line.contains('未完整');
    final color = incomplete
        ? theme.colorScheme.errorContainer
        : StudioTokens.of(context).accentSoft;
    final onColor = incomplete
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            incomplete ? Icons.sync_problem : Icons.check_circle_outline,
            size: 14,
            color: onColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              line,
              style: theme.textTheme.labelSmall?.copyWith(color: onColor),
            ),
          ),
        ],
      ),
    );
  }
}
