part of 'view.dart';

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
