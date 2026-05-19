import 'app_localizations.dart';

/// Localized display for an API / enum code. Never shows raw [code] alone when a
/// mapping exists; unknown codes use [AppLocalizations.studioUnknownCodeLabel].
String studioUnknownCodeLabel(AppLocalizations l10n, String code) {
  final trimmed = code.trim();
  if (trimmed.isEmpty) {
    return l10n.studioUnknownCodeEmpty;
  }
  return l10n.studioUnknownCodeLabel(trimmed);
}

String studioJobKindLabel(AppLocalizations l10n, String kind) {
  switch (kind.trim()) {
    case 'asset.generate.image':
      return l10n.studioJobKindAssetGenerateImage;
    case 'asset.polish.prompt':
      return l10n.studioJobKindAssetPolishPrompt;
    case 'asset.generate.batch':
      return l10n.studioJobKindAssetGenerateBatch;
    case 'asset.polish.batch':
      return l10n.studioJobKindAssetPolishBatch;
    case 'settings.vendor.model_test':
      return l10n.studioJobKindSettingsVendorModelTest;
    case 'settings.account.export':
      return l10n.studioJobKindSettingsAccountExport;
    case 'settings.workspace_shared_audit.export':
      return l10n.studioJobKindSettingsWorkspaceAuditExport;
    case 'flutter.probe':
      return l10n.studioJobKindFlutterProbe;
    case 'video.generate':
      return l10n.studioJobKindVideoGenerate;
    case 'video.export':
      return l10n.studioJobKindVideoExport;
    case 'short_video.pre_assembly':
      return l10n.studioJobKindShortVideoPreAssembly;
    case 'short_video.timeline_preview':
      return l10n.studioJobKindShortVideoTimelinePreview;
    case 'voiceover.generate':
      return l10n.studioJobKindVoiceoverGenerate;
    case 'subtitle.generate':
      return l10n.studioJobKindSubtitleGenerate;
    case 'bgm.generate':
      return l10n.studioJobKindBgmGenerate;
    case 'novel.crawl.import_batch':
      return l10n.studioJobKindNovelCrawlImportBatch;
    default:
      return studioUnknownCodeLabel(l10n, kind);
  }
}

String studioJobStatusLabel(AppLocalizations l10n, String status) {
  switch (status.trim().toLowerCase()) {
    case 'queued':
      return l10n.studioJobStatusQueued;
    case 'running':
      return l10n.studioJobStatusRunning;
    case 'failed':
      return l10n.studioJobStatusFailed;
    case 'succeeded':
      return l10n.studioJobStatusSucceeded;
    case 'cancelled':
      return l10n.studioJobStatusCancelled;
    case 'dead':
      return l10n.studioJobStatusDead;
    default:
      return studioUnknownCodeLabel(l10n, status);
  }
}

String studioJobListTitle(AppLocalizations l10n, String kind, String status) {
  return l10n.studioJobListTitle(
    studioJobKindLabel(l10n, kind),
    studioJobStatusLabel(l10n, status),
  );
}

String studioHarnessWsEventTypeLabel(AppLocalizations l10n, String eventType) {
  switch (eventType.trim()) {
    case 'harness.agent.started':
      return l10n.studioHarnessWsEventHarnessAgentStarted;
    case 'chat.content.updated':
      return l10n.studioHarnessWsEventChatContentUpdated;
    case 'harness.tool.result':
      return l10n.studioHarnessWsEventHarnessToolResult;
    case 'harness.agent.cancelled':
      return l10n.studioHarnessWsEventHarnessAgentCancelled;
    case 'chat.message.updated':
      return l10n.studioHarnessWsEventChatMessageUpdated;
    case 'error.occurred':
      return l10n.studioHarnessWsEventErrorOccurred;
    case 'generation.job.updated':
      return l10n.studioHarnessWsEventGenerationJobUpdated;
    default:
      return studioUnknownCodeLabel(l10n, eventType);
  }
}

String studioJobQueueMetricLabel(AppLocalizations l10n, String metric) {
  switch (metric.trim().toLowerCase()) {
    case 'pending':
      return l10n.studioJobQueueMetricPending;
    case 'claimable':
      return l10n.studioJobQueueMetricClaimable;
    case 'running':
      return l10n.studioJobQueueMetricRunning;
    case 'dead':
      return l10n.studioJobQueueMetricDead;
    case 'failed 24h':
    case 'failed_last_24h':
      return l10n.studioJobQueueMetricFailed24h;
    case 'oldest secs':
    case 'oldest_claimable_queued_age_secs':
      return l10n.studioJobQueueMetricOldestSecs;
    case 'pending_by_kind':
      return l10n.studioJobQueueMetricPendingByKind;
    default:
      return studioJobKindLabel(l10n, metric);
  }
}

String studioNotificationsComplianceStageLabel(
  AppLocalizations l10n,
  String stage,
) {
  switch (stage.trim()) {
    case 'critical_unclaimed':
      return l10n.notificationsComplianceStageCriticalUnclaimed;
    case 'over_capacity':
      return l10n.notificationsComplianceStageOverCapacity;
    case 'stalled_claimed':
      return l10n.notificationsComplianceStageStalledClaimed;
    case 'escalated_72h':
      return l10n.notificationsComplianceStageEscalated72h;
    default:
      return studioUnknownCodeLabel(l10n, stage);
  }
}

String studioAdminAclModeLabel(AppLocalizations l10n, String mode) {
  switch (mode.trim().toLowerCase()) {
    case 'inherited':
      return l10n.adminConsoleAclModeInherited;
    case 'restricted':
      return l10n.adminConsoleAclModeRestricted;
    case 'open':
      return l10n.adminConsoleAclModeOpen;
    default:
      return studioUnknownCodeLabel(l10n, mode);
  }
}

String studioBenchmarkExperimentStatusLabel(
  AppLocalizations l10n,
  String status,
) {
  switch (status.trim().toLowerCase()) {
    case 'draft':
      return l10n.benchmarkExperimentStatusDraft;
    case 'running':
      return l10n.benchmarkExperimentStatusRunning;
    case 'completed':
      return l10n.benchmarkExperimentStatusCompleted;
    case 'failed':
      return l10n.benchmarkExperimentStatusFailed;
    case 'archived':
      return l10n.benchmarkExperimentStatusArchived;
    default:
      return studioUnknownCodeLabel(l10n, status);
  }
}

String studioBenchmarkReviewTypeLabel(AppLocalizations l10n, String type) {
  switch (type.trim().toLowerCase()) {
    case 'human':
      return l10n.benchmarkReviewTypeHuman;
    case 'auto':
      return l10n.benchmarkReviewTypeAuto;
    case 'gate':
      return l10n.benchmarkReviewTypeGate;
    default:
      return studioUnknownCodeLabel(l10n, type);
  }
}

String studioBenchmarkReviewStatusLabel(AppLocalizations l10n, String status) {
  switch (status.trim().toLowerCase()) {
    case 'pending':
      return l10n.benchmarkReviewStatusPending;
    case 'approved':
      return l10n.benchmarkReviewStatusApproved;
    case 'rejected':
      return l10n.benchmarkReviewStatusRejected;
    case 'skipped':
      return l10n.benchmarkReviewStatusSkipped;
    default:
      return studioUnknownCodeLabel(l10n, status);
  }
}

String studioBenchmarkSampleTierLabel(AppLocalizations l10n, String tier) {
  switch (tier.trim().toLowerCase()) {
    case 'smoke':
      return l10n.benchmarkSampleTierSmoke;
    case 'regression':
      return l10n.benchmarkSampleTierRegression;
    case 'full':
      return l10n.benchmarkSampleTierFull;
    default:
      return studioUnknownCodeLabel(l10n, tier);
  }
}

String studioBenchmarkGateDecisionLabel(AppLocalizations l10n, String decision) {
  switch (decision.trim().toUpperCase()) {
    case 'PASS':
      return l10n.benchmarkGateDecisionPass;
    case 'FAIL':
      return l10n.benchmarkGateDecisionFail;
    default:
      return studioUnknownCodeLabel(l10n, decision);
  }
}

String studioModelPricingTypeLabel(AppLocalizations l10n, String type) {
  switch (type.trim().toLowerCase()) {
    case 'all':
      return l10n.studioModelPricingFilterAll;
    case 'text':
      return l10n.studioModelPricingTypeText;
    case 'image':
      return l10n.studioModelPricingTypeImage;
    case 'video':
      return l10n.studioModelPricingTypeVideo;
    default:
      return studioUnknownCodeLabel(l10n, type);
  }
}

String studioPlatformHealthValueLabel(AppLocalizations l10n, String value) {
  switch (value.trim().toLowerCase()) {
    case 'ok':
      return l10n.platformStatusHealthOk;
    case '-':
    case '':
      return l10n.platformStatusHealthUnknown;
    case 'healthy':
      return l10n.platformStatusHealthy;
    default:
      return studioUnknownCodeLabel(l10n, value);
  }
}

String studioApiKeysLastUsedLabel(AppLocalizations l10n, String raw) {
  if (raw.trim().isEmpty || raw == 'unknown') {
    return l10n.apiKeysLastUsedUnknown;
  }
  return raw;
}

String studioBillingAuditQueryFieldLabel(AppLocalizations l10n, String field) {
  switch (field.trim()) {
    case 'event_type':
      return l10n.billingAuditEventTypeLabel;
    case 'provider_event_id':
      return l10n.billingAuditProviderEventIdLabel;
    case 'provider_event_id_prefix':
      return l10n.billingAuditProviderEventIdPrefixLabel;
    case 'raw_event_id':
      return l10n.billingAuditRawEventIdLabel;
    case 'raw_event_id_prefix':
      return l10n.billingAuditRawEventIdPrefixLabel;
    case 'event_created_from':
      return l10n.billingAuditEventCreatedFromLabel;
    case 'event_created_to':
      return l10n.billingAuditEventCreatedToLabel;
    case 'created_from':
      return l10n.billingAuditCreatedFromLabel;
    case 'created_to':
      return l10n.billingAuditCreatedToLabel;
    default:
      return studioUnknownCodeLabel(l10n, field);
  }
}

String studioBillingProviderValueLabel(
  AppLocalizations l10n,
  String provider,
) {
  switch (provider.trim().toLowerCase()) {
    case '':
      return l10n.billingAuditAll;
    case 'stripe':
      return l10n.billingAuditProviderStripe;
    case 'alipay':
      return l10n.billingAuditProviderAlipay;
    case 'paddle':
      return l10n.billingAuditProviderPaddle;
    default:
      return studioUnknownCodeLabel(l10n, provider);
  }
}

String studioBillingSortValueLabel(AppLocalizations l10n, String sort) {
  switch (sort.trim()) {
    case 'id_desc':
      return l10n.billingAuditSortNewest;
    case 'id_asc':
      return l10n.billingAuditSortOldest;
    default:
      return studioUnknownCodeLabel(l10n, sort);
  }
}

String studioBillingInformationalValueLabel(
  AppLocalizations l10n,
  bool? informationalOnly,
) {
  if (informationalOnly == null) {
    return l10n.billingAuditAll;
  }
  return informationalOnly
      ? l10n.billingAuditOnlyInformational
      : l10n.billingAuditOnlyStateful;
}

String studioQualityDimensionLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'visual_consistency':
      return l10n.qualityReviewsDimensionVisualConsistency;
    case 'narrative_coherence':
      return l10n.qualityReviewsDimensionNarrativeCoherence;
    case 'lip_sync':
      return l10n.qualityReviewsDimensionLipSync;
    case 'pacing':
      return l10n.qualityReviewsDimensionPacing;
    case 'character_consistency':
      return l10n.qualityReviewsDimensionCharacterConsistency;
    case 'dialogue_naturalness':
      return l10n.qualityReviewsDimensionDialogueNaturalness;
    case 'faithfulness':
      return l10n.qualityReviewsDimensionFaithfulness;
    default:
      return studioUnknownCodeLabel(l10n, key);
  }
}
