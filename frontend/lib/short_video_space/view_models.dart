part of 'view.dart';

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
    this.previewOutputUrl,
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
  final String? previewOutputUrl;
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
    this.writebackIndicatesProblem = false,
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
  final bool writebackIndicatesProblem;
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
        padding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.xs,
          vertical: StudioSpacing.chromeActionGap,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
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
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.xs,
        vertical: StudioSpacing.chromeActionGap,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: StudioIconSize.xs, color: textColor),
          const SizedBox(width: StudioSpacing.xs),
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
