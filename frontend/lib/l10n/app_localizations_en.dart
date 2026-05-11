// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenFlow';

  @override
  String get localeSectionTitle => 'Display language';

  @override
  String get localeSystem => 'System default';

  @override
  String get localeEnglish => 'English';

  @override
  String get localeChinese => 'Simplified Chinese';

  @override
  String get workspaceModeTitle => 'Workspace mode';

  @override
  String get workspaceModeProduct => 'Product workspace';

  @override
  String get workspaceModeDebug => 'Ops and debug';

  @override
  String get workspaceModeDescriptionProduct =>
      'Focused on user workflows: projects, agent workspaces, tasks, and quality.';

  @override
  String get workspaceModeDescriptionDebug =>
      'Focused on ops probes: Harness tooling, WebSocket diagnostics, and system checks.';

  @override
  String errorLine(String detail) {
    return 'Error: $detail';
  }

  @override
  String get workspaceContextLoading => 'Loading workspace…';

  @override
  String get workspaceContextNoWorkspace => 'No workspace';

  @override
  String get workspaceContextNoProject => 'No project selected';

  @override
  String get workspaceBillingTitle => 'Workspace billing';

  @override
  String get workspaceBillingUnlimited => 'Unlimited';

  @override
  String get workspaceBillingUnknownTier => 'unknown';

  @override
  String workspaceBillingPlan(String tier) {
    return 'Plan: $tier';
  }

  @override
  String workspaceBillingDailyQuota(String quota) {
    return 'Daily quota: $quota';
  }

  @override
  String workspaceBillingPercentUsed(String percent) {
    return '$percent% used';
  }

  @override
  String get notificationsCenterTitle => 'Notifications';

  @override
  String get notificationsCenterSubtitle =>
      'Aggregates job completion, workspace invites, skill changes, and read state.';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsRiskyPrefsTooltip =>
      'Local client preferences (for example \"don\'t ask again\" on short-video risky actions).';

  @override
  String notificationsFilterUnread(int count) {
    return 'Unread $count';
  }

  @override
  String get notificationsTypeFilterLabel => 'Type';

  @override
  String get notificationsTypeAll => 'All';

  @override
  String get notificationsTypeJob => 'Jobs';

  @override
  String get notificationsTypeWorkspace => 'Team';

  @override
  String get notificationsTypeSkill => 'Skills';

  @override
  String get notificationsTypeCompliance => 'Compliance';

  @override
  String get notificationsSearchLabel => 'Search title / body / file / job';

  @override
  String get notificationsRefresh => 'Refresh';

  @override
  String get notificationsLoadMore => 'Load more';

  @override
  String get notificationsEmptyFiltered =>
      'No notifications match the current filters.';

  @override
  String get notificationsUnreadBadge => 'Unread';

  @override
  String get notificationsMarkRead => 'Mark read';

  @override
  String get notificationsOpen => 'Open';

  @override
  String get notificationsRecordJobSucceeded => 'Job completed';

  @override
  String get notificationsRecordJobFailed => 'Job failed';

  @override
  String get notificationsRecordJobCancelled => 'Job cancelled';

  @override
  String get notificationsRecordWorkspaceInviteCreated => 'Invite created';

  @override
  String get notificationsRecordWorkspaceInviteResent => 'Invite resent';

  @override
  String get notificationsRecordWorkspaceInviteRevoked => 'Invite revoked';

  @override
  String get notificationsRecordWorkspaceInviteAccepted => 'Invite accepted';

  @override
  String get notificationsRecordSkillChange => 'Skill change';

  @override
  String get notificationsRecordContentComplianceAlert =>
      'Content compliance alert';

  @override
  String get notificationsRecordContentComplianceCleared =>
      'Content compliance cleared';

  @override
  String get notificationsComplianceClearedThrottleTitle =>
      'Compliance cleared throttle (minutes)';

  @override
  String get notificationsComplianceMinutesHint => '1–1440';

  @override
  String get notificationsComplianceSavePolicy => 'Save policy';

  @override
  String get notificationsComplianceSaveAsTemplate => 'Save as template';

  @override
  String get notificationsComplianceSaveToWorkspaceShared =>
      'Save to workspace shared';

  @override
  String get notificationsComplianceExportTemplatesJson =>
      'Export templates JSON';

  @override
  String get notificationsComplianceImportTemplatesJson =>
      'Import templates JSON';

  @override
  String get notificationsComplianceClearedHelpShort =>
      'At most one cleared per stage within the window to reduce noise.';

  @override
  String get notificationsComplianceCustomTemplatesOnly =>
      'Custom templates only';

  @override
  String notificationsComplianceTemplateChip(String name) {
    return 'Template: $name';
  }

  @override
  String notificationsComplianceSharedChip(String name) {
    return 'Shared: $name';
  }

  @override
  String get notificationsComplianceTooltipMoveUp => 'Move up';

  @override
  String get notificationsComplianceTooltipMoveDown => 'Move down';

  @override
  String get notificationsComplianceTooltipEditTemplate => 'Edit template';

  @override
  String get notificationsComplianceTooltipDeleteTemplate => 'Delete template';

  @override
  String get notificationsComplianceWorkspaceSharedHeader =>
      'Workspace shared templates';

  @override
  String get notificationsComplianceTooltipEditSharedTemplate =>
      'Edit shared template';

  @override
  String get notificationsComplianceTooltipDeleteSharedTemplate =>
      'Delete shared template';

  @override
  String notificationsComplianceStageOverrideLabel(String stage) {
    return '$stage override';
  }

  @override
  String get notificationsComplianceStageOverrideHint =>
      'Empty = follow global';

  @override
  String get notificationsComplianceSharedAuditTitle => 'Shared template audit';

  @override
  String get notificationsComplianceFilterTemplateId => 'Template ID filter';

  @override
  String get notificationsComplianceFilterAction => 'Action filter';

  @override
  String get notificationsComplianceFilterStartIso => 'Start time (ISO 8601)';

  @override
  String get notificationsComplianceFilterEndIso => 'End time (ISO 8601)';

  @override
  String get notificationsComplianceApplyFilters => 'Apply filters';

  @override
  String get notificationsComplianceDownloadAuditJson => 'Download audit JSON';

  @override
  String get notificationsComplianceDownloadAuditCsv => 'Download audit CSV';

  @override
  String get notificationsComplianceAsyncJson => 'Async JSON';

  @override
  String get notificationsComplianceAsyncCsv => 'Async CSV';

  @override
  String get notificationsComplianceCloseTooltip => 'Dismiss';

  @override
  String get notificationsComplianceExportHistoryTitle => 'Export history';

  @override
  String get notificationsComplianceExportFormatFilter =>
      'Export format filter';

  @override
  String get notificationsComplianceExportedStartIso => 'Exported from (ISO)';

  @override
  String get notificationsComplianceExportedEndIso => 'Exported to (ISO)';

  @override
  String get notificationsComplianceFilterExports => 'Filter export history';

  @override
  String get notificationsComplianceReuseExportFiltersTooltip =>
      'Reuse this export’s filters above';

  @override
  String get notificationsComplianceMoreExportRecords => 'More export records';

  @override
  String get notificationsComplianceLoadMoreAudit => 'Load more audit';

  @override
  String get notificationsComplianceThrottleInvalidGlobal =>
      'Enter an integer from 1 to 1440 minutes.';

  @override
  String notificationsComplianceThrottleStageInvalid(String stage) {
    return '$stage: enter 1–1440 minutes, or leave blank.';
  }

  @override
  String get notificationsDialogSaveClearedTemplateTitle =>
      'Save cleared template';

  @override
  String get notificationsDialogSaveWorkspaceSharedTemplateTitle =>
      'Save workspace shared template';

  @override
  String notificationsDialogEditTemplateTitle(String id) {
    return 'Edit template: $id';
  }

  @override
  String notificationsDialogDeleteTemplateTitle(String label) {
    return 'Delete template: $label';
  }

  @override
  String get notificationsDialogDeleteTemplateBody =>
      'This cannot be undone. Continue?';

  @override
  String notificationsDialogDeleteSharedTemplateTitle(String label) {
    return 'Delete shared template: $label';
  }

  @override
  String get notificationsDialogDeleteSharedTemplateBody =>
      'This affects all members in the workspace. Continue?';

  @override
  String notificationsDialogEditSharedTemplateTitle(String id) {
    return 'Edit shared template: $id';
  }

  @override
  String get notificationsFieldTemplateIdAscii => 'Template ID (ASCII)';

  @override
  String get notificationsFieldTemplateName => 'Template name';

  @override
  String get notificationsFieldTemplateDescription => 'Description';

  @override
  String get notificationsFieldImportMode => 'Import mode';

  @override
  String get notificationsFieldPasteTemplatesJson => 'Paste templates JSON';

  @override
  String get notificationsImportModeReplace => 'replace (overwrite)';

  @override
  String get notificationsImportModeMerge => 'merge';

  @override
  String get notificationsActionCancel => 'Cancel';

  @override
  String get notificationsActionSave => 'Save';

  @override
  String get notificationsActionDelete => 'Delete';

  @override
  String get notificationsActionImport => 'Import';

  @override
  String get notificationsSnackTemplateIdAndNameRequired =>
      'Template ID and name cannot be empty.';

  @override
  String get notificationsSnackExportFiltersReused =>
      'Reused that export’s filters and refreshed the audit list.';

  @override
  String notificationsSnackDownloadedByHistory(String path) {
    return 'Downloaded with history filters: $path';
  }

  @override
  String notificationsSnackExportQueued(int taskId) {
    return 'Background export queued (task #$taskId). History refreshes when it completes.';
  }

  @override
  String notificationsSnackSharedAuditJsonSaved(String path) {
    return 'Shared audit JSON saved: $path';
  }

  @override
  String notificationsSnackSharedAuditCsvSaved(String path) {
    return 'Shared audit CSV saved: $path';
  }

  @override
  String get notificationsSnackTemplatesJsonCopied =>
      'Templates JSON copied to clipboard.';

  @override
  String get notificationsDialogImportTemplatesJsonTitle =>
      'Import templates JSON';

  @override
  String notificationsSnackImportDone(int count) {
    return 'Import finished: $count templates.';
  }

  @override
  String get notificationsUnknownTime => 'Unknown time';

  @override
  String notificationsPrefsAuditUpdatedLine(
    String time,
    String by,
    String source,
  ) {
    return 'Policy last updated: $time · $by · $source';
  }

  @override
  String get notificationsAuditActionUpsert => 'Upsert';

  @override
  String get notificationsAuditActionDelete => 'Delete';

  @override
  String get notificationsAuditAllActions => 'All actions';

  @override
  String get notificationsAuditAllTemplates => 'All templates';

  @override
  String get notificationsExportRecordLeadIn => 'Export record:';

  @override
  String get notificationsExportDownloadAsyncArtifact =>
      'Download the async export artifact';

  @override
  String get notificationsExportRedownloadSync =>
      'Download again with the same filters (sync)';

  @override
  String get notificationsExportDeliveryAsync => ' · Async';

  @override
  String notificationsExportDeliveryAsyncWithJob(String jobId) {
    return ' · Async (job: $jobId)';
  }

  @override
  String get notificationsExportDeliverySync => ' · Sync';

  @override
  String get riskyPrefsMenuDefaultTooltip => 'Local client preferences';

  @override
  String get riskyPrefsTooltipSameAsMainPanelHeaders =>
      'Local client preferences (same ⋯ menu as beside each main panel title)';

  @override
  String get riskyPrefsMenuViewSilencesTitle =>
      'View silenced high-risk confirmations';

  @override
  String get riskyPrefsMenuViewSilencesSubtitle =>
      'Read-only list; does not change settings';

  @override
  String get riskyPrefsMenuResetTitle =>
      'Restore high-risk confirmation prompts';

  @override
  String get riskyPrefsMenuResetSubtitle =>
      'This device only; unrelated to server settings';

  @override
  String get riskyPrefsSummaryDialogTitle => 'Silenced high-risk confirmations';

  @override
  String get riskyPrefsSummaryEmptyBody =>
      'No \"don\'t ask again\" choices are saved on this device.';

  @override
  String get riskyPrefsSummaryNonEmptyIntro =>
      'These actions will skip confirmation dialogs on this device (you can clear them anytime with \"Restore high-risk confirmation prompts\"):';

  @override
  String get riskyPrefsSummaryClose => 'Close';

  @override
  String get riskyPrefsResetDialogTitle => 'Restore confirmation dialogs';

  @override
  String get riskyPrefsResetBody =>
      'This clears local \"don\'t ask again\" choices. Deletes, archive/publish, cancel export, and similar actions will show confirmations again (this app on this device only).';

  @override
  String get riskyPrefsResetNoSavedLabel =>
      'No saved \"don\'t ask again\" entries. You can still clear any leftover keys.';

  @override
  String get riskyPrefsResetHasItemsLabel => 'Currently silenced:';

  @override
  String get riskyPrefsResetCancel => 'Cancel';

  @override
  String get riskyPrefsResetConfirm => 'Clear and restore';

  @override
  String get riskyPrefsResetSuccessSnack =>
      'Cleared local \"don\'t ask again\" preferences for high-risk actions; confirmations will show again.';

  @override
  String get riskyPrefsLabelDeleteVersion => 'Delete finished version';

  @override
  String get riskyPrefsLabelBatchDisable => 'Batch disable shots';

  @override
  String get riskyPrefsLabelRestoreDraft => 'Restore draft overwrite';

  @override
  String get riskyPrefsLabelCancelExport => 'Cancel finished export';

  @override
  String get riskyPrefsLabelBatchArchivePublish =>
      'Batch archive/publish drafts';

  @override
  String get platformConfigSectionTitle => 'Platform configuration';

  @override
  String get platformConfigSectionSubtitle =>
      'Manage product shell feature switches and ops-facing visibility. effective merges as defaults <- plan override <- current workspace override <- user override.';

  @override
  String get platformConfigLocalPrefsDescription =>
      'These items affect only local storage for this app on this device, not server-side platform settings. To restore confirmations for deletes, archive, export, etc., use the ⋯ menu in the header above.';

  @override
  String get platformConfigButtonRefreshing => 'Refreshing…';

  @override
  String get platformConfigButtonRefresh => 'Reload configuration';

  @override
  String get platformConfigButtonSaving => 'Saving…';

  @override
  String get platformConfigButtonSaveUser => 'Save user overrides';

  @override
  String get platformConfigButtonResetUser => 'Reset user overrides';

  @override
  String get platformConfigButtonSaveWorkspace =>
      'Save workspace configuration';

  @override
  String get platformConfigButtonResetWorkspace => 'Reset workspace overrides';

  @override
  String get platformConfigButtonCopyJson => 'Copy JSON';

  @override
  String get platformConfigToggleHelpHubTitle => 'Help Hub';

  @override
  String get platformConfigToggleHelpHubSubtitle =>
      'Show or hide help / documentation entry points';

  @override
  String get platformConfigToggleQualityMainTitle => 'Quality dashboard';

  @override
  String get platformConfigToggleQualityMainSubtitle =>
      'Quality ops board and main summary areas';

  @override
  String get platformConfigToggleQualityRefreshTitle =>
      'Quality refresh controls';

  @override
  String get platformConfigToggleQualityRefreshSubtitle =>
      'Materialized read-model refresh buttons and entry points';

  @override
  String get platformConfigTogglePlatformStatusTitle => 'Platform status';

  @override
  String get platformConfigTogglePlatformStatusSubtitle =>
      'Health / Ready / SLI / Metrics entry points';

  @override
  String get platformConfigToggleWorkspaceActivityTitle => 'Workspace activity';

  @override
  String get platformConfigToggleWorkspaceActivitySubtitle =>
      'Agent workspace activity navigation entry';

  @override
  String get platformConfigToggleBenchmarkTitle => 'Benchmark baseline';

  @override
  String get platformConfigToggleBenchmarkSubtitle =>
      'Benchmark / evaluation product entry points';

  @override
  String get platformConfigToggleJobsTitle => 'Jobs panel';

  @override
  String get platformConfigToggleJobsSubtitle => 'Jobs panel navigation entry';

  @override
  String get platformConfigPlanLayerIntro =>
      'Plan tier is a read-only overlay from server environment config; use it to layer defaults before workspace / user fine-tuning.';

  @override
  String get platformConfigPlanStateActive => 'Status: plan override is active';

  @override
  String get platformConfigPlanStateInactive =>
      'Status: no plan override; inherits defaults';

  @override
  String get platformConfigWorkspaceEnterpriseIntro =>
      'Shared overlay for the current enterprise workspace; applied before personal settings in effective merge.';

  @override
  String get platformConfigWorkspaceViewOnlyIntro =>
      'Shared overlay is shown read-only; only enterprise owner/admin can edit.';

  @override
  String get platformConfigWorkspaceStateWritten =>
      'Status: workspace override is saved';

  @override
  String get platformConfigWorkspaceStateInherit =>
      'Status: inherits defaults, then personal overrides';

  @override
  String get platformConfigWorkspaceNoDraftEnterprise =>
      'No editable shared overlay for this workspace. Switch to an enterprise owner/admin account, or wait for shared overlay to be provisioned.';

  @override
  String get platformConfigWorkspaceNoDraftPersonal =>
      'Personal workspaces do not support a shared workspace-level overlay; only enterprise workspaces do.';

  @override
  String get platformConfigUserOverrideIntro =>
      'Personal overlay is applied last—use it for your own ops view and tool preferences.';

  @override
  String get platformConfigUserStateWritten => 'Status: user override is saved';

  @override
  String get platformConfigUserStateInherit =>
      'Status: inherits workspace / defaults';

  @override
  String get platformConfigSnackUserSaved =>
      'User platform configuration saved.';

  @override
  String get platformConfigSnackUserReset => 'User override cleared.';

  @override
  String get platformConfigSnackWorkspaceSaved =>
      'Workspace platform configuration saved.';

  @override
  String get platformConfigSnackWorkspaceReset => 'Workspace override cleared.';

  @override
  String get platformConfigSnackCopyJsonDone =>
      'Platform configuration JSON copied.';

  @override
  String get platformConfigPleaseSignIn => 'Please sign in first';

  @override
  String get productNavSectionTitle => 'Product navigation';

  @override
  String get productNavShortVideoSpace => 'Short-video Space';

  @override
  String get productNavProjects => 'Projects';

  @override
  String get productNavAccount => 'Account';

  @override
  String get productNavApiKeys => 'API keys';

  @override
  String get productNavNotifications => 'Notifications';

  @override
  String get productNavContentCompliance => 'Compliance';

  @override
  String get productNavPlatformStatus => 'Platform status';

  @override
  String get productNavTeamWorkspaces => 'Team workspaces';

  @override
  String get productNavScriptWorkspace => 'Script workspace';

  @override
  String get productNavProductionWorkspace => 'Production workspace';

  @override
  String get productNavWorkspaceActivity => 'Workspace activity';

  @override
  String get productNavBenchmark => 'Benchmark';

  @override
  String get productNavTasks => 'Task center';

  @override
  String get productNavJobs => 'Jobs';

  @override
  String get productNavQuality => 'Quality';

  @override
  String get productNavPlatformConfig => 'Platform configuration';

  @override
  String get productNavHelp => 'Help';

  @override
  String get productAgentScriptWorkspaceTitle => 'Script workspace';

  @override
  String get productAgentScriptWorkspaceSubtitle =>
      'Script Agent flow: context probes, sub-agent orchestration, and body/plan writeback.';

  @override
  String get productAgentProductionWorkspaceTitle => 'Production workspace';

  @override
  String get productAgentProductionWorkspaceSubtitle =>
      'Production Agent flow: flow data reads, asset/storyboard tools, and safe writeback.';

  @override
  String get productAgentActivityTitle => 'Activity';

  @override
  String get productAgentActivitySubtitle =>
      'Recent WebSocket events, tool receipts, and writeback status in one execution log panel.';

  @override
  String get productPaneDisabledHelpHub =>
      'Help Hub is disabled by platform configuration. Re-enable it under Platform configuration.';

  @override
  String get productPaneDisabledQuality =>
      'The quality dashboard is disabled by platform configuration. Re-enable it under Platform configuration.';

  @override
  String get productPaneDisabledPlatformStatus =>
      'Platform status is disabled by platform configuration. Re-enable it under Platform configuration.';

  @override
  String get productPaneDisabledWorkspaceActivity =>
      'Workspace activity is disabled by platform configuration. Re-enable it under Platform configuration.';

  @override
  String get productPaneDisabledBenchmark =>
      'Benchmark baseline is disabled by platform configuration. Re-enable it under Platform configuration.';

  @override
  String get productPaneDisabledJobs =>
      'The Jobs panel is disabled by platform configuration. Re-enable it under Platform configuration.';

  @override
  String get productComplianceSnackAccountPanel =>
      'Switched to Account panel. For user administration, prefer your internal admin console.';

  @override
  String get productComplianceSnackNotSignedIn =>
      'Not signed in; cannot open the target context.';

  @override
  String productComplianceTeamContext(String detail) {
    return 'Switched to team workspace context: $detail';
  }

  @override
  String get productComplianceNoProjectContext =>
      'This report has no project context to open.';

  @override
  String productComplianceOpenTargetFailed(String detail) {
    return 'Failed to open target: $detail';
  }

  @override
  String get platformConfigPlanOverrideTitle => 'Plan override';

  @override
  String get platformConfigWorkspaceOverrideTitle => 'Workspace override';

  @override
  String get platformConfigUserOverrideTitle => 'User override';

  @override
  String get helpHubDocsTitle => 'Help / docs';

  @override
  String get helpHubLocalRiskLine =>
      'On this device: to restore high-risk confirmations (delete, archive, cancel export), use the ⋯ menu in the header (unrelated to server settings).';

  @override
  String get helpHubRefresh => 'Refresh';

  @override
  String get helpHubManageEntries => 'Manage links';

  @override
  String get helpHubLoading => 'Loading…';

  @override
  String get helpHubSearchLabel => 'Search help links (title / id / url)';

  @override
  String get helpHubNoEffectiveLinks =>
      'No help links are available. Check settings/help/hub configuration.';

  @override
  String get helpHubSearchEmpty =>
      'No links match your search. Try different keywords.';

  @override
  String get helpHubCopyLinkTooltip => 'Copy link';

  @override
  String get helpHubCopied => 'Copied.';

  @override
  String get helpHubCopyTitleUrlTooltip => 'Copy title + URL';

  @override
  String get helpHubCopiedHandoff => 'Copied document handoff.';

  @override
  String get helpHubManageDialogTitle =>
      'Manage help links (personal / workspace)';

  @override
  String get helpHubManagePrecedence =>
      'Effective order: personal override > workspace override > environment defaults.';

  @override
  String get helpHubManageWorkspaceLocked =>
      ' (This workspace cannot configure workspace-level links; personal override only.)';

  @override
  String get helpHubTabPersonal => 'Personal override';

  @override
  String get helpHubTabWorkspace => 'Workspace override';

  @override
  String get helpHubFieldId => 'id (dedupe / override key)';

  @override
  String get helpHubFieldTitle => 'Title';

  @override
  String get helpHubFieldUrl => 'URL';

  @override
  String get helpHubHintId => 'runbook-quality';

  @override
  String get helpHubHintUrl => 'https://docs.example.com/runbook';

  @override
  String get helpHubAdd => 'Add';

  @override
  String get helpHubValidationRequired => 'id, title, and url are required.';

  @override
  String get helpHubNoCustomInScope => 'No custom links in this scope.';

  @override
  String get helpHubDialogClose => 'Close';

  @override
  String get helpHubSave => 'Save';

  @override
  String get helpHubSaving => 'Saving…';

  @override
  String get helpHubCategoryRunbook => 'Runbook';

  @override
  String get helpHubCategoryBillingWebhook => 'Billing / Webhook';

  @override
  String get helpHubCategoryWorkspace => 'Workspace';

  @override
  String get helpHubCategoryQuality => 'Quality';

  @override
  String get helpHubCategoryStatus => 'Status';

  @override
  String get helpHubCategoryGeneral => 'General';

  @override
  String helpHubSummary(int total, int filtered, String extra) {
    return 'Total $total · Filtered $filtered$extra';
  }

  @override
  String helpHubSummaryCategoryCount(String name, int count) {
    return '$name:$count';
  }

  @override
  String get opsWhSectionTitle => 'Outbound webhooks';

  @override
  String get opsWhErrorUrlRequired => 'URL is required.';

  @override
  String get opsWhErrorWorkspaceId =>
      'workspaceId must be a valid UUID or empty.';

  @override
  String get opsWhErrorWorkspaceIdPatch =>
      'workspaceId must be a valid UUID, or clear the field to use global scope.';

  @override
  String get opsWhSnackCreated => 'Created; secret copied to clipboard.';

  @override
  String get opsWhSnackEventsUpdated => 'Subscription events updated.';

  @override
  String opsWhSnackDeliverOk(String status) {
    return 'Delivered (HTTP $status)';
  }

  @override
  String opsWhSnackDeliverFail(String detail) {
    return 'Delivery failed: $detail';
  }

  @override
  String get opsWhSnackScopeGlobal =>
      'Scope set to global (no workspace filter).';

  @override
  String get opsWhSnackScopeWorkspaceUpdated => 'workspaceId updated.';

  @override
  String get opsWhDeleteTitle => 'Delete webhook';

  @override
  String opsWhDeleteBody(String id) {
    return 'You are about to delete webhook: $id\nThis removes the destination URL.';
  }

  @override
  String get opsWhDeleteConfirm => 'Delete';

  @override
  String get opsWhDeleteConfirmButton => 'Confirm delete';

  @override
  String opsWhLastTestOk(String status) {
    return 'Last test: success (HTTP $status)';
  }

  @override
  String opsWhLastTestFail(String status, String error) {
    return 'Last test: failed (HTTP $status) $error';
  }

  @override
  String opsWhInventoryLine(
    int total,
    int filtered,
    int ok,
    int fail,
    String latestPart,
  ) {
    return 'Total $total · Filtered $filtered · Session tests OK $ok · Failed $fail$latestPart';
  }

  @override
  String opsWhInventoryLatestPart(String id) {
    return ' · Latest: $id';
  }

  @override
  String get opsWhEmptyNone =>
      'No outbound webhooks yet. Create one above to test delivery and manage lifecycle.';

  @override
  String get opsWhEmptyFiltered =>
      'No webhooks match your search. Adjust URL / id / createdAt keywords.';

  @override
  String get opsWhUrlLabel => 'Webhook URL';

  @override
  String get opsWhUrlHint => 'https://example.com/webhook';

  @override
  String get opsWhSecretLabel => 'Secret (optional; server generates if empty)';

  @override
  String get opsWhWorkspaceIdLabel => 'workspaceId (optional)';

  @override
  String get opsWhWorkspaceIdHint =>
      'Only deliver events for this workspace; must be a UUID';

  @override
  String get opsWhSubscribeHint =>
      'Subscribed events (select all = default; deselect types you do not need)';

  @override
  String get opsWhTestEventTypeLabel => 'Test eventType';

  @override
  String get opsWhTestEventTypeHint => 'test.ping';

  @override
  String get opsWhLatestCreatedTitle => 'Latest created webhook credentials';

  @override
  String get opsWhCopyId => 'Copy ID';

  @override
  String get opsWhCopyUrl => 'Copy URL';

  @override
  String get opsWhCopySecret => 'Copy secret';

  @override
  String get opsWhCreate => 'Create';

  @override
  String get opsWhCreating => 'Requesting…';

  @override
  String get opsWhRefreshList => 'Refresh list';

  @override
  String get opsWhSearchLabel => 'Search webhooks (URL / id / createdAt)';

  @override
  String get opsWhRecentActivity => 'Recent activity';

  @override
  String get opsWhCopyActivityTooltip => 'Copy record';

  @override
  String get opsWhActivityRecordSuffix => ' webhook activity';

  @override
  String get opsWhChipLatestCreated => 'Latest created';

  @override
  String get opsWhChipDisabled => 'Disabled';

  @override
  String get opsWhSubscribeHeading => 'Subscribed events';

  @override
  String get opsWhScopeHeading => 'Scope workspaceId (empty save = global)';

  @override
  String get opsWhScopeFieldHint => 'UUID; empty means no workspace filter';

  @override
  String get opsWhSaveScope => 'Save scope';

  @override
  String get opsWhSavingScope => 'Saving…';

  @override
  String get opsWhClearInput => 'Clear input';

  @override
  String get opsWhRecentDeliveries => 'Recent deliveries';

  @override
  String get opsWhTooltipCopyUrl => 'Copy URL';

  @override
  String get opsWhUrlCopiedSnack => 'Webhook URL copied.';

  @override
  String get opsWhTestDeliver => 'Test delivery';

  @override
  String get opsWhBusy => 'Working…';

  @override
  String get opsWhDeliveryLog => 'Delivery log';

  @override
  String get opsWhLoading => 'Loading…';

  @override
  String get opsWhDelete => 'Delete';

  @override
  String get billingAuditTitle => 'Billing webhook audit';

  @override
  String get billingAuditProviderLabel => 'Provider';

  @override
  String get billingAuditAll => 'All';

  @override
  String get billingAuditSortLabel => 'Sort';

  @override
  String get billingAuditSortNewest => 'Newest first';

  @override
  String get billingAuditSortOldest => 'Oldest first';

  @override
  String get billingAuditOnlyInformational => 'Informational only';

  @override
  String get billingAuditOnlyStateful => 'Stateful only';

  @override
  String get billingAuditEventTypeHint =>
      'e.g. invoice.paid / subscription.expired';

  @override
  String get billingAuditProviderEventIdHint => 'e.g. stripe:evt_123';

  @override
  String get billingAuditRawEventIdHint => 'e.g. evt_123';

  @override
  String get billingAuditProviderPrefixHint => 'e.g. stripe:evt_';

  @override
  String get billingAuditRawPrefixHint => 'e.g. evt_';

  @override
  String get billingAuditEventCreatedFromHint => '2026-04-01T00:00:00Z';

  @override
  String get billingAuditEventCreatedToHint => '2026-04-30T23:59:59Z';

  @override
  String get billingAuditQuery => 'Query';

  @override
  String get billingAuditQuerying => 'Reading…';

  @override
  String get billingAuditResetRefresh => 'Reset and refresh';

  @override
  String get billingAuditCopyCsv => 'Copy CSV';

  @override
  String get billingAuditCsvCopiedSnack => 'Current billing audit CSV copied.';

  @override
  String get billingAuditCopyQuerySummary => 'Copy query summary';

  @override
  String get billingAuditCopyQueryUrl => 'Copy query URL';

  @override
  String get billingAuditQueryUrlCopiedSnack => 'Current query URL copied.';

  @override
  String get billingAuditCopyFullCsv => 'Copy full CSV';

  @override
  String get billingAuditExporting => 'Exporting…';

  @override
  String get billingAuditLoading => 'Loading billing audit…';

  @override
  String billingAuditPageStats(int total, int loaded, String hasMore) {
    return 'total=$total · loaded=$loaded · has_more=$hasMore';
  }

  @override
  String get billingEmptyQuery =>
      'No billing webhook events match this query. Adjust provider, event id, time window, or informational filters.';

  @override
  String get billingAuditQuerySummaryCopied => 'Query summary copied.';

  @override
  String get billingAuditSnapshotCopied => 'Audit snapshot copied.';

  @override
  String billingCopiedWithLabel(String label) {
    return 'Copied $label.';
  }

  @override
  String billingAuditFullCsvCopied(int count) {
    return 'Full billing audit CSV copied ($count rows).';
  }

  @override
  String billingSnapLoaded(int count) {
    return 'Loaded: $count';
  }

  @override
  String billingSnapInformational(int count) {
    return 'Informational: $count';
  }

  @override
  String billingSnapStateful(int count) {
    return 'Stateful: $count';
  }

  @override
  String billingSnapProviders(String list) {
    return 'Providers: $list';
  }

  @override
  String billingSnapEventTypes(String list) {
    return 'Event types: $list';
  }

  @override
  String get billingAuditCurrentLoadTitle => 'Current load summary';

  @override
  String get billingAuditCopySnapshot => 'Copy audit snapshot';

  @override
  String get billingAuditCopyProviderEventId => 'Copy provider_event_id';

  @override
  String get billingAuditCopyRawEventId => 'Copy raw_event_id';

  @override
  String billingAuditFilterByProvider(String provider) {
    return 'Filter by $provider';
  }

  @override
  String billingAuditFilterByEventType(String eventType) {
    return 'Filter by $eventType';
  }

  @override
  String get billingAuditOnlyThisEvent => 'Only this event';

  @override
  String get billingAuditLoadMore => 'Load more';

  @override
  String billingMetaProvider(String value) {
    return 'provider=$value';
  }

  @override
  String billingMetaType(String value) {
    return 'type=$value';
  }

  @override
  String billingMetaCreated(String value) {
    return 'created=$value';
  }

  @override
  String billingMetaEventCreated(String value) {
    return 'event_created=$value';
  }

  @override
  String get billingMetaInformational => 'informational';

  @override
  String get billingMetaStateful => 'stateful';

  @override
  String billingRowRawEventId(String value) {
    return 'raw_event_id=$value';
  }

  @override
  String billingRowId(String value) {
    return 'id=$value';
  }

  @override
  String billingChipCount(String label, int count) {
    return '$label $count';
  }

  @override
  String get projectsListTitle => 'Projects';

  @override
  String get projectsListSubtitle =>
      'Load projects, summaries, art styles, and creative manuals, then open a project to keep editing.';

  @override
  String get projectsSnackProjectCreated => 'Project created';

  @override
  String get projectsSnackSignInArtStyles =>
      'Please sign in to load art styles.';

  @override
  String get projectsSnackSignInCreativeManuals =>
      'Please sign in to load creative manuals.';

  @override
  String get projectsSnackSignInAgentMemory =>
      'Please sign in to load Agent memory.';

  @override
  String get projectsEnterpriseEmptyTitle =>
      'No projects in this team workspace yet';

  @override
  String get projectsEnterpriseEmptyUnnamedFallback =>
      'This enterprise workspace';

  @override
  String projectsEnterpriseEmptyBody(String displayName) {
    return '$displayName has no projects yet. Create an empty project as a team starting point, then open Team workspaces to invite members and assign collaboration scope.';
  }

  @override
  String get projectsCreateFirstEmpty => 'Create an empty project';

  @override
  String get projectsOpenTeamWorkspaces => 'Open team workspaces';

  @override
  String get projectsLoadProjectList => 'Load projects';

  @override
  String get projectsViewSummary => 'View project summary';

  @override
  String get projectsLoadArtStyles => 'Load art styles';

  @override
  String get projectsOpenArtStylesWorkbench => 'Open art styles workbench';

  @override
  String get projectsOpenCreativeManualsWorkbench =>
      'Open creative manuals workbench';

  @override
  String get projectsOpenAgentMemoryWorkbench => 'Open Agent memory workbench';

  @override
  String get projectsCreateEmptyProject => 'New empty project';

  @override
  String get projectsLoading => 'Loading…';

  @override
  String get projectsCreating => 'Creating…';

  @override
  String get projectsRequesting => 'Requesting…';

  @override
  String get projectsCompatibilityTitle => 'Compatibility check';

  @override
  String get projectsCompatibilitySubtitle =>
      'Keeps the first-project Agent memory probe as a regression entry point (collapsed by default).';

  @override
  String get projectsCompatibilityProbeMemory => 'Probe first project memory';

  @override
  String get projectsSummaryLinePrefix => 'Project summary: ';

  @override
  String get projectsArtStylesLinePrefix => 'Art styles: ';

  @override
  String projectsArtStyleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count art styles',
      one: '1 art style',
    );
    return '$_temp0';
  }

  @override
  String get projectsArtStylesManage => 'Manage';

  @override
  String projectsProjectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projects',
      one: '1 project',
    );
    return '$_temp0';
  }

  @override
  String projectsUnnamedProject(int numericId) {
    return 'Project #$numericId';
  }

  @override
  String get projectsAgentMemoryPrefix => 'Project memory: ';

  @override
  String get projectsAccessModeRestricted => 'Explicit ACL';

  @override
  String get projectsAccessModeInherited => 'Inherited workspace';

  @override
  String get projectsRoleWorkspaceOwner => 'workspace owner';

  @override
  String get projectsRoleWorkspaceAdmin => 'workspace admin';

  @override
  String get projectsRoleProjectOwner => 'project owner';

  @override
  String get projectsRoleEditor => 'editor';

  @override
  String get projectsRoleViewer => 'viewer';

  @override
  String get projectsRoleMember => 'member';

  @override
  String get projectsDialogCreateTitle => 'New project';

  @override
  String get projectsDialogFieldName => 'Name';

  @override
  String get projectsDialogFieldIntro => 'Introduction';

  @override
  String get projectsDialogSectionBrief => 'Project brief';

  @override
  String get projectsDialogFieldPremise => 'Premise';

  @override
  String get projectsDialogFieldTargetAudience => 'Target audience';

  @override
  String get projectsDialogFieldEmotionalTone => 'Emotional tone';

  @override
  String get projectsDialogFieldCoreHook => 'Core hook';

  @override
  String get projectsDialogFieldVisualDirection => 'Visual direction';

  @override
  String get projectsDialogSectionBrand => 'Brand bible';

  @override
  String get projectsDialogFieldBrandName => 'Brand name';

  @override
  String get projectsDialogFieldBrandPromise => 'Brand promise';

  @override
  String get projectsDialogFieldVisualMotifsMultiline =>
      'Visual motifs (one per line)';

  @override
  String get projectsDialogFieldForbiddenElementsMultiline =>
      'Forbidden elements (one per line)';

  @override
  String get projectsDialogFieldContinuityRulesMultiline =>
      'Continuity rules (one per line)';

  @override
  String get projectsDialogCreateButton => 'Create';
}
