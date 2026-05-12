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
  String get shortVideoSpaceCannotSaveNoProject =>
      'Cannot save: no project selected or not logged in';

  @override
  String get shortVideoSpaceSavingInProgress =>
      'Saving in progress, please wait...';

  @override
  String get shortVideoSpaceSelectAllAvailable =>
      'Select all shortcut (Ctrl+A / Cmd+A) is available in the shot operation panel';

  @override
  String get shortVideoSpaceSearchFocused => 'Search box focused';

  @override
  String get shortVideoSpaceSearchNotAvailable =>
      'Search box not available (please open shot operation panel first)';

  @override
  String get shortVideoSpaceSaveProjectConfig => 'Save project configuration';

  @override
  String get shortVideoSpaceSelectAllShots =>
      'Select all shots (in batch operation mode)';

  @override
  String get shortVideoSpaceFocusSearch => 'Focus search box';

  @override
  String get shortVideoSpaceUndoOperation => 'Undo last operation';

  @override
  String get shortVideoSpaceRedoOperation => 'Redo last operation';

  @override
  String get shortVideoSpaceFileOperations => 'File Operations';

  @override
  String get shortVideoSpaceSelectionOperations => 'Selection Operations';

  @override
  String get shortVideoSpaceNavigation => 'Navigation';

  @override
  String get shortVideoSpaceEditOperations => 'Edit Operations';

  @override
  String get shortVideoSpaceKeyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get shortVideoSpaceClose => 'Close';

  @override
  String get shortVideoSpaceCurrentProjectOverview =>
      'Current Project Overview';

  @override
  String get shortVideoSpaceRecentBadCaseTrends => 'Recent Bad Case Trends';

  @override
  String get shortVideoSpaceRecentTaskFlow => 'Recent Task Flow';

  @override
  String get shortVideoSpaceAssetsOverview => 'Assets Overview';

  @override
  String get shortVideoSpaceAssemblySnapshot => 'Assembly Snapshot';

  @override
  String get shortVideoSpaceQualityReview =>
      'Quality Review (Quality Acceptance)';

  @override
  String get shortVideoSpaceMultiTrackExportDecision =>
      'Limited Multi-track Export Decision (K5)';

  @override
  String get shortVideoSpaceOpenProductionWorkspace =>
      'Open Production Workspace';

  @override
  String get shortVideoSpaceBasicShotOperations => 'Basic Shot Operations';

  @override
  String get shortVideoSpaceAssemblyStyleAdjustment =>
      'Assembly Style Adjustment';

  @override
  String get shortVideoSpaceExportPreCheck => 'Export Pre-check';

  @override
  String get shortVideoSpaceQualityGateBlockingReasons =>
      'Quality Gate Blocking Reasons';

  @override
  String get shortVideoSpaceBlockingItems =>
      'Blocking Items (Selected by Interface Order)';

  @override
  String get shortVideoSpaceWarningItems =>
      'Warning Items (Selected by Interface Order)';

  @override
  String get shortVideoSpaceExporting => 'Exporting...';

  @override
  String get shortVideoSpaceStartExport => 'Start Export';

  @override
  String get shortVideoSpaceExportHistory => 'Export History';

  @override
  String get shortVideoSpacePublishJobs => 'Publish Jobs';

  @override
  String get shortVideoSpaceScheduleCalendar =>
      'Schedule Calendar (counted by local calendar days; click a day to batch write timing)';

  @override
  String get shortVideoSpaceTargetConfiguration =>
      'Short Video Target Configuration';

  @override
  String get shortVideoSpaceConfigurationDescription =>
      'Write the creation mode and aspect ratio directly back to the project, so that subsequent scripts and production processes can continue to work based on the same project configuration.';

  @override
  String get shortVideoSpaceTargetProject => 'Target Project';

  @override
  String get shortVideoSpaceLoading => 'Loading';

  @override
  String get shortVideoSpaceRefreshProjects => 'Refresh Projects';

  @override
  String get shortVideoSpaceRestoreRiskyConfirmation =>
      'Restore High-Risk Confirmation Prompts';

  @override
  String get shortVideoSpacePortrait916 => 'Portrait 9:16';

  @override
  String get shortVideoSpaceLandscape169 => 'Landscape 16:9';

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
  String shortVideoSpaceErrorTimeout(String context) {
    return 'Request timeout$context, please check network connection and retry.';
  }

  @override
  String shortVideoSpaceErrorOperationFailed(String context, String error) {
    return 'Operation failed$context: $error';
  }

  @override
  String shortVideoSpaceErrorConcurrentLimitExceeded(String context) {
    return 'Concurrent workspace audit export limit reached, please wait for existing tasks to complete$context.';
  }

  @override
  String shortVideoSpaceErrorRateLimitWithWait(
    String context,
    String waitText,
  ) {
    return 'Too many requests$context, $waitText.';
  }

  @override
  String shortVideoSpaceErrorNotFound(String context) {
    return 'Record not found$context.';
  }

  @override
  String shortVideoSpaceErrorPermissionDenied(String context) {
    return 'Permission denied$context, please check login status.';
  }

  @override
  String get shortVideoSpaceErrorBadRequest => 'Bad request parameters';

  @override
  String shortVideoSpaceErrorBadRequestWithContext(
    String message,
    String context,
  ) {
    return '$message$context';
  }

  @override
  String shortVideoSpaceErrorServerError(String context) {
    return 'Server error$context, please retry later.';
  }

  @override
  String shortVideoSpaceErrorDetailedMessage(String message, String context) {
    return '$message$context';
  }

  @override
  String shortVideoSpaceErrorDefaultMessage(String context, String error) {
    return 'Operation failed$context: $error';
  }

  @override
  String get shortVideoSpaceErrorRetryButton => 'Retry';

  @override
  String get shortVideoSpaceDialogExportHistoryTitle => 'Export History';

  @override
  String get shortVideoSpaceDialogExportHistoryRefresh => 'Refresh';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusLabel => 'Status';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeLabel => 'Time';

  @override
  String get shortVideoSpaceDialogExportHistoryClose => 'Close';

  @override
  String get shortVideoSpaceDialogExportHistoryRetry => 'Retry';

  @override
  String get shortVideoSpaceDialogExportHistoryNoRecords => 'No export records';

  @override
  String get shortVideoSpaceDialogExportHistoryNoRecordsHint =>
      'Export records will appear here after exporting videos';

  @override
  String get shortVideoSpaceDialogExportHistoryDownload => 'Download';

  @override
  String get shortVideoSpaceDialogExportHistoryDownloading => 'Downloading...';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeFilterAll => 'All time';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeFilterToday => 'Today';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeFilterWeek => 'Last week';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeFilterMonth => 'Last month';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusFilterAll => 'All status';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusFilterCompleted =>
      'Completed';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusFilterFailed => 'Failed';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusFilterCancelled =>
      'Cancelled';

  @override
  String get shortVideoSpaceDialogExportHistoryFileSizeUnknown => 'Unknown';

  @override
  String shortVideoSpaceDialogExportHistoryFileSizeKB(String size) {
    return '$size KB';
  }

  @override
  String shortVideoSpaceDialogExportHistoryFileSizeMB(String size) {
    return '$size MB';
  }

  @override
  String shortVideoSpaceDialogExportHistoryFileSizeGB(String size) {
    return '$size GB';
  }

  @override
  String shortVideoSpaceDialogExportHistoryDurationSeconds(int seconds) {
    return '$seconds seconds';
  }

  @override
  String shortVideoSpaceDialogExportHistoryDurationMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String shortVideoSpaceDialogExportHistoryDurationHours(
    int hours,
    int minutes,
  ) {
    return '$hours hours $minutes minutes';
  }

  @override
  String shortVideoSpaceDialogExportHistoryCreatedAt(String time) {
    return 'Created: $time';
  }

  @override
  String shortVideoSpaceDialogExportHistoryCompletedAt(
    String time,
    String duration,
  ) {
    return 'Completed: $time · Duration: $duration';
  }

  @override
  String shortVideoSpaceDialogExportHistoryFileSize(String size) {
    return 'File size: $size';
  }

  @override
  String shortVideoSpaceDialogExportHistorySettings(
    String bitrate,
    int framerate,
  ) {
    return 'Settings: $bitrate · $framerate FPS';
  }

  @override
  String shortVideoSpaceDialogExportHistoryLoadError(String error) {
    return 'Failed to load export history: $error';
  }

  @override
  String get shortVideoSpaceDialogExportHistorySessionExpired =>
      'Session expired, please login again';

  @override
  String shortVideoSpaceDialogExportHistoryDownloadLinkCopied(String format) {
    return 'Download link copied ($format)';
  }

  @override
  String shortVideoSpaceDialogExportHistoryDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get shortVideoSpaceDialogExportHistoryTimeJustNow => 'Just now';

  @override
  String shortVideoSpaceDialogExportHistoryTimeMinutesAgo(int minutes) {
    return '$minutes minutes ago';
  }

  @override
  String shortVideoSpaceDialogExportHistoryTimeHoursAgo(int hours) {
    return '$hours hours ago';
  }

  @override
  String shortVideoSpaceDialogExportHistoryTimeDaysAgo(int days) {
    return '$days days ago';
  }

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

  @override
  String get projectsBusyProcessing => 'Processing…';

  @override
  String get projectsArtWorkbenchTitle => 'Art styles workbench';

  @override
  String get projectsArtWorkbenchIntro =>
      'Refresh the list, inspect covers, edit prompts, and extract prompts from images—beyond list-only probes.';

  @override
  String get projectsArtWorkbenchReloadList => 'Refresh list';

  @override
  String get projectsArtWorkbenchViewCover => 'View cover';

  @override
  String get projectsArtWorkbenchReadingCover => 'Reading cover…';

  @override
  String get projectsArtWorkbenchNew => 'New style';

  @override
  String get projectsArtWorkbenchSave => 'Save current style';

  @override
  String get projectsArtWorkbenchDelete => 'Delete current style';

  @override
  String get projectsArtWorkbenchCurrentStyle => 'Current style';

  @override
  String get projectsArtWorkbenchEmptyHint =>
      'No styles yet—fill the form below to create one.';

  @override
  String get projectsArtWorkbenchFieldName => 'Name';

  @override
  String get projectsArtWorkbenchFieldTags => 'Tags';

  @override
  String get projectsArtWorkbenchFieldCoverUrl => 'Cover URL / data URI';

  @override
  String get projectsArtWorkbenchFieldCoverUrlHelper =>
      'Use a reachable URL or data:image/...;base64,...';

  @override
  String get projectsArtWorkbenchFieldPrompt => 'Prompt';

  @override
  String get projectsArtWorkbenchExtractTitle => 'Prompt extraction';

  @override
  String get projectsArtWorkbenchExtractImagesLabel => 'Image inputs';

  @override
  String get projectsArtWorkbenchExtractImagesHelper =>
      'Separate multiple URLs / data URIs with commas or newlines.';

  @override
  String get projectsArtWorkbenchExtractButton => 'Extract prompt into editor';

  @override
  String get projectsArtWorkbenchCoverPreview => 'Cover preview';

  @override
  String get projectsCreativeManualTitle => 'Creative manuals workbench';

  @override
  String get projectsCreativeManualIntro =>
      'Manage director and visual manuals in one place: refresh, create, update, and delete.';

  @override
  String get projectsCreativeManualSegmentDirector => 'Director manual';

  @override
  String get projectsCreativeManualSegmentVisual => 'Visual manual';

  @override
  String get projectsCreativeManualReloadAll => 'Reload all manuals';

  @override
  String get projectsCreativeManualPathDirectorFolder =>
      'directorManual folder';

  @override
  String get projectsCreativeManualPathVisual => 'stylePath';

  @override
  String get projectsCreativeManualSelectionDirector =>
      'Current director manual';

  @override
  String get projectsCreativeManualSelectionVisual => 'Current visual manual';

  @override
  String get projectsCreativeManualCreateDirector => 'New director manual';

  @override
  String get projectsCreativeManualCreateVisual => 'New visual manual';

  @override
  String get projectsCreativeManualSaveDirector => 'Save director manual';

  @override
  String get projectsCreativeManualSaveVisual => 'Save visual manual';

  @override
  String get projectsCreativeManualDeleteDirector => 'Delete director manual';

  @override
  String get projectsCreativeManualDeleteVisual => 'Delete visual manual';

  @override
  String get projectsCreativeManualEmptyKind =>
      'No manuals of this type yet—create one with the form below.';

  @override
  String get projectsCreativeManualFieldName => 'Name';

  @override
  String get projectsCreativeManualFieldImagesList => 'Images list';

  @override
  String get projectsCreativeManualFieldImagesHelper =>
      'Separate URLs / paths with commas or newlines.';

  @override
  String get projectsCreativeManualFieldSlots => 'Data slots';

  @override
  String get projectsCreativeManualFieldSlotsHelper =>
      'One slot per line: label|value|data';

  @override
  String get projectsCreativeManualSummaryTitle => 'Summary';

  @override
  String projectsCreativeManualSummaryLine(
    String name,
    String path,
    int imageCount,
    int slotCount,
  ) {
    return '$name · Path $path · Images $imageCount · Slots $slotCount';
  }

  @override
  String get projectsCreativeManualStatusRefreshing =>
      'Refreshing creative manuals…';

  @override
  String projectsCreativeManualStatusReloadOk(
    int directorCount,
    int visualCount,
    int getCount,
    int postCount,
  ) {
    return 'Director $directorCount · Visual $visualCount · visual GET/POST=$getCount/$postCount';
  }

  @override
  String projectsCreativeManualStatusReloadFail(String detail) {
    return 'Reload failed: $detail';
  }

  @override
  String get projectsCreativeManualStatusCreateNeedFields =>
      'Create failed: name and path are required.';

  @override
  String get projectsCreativeManualStatusCreating => 'Creating manual…';

  @override
  String projectsCreativeManualStatusCreated(String kind, String path) {
    return 'Created $kind: $path';
  }

  @override
  String get projectsCreativeManualStatusSaveNeedSelect =>
      'Save failed: select a manual first.';

  @override
  String get projectsCreativeManualStatusSaveNeedFields =>
      'Save failed: name and path are required.';

  @override
  String get projectsCreativeManualStatusSaving => 'Saving manual…';

  @override
  String projectsCreativeManualStatusSaved(String kind, String path) {
    return 'Saved $kind: $path';
  }

  @override
  String get projectsCreativeManualStatusDeleteNeedSelect =>
      'Delete failed: select a manual first.';

  @override
  String get projectsCreativeManualStatusDeleting => 'Deleting manual…';

  @override
  String projectsCreativeManualStatusDeleted(String kind, String path) {
    return 'Deleted $kind: $path';
  }

  @override
  String projectsCreativeManualStatusOpFail(String verb, String detail) {
    return '$verb failed: $detail';
  }

  @override
  String get projectsCreativeManualKindDirector => 'Director manual';

  @override
  String get projectsCreativeManualKindVisual => 'Visual manual';

  @override
  String projectsCreativeManualInvalidSlotLine(String line) {
    return 'Invalid slot line (expected label|value|data): $line';
  }

  @override
  String get agentMemoryWorkbenchTitle => 'Agent memory workbench';

  @override
  String get agentMemoryWorkbenchIntro =>
      'Query, append, and clear project-scoped script/production Agent memory—without relying on the first-project probe only.';

  @override
  String get agentMemoryReloadProjects => 'Reload projects';

  @override
  String get agentMemoryQueryMemory => 'Query memory';

  @override
  String get agentMemoryLoadCostOverview => 'Load cost overview';

  @override
  String get agentMemoryOptimizeVideo => 'Optimize video memory';

  @override
  String agentMemoryProjectsPreviewLine(
    int count,
    String preview,
    String ellipsis,
  ) {
    return '$count projects · $preview$ellipsis';
  }

  @override
  String get agentMemoryUnnamedProject => 'Unnamed project';

  @override
  String get agentMemoryFieldProjectNumericId => 'Project numeric ID';

  @override
  String get agentMemoryFieldAgentType => 'Agent type';

  @override
  String get agentMemoryFieldEpisodesIdOptional => 'Episodes id (optional)';

  @override
  String get agentMemoryFieldScopeSignatureOptional =>
      'scopeSignature JSON (optional)';

  @override
  String get agentMemoryFieldScopeSignatureHelper =>
      'JSON object; typical keys: episodeId, storyboardIds, focusSections';

  @override
  String get agentMemoryFieldQueryType => 'Query type';

  @override
  String get agentMemoryFieldQueryTypeHelper => 'summary / message / all';

  @override
  String get agentMemoryFieldMemoryTier => 'Memory tier';

  @override
  String get agentMemoryFieldMemoryTierHelper =>
      'all / style_bible / stage_summary / delta_memory / message';

  @override
  String get agentMemoryFieldAutomationMode => 'Automation mode';

  @override
  String get agentMemoryFieldAutomationModeHelper => 'standard / lean / off';

  @override
  String get agentMemoryIsolateHint =>
      'Automatic memory is isolated by project numeric ID + agent type + episodes id.';

  @override
  String get agentMemoryOptimizeScopeHint =>
      'Optimization only affects productionAgent + episodes id scoped selected video memory; it is not shared across users, projects, or shorts.';

  @override
  String get agentMemoryOptimizeEnableHint =>
      'To enable optimization, set agent type to productionAgent and fill episodes id.';

  @override
  String get agentMemoryRecommendationPrefix => 'Suggestion: ';

  @override
  String get agentMemoryCopyChecklistTooltip => 'Copy execution checklist';

  @override
  String get agentMemoryChecklistCopiedSnack => 'Execution checklist copied.';

  @override
  String get agentMemoryAppendSection => 'Append memory';

  @override
  String get agentMemoryFieldAppendType => 'Append type';

  @override
  String get agentMemoryFieldAppendTypeHelper => 'message / summary';

  @override
  String get agentMemoryFieldAppendMemoryTier => 'Append memory tier';

  @override
  String get agentMemoryFieldAppendMemoryTierHelper =>
      'style_bible / stage_summary / delta_memory / message';

  @override
  String get agentMemoryFieldRole => 'Role';

  @override
  String get agentMemoryFieldNameOptional => 'Name (optional)';

  @override
  String get agentMemoryAppendButton => 'Append with current scope';

  @override
  String get agentMemoryFieldMemoryContent => 'Memory content';

  @override
  String get agentMemoryClearSection => 'Clear memory';

  @override
  String get agentMemoryFieldClearType => 'Clear type';

  @override
  String get agentMemoryFieldClearTypeHelper => 'summary / message / all';

  @override
  String get agentMemoryClearRun => 'Run clear';

  @override
  String get agentMemoryDuplicateChip => 'Duplicate';

  @override
  String agentMemoryTierGroupHeader(String label, int count, String last) {
    return '$label · $count rows · Last injected $last';
  }

  @override
  String agentMemoryMemoryRowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count memory rows',
      one: '1 memory row',
    );
    return '$_temp0';
  }

  @override
  String agentMemoryCharsAbbr(int n) {
    return '$n chars';
  }

  @override
  String agentMemorySubjectLabel(String value) {
    return 'subject $value';
  }

  @override
  String agentMemorySignalsLabel(String value) {
    return 'signals $value';
  }

  @override
  String get agentMemoryTierAll => 'All tiers';

  @override
  String get agentMemoryTierStyleBible => 'Style bible';

  @override
  String get agentMemoryTierStageSummary => 'Stage summary';

  @override
  String get agentMemoryTierDeltaMemory => 'Delta memory';

  @override
  String get agentMemoryTierMessage => 'Messages';

  @override
  String get agentMemoryClassNegative => 'Negative constraints';

  @override
  String get agentMemoryClassDeliveryVisual => 'Delivery + visual';

  @override
  String get agentMemoryClassDeliveryFirst => 'Delivery-first';

  @override
  String get agentMemoryClassVisualHeavy => 'Visual-heavy';

  @override
  String get agentMemoryClassVideoMemory => 'Video memory';

  @override
  String get agentMemoryActionMergeNegative => 'Merge negatives';

  @override
  String get agentMemoryActionObserve => 'Observe';

  @override
  String get agentMemoryActionCompress => 'Compress';

  @override
  String get agentMemoryActionKeep => 'Keep';

  @override
  String agentMemoryInsightCore(
    String roles,
    String typesPart,
    int totalChars,
    int longestChars,
    String dupPart,
  ) {
    return 'Roles: $roles$typesPart · ~$totalChars chars · longest $longestChars chars$dupPart';
  }

  @override
  String agentMemoryInsightTypesPart(String detail) {
    return ' · Types: $detail';
  }

  @override
  String agentMemoryInsightDupPart(int count) {
    return ' · Duplicates: $count';
  }

  @override
  String agentMemoryVideoInsight(
    int dRows,
    int dChars,
    int vRows,
    int vChars,
    int nRows,
    int nChars,
  ) {
    return 'Video memory: delivery $dRows/$dChars chars · visual $vRows/$vChars chars · negative $nRows/$nChars chars';
  }

  @override
  String agentMemoryEfficiencyInsight(
    int kRows,
    int kChars,
    int tRows,
    int tChars,
    int mRows,
    int mChars,
  ) {
    return 'Plan: keep $kRows/$kChars chars · trim $tRows/$tChars chars · merge negatives $mRows/$mChars chars';
  }

  @override
  String agentMemoryBucketPriorityLine(String detail) {
    return 'Bucket priority: $detail';
  }

  @override
  String agentMemoryBucketPriorityItem(
    String action,
    String name,
    int rows,
    int chars,
  ) {
    return '$action $name · $rows rows / $chars chars';
  }

  @override
  String get agentMemoryCostNever => 'never';

  @override
  String agentMemoryCostOverviewLine(
    String scope,
    int sb,
    int ss,
    int dm,
    int msg,
    int avgInj,
    int avgHit,
    String last,
  ) {
    return 'scope=$scope · Cost: style bible $sb · stage summary $ss · delta $dm · messages $msg · avg injected (30) $avgInj chars · avg hit tiers (30) $avgHit · last injected $last';
  }

  @override
  String get agentMemoryChecklistTitle => 'Execution checklist:';

  @override
  String agentMemoryChecklistScope(String scope) {
    return 'Scope: only memories for $scope; do not reuse across users, projects, or shorts.';
  }

  @override
  String get agentMemoryChecklistScopeFallback => 'current query scope';

  @override
  String agentMemoryChecklistCompress(String name) {
    return 'Compress filler shots/lighting in $name; keep delivery, tone, emotion, and character consistency.';
  }

  @override
  String agentMemoryChecklistMerge(String name) {
    return 'Merge duplicate risk/avoid constraints in $name; keep the strongest guardrails against continuity breaks.';
  }

  @override
  String agentMemoryChecklistKeep(String name) {
    return 'Keep the strongest delivery/emotion anchors in $name; avoid deleting cues that keep performances natural.';
  }

  @override
  String agentMemoryChecklistObserve(String name) {
    return 'Watch new entries in $name; avoid stacking duplicates.';
  }

  @override
  String agentMemoryChecklistReminder(String text) {
    return 'Reminder: $text';
  }

  @override
  String get agentMemoryRecDup =>
      'Duplicates detected—dedupe older memories so constraints are not injected repeatedly.';

  @override
  String get agentMemoryRecVisualOnly =>
      'Video memory is mostly framing/lighting—add a delivery, tone, or emotion anchor before deleting visual rows.';

  @override
  String get agentMemoryRecVisualBudget =>
      'Visual-heavy rows consume budget—trim old framing/lighting entries and reserve chars for delivery and emotion.';

  @override
  String get agentMemoryRecNegativeMerge =>
      'Many negative constraints—merge duplicate risk/avoid snippets before negative memory balloons.';

  @override
  String agentMemoryRecBucketHot(String name, int count) {
    return '$name already has $count rows—compress that bucket first so it does not dominate budget.';
  }

  @override
  String get agentMemoryRecLong =>
      'Memory is long—compress the longest rows before appending more.';

  @override
  String get agentMemoryRecManyRows =>
      'Many rows—read summaries or clear old messages to budget for current shots.';

  @override
  String get agentMemoryRecAssistantHeavy =>
      'Many assistant summaries—clear older ones and keep the latest execution constraints.';

  @override
  String get agentMemorySignalSubject => 'subject';

  @override
  String get agentMemorySignalEmotion => 'emotion';

  @override
  String get agentMemorySignalCamera => 'camera';

  @override
  String get agentMemorySignalVisual => 'visual';

  @override
  String get agentMemorySignalIdentity => 'identity';

  @override
  String get agentMemorySignalDialogue => 'dialogue';

  @override
  String get agentMemorySignalPerformance => 'performance';

  @override
  String agentMemorySignalNegative(String n) {
    return 'negative$n';
  }

  @override
  String agentMemoryStatusProjectsRefreshed(int count) {
    return 'Reloaded $count projects.';
  }

  @override
  String get agentMemoryErrFillProjectAndAgent =>
      'Enter a valid project ID (numeric or UUID from the list) and agent type.';

  @override
  String get agentMemoryErrFillAgentType => 'Enter agent type.';

  @override
  String agentMemoryQuerySummaryLine(
    int count,
    String memoryType,
    String tier,
  ) {
    return 'Loaded $count $memoryType memories · tier $tier.';
  }

  @override
  String get agentMemoryErrCostOverviewFields =>
      'Enter a valid project ID and agent type before loading cost overview.';

  @override
  String get agentMemoryStatusCostOverviewLoaded =>
      'Loaded memory cost overview.';

  @override
  String get agentMemoryErrAppendProjectFields =>
      'Enter project ID, agent type, role, and content before appending.';

  @override
  String get agentMemoryErrAppendAgentRoleContent =>
      'Enter agent type, role, and content before appending.';

  @override
  String agentMemoryStatusAppended(String id) {
    return 'Appended memory $id.';
  }

  @override
  String get agentMemoryErrClearProjectFields =>
      'Enter project ID and agent type before clearing.';

  @override
  String agentMemoryStatusCleared(String clearType) {
    return 'Cleared memory: $clearType.';
  }

  @override
  String get agentMemoryErrOptimizeProjectFields =>
      'Enter project ID, agent type, and episodes id before optimizing.';

  @override
  String get agentMemoryErrOptimizeAgentEpisodes =>
      'Enter agent type and episodes id before optimizing.';

  @override
  String agentMemoryStatusOptimized(
    String mode,
    int removedRows,
    int removedChars,
    int dupRows,
    int visRows,
  ) {
    return 'Optimized video memory ($mode): removed $removedRows rows / $removedChars chars (duplicates $dupRows, visual-only $visRows).';
  }

  @override
  String get agentMemoryErrScopeNotObject =>
      'scopeSignature must be a JSON object.';

  @override
  String get agentMemoryErrScopeNeedsDimension =>
      'scopeSignature needs at least one non-empty scope dimension.';

  @override
  String agentMemoryErrScopeTierRequires(String action) {
    return '$action requires non-empty scopeSignature JSON for this tier.';
  }

  @override
  String get agentMemoryActionLabelQueryScoped => 'Query scoped memory';

  @override
  String get agentMemoryActionLabelAppendScoped => 'Append scoped memory';

  @override
  String get taskCenterErrNotLoggedIn =>
      'Not signed in. Cannot open task center.';

  @override
  String get taskCenterProjectsNotLoaded => 'Task projects are not loaded yet.';

  @override
  String get taskCenterTaskListNotLoaded => 'Task list is not loaded yet.';

  @override
  String get taskCenterLocalClientPrefs => 'Local client preferences';

  @override
  String get taskCenterSectionIntro =>
      'Use the formal workbench for task projects/categories, filtered task listing, and details. The main section no longer depends on first-row or UUID probe buttons.';

  @override
  String get taskCenterOpenWorkbench => 'Open task workbench';

  @override
  String get taskCenterRefreshSummary => 'Refresh task summary';

  @override
  String get taskCenterCompatibilityCheck => 'Compatibility checks';

  @override
  String get taskCenterCompatibilityHint =>
      'Keep legacy loading/detail probes as regression entry points; collapsed by default.';

  @override
  String get taskCenterLoadTaskProjects => 'Load task projects';

  @override
  String get taskCenterLoadTaskCategories => 'Load task categories';

  @override
  String get taskCenterLoadTaskList => 'Load task list';

  @override
  String get taskCenterViewFirstTaskDetails => 'View first task details';

  @override
  String get taskCenterFieldTaskUuidTapToFill =>
      'Task UUID (tap a row below to fill)';

  @override
  String get taskCenterViewByUuid => 'View details by UUID';

  @override
  String taskCenterJobsCount(int count) {
    return '$count tasks';
  }

  @override
  String taskCenterCategoriesLine(String line) {
    return 'Category summary: $line';
  }

  @override
  String taskCenterNumericIdDetailsLine(String line) {
    return 'Task details (numeric ID): $line';
  }

  @override
  String taskCenterUuidDetailsLine(String line) {
    return 'UUID details: $line';
  }

  @override
  String get taskCenterPhasePrep => 'Prep';

  @override
  String get taskCenterPhaseImage => 'Image';

  @override
  String get taskCenterPhaseVideo => 'Video';

  @override
  String get taskCenterPhaseExport => 'Export';

  @override
  String get taskCenterPhaseQuality => 'Quality';

  @override
  String get taskCenterWorkbenchTitle => 'Task workbench';

  @override
  String taskCenterWorkbenchIntro(String realtime) {
    return 'Use one dialog to load task projects/categories, filter lists by project/category, and inspect details by numeric task id or UUID.$realtime';
  }

  @override
  String get taskCenterWorkbenchRealtimeConnected =>
      ' Live task updates are connected.';

  @override
  String get taskCenterWorkbenchFilterAndList => 'Filters and list';

  @override
  String get taskCenterReloadTaskProjects => 'Reload task projects';

  @override
  String get taskCenterReloadTaskCategories => 'Reload task categories';

  @override
  String get taskCenterLoadTasksByFilters => 'Load tasks by filters';

  @override
  String get taskCenterFieldPage => 'Page';

  @override
  String get taskCenterFieldPageSize => 'Page size';

  @override
  String get taskCenterFieldProjectNumericIdOptional =>
      'Project numeric ID (optional)';

  @override
  String get taskCenterFieldTaskClassOptional => 'Task class (optional)';

  @override
  String get taskCenterFieldTaskStatusOptional => 'Task status (optional)';

  @override
  String get taskCenterFieldProductionPhaseOptional =>
      'Short-video phase (optional: prep/image/video/export/quality)';

  @override
  String taskCenterFailureReason(String text) {
    return 'Failure reason=$text';
  }

  @override
  String get taskCenterRetry => 'Retry';

  @override
  String get taskCenterCancel => 'Cancel';

  @override
  String get taskCenterTaskDetailsSection => 'Task details';

  @override
  String get taskCenterFieldNumericTaskId => 'Numeric task id';

  @override
  String get taskCenterLoadNumericIdDetails => 'Load task details (numeric ID)';

  @override
  String get taskCenterFieldTaskUuid => 'Task UUID';

  @override
  String get taskCenterLoadUuidDetails => 'Load UUID details';

  @override
  String taskCenterStatusLine(String line) {
    return 'Status: $line';
  }

  @override
  String taskCenterStructuredFailure(String label) {
    return 'Structured failure · $label';
  }

  @override
  String get taskCenterOpenProductionWorkspace => 'Open production workspace';

  @override
  String get taskCenterOpenScriptWorkspace => 'Open script workspace';

  @override
  String get taskCenterRegenerate => 'Regenerate';

  @override
  String get taskCenterPartialRework => 'Partial rework';

  @override
  String get taskCenterWritebackCompensation => 'Writeback compensation';

  @override
  String get taskCenterOpenSpacePublish => 'Open short-video Space (publish)';

  @override
  String get taskCenterOpenProductionStoryboard =>
      'Open production workspace (storyboard)';

  @override
  String get taskCenterOpenScriptScript => 'Open script workspace (script)';

  @override
  String get taskCenterOpenSpaceProject => 'Open short-video Space (project)';

  @override
  String taskCenterStatusLoadedTaskProjects(int count) {
    return 'Loaded $count task projects.';
  }

  @override
  String taskCenterStatusLoadedTaskCategories(int count) {
    return 'Loaded $count task categories.';
  }

  @override
  String taskCenterStatusRefreshedTasks(int count) {
    return 'Refreshed $count tasks.';
  }

  @override
  String get taskCenterErrInvalidNumericTaskId =>
      'Enter a valid numeric task ID.';

  @override
  String get taskCenterErrFillTaskUuid => 'Enter task UUID.';

  @override
  String get taskCenterOriginRetrySubmitted => 'Retry submitted';

  @override
  String get taskCenterOriginTaskCancelled => 'Task cancelled';

  @override
  String get taskCenterStatusEnteredWritebackCompensation =>
      'Entered writeback compensation: load UUID details first and verify writeback status.';

  @override
  String get taskCenterOriginRealtimeUpdate => 'Realtime update received';

  @override
  String taskCenterStatusMergedUpdate(
    String origin,
    int taskId,
    String kind,
    String status,
  ) {
    return '$origin: #$taskId $kind -> $status';
  }

  @override
  String get taskCenterProjectsEmpty => 'No task projects currently.';

  @override
  String taskCenterProjectsSummary(int count, String preview, String ellipsis) {
    return '$count projects · $preview$ellipsis';
  }

  @override
  String get taskCenterCategoriesEmpty => 'No task categories currently.';

  @override
  String taskCenterCategoriesSummary(
    int count,
    String preview,
    String ellipsis,
  ) {
    return '$count categories · $preview$ellipsis';
  }

  @override
  String get taskCenterJobsEmpty => 'No task records currently.';

  @override
  String taskCenterJobsSummary(int count, String preview, String ellipsis) {
    return '$count tasks · $preview$ellipsis';
  }

  @override
  String get taskCenterFailurePayloadMissingSourceUrl => 'Missing source_url';

  @override
  String get taskCenterFailurePayloadSourceUrlEmpty => 'Output URL is empty';

  @override
  String get taskCenterFailurePayloadFormatInvalid => 'Invalid export format';

  @override
  String get taskCenterFailureLocalExportDirUnset =>
      'Export directory is not configured on server';

  @override
  String get taskCenterFailureExportProviderFailed => 'Export provider failed';

  @override
  String get taskCenterFailureExportDirectoryCreateFailed =>
      'Failed to create export directory';

  @override
  String get taskCenterFailureExportFilePersistFailed =>
      'Failed to persist export file';

  @override
  String get taskCenterFailureVideoDownloadHttp => 'Source video HTTP failed';

  @override
  String get taskCenterFailureVideoDownloadStream =>
      'Source video stream interrupted';

  @override
  String get taskCenterFailureVideoFormatMismatchNoTranscode =>
      'Format mismatch (no transcoding)';

  @override
  String get taskCenterFailureVideoContentLengthExceedsLimit =>
      'Source video too large (content-length)';

  @override
  String get taskCenterFailureVideoBodyExceedsLimit =>
      'Source video too large (body)';

  @override
  String get taskCenterFailureUnknownCode => 'Unknown failure code';

  @override
  String get projectsCreativeManualVerbCreate => 'Create';

  @override
  String get projectsCreativeManualVerbSave => 'Save';

  @override
  String get projectsCreativeManualVerbDelete => 'Delete';

  @override
  String get projectsArtWorkbenchStatusRefreshing => 'Refreshing art styles…';

  @override
  String projectsArtWorkbenchStatusRefreshed(int count) {
    return 'Refreshed $count art styles.';
  }

  @override
  String projectsArtWorkbenchStatusRefreshFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get projectsArtWorkbenchStatusReadingCover => 'Reading cover…';

  @override
  String projectsArtWorkbenchStatusReadCover(int id) {
    return 'Read cover for style #$id.';
  }

  @override
  String projectsArtWorkbenchStatusReadCoverFailed(String error) {
    return 'Read cover failed: $error';
  }

  @override
  String get projectsArtWorkbenchStatusCreateNeedName =>
      'Create failed: name is required.';

  @override
  String get projectsArtWorkbenchStatusCreating => 'Creating art style…';

  @override
  String projectsArtWorkbenchStatusCreated(int id) {
    return 'Created style #$id.';
  }

  @override
  String projectsArtWorkbenchStatusCreateFailed(String error) {
    return 'Create failed: $error';
  }

  @override
  String get projectsArtWorkbenchStatusSaveNeedSelect =>
      'Save failed: select a style first.';

  @override
  String get projectsArtWorkbenchStatusSaving => 'Saving art style…';

  @override
  String projectsArtWorkbenchStatusSaved(int id) {
    return 'Updated style #$id.';
  }

  @override
  String projectsArtWorkbenchStatusSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get projectsArtWorkbenchStatusDeleteNeedSelect =>
      'Delete failed: select a style first.';

  @override
  String get projectsArtWorkbenchStatusDeleting => 'Deleting art style…';

  @override
  String projectsArtWorkbenchStatusDeleted(int id) {
    return 'Deleted style #$id.';
  }

  @override
  String projectsArtWorkbenchStatusDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get projectsArtWorkbenchStatusExtractNeedInput =>
      'Extraction failed: provide at least one image URL or data URI.';

  @override
  String get projectsArtWorkbenchStatusExtracting =>
      'Extracting art-style prompt…';

  @override
  String get projectsArtWorkbenchStatusExtracted =>
      'Prompt generated. You can save it to the current style.';

  @override
  String projectsArtWorkbenchStatusExtractFailed(String error) {
    return 'Extraction failed: $error';
  }

  @override
  String get globalSearchErrSignInFirst => 'Please sign in first.';

  @override
  String globalSearchErrSearchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get globalSearchCopiedDeepLink => 'Copied current search deep link.';

  @override
  String get globalSearchAllTypes => 'All';

  @override
  String get globalSearchTimeStart => 'start';

  @override
  String get globalSearchTimeNow => 'now';

  @override
  String get globalSearchAllTime => 'All time';

  @override
  String get globalSearchNeverUsed => 'never used';

  @override
  String get globalSearchSaveViewTitle => 'Save search view';

  @override
  String get globalSearchViewNameField => 'View name';

  @override
  String get globalSearchViewNameHint => 'e.g. scripts in last 30 days';

  @override
  String get globalSearchCancel => 'Cancel';

  @override
  String get globalSearchSave => 'Save';

  @override
  String get globalSearchViewNameRequired => 'View name is required.';

  @override
  String get globalSearchViewSaved => 'Search view saved.';

  @override
  String get globalSearchNoSavedViews => 'No saved search views yet.';

  @override
  String get globalSearchPinned => 'Pinned';

  @override
  String get globalSearchUnpin => 'Unpin';

  @override
  String get globalSearchPinToSearchBar => 'Pin to search bar';

  @override
  String get globalSearchUnpinnedView => 'Unpinned search view.';

  @override
  String get globalSearchPinnedToSearchBar => 'Pinned to search bar.';

  @override
  String get globalSearchDelete => 'Delete';

  @override
  String get globalSearchViewDeleted => 'Search view deleted.';

  @override
  String get globalSearchTypeProject => 'Project';

  @override
  String get globalSearchTypeScript => 'Script';

  @override
  String get globalSearchTypeAsset => 'Asset';

  @override
  String get globalSearchTypeNovel => 'Novel chapters';

  @override
  String get globalSearchTypeNovelEvent => 'Novel events';

  @override
  String globalSearchTitle(String query) {
    return 'Search: $query';
  }

  @override
  String get globalSearchTooltipSaveCurrentView => 'Save current view';

  @override
  String get globalSearchTooltipSavedViews => 'Saved views';

  @override
  String get globalSearchTooltipCopyDeepLink => 'Copy search deep link';

  @override
  String get globalSearchTooltipFilter => 'Filter';

  @override
  String globalSearchFoundResults(int count) {
    return 'Found $count results';
  }

  @override
  String get globalSearchClearFilters => 'Clear filters';

  @override
  String globalSearchTimeChip(String from, String to) {
    return 'Time $from ~ $to';
  }

  @override
  String get globalSearchErrorTitle => 'Search error';

  @override
  String get globalSearchUnknownError => 'Unknown error';

  @override
  String get globalSearchRetry => 'Retry';

  @override
  String get globalSearchNoResultsTitle => 'No matching results';

  @override
  String get globalSearchNoResultsHint => 'Try different keywords';

  @override
  String get globalSearchPrevPage => 'Previous page';

  @override
  String globalSearchCurrentPage(int page) {
    return 'Page $page';
  }

  @override
  String get globalSearchNextPage => 'Next page';

  @override
  String get globalSearchTimeJustNow => 'just now';

  @override
  String globalSearchTimeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String globalSearchTimeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String globalSearchTimeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get globalSearchChooseStartDate => 'Choose start date';

  @override
  String get globalSearchChooseEndDate => 'Choose end date';

  @override
  String get globalSearchConfirm => 'Confirm';

  @override
  String globalSearchAppliedFilters(int count) {
    return 'Applied $count filters';
  }

  @override
  String get globalSearchClearedAllFilters => 'Cleared all filters.';

  @override
  String get globalSearchAdvancedFilterTitle => 'Advanced filters';

  @override
  String get globalSearchResultTypeSection => 'Result type';

  @override
  String get globalSearchCreatedTimeSection => 'Created time';

  @override
  String get globalSearchTypeNovelEventOutline => 'Novel outline events';

  @override
  String globalSearchStartDateLabel(String date) {
    return 'Start: $date';
  }

  @override
  String globalSearchEndDateLabel(String date) {
    return 'End: $date';
  }

  @override
  String get globalSearchClearTimeRange => 'Clear time range';

  @override
  String get globalSearchApplyFilter => 'Apply filters';

  @override
  String get globalSearchWorkspaceUnlabeled => 'Unlabeled workspace';

  @override
  String get globalSearchWorkspaceCurrent => 'Current workspace';

  @override
  String get globalSearchViewActions => 'View actions';

  @override
  String get globalSearchRename => 'Rename';

  @override
  String get globalSearchDeleteView => 'Delete view';

  @override
  String get globalSearchRenameViewTitle => 'Rename search view';

  @override
  String get globalSearchRenameViewHint => 'Enter a new view name';

  @override
  String get globalSearchRenamedView => 'Renamed search view.';

  @override
  String get globalSearchDeleteViewTitle => 'Delete search view';

  @override
  String globalSearchDeleteViewConfirmRemote(String title) {
    return 'Delete \"$title\"? Signed-in mode will sync removal to all clients with this saved view data.';
  }

  @override
  String globalSearchDeleteViewConfirmLocal(String title) {
    return 'Delete \"$title\"? This only removes the locally saved view.';
  }

  @override
  String get globalSearchPinnedViewsTitle => 'Pinned views';

  @override
  String get globalSearchRecentViewsTitle => 'Recent views';

  @override
  String get globalSearchQuickTemplatesTitle => 'Quick templates';

  @override
  String get globalSearchLiveSuggestionsTitle => 'Live suggestions';

  @override
  String get globalSearchRecentSearchTitle => 'Recent searches';

  @override
  String get globalSearchClearHistory => 'Clear history';

  @override
  String get globalSearchNoPreviewHint =>
      'No preview matches yet. Press Enter for full results.';

  @override
  String get globalSearchMinCharsHint =>
      'Enter at least 2 characters to search.';

  @override
  String get globalSearchHistoryCleared => 'Search history cleared.';

  @override
  String globalSearchClearHistoryFailed(String error) {
    return 'Failed to clear history: $error';
  }

  @override
  String globalSearchEnterAtLeastChars(int count) {
    return 'Enter at least $count characters.';
  }

  @override
  String globalSearchMaxCharsHint(int count) {
    return 'Search query is too long. Limit to $count characters.';
  }

  @override
  String get globalSearchInputHint => 'Search projects, scripts, assets...';

  @override
  String get globalSearchActionSearch => 'Search';

  @override
  String get globalSearchLocalClientPrefsTooltip =>
      'Local client preferences (view silenced / restore confirmations)';

  @override
  String globalSearchSavedUsed(int count) {
    return 'used=$count';
  }

  @override
  String get globalSearchTemplateRecent7d => 'Last 7 days';

  @override
  String get globalSearchTemplateProjects30d => 'Projects in last 30 days';

  @override
  String get globalSearchTemplateScripts30d => 'Scripts in last 30 days';

  @override
  String get globalSearchClearSearchHistoryTitle => 'Clear search history';

  @override
  String get globalSearchClearSearchHistoryConfirm =>
      'Clear all search history? This action cannot be undone.';

  @override
  String get globalSearchLoadHistoryFailed => 'Failed to load history';

  @override
  String get globalSearchNoSearchHistory => 'No search history yet';

  @override
  String globalSearchResultRows(int count) {
    return '$count results';
  }

  @override
  String get qualityReviewsErrNotLoggedIn =>
      'Not signed in. Unable to load quality reviews.';

  @override
  String get qualityReviewsSummaryNotLoaded => 'Review list not loaded yet.';

  @override
  String get qualityReviewsSectionIntro =>
      'View review list, bad cases, and stage pass rates. Low-score bad cases write back negative memory, while high-score passes promote positive memory.';

  @override
  String get qualityReviewsOpsDashboardTitle => 'Quality operations dashboard';

  @override
  String get qualityReviewsCopiedDashboardSummary =>
      'Copied dashboard summary.';

  @override
  String get qualityReviewsCopyDashboardSummary => 'Copy dashboard summary';

  @override
  String get qualityReviewsFieldReviewId =>
      'Review ID (tap from list below to autofill)';

  @override
  String get qualityReviewsViewReviewDetails => 'View review details';

  @override
  String qualityReviewsSummaryReviewDetails(String value) {
    return 'Review details: $value';
  }

  @override
  String qualityReviewsSummaryStats(String value) {
    return 'Quality stats: $value';
  }

  @override
  String qualityReviewsSummaryStagePassRate(String value) {
    return 'Stage pass rate: $value';
  }

  @override
  String qualityReviewsSummaryStageGrade(String value) {
    return 'Stage grade distribution: $value';
  }

  @override
  String qualityReviewsSummaryScopeInsights(String value) {
    return 'Scope leaderboard: $value';
  }

  @override
  String qualityReviewsSummaryTokenEfficiency(String value) {
    return 'Token efficiency: $value';
  }

  @override
  String qualityReviewsSummaryBadCaseHotspots(String value) {
    return 'Bad-case hotspots: $value';
  }

  @override
  String get qualityReviewsOpenWorkbench => 'Open quality workbench';

  @override
  String get qualityReviewsLoadCurrentDashboard => 'Load current dashboard';

  @override
  String get qualityReviewsRefreshReadModel => 'Refresh underlying read model';

  @override
  String get qualityReviewsLoadReviewList => 'Load review list';

  @override
  String get qualityReviewsViewBadCases => 'View bad cases';

  @override
  String get qualityReviewsViewStats => 'View quality stats';

  @override
  String get qualityReviewsViewStagePassRate => 'View stage pass rates';

  @override
  String get qualityReviewsDashboardNotLoadedRefreshEnabled =>
      'Quality dashboard not loaded. You can refresh aggregated stats, bad-case hotspots, stage distributions, and token efficiency directly.';

  @override
  String get qualityReviewsDashboardNotLoadedRefreshDisabled =>
      'Quality dashboard not loaded. Refresh controls are disabled by platform config; load current dashboard to view existing aggregates and bad-case hotspots.';

  @override
  String get qualityReviewsTargetType => 'Target type';

  @override
  String qualityReviewsTargetTypeChip(String target, String pass, int count) {
    return '$target $pass% · $count items';
  }

  @override
  String get qualityReviewsStageGrade => 'Stage grade';

  @override
  String get qualityReviewsBadCaseHotspots => 'Bad-case hotspots';

  @override
  String qualityReviewsBadCaseChip(String category, int count) {
    return '$category $count';
  }

  @override
  String get qualityReviewsUncategorized => 'Uncategorized';

  @override
  String get qualityReviewsScopeLeaderboard => 'Scope leaderboard';

  @override
  String get qualityReviewsTokenEfficiency => 'Token efficiency';

  @override
  String get qualityReviewsCompatibilityCheck => 'Compatibility check';

  @override
  String get qualityReviewsCompatibilityCheckIntro =>
      'Keep a read-only regression entry to ensure review list and detail queries still work.';

  @override
  String get qualityReviewsReadProbeLabel => 'Quality review read probe';

  @override
  String get qualityReviewsRunReadOnlyRegressionCheck =>
      'Run read-only regression check';

  @override
  String qualityReviewsCount(int count) {
    return '$count reviews';
  }

  @override
  String get qualityReviewsFilterBadCase => 'bad case';

  @override
  String get qualityReviewsFilterDeliveryPriorityHit =>
      'delivery/tone priority hit';

  @override
  String qualityReviewsFilterStage(String value) {
    return 'Stage $value';
  }

  @override
  String qualityReviewsFilterGrade(String value) {
    return 'Grade $value';
  }

  @override
  String qualityReviewsStatusLoadedReviews(int count) {
    return 'Loaded $count reviews';
  }

  @override
  String qualityReviewsStatusLoadedReviewsWithLabels(int count, String labels) {
    return 'Loaded $count reviews with $labels';
  }

  @override
  String get qualityReviewsStatusRefreshedStats => 'Refreshed quality stats';

  @override
  String get qualityReviewsStatusRefreshedScopeLeaderboard =>
      'Refreshed scope leaderboard';

  @override
  String get qualityReviewsStatusRefreshedStageAndGrade =>
      'Refreshed stage pass rates and grade distribution';

  @override
  String get qualityReviewsNoBadCaseData => 'No bad-case data';

  @override
  String qualityReviewsBadCaseStatsLine(
    String category,
    int count,
    String pass,
  ) {
    return '$category $count items pass=$pass';
  }

  @override
  String get qualityReviewsStatusRefreshedBadCaseDistribution =>
      'Refreshed bad-case distribution';

  @override
  String get qualityReviewsStatusRefreshedTokenAggregate =>
      'Refreshed token aggregate';

  @override
  String get qualityReviewsStatusRefreshedTokenSavingSamples =>
      'Refreshed token-saving samples';

  @override
  String get qualityReviewsErrInputReviewIdFirst =>
      'Please input review ID first';

  @override
  String get qualityReviewsStatusLoadedReviewDetails => 'Loaded review details';

  @override
  String get qualityReviewsErrTargetTypeSourceRequired =>
      'targetType and source are required';

  @override
  String get qualityReviewsErrScriptNeedsProject =>
      'scriptId requires projectId';

  @override
  String get qualityReviewsErrStoryboardTargetIdPositive =>
      'When creating storyboard review, targetId must be a positive integer shot ID';

  @override
  String qualityReviewsStatusCreated(String id) {
    return 'Created review $id';
  }

  @override
  String qualityReviewsStatusCreatedWithScopedWriteback(String id) {
    return 'Created review $id; this row will write back to project/script scoped memory';
  }

  @override
  String get qualityReviewsWorkbenchTitle => 'Quality workbench';

  @override
  String get qualityReviewsWorkbenchIntro =>
      'Use one entry for review filtering, bad-case lookup, stats loading, detail queries, and manual creation.';

  @override
  String get qualityReviewsOnlyBadCases => 'Only bad cases';

  @override
  String get qualityReviewsOnlyDeliveryPriorityHit =>
      'Only delivery/tone priority hits';

  @override
  String get qualityReviewsOnlyAutoSamples => 'Only auto samples';

  @override
  String get qualityReviewsFilterAutoSamples => 'auto samples';

  @override
  String qualityReviewsFilterQueryLine(String value) {
    return 'Filter query: $value';
  }

  @override
  String get qualityReviewsCopyFilterQuery => 'Copy filter query';

  @override
  String get qualityReviewsCopiedFilterQuery => 'Copied filter query.';

  @override
  String get qualityReviewsCopyApiUrl => 'Copy full API URL';

  @override
  String get qualityReviewsCopiedApiUrl => 'Copied API URL.';

  @override
  String get qualityReviewsFilterAndReadSection => 'Filter and load';

  @override
  String get qualityReviewsFilterProjectId => 'Filter projectId';

  @override
  String get qualityReviewsFilterScriptId => 'Filter scriptId';

  @override
  String get qualityReviewsFilterTargetType => 'Filter targetType';

  @override
  String get qualityReviewsFilterTargetId => 'Filter targetId';

  @override
  String get qualityReviewsFilterJobId => 'Filter jobId';

  @override
  String get qualityReviewsFilterStageLabel => 'Stage filter';

  @override
  String get qualityReviewsFilterGradeLabel => 'Grade filter';

  @override
  String get qualityReviewsAll => 'All';

  @override
  String get qualityReviewsSummarizing => 'Summarizing...';

  @override
  String get qualityReviewsLoading => 'Loading...';

  @override
  String get qualityReviewsLoadStats => 'Load quality stats';

  @override
  String get qualityReviewsLoadScopeLeaderboard => 'Load scope leaderboard';

  @override
  String get qualityReviewsLoadTokenEfficiency => 'Load token efficiency';

  @override
  String get qualityReviewsLoadTokenSavingSamples =>
      'Load token-saving samples';

  @override
  String get qualityReviewsLoadStagePassRate => 'Load stage pass rate';

  @override
  String get qualityReviewsLoadBadCaseDistribution =>
      'Load bad-case distribution';

  @override
  String get qualityReviewsDetailsQuerySection => 'Details query';

  @override
  String get qualityReviewsReviewId => 'Review ID';

  @override
  String get qualityReviewsCreateReviewSection => 'Create review';

  @override
  String get qualityReviewsCreateProjectIdOptional => 'projectId (optional)';

  @override
  String get qualityReviewsCreateProjectIdHelper =>
      'When provided, low-score/bad-case rows can auto-write project-scoped memory.';

  @override
  String get qualityReviewsCreateScriptIdOptional => 'scriptId (optional)';

  @override
  String get qualityReviewsCreateScriptIdHelper =>
      'Fill with projectId together to write into script-scoped memory.';

  @override
  String get qualityReviewsCreating => 'Creating...';

  @override
  String get qualityReviewsCreateReview => 'Create review';

  @override
  String qualityReviewsStatusLine(String value) {
    return 'Status: $value';
  }

  @override
  String qualityReviewsSummaryTokenAggregate(String value) {
    return 'Token aggregate: $value';
  }

  @override
  String qualityReviewsSummaryMemoryAction(String value) {
    return 'Memory action: $value';
  }

  @override
  String get qualityReviewsCopyExecutionChecklist => 'Copy execution checklist';

  @override
  String get qualityReviewsCopiedExecutionChecklist =>
      'Copied execution checklist.';

  @override
  String qualityReviewsSummaryTokenSavingSamples(String value) {
    return 'Token-saving samples: $value';
  }

  @override
  String qualityReviewsSummaryBadCaseDistribution(String value) {
    return 'Bad-case distribution: $value';
  }

  @override
  String get qualityReviewsGradeDistribution => 'Grade distribution';

  @override
  String qualityReviewsTotalAndPassRate(int total, String rate) {
    return 'Total $total · A+B pass rate $rate%';
  }

  @override
  String qualityReviewsPromptDiagnostics(String value) {
    return 'Prompt diagnostics: $value';
  }

  @override
  String qualityReviewsScopePressure(String value) {
    return 'Scope pressure: $value';
  }

  @override
  String qualityReviewsMemorySlimming(String value) {
    return 'Memory slimming: $value';
  }

  @override
  String qualityReviewsPriorityFix(String value) {
    return 'Priority fixes: $value';
  }

  @override
  String qualityReviewsRepairSuggestions(String value) {
    return 'Repair suggestions: $value';
  }

  @override
  String qualityReviewsFilterCountLine(String filters, int count) {
    return '$filters $count reviews';
  }

  @override
  String qualityReviewsSuggestions(String value) {
    return 'Suggestions: $value';
  }

  @override
  String get qualityReviewsEmptyForCurrentFilters =>
      'No reviews under current filters';

  @override
  String get qualityReviewsNoTokenEfficiencyStats =>
      'No token efficiency stats yet';

  @override
  String get qualityReviewsActionKeepDeliveryMemory =>
      'action=keep delivery memory';

  @override
  String get qualityReviewsActionReuseNegativeMemory =>
      'action=reuse negative constraints';

  @override
  String get qualityReviewsActionTrimGenericStyle =>
      'action=trim generic style memory';

  @override
  String get qualityReviewsActionPromoteSelectedMemory =>
      'action=promote selected memory';

  @override
  String get qualityReviewsFocusLabel => 'focus';

  @override
  String get qualityReviewsNoTokenEfficiencySamples =>
      'No token efficiency samples yet';

  @override
  String get qualityReviewsDeliveryPriority => 'delivery-priority';

  @override
  String get qualityReviewsRegular => 'regular';

  @override
  String get qualityReviewsNoReviews => 'No quality reviews yet';

  @override
  String qualityReviewsSummaryLine(int total, int autoCount, String details) {
    return 'Reviews $total · auto $autoCount · $details';
  }

  @override
  String get qualityReviewsNoQualityStats => 'No quality stats yet';

  @override
  String get qualityReviewsNoScopeLeaderboard => 'No scope leaderboard yet';

  @override
  String get qualityReviewsItemUnit => 'items';

  @override
  String get qualityReviewsEmotionRisk => 'emotion';

  @override
  String get qualityReviewsRealismRisk => 'realism';

  @override
  String get qualityReviewsPromotionsLabel => 'promotions';

  @override
  String get qualityReviewsBadCaseWriteback => 'bad-case writeback';

  @override
  String get qualityReviewsSummaryWriteback => 'summary writeback';

  @override
  String get qualityReviewsWritebackSlim => 'writeback slim';

  @override
  String get qualityReviewsFocusWatch => 'watch';

  @override
  String get qualityReviewsNoStagePassRate => 'No stage pass rates yet';

  @override
  String get qualityReviewsNoStageGradeDistribution =>
      'No stage grade distribution yet';

  @override
  String get qualityReviewsNoBadCaseHotspots => 'No bad-case hotspots yet';

  @override
  String get qualityReviewsSummaryStatsPrefix => 'Stats';

  @override
  String get qualityReviewsSummaryStagePrefix => 'Stage';

  @override
  String get qualityReviewsSummaryGradePrefix => 'Grade';

  @override
  String get qualityReviewsSummaryBadCasePrefix => 'Bad case';

  @override
  String get qualityReviewsDiagnosticLabel => 'diagnostic';

  @override
  String get qualityReviewsWritebackLabel => 'writeback';

  @override
  String get qualityReviewsSuggestionsLabel => 'suggestions';

  @override
  String get qualityReviewsNegativeConstraintReviewAndBadCase =>
      'negative constraint=reviews+bad-case memory';

  @override
  String get qualityReviewsNegativeConstraintRecentReviews =>
      'negative constraint=recent reviews';

  @override
  String get qualityReviewsNegativeConstraintBadCaseMemory =>
      'negative constraint=bad-case memory';

  @override
  String get qualityReviewsNegativeConstraintPendingBadCase =>
      'negative constraint=pending bad cases';

  @override
  String get qualityReviewsNegativeConstraintPendingRejected =>
      'negative constraint=pending rejected items';

  @override
  String qualityReviewsNegativeConstraintGeneric(String source) {
    return 'negative constraint=$source';
  }

  @override
  String qualityReviewsBucketCount(String bucket, int count) {
    return '$bucket$count times';
  }

  @override
  String get qualityReviewsFeedbackTagDeliveryRealism => 'dialogue realism';

  @override
  String get qualityReviewsFeedbackTagEmotionArc => 'emotion arc';

  @override
  String get qualityReviewsFeedbackTagIdentityContinuity =>
      'identity continuity';

  @override
  String get qualityReviewsFeedbackTagLightingRealism => 'lighting realism';

  @override
  String qualityReviewsScopeProject(int count) {
    return 'project $count';
  }

  @override
  String qualityReviewsScopeScript(int count) {
    return 'script $count';
  }

  @override
  String qualityReviewsScopeRole(int count) {
    return 'role $count';
  }

  @override
  String get qualityReviewsFocusSelectedVideoMemory => 'selected shot memory';

  @override
  String get qualityReviewsFocusRejectedVideoNegativeMemory =>
      'bad-case memory';

  @override
  String get qualityReviewsFocusProjectVideoStyleMemory =>
      'project style memory';

  @override
  String get qualityReviewsFocusCurrentMemory => 'current memory';

  @override
  String get qualityReviewsSuggestionReferenceFrame =>
      'Add reference frame and previous-shot continuity first; lock face, costume/props, and blocking continuity.';

  @override
  String get qualityReviewsSuggestionContinuity =>
      'Compress continuity constraints to 1-2 hard rules: camera setup, costume/props, and character positions only.';

  @override
  String get qualityReviewsSuggestionDelivery =>
      'Keep delivery/tone memory, add performable emotional actions, and do not trim delivery memory first.';

  @override
  String get qualityReviewsSuggestionTrimGeneric =>
      'Continue trimming generic action/lighting lines and reserve budget for expressions, lip sync, and identity continuity.';

  @override
  String get qualityReviewsSuggestionNegativeReuse =>
      'Reuse existing bad-case negative constraints; dedupe manually added phrases first to avoid repeated token burn.';

  @override
  String get qualityReviewsSuggestionDirectorTrim =>
      'Director descriptions already yielded to memory; reclaim repeated director lines first and keep key performance anchors.';

  @override
  String get qualityReviewsSuggestionProjectScopeTrim =>
      'Current hits are mostly project-scoped memory; trim generic style lines first and keep character performance details.';

  @override
  String get qualityReviewsSuggestionRoleScopeKeep =>
      'Role-scoped memory already hit; strengthen role performance actions first and avoid regressing to generic project copy.';

  @override
  String get qualityReviewsSuggestionEmotion =>
      'In next round, turn emotional arc into observable actions; avoid explanatory dialogue only.';

  @override
  String get qualityReviewsSuggestionVisual =>
      'Prioritize character appearance and shot realism constraints, then decide whether to add more style descriptions.';

  @override
  String get qualityReviewsSuggestionGeneral =>
      'Lock emotion, continuity, and bad-case constraints first, then run the next generation round.';

  @override
  String qualityReviewsRepairPlanCount(String suggestion, int count) {
    return '$suggestion $count times';
  }

  @override
  String get qualityReviewsCurrentFilterScope => 'current filter scope';

  @override
  String qualityReviewsActionPlanKeepDelivery(String targetType, String focus) {
    return '$targetType: keep delivery/emotion memory from $focus; continue trimming generic style lines before delivery fragments.';
  }

  @override
  String qualityReviewsActionPlanReuseNegative(
    String targetType,
    String focus,
  ) {
    return '$targetType: reuse $focus for bad-case isolation constraints; lock glitches/fakeness before deciding prompt additions.';
  }

  @override
  String qualityReviewsActionPlanTrimGeneric(String targetType, String focus) {
    return '$targetType: prioritize trimming action/lighting/mood filler in $focus; reserve tokens for performance, lip sync, and continuity.';
  }

  @override
  String qualityReviewsActionPlanPromoteSelected(
    String targetType,
    String focus,
  ) {
    return '$targetType: promote one high-score sample to $focus; reuse emotion and shot execution while reducing repetitive descriptions.';
  }

  @override
  String qualityReviewsScopedMemorySuggestion(String scope, String value) {
    return '$scope scoped-memory suggestion: $value';
  }

  @override
  String qualityReviewsChecklistKeepDelivery(String focus) {
    return 'Keep performance/tone/lip-sync/emotion memory in $focus, only trim generic style filler.';
  }

  @override
  String qualityReviewsChecklistReuseNegative(String focus) {
    return 'Reuse bad-case constraints in $focus first; lock glitches/fakeness/coldness before deciding prompt additions.';
  }

  @override
  String qualityReviewsChecklistTrimGeneric(String focus) {
    return 'Remove action/lighting/mood filler in $focus; keep tokens for performance and continuity.';
  }

  @override
  String qualityReviewsChecklistPromoteSelected(String focus) {
    return 'Promote high-score samples to $focus; reuse emotion and shot execution while reducing repetitive director copy.';
  }

  @override
  String qualityReviewsChecklistTitle(String scope) {
    return '$scope checklist:';
  }

  @override
  String qualityReviewsChecklistScope(String scope) {
    return 'Scope: memory takes effect only in $scope; no reuse across users, projects, or shows.';
  }

  @override
  String qualityReviewsAutoSampleSummary(
    int count,
    String prompt,
    String memory,
    String visual,
    String delivery,
    String hitRate,
  ) {
    return 'auto samples $count · avg prompt=$prompt chars · memory=$memory (visual=$visual, delivery=$delivery) · delivery-priority hit $hitRate%';
  }

  @override
  String qualityReviewsAutoDiagnosticsCount(int count) {
    return 'auto diagnostics $count';
  }

  @override
  String qualityReviewsAveragePrompt(String prompt) {
    return 'avg prompt=$prompt chars';
  }

  @override
  String qualityReviewsDeliveryPriorityRate(String rate) {
    return 'delivery-priority $rate%';
  }

  @override
  String get qualityReviewsTimesUnit => ' times';

  @override
  String qualityReviewsHitMemoryBuckets(String value) {
    return 'hit memory $value';
  }

  @override
  String qualityReviewsSuppressedBuckets(String value) {
    return 'suppressed buckets $value';
  }

  @override
  String qualityReviewsDirectorYieldCount(int hit, int total) {
    return 'director yield $hit/$total';
  }

  @override
  String qualityReviewsContinuityConstraintCount(int hit, int total) {
    return 'continuity constraints $hit/$total';
  }

  @override
  String qualityReviewsReferenceFrameCount(int hit, int total) {
    return 'reference frame $hit/$total';
  }

  @override
  String qualityReviewsHitBucketsInline(String value) {
    return 'hit=$value';
  }

  @override
  String qualityReviewsSuppressedBucketsInline(String value) {
    return 'suppressed=$value';
  }

  @override
  String get qualityReviewsDirectorYield => 'director yield';

  @override
  String qualityReviewsSavedChars(int chars) {
    return 'saved $chars chars';
  }

  @override
  String qualityReviewsNegativeSlim(int fragments, int chars) {
    return 'negative slim=$fragments items/$chars chars';
  }

  @override
  String qualityReviewsMemoryScopeLevel(String value) {
    return 'memory scope=$value';
  }

  @override
  String qualityReviewsContinuityCount(int count) {
    return 'continuity $count';
  }

  @override
  String get qualityReviewsReferenceFrame => 'reference frame';

  @override
  String get qualityReviewsWritebackPromotedSelected =>
      'promoted selected memory';

  @override
  String get qualityReviewsWritebackRejectedMemory =>
      'bad-case memory writeback';

  @override
  String get qualityReviewsWritebackSummaryMemory => 'review summary writeback';

  @override
  String get qualityReviewsWritebackMissingPromptSeed =>
      'selected memory missing prompt seed';

  @override
  String get qualityReviewsWritebackEmptySelectedMemory =>
      'selected memory yielded no effective fragment';

  @override
  String qualityReviewsShotId(int id) {
    return 'shot $id';
  }

  @override
  String qualityReviewsWriteMemory(String name) {
    return 'write=$name';
  }

  @override
  String qualityReviewsClearMemory(String name) {
    return 'clear=$name';
  }

  @override
  String qualityReviewsSlimSummary(int chars, int rows, int dup, int visual) {
    return 'slim $chars chars / $rows items (dup $dup / visual-only $visual)';
  }

  @override
  String qualityReviewsFocusWatchTag(String value) {
    return 'watch=$value';
  }

  @override
  String qualityReviewsHitSummary(String value) {
    return 'hit $value';
  }

  @override
  String qualityReviewsSuppressedSummary(String value) {
    return 'suppressed $value';
  }

  @override
  String qualityReviewsMemoryOptimizationScopeLine(
    String scope,
    int reviews,
    int chars,
    int rows,
    int dup,
    int visual,
  ) {
    return '$scope $reviews items · slim $chars chars / $rows items (dup $dup / visual-only $visual)';
  }

  @override
  String qualityReviewsBadCaseCount(int count) {
    return 'bad cases $count';
  }

  @override
  String qualityReviewsDialogueRiskCount(int count) {
    return 'emotion/dialogue $count';
  }

  @override
  String qualityReviewsVisualRiskCount(int count) {
    return 'realism $count';
  }

  @override
  String qualityReviewsNextStep(String value) {
    return 'next step $value';
  }

  @override
  String get qualityReviewsEmpty => '(empty)';

  @override
  String qualityReviewsDashboardRefreshPerformed(
    int rows,
    int reviews,
    int usage,
    String time,
  ) {
    return 'Snapshot refreshed: $rows review facts · reviews=$reviews · usage=$usage · $time';
  }

  @override
  String qualityReviewsDashboardRefreshSkipped(String time) {
    return 'Snapshot unchanged · fresh snapshot skipped refresh · $time';
  }

  @override
  String get qualityReviewsFreshnessUnknownAge => 'unknown_age';

  @override
  String get qualityReviewsFreshnessNever => 'never';

  @override
  String get qualityReviewsFreshnessNone => 'none';

  @override
  String get qualityReviewsFreshnessStale => 'STALE';

  @override
  String get qualityReviewsFreshnessFresh => 'fresh';

  @override
  String get qualityReviewsStageStorySkeleton => 'Story skeleton';

  @override
  String get qualityReviewsStageAdaptationStrategy => 'Adaptation strategy';

  @override
  String get qualityReviewsStageDirectorPlanning => 'Director planning';

  @override
  String get qualityReviewsStageStoryboardTable => 'Storyboard table';

  @override
  String get qualityReviewsStageStoryboardPanel => 'Storyboard panel';

  @override
  String get qualityReviewsStageVideoPrompt => 'Video prompt';

  @override
  String get qualityReviewsSourceAuto => 'source=auto';

  @override
  String get qualityReviewsFieldTargetType => 'targetType';

  @override
  String get qualityReviewsFieldTargetId => 'targetId';

  @override
  String get qualityReviewsFieldSource => 'source';

  @override
  String get qualityReviewsFieldOverallScore => 'overallScore';

  @override
  String get qualityReviewsFieldStage => 'stage';

  @override
  String get qualityReviewsFieldGrade => 'grade';

  @override
  String get qualityReviewsFieldComments => 'comments';

  @override
  String get qualityReviewsFieldPassed => 'passed';

  @override
  String get qualityReviewsFieldIsBadCase => 'isBadCase';

  @override
  String get qualityReviewsFieldBadCaseCategory => 'badCaseCategory';

  @override
  String get qualityReviewsDeliveryTag => 'delivery';

  @override
  String get qualityReviewsAutoTag => 'auto';

  @override
  String get qualityReviewsMemoryTag => 'memory';

  @override
  String get qualityReviewsNotAvailable => 'n/a';

  @override
  String qualityReviewsReviewRowTitle(
    String targetType,
    String source,
    String score,
  ) {
    return '$targetType · $source · score=$score';
  }

  @override
  String qualityReviewsStageGradeRow(String stage, int a, int b, int c, int d) {
    return '$stage · A $a / B $b / C $c / D $d';
  }

  @override
  String get teamWorkspaceInviteTokenAutofillHint =>
      'Invite token was auto-filled from the link. You can accept directly.';

  @override
  String get teamWorkspaceOnlyPersonalTitle =>
      'Only Personal workspace is active';

  @override
  String get teamWorkspaceOnlyPersonalBody =>
      'To start team collaboration, create an enterprise workspace first, then invite members from member management. Projects, jobs, and Agent context can then share the same team scope.';

  @override
  String get teamWorkspaceArchivedFlag => ', archived';

  @override
  String get teamWorkspaceCurrentFlag => ', current workspace';

  @override
  String teamWorkspaceRowSemantics(
    String name,
    String type,
    String role,
    String archived,
    String current,
  ) {
    return '$name, $type workspace, your role is $role$archived$current';
  }

  @override
  String teamWorkspaceActionTooltip(String action, String workspace) {
    return '$action $workspace';
  }

  @override
  String get teamWorkspaceEnterEnterpriseName =>
      'Please enter enterprise workspace name';

  @override
  String get teamWorkspaceCreated => 'Enterprise workspace created';

  @override
  String teamWorkspaceCreateFailed(String error) {
    return 'Create failed: $error';
  }

  @override
  String get teamWorkspaceEnterInviteToken => 'Please enter invite token';

  @override
  String get teamWorkspaceInviteAcceptedAndJoined =>
      'Invite accepted and joined workspace';

  @override
  String teamWorkspaceAcceptInviteFailed(String error) {
    return 'Accept invite failed: $error';
  }

  @override
  String get teamWorkspaceArchiveDialogTitle => 'Archive enterprise workspace?';

  @override
  String get teamWorkspaceArchiveDialogBody =>
      'After archiving, this workspace is hidden from default list; if it is current workspace, context switches back to Personal.';

  @override
  String get teamWorkspaceArchiveAction => 'Archive';

  @override
  String get teamWorkspaceArchived => 'Archived';

  @override
  String get teamWorkspaceRestored => 'Restored';

  @override
  String teamWorkspaceOpFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String teamWorkspaceSwitchedTo(String name) {
    return 'Switched to $name';
  }

  @override
  String teamWorkspaceSwitchFailed(String error) {
    return 'Switch failed: $error';
  }

  @override
  String get teamWorkspaceLoginRequired =>
      'Sign in to manage enterprise workspaces.';

  @override
  String get teamWorkspaceTitle => 'Team workspaces';

  @override
  String get teamWorkspaceIntro =>
      'List your accessible workspaces (including Personal), create enterprise workspaces, and allow owner/admin to archive or restore them.';

  @override
  String get teamWorkspaceCreating => 'Creating…';

  @override
  String get teamWorkspaceCreateAction => 'Create';

  @override
  String get teamWorkspaceJoining => 'Joining…';

  @override
  String get teamWorkspaceAcceptInviteAction => 'Accept invite';

  @override
  String get teamWorkspaceShowArchivedToggle =>
      'Show archived enterprise workspaces';

  @override
  String get teamWorkspaceLoading => 'Loading…';

  @override
  String get teamWorkspaceRefreshList => 'Refresh list';

  @override
  String get teamWorkspaceNoListDataHint =>
      'No list data yet; tap \"Refresh list\".';

  @override
  String get teamWorkspaceNoWorkspacesHint =>
      'No workspace found (unexpected); normally Personal is always available.';

  @override
  String get teamWorkspaceArchivedBadge => 'archived';

  @override
  String get teamWorkspaceCurrentBadge => 'Current';

  @override
  String get teamWorkspaceManageMembersAction => 'Manage members';

  @override
  String get teamWorkspaceMembersShortAction => 'Members';

  @override
  String get teamWorkspaceManageInvitesAction => 'Manage invites';

  @override
  String get teamWorkspaceInvitesShortAction => 'Invites';

  @override
  String get teamWorkspaceSwitchActionLabel => 'Switch to workspace';

  @override
  String get teamWorkspaceSwitchHereAction => 'Switch here';

  @override
  String get teamWorkspaceArchiveActionLabel => 'Archive workspace';

  @override
  String get teamWorkspaceRestoreActionLabel => 'Restore workspace';

  @override
  String get teamWorkspaceRestoreAction => 'Restore';

  @override
  String teamWorkspaceInviteMetaLine(String status, String expiry) {
    return 'Status: $status · expires: $expiry';
  }

  @override
  String get teamWorkspaceInviteStatusRevoked => 'Revoked';

  @override
  String get teamWorkspaceInviteStatusExpired => 'Expired';

  @override
  String get teamWorkspaceInviteStatusValid => 'Valid';

  @override
  String get teamWorkspaceInviteStatusAccepted => 'Accepted';

  @override
  String get teamWorkspaceAuditMemberUpserted => 'Member added or updated';

  @override
  String get teamWorkspaceAuditMemberRoleChanged => 'Member role changed';

  @override
  String get teamWorkspaceAuditMemberRemoved => 'Member removed';

  @override
  String get teamWorkspaceAuditMemberLeft => 'Member left workspace';

  @override
  String get teamWorkspaceAuditOwnerTransferred => 'Owner transferred';

  @override
  String get teamWorkspaceAuditInviteCreated => 'Invite created';

  @override
  String get teamWorkspaceAuditInviteResent => 'Invite resent';

  @override
  String get teamWorkspaceAuditInviteRevoked => 'Invite revoked';

  @override
  String get teamWorkspaceAuditInviteAccepted => 'Invite accepted';

  @override
  String get teamWorkspaceTransferOwnerTitle => 'Transfer owner';

  @override
  String teamWorkspaceTransferOwnerBody(
    String workspace,
    String fromUser,
    String toUser,
  ) {
    return 'Transfer owner of $workspace from $fromUser to $toUser.\n\nAfter confirmation, current owner is downgraded to admin and target member is promoted to owner.';
  }

  @override
  String get teamWorkspaceConfirmTransferOwner => 'Confirm transfer';

  @override
  String teamWorkspaceMembersDialogTitle(String workspace) {
    return 'Members · $workspace';
  }

  @override
  String get teamWorkspaceUserUuidLabel => 'User UUID';

  @override
  String get teamWorkspaceRoleLabel => 'Role';

  @override
  String get teamWorkspaceEnterUserUuid => 'Please enter user UUID';

  @override
  String get teamWorkspaceAddingMember => 'Adding…';

  @override
  String get teamWorkspaceAddMemberAction => 'Add member';

  @override
  String get teamWorkspaceRefreshAction => 'Refresh';

  @override
  String get teamWorkspaceInviteEmailLabel => 'Invite email';

  @override
  String get teamWorkspaceEnterInviteEmail => 'Please enter invite email';

  @override
  String get teamWorkspaceGeneratingInvite => 'Generating invite…';

  @override
  String get teamWorkspaceGenerateInviteLinkAction => 'Generate invite link';

  @override
  String get teamWorkspaceOpsStatsTitle => 'Internal ops stats';

  @override
  String get teamWorkspaceReading => 'Reading…';

  @override
  String get teamWorkspaceRefreshStats => 'Refresh stats';

  @override
  String teamWorkspaceStatsMembers(int count) {
    return 'Members $count';
  }

  @override
  String teamWorkspaceStatsProjects(int count) {
    return 'Projects $count';
  }

  @override
  String teamWorkspaceStatsActiveJobs(int count) {
    return 'Active jobs $count';
  }

  @override
  String get teamWorkspacePlatformInvitesTitle => 'Platform invites (server)';

  @override
  String get teamWorkspaceIncludeRevokedInvites => 'Include revoked invites';

  @override
  String get teamWorkspaceShowExpiredInvites => 'Show expired invites';

  @override
  String get teamWorkspaceSearchInvitesHint =>
      'Search invites (email / role / status)';

  @override
  String get teamWorkspaceNoInviteRecords =>
      'No invite records yet. Generate one or load more from server.';

  @override
  String teamWorkspaceInviteTokenLine(String token) {
    return 'invite token: $token';
  }

  @override
  String get teamWorkspaceRefreshInviteLinkTooltip =>
      'Refresh link (extend expiry and rotate token)';

  @override
  String get teamWorkspaceRevokeInviteTooltip => 'Revoke invite';

  @override
  String get teamWorkspaceCopyInviteInfoTooltip => 'Copy invite info';

  @override
  String teamWorkspaceCopiedInvite(String email) {
    return 'Copied invite: $email';
  }

  @override
  String get teamWorkspaceLoadMoreInvites => 'Load more invites';

  @override
  String get teamWorkspaceActivityRecordsTitle => 'Activity records';

  @override
  String get teamWorkspaceSearchActivityHint =>
      'Search activity (action / actor / target / role / email)';

  @override
  String get teamWorkspaceNoActivityRecords => 'No activity records.';

  @override
  String get teamWorkspaceLoadMoreActivity => 'Load more activity';

  @override
  String teamWorkspaceCurrentOwnerLine(String userId) {
    return 'Current owner: $userId';
  }

  @override
  String get teamWorkspaceSearchMembersHint => 'Search members (UUID / role)';

  @override
  String get teamWorkspaceNoMembers => 'No members (unexpected).';

  @override
  String get teamWorkspaceTransferOwnerTooltip => 'Transfer owner';

  @override
  String get teamWorkspaceRemoveMemberTooltip => 'Remove member';

  @override
  String get teamWorkspaceLeftWorkspace => 'Left this workspace';

  @override
  String get teamWorkspaceLeaving => 'Leaving…';

  @override
  String get teamWorkspaceLeaveWorkspaceAction => 'Leave workspace';

  @override
  String get teamWorkspaceRoleOptionMember => 'member';

  @override
  String get teamWorkspaceRoleOptionAdmin => 'admin';

  @override
  String get teamWorkspaceStatusOptionPending => 'pending';

  @override
  String get teamWorkspaceStatusOptionAccepted => 'accepted';

  @override
  String get teamWorkspaceStatusOptionRevoked => 'revoked';

  @override
  String get teamWorkspaceStatusOptionAll => 'all';

  @override
  String teamWorkspaceInvitesDialogTitle(String workspace) {
    return 'Invites · $workspace';
  }

  @override
  String get teamWorkspaceGenerating => 'Generating…';

  @override
  String get teamWorkspaceGenerateInviteAction => 'Generate invite';

  @override
  String get teamWorkspaceRefreshInvitesAction => 'Refresh invites';

  @override
  String teamWorkspaceCopiedInviteCount(int count) {
    return 'Copied $count invites';
  }

  @override
  String get teamWorkspaceBulkCopyAction => 'Bulk copy';

  @override
  String get teamWorkspaceClearSelectionAction => 'Clear selection';

  @override
  String get teamWorkspaceStatusLabel => 'Status';

  @override
  String get teamWorkspacePageSizeLabel => 'Page size';

  @override
  String get teamWorkspaceNoInvitesForCurrentFilters =>
      'No invites for current filters.';

  @override
  String teamWorkspacePagingLine(int page, int pages, int total) {
    return 'Page $page / $pages · total $total';
  }

  @override
  String get teamWorkspacePrevPageAction => 'Previous';

  @override
  String get teamWorkspaceNextPageAction => 'Next';

  @override
  String get teamWorkspaceResendInviteLinkAction => 'Resend link';

  @override
  String get teamWorkspaceRevokeAction => 'Revoke';

  @override
  String get teamWorkspaceRoleOptionOwner => 'owner';

  @override
  String teamWorkspaceMemberPrimaryOwnerLine(String role) {
    return '$role · primary owner';
  }

  @override
  String get teamWorkspaceEnterpriseNameLabel => 'Enterprise workspace name';

  @override
  String get teamWorkspaceInviteTokenInputLabel =>
      'Invite token (accept and join)';

  @override
  String get platformStatusRecoveredHealthy =>
      'Platform status is healthy again';

  @override
  String get platformStatusDegradedWarning =>
      'Platform degraded; check SLI and hot endpoints';

  @override
  String get platformStatusNotRefreshed => 'Not refreshed';

  @override
  String get platformStatusTitle => 'Platform status';

  @override
  String platformStatusWindowMinutes(int minutes) {
    return '$minutes minute window';
  }

  @override
  String platformStatusWindowHours(int hours) {
    return '$hours hour window';
  }

  @override
  String get platformStatusRefreshAction => 'Refresh';

  @override
  String get platformStatusIntro =>
      'Inspect health, readiness, version, SLI health, and endpoint request overview.';

  @override
  String platformStatusLastRefreshed(String time) {
    return 'Last refreshed: $time';
  }

  @override
  String get platformStatusAutoRefresh => 'Auto polling';

  @override
  String get platformStatusHealthy => 'healthy';

  @override
  String get platformStatusDegraded => 'degraded';

  @override
  String platformStatusVersionLine(
    String service,
    String version,
    String gitSha,
  ) {
    return 'Version: $service $version$gitSha';
  }

  @override
  String get platformStatusSliSnapshot => 'SLI snapshot';

  @override
  String get platformStatusHotEndpoints => 'Hot endpoints';

  @override
  String get platformStatusChipHealth => 'Health';

  @override
  String get platformStatusChipReady => 'Ready';

  @override
  String get platformStatusChipSli => 'SLI';

  @override
  String get platformStatusChipEndpoints => 'Endpoints';

  @override
  String get platformStatusChipDegraded => 'Degraded';

  @override
  String platformStatusSliTileSubtitle(
    String path,
    String p95Ms,
    String successRate,
  ) {
    return '$path · P95 ${p95Ms}ms · success $successRate%';
  }

  @override
  String platformStatusRequests(int count) {
    return 'requests $count';
  }

  @override
  String platformStatusEndpointTileSubtitle(
    int total,
    String successRate,
    String p95Ms,
  ) {
    return 'total $total · success $successRate% · P95 ${p95Ms}ms';
  }

  @override
  String platformStatusServerErrors(int count) {
    return '5xx $count';
  }

  @override
  String get adminConsoleTitle => 'Admin console';

  @override
  String get adminConsoleIntro =>
      'Internal governance surface. Unified search over users, workspace, project, and job; supports user governance, workspace context repair, member remediation, and workspace/project ownership, archive, and internal-note governance.';

  @override
  String get adminConsoleSearchLabel =>
      'Search email / workspace / project / job';

  @override
  String get adminConsoleSearchHint =>
      'Supports UUID prefix, project numeric_id, and status/kind keywords';

  @override
  String get adminConsoleSearchAction => 'Search';

  @override
  String get adminConsoleClearDetailAction => 'Clear detail';

  @override
  String get adminConsoleGroupUsers => 'Users';

  @override
  String get adminConsoleEmptyUsers => 'No matching users';

  @override
  String get adminConsoleGroupWorkspaces => 'Workspace';

  @override
  String get adminConsoleEmptyWorkspaces => 'No matching workspace';

  @override
  String get adminConsoleGroupProjects => 'Project';

  @override
  String get adminConsoleEmptyProjects => 'No matching project';

  @override
  String get adminConsoleGroupJobs => 'Job';

  @override
  String get adminConsoleEmptyJobs => 'No matching job';

  @override
  String adminConsoleUserHitSummary(
    String plan,
    String status,
    int workspaces,
    int projects,
    int activeJobs,
  ) {
    return 'plan $plan · $status · ws $workspaces · project $projects · active job $activeJobs';
  }

  @override
  String adminConsoleWorkspaceHitSummary(
    String workspaceType,
    int members,
    int projects,
    int activeJobs,
    String archivedSuffix,
  ) {
    return '$workspaceType · member $members · project $projects · active job $activeJobs$archivedSuffix';
  }

  @override
  String get adminConsoleArchivedSuffix => ' · archived';

  @override
  String get adminConsoleNoWorkspace => 'no workspace';

  @override
  String adminConsoleProjectHitSummary(
    int numericId,
    String workspaceName,
    String owner,
    String archivedSuffix,
  ) {
    return '#$numericId · $workspaceName · $owner$archivedSuffix';
  }

  @override
  String adminConsoleJobHitTitle(String kind, String status) {
    return '$kind · $status';
  }

  @override
  String adminConsoleJobHitSummary(
    String owner,
    String projectNumericId,
    String createdAt,
  ) {
    return '$owner · project $projectNumericId · $createdAt';
  }

  @override
  String adminConsoleChipPlan(String value) {
    return 'plan $value';
  }

  @override
  String adminConsoleChipWorkspace(int value) {
    return 'workspace $value';
  }

  @override
  String adminConsoleChipProject(int value) {
    return 'project $value';
  }

  @override
  String adminConsoleChipActiveJob(int value) {
    return 'active job $value';
  }

  @override
  String adminConsoleChipApiKey(int value) {
    return 'api key $value';
  }

  @override
  String adminConsoleChipUnreadNotif(int value) {
    return 'unread notif $value';
  }

  @override
  String get adminConsoleSectionMemberships => 'Memberships';

  @override
  String get adminConsoleSectionRecentJobs => 'Recent jobs';

  @override
  String get adminConsoleSectionGovernanceAudit => 'Governance audit';

  @override
  String get adminConsoleGovernanceActionsTitle => 'Governance actions';

  @override
  String get adminConsoleStatusActive => 'Active';

  @override
  String get adminConsoleStatusSuspended => 'Suspended';

  @override
  String get adminConsoleSuspendReasonLabel => 'Suspension reason';

  @override
  String get adminConsoleSuspendReasonHint =>
      'For example: abuse, refund dispute, or manual risk-control hit';

  @override
  String get adminConsoleSuspendReasonDisabledHint =>
      'Suspension reason is not saved when user is active';

  @override
  String get adminConsoleInternalNoteLabel => 'Internal note';

  @override
  String get adminConsoleInternalNoteHint =>
      'Context for operations / support / risk-control teammates';

  @override
  String get adminConsoleDailyQuotaOverrideTitle => 'Daily quota override';

  @override
  String get adminConsoleDailyQuotaNotOverridden =>
      'No override currently; package default quota is used.';

  @override
  String adminConsoleDailyQuotaCurrentOverride(int value) {
    return 'Current override: $value';
  }

  @override
  String get adminConsoleQuotaActionPreserve => 'Keep current';

  @override
  String get adminConsoleQuotaActionClear => 'Clear override';

  @override
  String get adminConsoleQuotaActionSet => 'Set quota';

  @override
  String get adminConsoleDailyQuotaInputExample => 'e.g. 500';

  @override
  String get adminConsoleDailyQuotaInputDisabledHint =>
      'Only effective when \"Set quota\" is selected';

  @override
  String get adminConsoleSaving => 'Saving...';

  @override
  String get adminConsoleSaveGovernanceSettings => 'Save governance settings';

  @override
  String get adminConsoleWorkspaceContextRepairTitle =>
      'Workspace context repair';

  @override
  String get adminConsoleWorkspaceContextRepairIntro =>
      'Used for scenarios where current_workspace points to an invalid workspace, or membership has changed but user is still stuck on old workspace.';

  @override
  String get adminConsoleWorkspaceContextRebuildAndSwitchPersonal =>
      'Rebuild and switch to Personal';

  @override
  String get adminConsoleWorkspaceContextSwitchPersonal => 'Switch to Personal';

  @override
  String adminConsoleWorkspaceContextSwitchTo(String workspaceName) {
    return 'Switch to $workspaceName';
  }

  @override
  String get adminConsoleWorkspaceContextRepairing =>
      'Repairing workspace context...';

  @override
  String get adminConsoleWorkspaceGovernanceTitle => 'Workspace governance';

  @override
  String get adminConsoleWorkspaceGovernancePersonalHint =>
      'Personal workspace cannot be archived; internal notes (metadata.internalOps) can be maintained.';

  @override
  String get adminConsoleWorkspaceGovernanceEnterpriseHint =>
      'Enterprise workspace can be archived (soft-frozen) or restored; internal notes are written to metadata.internalOps.';

  @override
  String get adminConsoleLifecyclePreserve => 'Keep lifecycle unchanged';

  @override
  String get adminConsoleLifecycleArchive => 'Archive';

  @override
  String get adminConsoleLifecycleRestore => 'Restore';

  @override
  String get adminConsoleNoteActionPreserve => 'Keep note unchanged';

  @override
  String get adminConsoleNoteActionClear => 'Clear note';

  @override
  String get adminConsoleNoteActionSet => 'Write/Update note';

  @override
  String get adminConsoleInternalNoteBodyLabel => 'Internal note body';

  @override
  String get adminConsoleInternalNoteBodySubmitHint =>
      'Submitted only when \"Write/Update note\" is selected';

  @override
  String get adminConsoleInternalNoteBodyEditableHint =>
      'Editable after selecting \"Write/Update note\"';

  @override
  String get adminConsoleSaveGovernance => 'Save governance';

  @override
  String get adminConsoleWorkspaceMemberRemediationTitle =>
      'Member remediation';

  @override
  String get adminConsoleWorkspaceMemberRemediationHint =>
      'Internal ops can directly add member, change role, or remove member. Removal also falls back current workspace and clears stale project ACL entries under this workspace.';

  @override
  String get adminConsoleMemberUserIdLabel => 'Member userId';

  @override
  String get adminConsoleMemberUserIdHint =>
      'Enter user UUID to add member or change role';

  @override
  String get adminConsoleRoleMember => 'member';

  @override
  String get adminConsoleRoleAdmin => 'admin';

  @override
  String get adminConsoleProcessing => 'Processing...';

  @override
  String get adminConsoleUpsertMemberAction => 'Add member / change role';

  @override
  String get adminConsoleSetAsMember => 'Set as member';

  @override
  String get adminConsoleSetAsAdmin => 'Set as admin';

  @override
  String get adminConsoleRemoveAction => 'Remove';

  @override
  String get adminConsoleOwnerTransferHint => 'Use owner transfer for owner';

  @override
  String get adminConsoleWorkspaceOwnerRemediationTitle => 'Owner remediation';

  @override
  String get adminConsoleWorkspaceOwnerRemediationPersonalHint =>
      'Owner transfer is not allowed for personal workspace.';

  @override
  String get adminConsoleWorkspaceOwnerRemediationHint =>
      'Internal ops can directly remediate workspace owner. Target user must already be a workspace member, and previous owner is automatically downgraded to admin.';

  @override
  String get adminConsoleTargetOwnerUserIdLabel => 'Target owner userId';

  @override
  String get adminConsoleTargetOwnerUserIdHint => 'Enter target member UUID';

  @override
  String get adminConsoleTransferOwnerAction => 'Transfer owner';

  @override
  String get adminConsoleSetAsOwner => 'Set as owner';

  @override
  String get adminConsoleAclSummaryTitle => 'ACL summary';

  @override
  String adminConsoleRoleCountOwner(int count) {
    return 'owner $count';
  }

  @override
  String adminConsoleRoleCountAdmin(int count) {
    return 'admin $count';
  }

  @override
  String adminConsoleRoleCountMember(int count) {
    return 'member $count';
  }

  @override
  String get adminConsoleNoProjectAclSummary =>
      'No project ACL summary in current workspace';

  @override
  String adminConsoleExplicitAclCount(int count) {
    return 'explicit $count';
  }

  @override
  String adminConsoleEditorCount(int count) {
    return 'editor $count';
  }

  @override
  String adminConsoleViewerCount(int count) {
    return 'viewer $count';
  }

  @override
  String get adminConsoleViewAction => 'View';

  @override
  String get adminConsoleBatchProjectGovernanceTitle =>
      'Batch project governance';

  @override
  String get adminConsoleBatchProjectGovernanceHint =>
      'Batch apply archive / restore / internal note writes to selected projects under current workspace for clustered ACL and governance remediation.';

  @override
  String get adminConsoleBatchLifecyclePreserve =>
      'Keep archive state unchanged';

  @override
  String get adminConsoleBatchLifecycleArchive => 'Batch archive';

  @override
  String get adminConsoleBatchLifecycleRestore => 'Batch restore';

  @override
  String get adminConsoleBatchNotePreserve => 'Keep note unchanged';

  @override
  String get adminConsoleBatchNoteClear => 'Clear note';

  @override
  String get adminConsoleBatchNoteSet => 'Write note';

  @override
  String get adminConsoleBatchNoteBodyLabel => 'Batch internal note';

  @override
  String get adminConsoleBatchNoteBodySubmitHint =>
      'Submitted only when \"Write note\" is selected';

  @override
  String get adminConsoleBatchNoteBodyEditableHint =>
      'Editable after selecting \"Write note\"';

  @override
  String adminConsoleBatchApplyAction(int count) {
    return 'Batch apply to $count projects';
  }

  @override
  String get adminConsoleSectionMembers => 'Members';

  @override
  String get adminConsoleSectionRecentProjects => 'Recent projects';

  @override
  String get adminConsoleProjectOwnerRemediationTitle =>
      'Project owner remediation';

  @override
  String get adminConsoleProjectOwnerRemediationHint =>
      'Internal ops can directly remediate project owner. Target user must already be a member in the project workspace. If ACL is enabled, old owner with member role keeps editor access automatically.';

  @override
  String get adminConsoleTargetProjectOwnerUserIdHint =>
      'Enter target workspace member UUID';

  @override
  String get adminConsoleRepairProjectOwnerAction => 'Repair project owner';

  @override
  String get adminConsoleProjectGovernanceTitle => 'Project governance';

  @override
  String get adminConsoleProjectGovernanceHint =>
      'After archive, the project is hidden from member lists and aggregate statistics, and all project-scope APIs return 403; restore reverses this. Internal note is written to metadata.internalOps.';

  @override
  String adminConsoleProjectTitleWithName(String name, int numericId) {
    return '$name (#$numericId)';
  }

  @override
  String adminConsoleProjectTitle(int numericId) {
    return 'Project #$numericId';
  }

  @override
  String get adminConsoleSectionExplicitAclMembers => 'Explicit ACL members';

  @override
  String get adminConsoleSectionWorkspaceCandidates =>
      'Workspace candidate members';

  @override
  String get adminConsoleNoData => 'No data yet';

  @override
  String get adminConsoleErrSearchAtLeast2Chars =>
      'Please enter at least 2 characters';

  @override
  String get adminConsoleErrSuspendReasonRequired =>
      'Suspension reason is required when suspending a user';

  @override
  String get adminConsoleErrDailyQuotaPositiveRequired =>
      'A positive integer is required when setting daily quota';

  @override
  String get adminConsoleErrInternalNoteRequired =>
      'Internal note content is required when setting note';

  @override
  String get adminConsoleErrMemberUserIdRequired =>
      'Member userId cannot be empty';

  @override
  String get adminConsoleErrMemberRoleRequired =>
      'Role is required when adding or updating a member';

  @override
  String get adminConsoleErrTargetOwnerUserIdRequired =>
      'Target owner userId cannot be empty';

  @override
  String get adminConsoleErrAtLeastOneProjectRequired =>
      'Select at least one project';

  @override
  String get adminConsoleErrBatchNoteRequired =>
      'Batch note content is required when writing notes';

  @override
  String get contentComplianceWorkspacePersonalScope =>
      'Personal / direct user scope';

  @override
  String get contentComplianceOpenProject => 'Open project';

  @override
  String get contentComplianceOpenScriptProject => 'Open script project';

  @override
  String get contentComplianceOpenStoryboardProject =>
      'Open storyboard project';

  @override
  String get contentComplianceOpenAssetProject => 'Open asset project';

  @override
  String get contentComplianceOpenNovelProject => 'Open novel project';

  @override
  String get contentComplianceOpenUserContext => 'View user context';

  @override
  String get contentComplianceOpenContext => 'Open context';

  @override
  String get contentComplianceOwnerUnclaimed => 'Unclaimed';

  @override
  String get contentComplianceEscalationCriticalUnclaimed =>
      'critical unclaimed';

  @override
  String get contentComplianceEscalationStalledClaimed => 'claimed stalled';

  @override
  String get contentComplianceEscalationOverCapacity => 'reviewer overloaded';

  @override
  String get contentComplianceEscalationEscalated72h => '72h escalated';

  @override
  String get contentComplianceEscalationUrgent => 'Urgent';

  @override
  String get contentComplianceEscalationClosed => 'Closed';

  @override
  String get contentComplianceEscalationWatch => 'Watch';

  @override
  String get contentComplianceAlertHintCriticalUnclaimed =>
      'Start by bulk-claiming critical unclaimed items.';

  @override
  String get contentComplianceAlertHintOverCapacity =>
      'Preview or run auto-rebalance first.';

  @override
  String get contentComplianceAlertHintStalledClaimed =>
      'Handle stalled claimed items first (reassign or converge).';

  @override
  String get contentComplianceAlertHintEscalated72h =>
      'Prioritize clearing 72h non-converged items.';

  @override
  String get contentComplianceAlertHintDefault =>
      'Review this layer and address high-risk items first.';

  @override
  String get contentComplianceSnackNoCriticalUnclaimedBulkClaim =>
      'No critical unclaimed items available for bulk claim.';

  @override
  String contentComplianceSnackSelectedStalledClaimed(int count) {
    return 'Selected $count stalled claimed items; you can reassign or process them.';
  }

  @override
  String contentComplianceSnackSelected72hUnconverged(int count) {
    return 'Selected $count 72h non-converged items; you can reassign or process them.';
  }

  @override
  String contentComplianceSnackSelectedCriticalUnclaimed(int count) {
    return 'Selected $count critical unclaimed items.';
  }

  @override
  String contentComplianceSnackSelected72hItems(int count) {
    return 'Selected $count 72h non-converged items.';
  }

  @override
  String get contentComplianceSnackRestoredDefaultActionOrder =>
      'Restored default action order.';

  @override
  String get contentComplianceBulkClaim => 'Bulk claim';

  @override
  String get contentComplianceBulkResolve => 'Bulk resolve';

  @override
  String get contentComplianceBulkDismiss => 'Bulk dismiss';

  @override
  String get contentComplianceBulkGeneric => 'Bulk action';

  @override
  String contentComplianceBulkConfirmBody(String verb, int count) {
    return 'Run $verb on $count reports?';
  }

  @override
  String get contentComplianceBulkConfirmNoteReuse =>
      '\n\nWill reuse the current resolution note.';

  @override
  String contentComplianceBulkResult(
    String verb,
    int succeeded,
    int failed,
    int remainingAlerts,
    int criticalAlerts,
  ) {
    return '$verb finished: succeeded $succeeded, failed $failed; $remainingAlerts alerts remaining ($criticalAlerts high priority).';
  }

  @override
  String contentComplianceCsvCopied(int count) {
    return 'Copied filtered queue CSV ($count rows).';
  }

  @override
  String get contentComplianceFillReviewerFirst =>
      'Enter a target reviewer first.';

  @override
  String get contentComplianceReassignTitle => 'Bulk reassign';

  @override
  String contentComplianceReassignBody(int count, String assignee) {
    return 'Reassign $count reports to $assignee?';
  }

  @override
  String contentComplianceReassignResult(
    String assignee,
    int succeeded,
    int failed,
  ) {
    return 'Reassigned to $assignee: succeeded $succeeded, failed $failed.';
  }

  @override
  String get contentComplianceAutoRebalanceNoOverload =>
      'No overloaded reviewers; auto-rebalance is not needed.';

  @override
  String get contentComplianceAutoRebalanceTitlePreview =>
      'Preview auto-rebalance';

  @override
  String get contentComplianceAutoRebalanceTitleExecute => 'Run auto-rebalance';

  @override
  String contentComplianceAutoRebalanceBodyPreview(int limit) {
    return 'Preview reassignment plan at capacity threshold ($limit); nothing will be written.';
  }

  @override
  String contentComplianceAutoRebalanceBodyExecute(int limit) {
    return 'Run automatic reassignment at capacity threshold ($limit) and write audit records.';
  }

  @override
  String get contentComplianceStartPreview => 'Start preview';

  @override
  String get contentComplianceExecuteNow => 'Run now';

  @override
  String contentComplianceAutoRebalanceResultPreview(
    int planned,
    int capacity,
  ) {
    return 'Auto-rebalance preview: $planned moves suggested (capacity $capacity).';
  }

  @override
  String contentComplianceAutoRebalanceResultExecute(
    int planned,
    int executed,
    int overCapacityRemaining,
    int remainingAlerts,
  ) {
    return 'Auto-rebalance done: planned $planned, executed $executed; over_capacity remaining $overCapacityRemaining, $remainingAlerts alerts total.';
  }

  @override
  String contentComplianceAuditTitle(String reportId) {
    return 'Report audit · $reportId';
  }

  @override
  String get contentComplianceAuditEmpty => 'No audit records to display.';

  @override
  String get contentComplianceTitle => 'Content & compliance';

  @override
  String get contentComplianceIntro =>
      'One place for user-submitted content reports and internal-ops claim/resolve review queues.';

  @override
  String get contentComplianceSubmitReportTitle => 'Submit report';

  @override
  String get contentComplianceTargetUuidHint => 'Enter reported object UUID';

  @override
  String get contentComplianceDetailLabel => 'Additional details';

  @override
  String get contentComplianceDetailHint =>
      'Add context, timeline, or risk description';

  @override
  String get contentComplianceSubmitting => 'Submitting…';

  @override
  String get contentComplianceSubmitReport => 'Submit report';

  @override
  String get contentComplianceQueueTitle => 'Review queue';

  @override
  String get contentComplianceClearFilters => 'Clear filters';

  @override
  String get contentComplianceRefresh => 'Refresh';

  @override
  String get contentComplianceCopyCsv => 'Copy CSV';

  @override
  String contentComplianceTopActionSummary(
    String title,
    int count,
    String hint,
  ) {
    return 'Primary action: $title ($count)\n$hint';
  }

  @override
  String get contentComplianceViewLayer => 'View this layer';

  @override
  String get contentComplianceRestoreDefaultActionOrder =>
      'Restore default action order';

  @override
  String get contentCompliancePreviewRebalanceShort => 'Preview rebalance';

  @override
  String get contentComplianceExecuteRebalanceShort => 'Run rebalance';

  @override
  String contentComplianceSnackSelectedCriticalReadyClaim(int count) {
    return 'Selected $count critical unclaimed items; you can bulk claim.';
  }

  @override
  String get contentComplianceSelectCriticalUnclaimed =>
      'Select critical unclaimed';

  @override
  String get contentComplianceSnackNoCriticalUnclaimedInList =>
      'No critical unclaimed items in the current list for bulk claim.';

  @override
  String get contentComplianceBulkClaimOneClick => 'Bulk claim (one click)';

  @override
  String get contentComplianceSelectStalled => 'Select stalled';

  @override
  String get contentCompliancePreviewStalledRebalance =>
      'Preview stalled rebalance';

  @override
  String get contentComplianceSelect72hUnconverged =>
      'Select 72h non-converged';

  @override
  String get contentComplianceClaimedOnly => 'Claimed only';

  @override
  String get contentComplianceOwnerChipUnclaimed => 'owner: unclaimed';

  @override
  String contentComplianceOwnerChip(String owner) {
    return 'owner: $owner';
  }

  @override
  String contentComplianceEscalationChipPrefix(String stage) {
    return 'Escalation: $stage';
  }

  @override
  String contentComplianceSlaUnclaimedCritical(int count) {
    return 'critical unclaimed $count';
  }

  @override
  String contentComplianceOverloadedReviewers(int count) {
    return 'overloaded reviewers $count';
  }

  @override
  String contentComplianceRebalanceNeeded(int count) {
    return 'rebalance needed $count';
  }

  @override
  String get contentComplianceReviewerOwnerLoad => 'Reviewer / owner load';

  @override
  String contentComplianceOverCapacitySuffix(int by) {
    return ' · overloaded +$by';
  }

  @override
  String get contentComplianceEscalationRhythm => 'Escalation rhythm';

  @override
  String get contentComplianceWorkspaceHotspots => 'Workspace hotspots';

  @override
  String get contentComplianceQueueEmpty => 'No pending reports right now.';

  @override
  String get contentComplianceCopyTarget => 'Copy target';

  @override
  String get contentComplianceCopiedTargetUuid => 'Copied target UUID';

  @override
  String get contentComplianceCopyReport => 'Copy report';

  @override
  String get contentComplianceCopiedReportUuid => 'Copied report UUID';

  @override
  String get contentComplianceAdminConsoleContext => 'Admin console context';

  @override
  String get contentComplianceLoadingAudit => 'Loading audit…';

  @override
  String get contentComplianceViewAudit => 'View audit';

  @override
  String get contentComplianceBulkReassignReviewerLabel =>
      'Bulk reassign reviewer';

  @override
  String get contentComplianceBulkReassignReviewerHint =>
      'e.g. internal_ops_cn_shift_b';

  @override
  String contentComplianceSelectedCount(int count) {
    return 'Selected $count';
  }

  @override
  String get contentComplianceSelectAllOpen => 'Select all open';

  @override
  String get contentComplianceClearSelection => 'Clear selection';

  @override
  String get contentComplianceBulkReassign => 'Bulk reassign';

  @override
  String get contentComplianceResolutionNoteHint =>
      'Reused for claim / resolve when provided';

  @override
  String get contentComplianceTopSecondaryPendingOnly => 'Select pending only';

  @override
  String get contentComplianceTopSecondaryRunRebalance => 'Run auto-rebalance';

  @override
  String get contentComplianceTopSecondaryPreviewStalledRebalance =>
      'Preview stalled rebalance';

  @override
  String get contentComplianceTopSecondarySelect72hOnly =>
      'Select 72h non-converged only';

  @override
  String get contentComplianceDialogContinue => 'Continue';

  @override
  String get contentComplianceLabelSelect72hUnconverged =>
      'Select 72h non-converged';

  @override
  String get contentComplianceErrAssigneeRequired =>
      'Assignee reviewer cannot be empty.';

  @override
  String get taskCenterFieldProjectUuidOptional => 'Project UUID (optional)';

  @override
  String qualityReviewsScopeSeedLine(String line) {
    return 'Scope seed: $line';
  }

  @override
  String get projectEditorAssetHistoryTitle => 'Asset History Workbench';

  @override
  String get projectEditorAssetHistoryTypeFilterLabel =>
      'Type filter (optional)';

  @override
  String get projectEditorAssetHistoryTypeFilterHelper =>
      'Comma-separated, e.g. role,clip,props; leave empty for all';

  @override
  String get projectEditorAssetHistoryLoading => 'Loading…';

  @override
  String get projectEditorAssetHistoryQueryButton => 'Query history assets';

  @override
  String get projectEditorAssetHistoryClearFilter => 'Clear type filter';

  @override
  String get projectEditorAssetHistoryLoadingAssets =>
      'Loading history assets…';

  @override
  String get projectEditorAssetHistoryEmptyState =>
      'No data, click \"Query history assets\" to start.';

  @override
  String get projectEditorAssetHistoryImageDropdownLabel => 'History image';

  @override
  String get projectEditorAssetHistoryNoImages =>
      'This asset has no history images';

  @override
  String projectEditorAssetHistoryCurrentImage(int sortIndex, String state) {
    return 'Current image: sort=$sortIndex · state=$state';
  }

  @override
  String get projectEditorAssetHistoryNoPreview =>
      'Current image has no available preview (may be path placeholder or remote resource temporarily unavailable)';

  @override
  String get projectEditorAssetHistoryClose => 'Close';

  @override
  String get projectEditorAssetGenerationTitle => 'Asset Generation Workbench';

  @override
  String get projectEditorAssetGenerationDescription =>
      'Consolidates production asset summary, batch generation, status polling, derivative cleanup, and cover URL updates into the main project asset workflow, no longer relying solely on system probes.';

  @override
  String get projectEditorAssetGenerationClose => 'Close';

  @override
  String get projectEditorScriptsBatchAddTitle => 'Batch Add Scripts';

  @override
  String get projectEditorScriptsBatchAddCountLabel => 'Count (1-20)';

  @override
  String get projectEditorScriptsBatchAddCountHelper =>
      'Maximum 20 per batch to avoid accidental operations.';

  @override
  String get projectEditorScriptsBatchAddNamePrefixLabel => 'Name prefix';

  @override
  String get projectEditorScriptsBatchAddContentLabel =>
      'Default script content';

  @override
  String get projectEditorScriptsBatchAddCancel => 'Cancel';

  @override
  String get projectEditorScriptsBatchAddCreate => 'Create';

  @override
  String get projectEditorScriptsBatchAddCountError =>
      'Count must be an integer between 1-20';

  @override
  String get projectEditorScriptsBatchAddDefaultPrefix => 'New Script';

  @override
  String get projectEditorScriptsBatchAddDefaultContent =>
      'Plot synopsis to be added.';

  @override
  String projectEditorScriptsBatchAddSuccess(int count) {
    return 'Created $count scripts in batch';
  }

  @override
  String get projectEditorProbeTasksZeroItems => '0 items';

  @override
  String get projectEditorProbeTasksZeroClasses => '0 classes';

  @override
  String projectEditorProbeTasksCompatGetTaskApi(int total, int count) {
    return 'compat get-task-api (GET jobs/page): total=$total · $count items on this page';
  }

  @override
  String get projectEditorProbeProjectsZeroItems => '0 items';

  @override
  String projectEditorProbeProjectsCompatList(String line) {
    return 'GET …/projects (compat list): $line';
  }

  @override
  String get projectEditorProbeScriptsZeroItems => '0 items';

  @override
  String get projectEditorProbeScriptsEmpty =>
      '(empty: all extracting or idle)';

  @override
  String get projectEditorProbeScriptsGetFirstScript =>
      'GET projects/…/scripts (first)';

  @override
  String get projectEditorProbeScriptsLoading => 'script…';

  @override
  String projectEditorProbeScriptsPostGetScriptApi(
    int count,
    String sample,
    Object id,
  ) {
    return 'POST …/projects/$id/scripts/get-script-api: $count items · $sample';
  }

  @override
  String get projectEditorProbeTasksBusyLabel => 'tasks…';

  @override
  String get projectEditorProbeTasksButtonCompatGetProject =>
      'compat tasks get-project';

  @override
  String projectEditorProbeTasksCompatGetProjectResult(String line) {
    return 'compat getProject (GET projects): $line';
  }

  @override
  String get projectEditorProbeTasksButtonCompatCategories =>
      'compat tasks categories';

  @override
  String projectEditorProbeTasksCompatCategoriesResult(String line) {
    return 'compat categories (GET jobs/kinds): $line';
  }

  @override
  String get projectEditorProbeTasksButtonCompatList => 'compat tasks list';

  @override
  String get projectEditorProbeTasksButtonCompatTaskDetails =>
      'compat task-details int';

  @override
  String projectEditorProbeTasksCompatTaskDetailsResult(
    int taskId,
    String kind,
    String status,
  ) {
    return 'compat task-details (GET jobs/task-detail): #$taskId -> $kind/$status';
  }

  @override
  String get projectEditorProbeProjectBusyLabel => 'project…';

  @override
  String get projectEditorProbeProjectButtonGetProject =>
      'POST project get-project';

  @override
  String projectEditorProbeProjectEditNoopResult(
    int numericId,
    String message,
  ) {
    return 'POST …/project/edit-project noop #$numericId: $message';
  }

  @override
  String get projectEditorProbeProjectButtonEditNoop =>
      'POST project edit (noop)';

  @override
  String get projectEditorProbeProjectButtonDeleteZero =>
      'POST project delete id=0';

  @override
  String get projectEditorProbeProjectDeleteUnexpected200 =>
      'POST …/project/delete-project: unexpected 200';

  @override
  String get projectEditorProbeProjectDeleteExpected400 =>
      'POST …/project/delete-project id=0 -> 400 (expected)';

  @override
  String get projectEditorProbeProjectButtonEditZero =>
      'POST project edit id=0';

  @override
  String get projectEditorProbeProjectEditUnexpected200 =>
      'POST …/project/edit-project: unexpected 200';

  @override
  String get projectEditorProbeProjectEditExpected400 =>
      'POST …/project/edit-project id=0 -> 400 (expected)';

  @override
  String get projectEditorProbeProjectButtonAddDelete => 'POST project add→del';

  @override
  String projectEditorProbeProjectAddMissingAfterList(String name) {
    return 'add-project ok but get-project missing name=\"$name\"';
  }

  @override
  String projectEditorProbeProjectAddDeleteOk(int numericId) {
    return 'POST add-project → delete project#$numericId ok';
  }

  @override
  String projectEditorProbeScriptsBatchAddProbeResult(int inserted) {
    return 'POST …/projects/:id/scripts/batch-add: inserted=$inserted';
  }

  @override
  String get projectEditorProbeScriptsButtonBatchAdd =>
      'POST projects/…/scripts/batch-add';

  @override
  String get projectEditorProbeScriptsButtonPostGetScriptApi =>
      'POST get-script-api';

  @override
  String projectEditorProbeScriptsGetByNumericResult(int sid, String name) {
    return 'GET …/projects/:id/scripts/$sid: $name';
  }

  @override
  String get projectEditorProbeScriptsPatchNameNoopBusy => 'script…';

  @override
  String get projectEditorProbeScriptsButtonPatchNameNoop =>
      'PATCH projects/…/scripts (name noop)';

  @override
  String projectEditorProbeScriptsPatchNameNoopResult(int sid, String name) {
    return 'PATCH …/projects/:id/scripts/$sid name noop → $name';
  }

  @override
  String get projectEditorProbeScriptsExportZipBusy => 'export…';

  @override
  String get projectEditorProbeScriptsButtonExportZip =>
      'POST scripts/export (ZIP)';

  @override
  String projectEditorProbeScriptsExportZipResult(int bytes, int count) {
    return 'POST …/scripts/export: $bytes bytes · $count numeric id(s)';
  }

  @override
  String get projectEditorProbeScriptsPollExtractBusy => 'poll…';

  @override
  String get projectEditorProbeScriptsButtonPollExtract =>
      'POST extract-state/poll';

  @override
  String projectEditorProbeScriptsPollExtractResult(
    int rowCount,
    String sample,
  ) {
    return 'POST …/extract-state/poll: $rowCount row(s) $sample';
  }

  @override
  String get projectEditorProbeScriptsExtractAssetsBusy => 'extract…';

  @override
  String get projectEditorProbeScriptsButtonExtractAssets =>
      'POST extract-assets';

  @override
  String projectEditorProbeScriptsExtractAssetsResult(
    String status,
    String message,
  ) {
    return 'POST …/extract-assets: $status — $message';
  }

  @override
  String projectEditorNovelsEventsDefaultCreateName(int stamp) {
    return 'Event_$stamp';
  }

  @override
  String get projectEditorNovelsEventsDefaultCreateDetail =>
      'Describe the event here.';

  @override
  String get projectEditorNovelsEventsInfoNoEvents =>
      'This project has no events yet.';

  @override
  String projectEditorNovelsEventsInfoLoaded(int count) {
    return 'Loaded $count events.';
  }

  @override
  String get projectEditorNovelsEventsInfoListEmpty => 'Event list is empty.';

  @override
  String projectEditorNovelsEventsInfoRefreshed(int count) {
    return 'Refreshed: $count events in total.';
  }

  @override
  String projectEditorNovelsEventsInfoSearchDual(int restTotal, int wbTotal) {
    return 'REST matched $restTotal; workbench matched $wbTotal.';
  }

  @override
  String get projectEditorNovelsEventsInfoCreated => 'Event created.';

  @override
  String projectEditorNovelsEventsInfoCreatedWithId(int id) {
    return 'Event created; numeric id = $id.';
  }

  @override
  String projectEditorNovelsEventsInfoUpdated(int eventId, String message) {
    return 'Updated event $eventId: $message';
  }

  @override
  String projectEditorNovelsEventsInfoDeleted(int eventId, String message) {
    return 'Deleted event $eventId: $message';
  }

  @override
  String projectEditorNovelsEventsInfoBatchDeleted(int count, String message) {
    return 'Batch deleted $count events: $message';
  }

  @override
  String get projectEditorNovelsEventsWorkbenchTitle => 'Events workbench';

  @override
  String get projectEditorNovelsEventsPreviewSectionTitle =>
      'Current event preview';

  @override
  String projectEditorNovelsEventsPreviewRow(
    int numericId,
    String name,
    String indexesLine,
  ) {
    return '$numericId · $name · chapter indexes $indexesLine';
  }

  @override
  String get projectEditorNovelsEventsSearchLabel => 'Search event keyword';

  @override
  String get projectEditorNovelsEventsSearchHelper =>
      'Calls both REST and workbench get-events search';

  @override
  String get projectEditorNovelsEventsSearchButton => 'Search events';

  @override
  String get projectEditorNovelsEventsRefreshListButton => 'Refresh list';

  @override
  String get projectEditorNovelsEventsNewEventHeading => 'New event';

  @override
  String get projectEditorNovelsEventsFieldEventName => 'Event name';

  @override
  String get projectEditorNovelsEventsFieldEventDescription =>
      'Event description';

  @override
  String get projectEditorNovelsEventsFieldChapterIdsLabel =>
      'Linked chapter IDs';

  @override
  String get projectEditorNovelsEventsFieldChapterIdsHelper =>
      'Comma-separated chapter numeric IDs';

  @override
  String get projectEditorNovelsEventsCreateButton => 'Create event';

  @override
  String get projectEditorNovelsEventsUpdateHeading => 'Update event';

  @override
  String get projectEditorNovelsEventsFieldNumericId => 'Event numeric ID';

  @override
  String get projectEditorNovelsEventsFieldUpdatedName => 'Updated event name';

  @override
  String get projectEditorNovelsEventsFieldUpdatedDescription =>
      'Updated event description';

  @override
  String get projectEditorNovelsEventsFieldUpdatedChapterIds =>
      'Updated chapter IDs';

  @override
  String get projectEditorNovelsEventsFieldUpdatedChapterIdsHelper =>
      'Chapter numeric IDs; mapped to chapterIds internally';

  @override
  String get projectEditorNovelsEventsSaveButton => 'Save event';

  @override
  String get projectEditorNovelsEventsDeleteHeading => 'Delete / batch delete';

  @override
  String get projectEditorNovelsEventsDeleteCurrentButton =>
      'Delete current event';

  @override
  String get projectEditorNovelsEventsBatchDeleteIdsLabel =>
      'Batch delete event IDs';

  @override
  String get projectEditorNovelsEventsBatchDeleteIdsHelper =>
      'Comma-separated IDs (POST …/novel-events/batch-delete).';

  @override
  String get projectEditorNovelsEventsBatchDeleteButton =>
      'Batch delete events';

  @override
  String get projectEditorNovelsEventsCloseButton => 'Close';

  @override
  String get projectEditorNovelsAndEventsTitle => 'Novels & events';

  @override
  String get projectEditorNovelsEventsGenerateEmptyAdmitted =>
      'No admitted chapters eligible for event generation; admit chapters first.';

  @override
  String projectEditorNovelsEventsGenerateTriggered(
    String ids,
    String message,
  ) {
    return 'Triggered event generation for chapters $ids: $message';
  }

  @override
  String get projectEditorNovelsChapterWorkbenchTitle => 'Chapters workbench';

  @override
  String get projectEditorNovelsChapterWorkbenchPreviewTitle =>
      'Current chapter preview';

  @override
  String projectEditorNovelsChapterWorkbenchPreviewRow(
    int numericId,
    String chapter,
    String intakeSource,
    String intakeStatus,
    String eventState,
  ) {
    return '$numericId · $chapter · $intakeSource / $intakeStatus · event state $eventState';
  }

  @override
  String get projectEditorNovelsChapterWorkbenchCloseButton => 'Close';

  @override
  String get projectEditorNovelsChapterWorkbenchInfoNoChapters =>
      'This project has no chapters yet.';

  @override
  String projectEditorNovelsChapterWorkbenchInfoLoaded(int count) {
    return 'Loaded $count chapters.';
  }

  @override
  String get projectEditorNovelsChapterWorkbenchInfoListEmpty =>
      'Chapter list is empty.';

  @override
  String projectEditorNovelsChapterWorkbenchInfoRefreshed(int count) {
    return 'Refreshed: $count chapters in total.';
  }

  @override
  String get projectEditorNovelsActionErrorUrlEmpty =>
      'Enter a crawl URL first.';

  @override
  String get projectEditorNovelsActionErrorUrlInvalid =>
      'Crawl URL must be a valid http/https address.';

  @override
  String projectEditorNovelsActionErrorCrawlHttp(int code) {
    return 'Crawl failed, HTTP $code';
  }

  @override
  String projectEditorNovelsActionCrawlImportPreviewEmpty(String title) {
    return 'Captured $title, but no importable body was extracted.';
  }

  @override
  String projectEditorNovelsActionCrawlImportPreviewOk(
    String title,
    int count,
  ) {
    return 'Captured $title; extracted $count importable chapters.';
  }

  @override
  String get projectEditorNovelsActionCrawlSideServer => 'server-side crawl';

  @override
  String get projectEditorNovelsActionCrawlSideClient => 'client-side crawl';

  @override
  String projectEditorNovelsActionCrawlDoneInfo(
    String side,
    String title,
    String mode,
    int pageCount,
    int chapterUrlCount,
    int bodyCharCount,
  ) {
    return '$side completed: $title (mode $mode, pages $pageCount, chapter link candidates $chapterUrlCount, body $bodyCharCount chars)';
  }

  @override
  String projectEditorNovelsActionSearchHit(int total, int shown) {
    return 'Search matched $total rows; showing $shown.';
  }

  @override
  String projectEditorNovelsActionSearchFiltered(
    int total,
    String filters,
    int shown,
  ) {
    return 'Filter matched $total rows ($filters); showing $shown.';
  }

  @override
  String get projectEditorNovelsActionErrorPreparseRequired =>
      'Pre-parse the whole book first.';

  @override
  String projectEditorNovelsActionErrorImportQuality(String blockers) {
    return 'Import quality gate failed: $blockers';
  }

  @override
  String projectEditorNovelsActionImportQualityHint(String warnings) {
    return 'Import quality hint: $warnings';
  }

  @override
  String get projectEditorNovelsActionErrorBatchSizePositive =>
      'Batch size must be greater than 0.';

  @override
  String projectEditorNovelsActionErrorChapterBodyEmpty(int index) {
    return 'Chapter #$index has empty body; fix it in the pre-parse preview before importing.';
  }

  @override
  String projectEditorNovelsActionImportProgress(int end, int total) {
    return 'Imported $end/$total chapters…';
  }

  @override
  String projectEditorNovelsActionImportComplete(int count) {
    return 'Whole-book import finished; added $count chapters.';
  }

  @override
  String projectEditorNovelsActionServerImportDone(
    String title,
    int chaptersCreated,
    String mode,
    int pageCount,
    int chapterUrlCount,
    int bodyCharCount,
  ) {
    return 'Server-hosted import finished: $title (added $chaptersCreated chapters, mode $mode, crawled $pageCount pages, chapter link candidates $chapterUrlCount, body $bodyCharCount chars)';
  }

  @override
  String get projectEditorNovelsActionErrorBatchUrlsEmpty =>
      'Enter at least one URL line in the batch hosted URL field.';

  @override
  String projectEditorNovelsActionBatchImportDone(
    int succeeded,
    int total,
    int failed,
    String detail,
  ) {
    return 'Batch server import: succeeded $succeeded/$total, failed $failed.$detail';
  }

  @override
  String get projectEditorNovelsActionBatchImportFailuresPrefix =>
      ' Failure samples: ';

  @override
  String projectEditorNovelsActionCrawlScheduleCreated(
    int taskId,
    String status,
    int delayMinutes,
    int repeatMinutes,
  ) {
    return 'Created crawl schedule: task id $taskId ($status; delay ${delayMinutes}m; repeat ${repeatMinutes}m)';
  }

  @override
  String get projectEditorNovelsActionCrawlSchedulesEmpty =>
      'No hosted crawl schedules (showing up to 100 recent for this project).';

  @override
  String projectEditorNovelsActionCrawlSchedulesSummary(
    int count,
    String head,
  ) {
    return 'This project has $count hosted crawl schedules; recent: $head';
  }

  @override
  String projectEditorNovelsActionCrawlObservability(
    int totalChapters,
    String topSources,
    String topStatuses,
    String jobs,
    String recent,
  ) {
    return 'Hosted stats: chapters $totalChapters; source[$topSources]; status[$topStatuses]; crawlJobs[$jobs].$recent';
  }

  @override
  String projectEditorNovelsActionCrawlObservabilityRecentImports(String ids) {
    return ' Recent server imports: $ids';
  }

  @override
  String projectEditorNovelsActionChapterReadOk(int id) {
    return 'Loaded chapter #$id.';
  }

  @override
  String projectEditorNovelsActionChapterSaveOk(int id) {
    return 'Updated chapter #$id.';
  }

  @override
  String projectEditorNovelsActionChapterDeleteOk(int id) {
    return 'Deleted chapter #$id.';
  }

  @override
  String get projectEditorNovelsActionErrorIdsEmpty =>
      'Provide at least one chapter id.';

  @override
  String projectEditorNovelsActionEventsGenerateOk(String message) {
    return 'Triggered event generation: $message';
  }

  @override
  String get projectEditorNovelsActionListLabelEmpty => '(empty list)';

  @override
  String get projectEditorNovelsActionListLabelAllZero => '(all zero)';

  @override
  String projectEditorNovelsActionWorkbenchDataResult(
    int count,
    String sample,
  ) {
    return 'workbench get-novel-data returned $count rows: $sample';
  }

  @override
  String projectEditorNovelsActionWorkbenchIndexResult(
    int count,
    String sample,
  ) {
    return 'workbench get-novel-index returned $count rows: $sample';
  }

  @override
  String projectEditorNovelsActionWorkbenchEventStateResult(
    int count,
    String sample,
  ) {
    return 'workbench get-novel-event-state returned $count rows: $sample';
  }

  @override
  String projectEditorNovelsActionBatchDeleteOk(int count, String message) {
    return 'Batch deleted $count chapters: $message';
  }

  @override
  String get projectEditorNovelsActionErrorAdmissionStatusEmpty =>
      'Select a target admission status first.';

  @override
  String projectEditorNovelsActionBatchAdmissionOk(int count, String status) {
    return 'Batch updated $count chapters to $status.';
  }

  @override
  String get projectEditorNovelsChapterWorkbenchValueUnknown => 'unknown';

  @override
  String get projectEditorNovelsChapterWorkbenchValueUnset => 'unset';

  @override
  String get projectEditorNovelsActionSearchFiltersCleared =>
      'Chapter search filters cleared.';

  @override
  String get projectEditorNovelsActionChapterCreateOk => 'Chapter created.';

  @override
  String get projectEditorNovelsActionPreparseResultEmpty =>
      'No importable content was detected.';

  @override
  String projectEditorNovelsActionPreparseResultOk(int count) {
    return 'Pre-parsed $count chapters; confirm titles and order before importing.';
  }

  @override
  String get projectEditorNovelsActionImportPreviewAppendChapter =>
      'Appended 1 supplement chapter; fill in title and body before importing.';

  @override
  String projectEditorNovelsActionImportPreviewDeletedRow(int chapterIndex) {
    return 'Removed pre-parsed row #$chapterIndex.';
  }

  @override
  String projectEditorNovelsActionImportPreviewRowTitleUpdated(
    int chapterIndex,
  ) {
    return 'Updated title for pre-parsed row #$chapterIndex.';
  }

  @override
  String projectEditorNovelsActionImportPreviewRowBodyUpdated(
    int chapterIndex,
  ) {
    return 'Updated body for row #$chapterIndex.';
  }

  @override
  String projectEditorNovelsActionImportPreviewAreaTitle(int count) {
    return 'Pre-parse edit area ($count rows)';
  }

  @override
  String get projectEditorNovelsActionImportPreviewFooterNote =>
      'Import will renumber automatically; empty-body chapters are blocked—fix them here first.';

  @override
  String get projectEditorNovelsActionImportPreviewLongListHint =>
      'Preview is long; scroll to edit every chapter.';

  @override
  String projectEditorNovelsActionImportPreviewSupplementChapterTitle(int n) {
    return 'Supplement chapter $n';
  }

  @override
  String get projectEditorNovelsWorkbenchCardSummaryEmptyHelp =>
      'Use explicit forms to add, search, view, update, delete chapters, and generate events—without legacy first/last probe shortcuts.';

  @override
  String projectEditorNovelsWorkbenchCardSummaryDualBounds(
    String summaryLine,
    int firstId,
    String firstChapter,
    int lastId,
    String lastChapter,
  ) {
    return '$summaryLine · first #$firstId $firstChapter · last #$lastId $lastChapter.';
  }

  @override
  String get projectEditorNovelsWorkbenchCardOpenButton =>
      'Open chapters workbench';

  @override
  String get projectEditorNovelsWorkbenchCardRefreshChapters =>
      'Refresh chapters';

  @override
  String get projectEditorNovelsWorkbenchCardRefreshChaptersBusy =>
      'Refreshing chapters…';

  @override
  String get projectEditorNovelsWorkbenchCardGenerateEventsForTopThree =>
      'Generate events for top 3';

  @override
  String get projectEditorNovelsWorkbenchSearchKeywordLabel =>
      'Search chapter keyword';

  @override
  String get projectEditorNovelsWorkbenchSearchKeywordHelper =>
      'Calls GET /projects/:project_uuid/novels?search=';

  @override
  String get projectEditorNovelsWorkbenchSearchIntakeStatusLabel =>
      'Admission status';

  @override
  String get projectEditorNovelsWorkbenchSearchIntakeStatusAll =>
      'All statuses';

  @override
  String get projectEditorNovelsWorkbenchSearchIntakeSourceLabel =>
      'Intake source';

  @override
  String get projectEditorNovelsWorkbenchSearchIntakeSourceAll => 'All sources';

  @override
  String get projectEditorNovelsWorkbenchSearchButton => 'Search';

  @override
  String get projectEditorNovelsWorkbenchSearchClearFilters => 'Clear filters';

  @override
  String get projectEditorNovelsWorkbenchSearchRefreshList => 'Refresh list';

  @override
  String get projectEditorNovelsWorkbenchCreateSectionTitle => 'Add chapter';

  @override
  String get projectEditorNovelsWorkbenchCreateChapterTitleLabel =>
      'Chapter title';

  @override
  String get projectEditorNovelsWorkbenchCreateChapterBodyLabel =>
      'Chapter body';

  @override
  String get projectEditorNovelsWorkbenchCreateSubmit => 'Add chapter';

  @override
  String get projectEditorNovelsWorkbenchEditSectionTitle =>
      'Read / update chapter';

  @override
  String get projectEditorNovelsWorkbenchEditNumericIdLabel =>
      'Chapter numeric ID';

  @override
  String get projectEditorNovelsWorkbenchEditReadButton => 'Load chapter';

  @override
  String get projectEditorNovelsWorkbenchEditPatchChapterLabel =>
      'Updated chapter title';

  @override
  String get projectEditorNovelsWorkbenchEditPatchBodyLabel =>
      'Updated chapter body';

  @override
  String get projectEditorNovelsWorkbenchEditIntakeStatusLabel =>
      'Admission status';

  @override
  String get projectEditorNovelsWorkbenchEditIntakeStatusHelper =>
      'draft / pending_review / admitted / rejected';

  @override
  String get projectEditorNovelsWorkbenchEditSourceUrlLabel => 'Source URL';

  @override
  String get projectEditorNovelsWorkbenchEditIntakeNoteLabel =>
      'Admission note';

  @override
  String get projectEditorNovelsWorkbenchEditSaveButton => 'Save chapter';

  @override
  String get projectEditorNovelsWorkbenchDeleteSectionTitle =>
      'Delete / generate events';

  @override
  String get projectEditorNovelsWorkbenchDeleteNumericIdLabel =>
      'Chapter numeric ID to delete';

  @override
  String get projectEditorNovelsWorkbenchDeleteButton => 'Delete chapter';

  @override
  String get projectEditorNovelsWorkbenchDeleteGenerateIdsLabel =>
      'Chapter IDs for event generation';

  @override
  String get projectEditorNovelsWorkbenchDeleteGenerateIdsHelper =>
      'Comma-separated, e.g. 1,2,3';

  @override
  String get projectEditorNovelsWorkbenchDeleteGenerateEventsButton =>
      'Generate chapter events';

  @override
  String get projectEditorNovelsWorkbenchSnapshotSectionTitle =>
      'Snapshots / batch actions';

  @override
  String get projectEditorNovelsWorkbenchSnapshotEventStateIdsLabel =>
      'Chapter IDs (numeric)';

  @override
  String get projectEditorNovelsWorkbenchSnapshotEventStateIdsHelper =>
      'For get-novel-event-state; comma-separated, e.g. 1,2,3';

  @override
  String get projectEditorNovelsWorkbenchSnapshotReadNovelDataButton =>
      'Read get-novel-data';

  @override
  String get projectEditorNovelsWorkbenchSnapshotReadNovelIndexButton =>
      'Read get-novel-index';

  @override
  String get projectEditorNovelsWorkbenchSnapshotReadEventStateButton =>
      'Read event-state';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsLabel =>
      'Batch delete chapter IDs';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsHelper =>
      'Calls workbench batch-delete; comma-separated; refreshes the workbench after delete.';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchDeleteButton =>
      'Batch delete chapters';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsLabel =>
      'Batch admission chapter IDs';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsHelper =>
      'Comma-separated, e.g. 1,2,3';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionStatusLabel =>
      'Target admission status';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteLabel =>
      'Batch admission note';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteHelper =>
      'Leave empty to clear; overwrites intake_note for selected chapters.';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionButton =>
      'Batch update admission status';

  @override
  String get projectEditorNovelsWorkbenchImportSectionTitle =>
      'Whole-book import';

  @override
  String get projectEditorNovelsWorkbenchImportCrawlUrlLabel => 'Crawl URL';

  @override
  String get projectEditorNovelsWorkbenchImportCrawlUrlHelper =>
      'Prefer client crawl + fix + import; server is for hosted preview.';

  @override
  String get projectEditorNovelsWorkbenchImportBatchUrlsLabel =>
      'Batch hosted URLs (one per line)';

  @override
  String get projectEditorNovelsWorkbenchImportBatchUrlsHelper =>
      'Hosted import (paid) batch trigger only; default import still uses the pre-parse editor.';

  @override
  String get projectEditorNovelsWorkbenchImportScheduleDelayLabel =>
      'Hosted schedule delay (minutes)';

  @override
  String get projectEditorNovelsWorkbenchImportScheduleDelayHelper =>
      '0 means run immediately';

  @override
  String get projectEditorNovelsWorkbenchImportScheduleRepeatLabel =>
      'Repeat interval (minutes)';

  @override
  String get projectEditorNovelsWorkbenchImportScheduleRepeatHelper =>
      'Leave empty for no repeat';

  @override
  String get projectEditorNovelsWorkbenchImportCreateScheduleButton =>
      'Create hosted crawl schedule';

  @override
  String get projectEditorNovelsWorkbenchImportListSchedulesButton =>
      'View hosted schedules';

  @override
  String get projectEditorNovelsWorkbenchImportRefreshObservabilityButton =>
      'Refresh hosted stats';

  @override
  String get projectEditorNovelsWorkbenchImportCrawlPreparseButton =>
      'Crawl and pre-parse';

  @override
  String get projectEditorNovelsWorkbenchImportRawPasteLabel =>
      'Paste whole book or multi-chapter text';

  @override
  String get projectEditorNovelsWorkbenchImportRawPasteHelper =>
      'Auto-split by headings like “Chapter 12”, “第3回”, “第五集”.';

  @override
  String get projectEditorNovelsWorkbenchImportBatchSizeLabel =>
      'Chapters per import batch';

  @override
  String get projectEditorNovelsWorkbenchImportPreparseButton =>
      'Pre-parse whole book';

  @override
  String get projectEditorNovelsWorkbenchImportParsedChaptersButton =>
      'Import pre-parsed chapters';

  @override
  String get projectEditorNovelsWorkbenchImportServerImportButton =>
      'Hosted import (paid)';

  @override
  String get projectEditorNovelsWorkbenchImportServerBatchButton =>
      'Batch hosted import (paid)';

  @override
  String get projectEditorNovelsWorkbenchImportExecutionSideLabel =>
      'Crawl execution side';

  @override
  String get projectEditorNovelsWorkbenchImportExecutionSideClient =>
      'client (available)';

  @override
  String get projectEditorNovelsWorkbenchImportExecutionSideServer =>
      'server (hosted preview)';

  @override
  String get projectEditorNovelsWorkbenchImportIntakeStatusAfterImportLabel =>
      'Admission status after import';

  @override
  String get projectEditorNovelsWorkbenchImportIntakeNoteLabel => 'Import note';

  @override
  String get projectEditorNovelsWorkbenchImportIntakeNoteHelper =>
      'Crawl source, cleanup notes, review reasons, etc.';

  @override
  String get projectEditorNovelsWorkbenchImportPreviewAddChapterButton =>
      'Add chapter';

  @override
  String get projectEditorNovelsWorkbenchImportPreviewDeleteChapterTooltip =>
      'Remove this chapter';

  @override
  String get projectEditorNovelsWorkbenchImportPreviewChapterTitleField =>
      'Chapter title';

  @override
  String get projectEditorNovelsWorkbenchImportPreviewChapterBodyField =>
      'Chapter body';

  @override
  String projectEditorScriptsWorkbenchBatchFollowUpLine(
    String actionSummary,
    String nextAction,
    String detail,
  ) {
    return '$actionSummary Suggested next step: $nextAction. $detail';
  }

  @override
  String get projectEditorScriptsWorkbenchRecommendSyncContext =>
      'Read script context';

  @override
  String get projectEditorScriptsWorkbenchRecommendPollSelected =>
      'Poll selected extract states';

  @override
  String get projectEditorScriptsWorkbenchRecommendExtractSelected =>
      'Extract assets for selected scripts';

  @override
  String get projectEditorScriptsWorkbenchRecommendExportSelected =>
      'Export selected scripts';

  @override
  String get projectEditorScriptsWorkbenchReloadEmpty =>
      'Refresh finished; no scripts in this project.';

  @override
  String projectEditorScriptsWorkbenchReloadCount(int count) {
    return 'Refresh finished; loaded $count scripts.';
  }

  @override
  String get projectEditorScriptsWorkbenchReadContextEmpty =>
      'Context read finished; no matching scripts.';

  @override
  String projectEditorScriptsWorkbenchReadContextCount(int count) {
    return 'Loaded $count script context rows.';
  }

  @override
  String get projectEditorScriptsWorkbenchErrorNeedScriptIds =>
      'Enter at least one script id.';

  @override
  String projectEditorScriptsWorkbenchExportSelectedSummary(
    int count,
    String zipSize,
  ) {
    return 'Exported $count scripts, ZIP $zipSize.';
  }

  @override
  String get projectEditorScriptsWorkbenchPollExtractIdleOrComplete =>
      'All idle or completed';

  @override
  String projectEditorScriptsWorkbenchPollSelectedSummary(
    int count,
    String sample,
  ) {
    return 'Polled $count scripts for extract state: $sample';
  }

  @override
  String projectEditorScriptsWorkbenchExtractSubmittedSelected(
    int count,
    String status,
    String message,
  ) {
    return 'Submitted asset extract for $count scripts: $status · $message';
  }

  @override
  String get projectEditorScriptsWorkbenchBatchCreateCountInvalid =>
      'Count must be an integer between 1 and 20.';

  @override
  String get projectEditorScriptsWorkbenchDefaultNewScriptName => 'New script';

  @override
  String projectEditorScriptsWorkbenchBatchCreated(int inserted) {
    return 'Batch created $inserted scripts.';
  }

  @override
  String projectEditorScriptsWorkbenchCreatedScriptFollowUp(int id) {
    return 'Created script #$id.';
  }

  @override
  String projectEditorScriptsWorkbenchCreatedScriptSnackBar(int id) {
    return 'Created script #$id';
  }

  @override
  String projectEditorScriptsWorkbenchExportAllFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String projectEditorScriptsWorkbenchPollAllFailed(String error) {
    return 'Polling extract state failed: $error';
  }

  @override
  String projectEditorScriptsWorkbenchExtractAllFailed(String error) {
    return 'Submitting asset extract failed: $error';
  }

  @override
  String projectEditorScriptsWorkbenchExportAllSummary(
    int count,
    String zipSize,
  ) {
    return 'Exported $count scripts, ZIP $zipSize.';
  }

  @override
  String projectEditorScriptsWorkbenchPollAllSummary(int count, String sample) {
    return 'Polled $count scripts for extract state: $sample';
  }

  @override
  String projectEditorScriptsWorkbenchExtractAllSummary(
    int count,
    String status,
    String message,
  ) {
    return 'Submitted asset extract for $count scripts: $status · $message';
  }

  @override
  String get projectEditorScriptsWorkbenchOverviewOpenWorkbenchReadContext =>
      'Open workbench to read context';

  @override
  String get projectEditorScriptsWorkbenchOverviewPollAllExtract =>
      'Poll extract state for all';

  @override
  String get projectEditorScriptsWorkbenchOverviewExtractAllAssets =>
      'Extract assets for all scripts';

  @override
  String get projectEditorScriptsWorkbenchOverviewExportAllScripts =>
      'Export all scripts';

  @override
  String get projectEditorScriptsSessionInfoNoScripts =>
      'This project has no scripts yet.';

  @override
  String projectEditorScriptsSessionInfoLoadedCount(int count) {
    return '$count scripts loaded; you can filter and run batch actions.';
  }

  @override
  String get projectEditorScriptsSessionDefaultAddBody =>
      'Plot outline to be filled.';

  @override
  String get projectEditorScriptsDiagnosisBatchEmptySummary =>
      'No scripts selected for processing.';

  @override
  String get projectEditorScriptsDiagnosisBatchEmptyDetail =>
      'Read script context or enter target script ids, then run batch export, polling, or asset extract.';

  @override
  String projectEditorScriptsDiagnosisBatchRunningSummary(int count) {
    return '$count selected script(s) are still extracting.';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchRunningDetail =>
      'Poll selected extract states first to confirm batch work finished before retrying extract.';

  @override
  String projectEditorScriptsDiagnosisBatchFailedSummary(int count) {
    return '$count selected script(s) recently failed extract.';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchFailedDetail =>
      'Start asset extract again for the selection; prioritize fixing failed items.';

  @override
  String projectEditorScriptsDiagnosisBatchMissingContextSummary(int count) {
    return '$count selected script(s) are missing a context snapshot.';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchMissingContextDetail =>
      'Read script context first to see which scripts already have assets, then decide whether to export ZIP or run asset extract.';

  @override
  String projectEditorScriptsDiagnosisBatchAllAssetsSummary(int count) {
    return 'All $count selected script(s) already have related assets.';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchAllAssetsDetail =>
      'You can export a ZIP of the selection for review, or continue in the single-script workbench for images.';

  @override
  String projectEditorScriptsDiagnosisBatchPendingExtractSummary(int count) {
    return '$count selected script(s) still have items pending extract.';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchPendingExtractDetail =>
      'Start batch asset extract to turn the current selection into assets usable for images and storyboards.';

  @override
  String get projectEditorScriptsDiagnosisSingleNoSnapshotSummary =>
      'No workbench snapshot for the current script yet.';

  @override
  String get projectEditorScriptsDiagnosisSingleNoSnapshotDetail =>
      'Sync the workbench first to load get-script-api context and the latest extract state.';

  @override
  String get projectEditorScriptsDiagnosisSingleExtractFailedSummary =>
      'The latest asset extract run failed.';

  @override
  String get projectEditorScriptsDiagnosisSingleExtractFailedDetailNoReason =>
      'Fix inputs and start asset extract again for this script.';

  @override
  String projectEditorScriptsDiagnosisSingleExtractFailedDetailWithReason(
    String reason,
  ) {
    return 'Reason: $reason. Fix inputs and start asset extract again.';
  }

  @override
  String get projectEditorScriptsDiagnosisSingleExtractRunningSummary =>
      'Asset extract is in progress.';

  @override
  String get projectEditorScriptsDiagnosisSingleExtractRunningDetail =>
      'Poll extract state first to confirm the task finished before continuing to image editing.';

  @override
  String get projectEditorScriptsDiagnosisSingleNoAssetsSummary =>
      'This script has no related assets yet.';

  @override
  String get projectEditorScriptsDiagnosisSingleNoAssetsDetail =>
      'You can start asset extract to turn script context into assets for images and storyboards.';

  @override
  String get projectEditorScriptsDiagnosisSingleHasAssetsSummary =>
      'This script already has related assets.';

  @override
  String projectEditorScriptsDiagnosisSingleHasAssetsDetail(int count) {
    return 'Synced $count related assets; continue to the edit-image workbench or export a ZIP for local review.';
  }

  @override
  String get projectEditorScriptsSingleWorkbenchRecommendSyncWorkbench =>
      'Sync workbench';

  @override
  String get projectEditorScriptsSingleWorkbenchRecommendPollExtractState =>
      'Poll extract state';

  @override
  String get projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets =>
      'Extract assets for this script';

  @override
  String
  get projectEditorScriptsSingleWorkbenchRecommendOpenEditImageWorkbench =>
      'Open edit-image workbench';

  @override
  String get projectEditorScriptsSingleWorkbenchRecommendExportScriptZip =>
      'Export this script ZIP';

  @override
  String get projectEditorScriptsSingleWorkbenchContextNotInApi =>
      'This script is not present in get-script-api results yet.';

  @override
  String projectEditorScriptsSingleWorkbenchContextLoaded(int assetCount) {
    return 'Loaded script context: $assetCount related assets';
  }

  @override
  String projectEditorScriptsSingleWorkbenchContextReadFailed(String error) {
    return 'Failed to read script context: $error';
  }

  @override
  String projectEditorScriptsSingleWorkbenchFollowUpExportDone(String zipSize) {
    return 'Export finished: 1 script, ZIP $zipSize.';
  }

  @override
  String projectEditorScriptsSingleWorkbenchFollowUpPollState(
    String stateLine,
  ) {
    return 'Polled extract state for this script: $stateLine';
  }

  @override
  String projectEditorScriptsSingleWorkbenchFollowUpExtractSubmitted(
    String status,
    String message,
  ) {
    return 'Asset extract submitted: $status · $message';
  }

  @override
  String get projectEditorScriptsSingleWorkbenchEditClosedStillMissing =>
      'Edit-image workbench closed; this script is still not present in get-script-api results.';

  @override
  String get projectEditorScriptsSingleWorkbenchFollowUpEditClosedSynced =>
      'Edit-image workbench closed; synced script context and extract state.';

  @override
  String get projectEditorScriptsSingleWorkbenchSyncBusy => 'Syncing…';

  @override
  String get projectEditorScriptsExtractStateEmpty =>
      'Extract state is empty: usually idle or completed.';

  @override
  String projectEditorScriptsExtractStateLine(int state, String errorSuffix) {
    return 'Extract state: $state$errorSuffix';
  }

  @override
  String get scriptEditorRelatedAssetsNone => 'No related assets';

  @override
  String get scriptEditorRelatedAssetsNameSeparator => ', ';

  @override
  String scriptEditorRelatedAssetsOverflow(
    String visibleNames,
    int totalCount,
  ) {
    return '$visibleNames · $totalCount items';
  }

  @override
  String get scriptEditorWorkbenchPanelTitle => 'Script workbench';

  @override
  String get scriptEditorWorkbenchPanelIntro =>
      'Automatically sync get-script-api context and extract state; supports ZIP export, asset extract, and edit-image flows.';

  @override
  String scriptEditorWorkbenchRelatedAssetsLine(String assets) {
    return 'Related assets: $assets';
  }

  @override
  String scriptEditorDialogTitle(int numericId) {
    return 'Script #$numericId';
  }

  @override
  String get scriptEditorFieldNameLabelClearIfEmpty =>
      'Name (leave empty to clear)';

  @override
  String get scriptEditorFieldContentLabelClearIfEmpty =>
      'Content (leave empty to clear)';

  @override
  String get scriptEditorFieldExtractStateLabelClearIfEmpty =>
      'Extract state (leave empty to clear)';

  @override
  String get scriptEditorOpenStoryboards => 'Storyboards…';

  @override
  String get scriptEditorDeleteScriptButton => 'Delete script';

  @override
  String get scriptEditorDeleteConfirmTitle => 'Delete this script?';

  @override
  String scriptEditorDeleteConfirmBody(int numericId) {
    return 'This will delete script #$numericId and its storyboards (database cascade).';
  }

  @override
  String get scriptEditorDeleteConfirmDelete => 'Delete';

  @override
  String get scriptEditorExtractStateMustBeInteger =>
      'extract_state must be an integer';

  @override
  String get scriptEditorSaveSaving => 'Saving…';

  @override
  String get scriptEditorSaveChanges => 'Save changes';

  @override
  String get scriptEditorDeletedSnackBar => 'Script deleted';

  @override
  String projectEditorScriptsSingleWorkbenchRecentExtractError(String reason) {
    return 'Recent extract error: $reason';
  }

  @override
  String get projectEditorScriptsWorkbenchDialogTitle =>
      'Script batch workbench';

  @override
  String get projectEditorScriptsWorkbenchDialogNameFilterLabel =>
      'Filter scripts by name';

  @override
  String get projectEditorScriptsWorkbenchDialogNameFilterHelper =>
      'When calling POST …/projects/<project id>/scripts/get-script-api, filter by name; leave empty to load full context.';

  @override
  String get projectEditorScriptsWorkbenchDialogReadScriptContext =>
      'Read script context';

  @override
  String get projectEditorScriptsWorkbenchDialogUseCurrentPreview =>
      'Use current preview';

  @override
  String get projectEditorScriptsWorkbenchDialogUseAllScripts =>
      'Use all project scripts';

  @override
  String get projectEditorScriptsWorkbenchDialogReloadProjectScripts =>
      'Reload project scripts';

  @override
  String get projectEditorScriptsWorkbenchDialogTargetScriptIdsLabel =>
      'Target script numeric ids';

  @override
  String get projectEditorScriptsWorkbenchDialogTargetScriptIdsHelper =>
      'Separate with commas, spaces, or newlines; batch export, polling, and asset extract use this list.';

  @override
  String get projectEditorScriptsWorkbenchDialogExtractGroupSizeLabel =>
      'Asset extract group size';

  @override
  String get projectEditorScriptsWorkbenchDialogExtractGroupSizeHelper =>
      'Leave empty for backend default; used for extract-assets when set.';

  @override
  String get projectEditorScriptsWorkbenchDialogContextPreviewHeading =>
      'Context preview';

  @override
  String get projectEditorScriptsWorkbenchDialogContextPreviewEmpty =>
      'Nothing to preview yet.';

  @override
  String projectEditorScriptsWorkbenchDialogPreviewRowBrief(
    int numericId,
    String name,
    int extractState,
  ) {
    return '#$numericId $name · extract state $extractState';
  }

  @override
  String projectEditorScriptsWorkbenchDialogPreviewRowWithAssets(
    int numericId,
    String name,
    int extractState,
    String assets,
  ) {
    return '#$numericId $name · extract state $extractState · assets $assets';
  }

  @override
  String get projectEditorScriptsWorkbenchDialogBatchCreate => 'Batch create';

  @override
  String get projectEditorScriptsWorkbenchDialogClose => 'Close';

  @override
  String get projectEditorAssetSummaryProductionEmpty =>
      'Production asset data is empty';

  @override
  String projectEditorAssetSummaryProductionLine(
    int total,
    String typesLine,
    String sampleLine,
  ) {
    return 'Production assets $total items · $typesLine · Sample: $sampleLine';
  }

  @override
  String projectEditorAssetSummaryTypeCount(String type, int count) {
    return '$type $count items';
  }

  @override
  String get projectEditorAssetSummaryPollingEmpty =>
      'No image status returned for selected assets';

  @override
  String projectEditorAssetSummaryPollingLine(
    int count,
    String stateLine,
    String sampleLine,
  ) {
    return 'Polled $count assets · $stateLine · Sample: $sampleLine';
  }

  @override
  String projectEditorAssetSummaryStateCount(String state, int count) {
    return '$state $count items';
  }

  @override
  String projectEditorAssetSummaryImageCount(int assetId, int count) {
    return '#$assetId: $count images';
  }

  @override
  String projectEditorAssetSummaryMaterialContext(
    int imageCount,
    int videoCount,
  ) {
    return 'Material context $imageCount image materials · $videoCount video materials';
  }

  @override
  String get projectEditorAssetSummaryBatchEmpty =>
      'Batch candidates are empty';

  @override
  String projectEditorAssetSummaryBatchLine(
    int count,
    int total,
    String sampleLine,
  ) {
    return 'Batch candidates $count/$total items · Sample: $sampleLine';
  }

  @override
  String get projectEditorAssetSummaryPromptEmpty =>
      'No prompt status returned';

  @override
  String projectEditorAssetSummaryPromptLine(int count, String stateLine) {
    return 'Prompt polling $count items · $stateLine';
  }

  @override
  String get projectEditorAssetSummarySelectionNone =>
      'No assets currently selected';

  @override
  String projectEditorAssetSummarySelectionSingle(int id, String name) {
    return 'Currently selected #$id $name';
  }

  @override
  String projectEditorAssetSummarySelectionMultiple(int count, String sample) {
    return 'Currently selected $count assets: $sample';
  }

  @override
  String get authSupabaseNotConfigured =>
      'Not configured: run example\nflutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authSignOut => 'Sign Out';

  @override
  String authSignedInUser(String userId) {
    return 'Signed in user: $userId';
  }

  @override
  String get authRequestInProgress => 'Requesting…';

  @override
  String get authGetMeBearer => 'GET /api/v1/me (Bearer)';

  @override
  String authMeResponse(String response) {
    return '/me: $response';
  }

  @override
  String get authDevSwitchProbe =>
      'GET+PUT /api/v1/settings/dev/switch-ai-tool';

  @override
  String authDevSwitchResponse(String response) {
    return 'dev switch: $response';
  }

  @override
  String get authMemoryConfigProbe =>
      'memory-config GET+POST + clear-agent-memories';

  @override
  String authMemoryConfigResponse(String response) {
    return 'memory-config: $response';
  }

  @override
  String get authAboutProbe =>
      'POST …/settings/about/check-update + download-app';

  @override
  String authAboutResponse(String response) {
    return 'about: $response';
  }

  @override
  String get authUsageSummary => 'GET /api/v1/usage/summary';

  @override
  String authUsageResponse(String response) {
    return 'usage: $response';
  }

  @override
  String get authPromptsProbe => 'GET /api/v1/prompts + GET/1 + PATCH/1';

  @override
  String authPromptsResponse(String response) {
    return 'prompts: $response';
  }

  @override
  String get authVisualManualProbe => 'GET+POST /api/v1/visual-manual';

  @override
  String authVisualManualResponse(String response) {
    return 'visual-manual: $response';
  }

  @override
  String get authDirectorManualProbe => 'POST …/project/query-director-manual';

  @override
  String authDirectorManualResponse(String response) {
    return 'director-manual: $response';
  }

  @override
  String get authSkillsBinaryProbe => 'GET /api/v1/skills/binary (_smoke PNG)';

  @override
  String authSkillsBinaryResponse(String response) {
    return 'skills/binary: $response';
  }

  @override
  String get authModelsCatalogProbe =>
      'models + vendors + vendor-add + danger + production + agent-deploy + model-test + script-agent + assets-gen';

  @override
  String get authTextModelDefaultProbe =>
      'GET+PATCH /api/v1/models/text-default';

  @override
  String get authModelDetailProbe =>
      'GET /api/v1/models/detail (1:gpt-4o-mini)';

  @override
  String authModelsResponse(String response) {
    return 'models: $response';
  }

  @override
  String authTextDefaultResponse(String response) {
    return 'text-default: $response';
  }

  @override
  String authModelDetailResponse(String response) {
    return 'model detail: $response';
  }

  @override
  String get shortVideoSpaceDialogExportProgressTitle => 'Export Progress';

  @override
  String get shortVideoSpaceDialogExportProgressStatusQueued => 'Queued';

  @override
  String get shortVideoSpaceDialogExportProgressStatusProcessing =>
      'Processing';

  @override
  String get shortVideoSpaceDialogExportProgressStatusCompleted => 'Completed';

  @override
  String get shortVideoSpaceDialogExportProgressStatusFailed => 'Failed';

  @override
  String get shortVideoSpaceDialogExportProgressStatusCancelled => 'Cancelled';

  @override
  String get shortVideoSpaceDialogExportProgressStageInitializing =>
      'Initializing';

  @override
  String get shortVideoSpaceDialogExportProgressStageLoadingAssets =>
      'Loading Assets';

  @override
  String get shortVideoSpaceDialogExportProgressStageEncoding =>
      'Encoding Video';

  @override
  String get shortVideoSpaceDialogExportProgressStageUploading =>
      'Uploading File';

  @override
  String get shortVideoSpaceDialogExportProgressStageFinalizing => 'Finalizing';

  @override
  String get shortVideoSpaceDialogExportProgressLoadingStatus =>
      'Fetching export status...';

  @override
  String shortVideoSpaceDialogExportProgressFetchError(String error) {
    return 'Failed to fetch progress: $error';
  }

  @override
  String get shortVideoSpaceDialogExportProgressSessionExpired =>
      'Session expired, please login again';

  @override
  String shortVideoSpaceDialogExportProgressCancelFailed(String error) {
    return 'Cancel failed: $error';
  }

  @override
  String shortVideoSpaceDialogExportProgressTaskId(String taskId) {
    return 'Task ID: $taskId';
  }

  @override
  String get shortVideoSpaceDialogExportProgressCancelButton => 'Cancel Export';

  @override
  String get shortVideoSpaceDialogExportProgressCloseButton => 'Close';

  @override
  String get shortVideoSpaceDialogExportProgressMessageQueued =>
      'Export task queued, waiting for processing...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageInitializing =>
      'Initializing export task...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageLoadingAssets =>
      'Loading video assets and audio files...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageEncoding =>
      'Encoding video, this may take a few minutes...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageUploading =>
      'Uploading exported video file...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageFinalizing =>
      'Completing final processing steps...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageProcessing =>
      'Processing export task...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageCompleted =>
      'Export completed successfully! Video is ready for download.';

  @override
  String get shortVideoSpaceDialogExportProgressMessageFailed =>
      'Export failed, please retry or contact support.';

  @override
  String get shortVideoSpaceDialogExportProgressMessageCancelled =>
      'Export has been cancelled.';

  @override
  String get shortVideoSpaceDialogConfirmDeleteVersionTitle => 'Confirm Delete';

  @override
  String shortVideoSpaceDialogConfirmDeleteVersionMessage(String versionName) {
    return 'Are you sure you want to delete version \"$versionName\"?\n\nThis action cannot be undone.';
  }

  @override
  String get shortVideoSpaceDialogConfirmDeleteVersionDontShow =>
      'Don\'t show again';

  @override
  String get shortVideoSpaceDialogConfirmDeleteVersionCancel => 'Cancel';

  @override
  String get shortVideoSpaceDialogConfirmDeleteVersionConfirm => 'Delete';

  @override
  String get shortVideoSpaceDialogConfirmBatchDisableTitle =>
      'Confirm Batch Disable';

  @override
  String shortVideoSpaceDialogConfirmBatchDisableMessage(int shotCount) {
    return 'Are you sure you want to disable $shotCount selected shots?\n\nDisabled shots will not appear in the final video.';
  }

  @override
  String get shortVideoSpaceDialogConfirmBatchDisableConfirm =>
      'Confirm Disable';

  @override
  String get shortVideoSpaceDialogConfirmRestoreDraftTitle =>
      'Confirm Restore Draft';

  @override
  String shortVideoSpaceDialogConfirmRestoreDraftMessage(String draftName) {
    return 'Are you sure you want to restore draft \"$draftName\"?\n\nCurrent unsaved edits will be lost.';
  }

  @override
  String get shortVideoSpaceDialogConfirmRestoreDraftConfirm => 'Restore';

  @override
  String get shortVideoSpaceDialogConfirmCancelExportTitle => 'Cancel Export';

  @override
  String get shortVideoSpaceDialogConfirmCancelExportMessage =>
      'Are you sure you want to cancel the export? Processed content will be lost.';

  @override
  String get shortVideoSpaceDialogConfirmCancelExportContinue =>
      'Continue Export';

  @override
  String get shortVideoSpaceDialogConfirmCancelExportConfirm =>
      'Confirm Cancel';

  @override
  String get shortVideoSpaceDialogConfirmBatchArchiveTitle =>
      'Confirm Batch Archive';

  @override
  String shortVideoSpaceDialogConfirmBatchArchiveMessage(int draftCount) {
    return 'Are you sure you want to archive $draftCount publish drafts? They will be removed from the publish queue (may be recoverable depending on backend policy).';
  }

  @override
  String get shortVideoSpaceDialogConfirmBatchArchiveConfirm =>
      'Confirm Archive';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsTitle =>
      'Voiceover Settings';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsProviderLabel =>
      'TTS Provider';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsProviderOpenAI =>
      'OpenAI TTS';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsProviderAzure => 'Azure TTS';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsProviderGoogle =>
      'Google TTS';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceLabel => 'Voice';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceAlloy =>
      'Alloy (Neutral)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceEcho => 'Echo (Male)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceFable =>
      'Fable (British)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceOnyx => 'Onyx (Deep)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceNova => 'Nova (Female)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceShimmer =>
      'Shimmer (Soft)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionLabel => 'Emotion';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionNeutral => 'Neutral';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionHappy => 'Happy';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionSad => 'Sad';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionAngry => 'Angry';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsSpeedLabel => 'Speed';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsSpeedRange =>
      'Range: 0.5x (slow) - 2.0x (fast)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsInfoMessage =>
      'Settings will apply to newly generated voiceovers. Existing voiceovers need to be regenerated to apply new parameters.';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsCancel => 'Cancel';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsSave => 'Save';

  @override
  String get shortVideoSpacePublishQualityStageUnlabeled => 'Unlabeled stage';

  @override
  String get shortVideoSpacePublishQualityStageStorySkeleton =>
      'Story skeleton';

  @override
  String get shortVideoSpacePublishQualityStageAdaptationStrategy =>
      'Adaptation strategy';

  @override
  String get shortVideoSpacePublishQualityStageDirectorPlanning =>
      'Director planning';

  @override
  String get shortVideoSpacePublishQualityStageStoryboardTable =>
      'Storyboard table';

  @override
  String get shortVideoSpacePublishQualityStageStoryboardPanel =>
      'Storyboard panel';

  @override
  String get shortVideoSpacePublishQualityStageVideoPrompt =>
      'Video prompt / Final';

  @override
  String get shortVideoSpacePublishExportIssueCandidatePending =>
      'Candidate pending confirmation';

  @override
  String get shortVideoSpacePublishExportIssueMissingSelectedMedia =>
      'Missing final media';

  @override
  String get shortVideoSpacePublishExportIssueSelectedMediaNotVideo =>
      'Selected media is not video';

  @override
  String get shortVideoSpacePublishExportIssueSubtitlePlaceholder =>
      'Subtitle / voiceover text missing';

  @override
  String get shortVideoSpacePublishExportIssueSubtitleEmpty =>
      'Subtitle is empty';

  @override
  String get shortVideoSpacePublishExportIssueVoiceoverFailed =>
      'Voiceover generation failed';

  @override
  String get shortVideoSpacePublishExportIssueVoiceoverAudioMissing =>
      'Voiceover audio not ready';

  @override
  String get shortVideoSpacePublishExportIssueVoiceoverNotReady =>
      'Voiceover not ready';

  @override
  String get shortVideoSpacePublishExportIssueDurationNotExplicit =>
      'Duration not specified (export default)';

  @override
  String get shortVideoSpacePublishExportIssueDurationNotSet =>
      'Duration not set';

  @override
  String get shortVideoSpacePublishExportIssueDurationUnparsable =>
      'Duration format error';

  @override
  String get shortVideoSpacePublishExportIssueCompletionUncertain =>
      'Final status not marked as completed';

  @override
  String get shortVideoSpacePublishAssemblyLoadingHeadline =>
      'Loading final assembly snapshot…';

  @override
  String get shortVideoSpacePublishAssemblyLoadingDetail =>
      'Data from GET …/short-video-assembly (aggregates storyboards and final elements by script order).';

  @override
  String get shortVideoSpacePublishAssemblyUnavailableHeadline =>
      'Final assembly snapshot unavailable.';

  @override
  String get shortVideoSpacePublishAssemblyUnavailableDetail =>
      'Please refresh later, or confirm storyboards and timeline in production workspace.';

  @override
  String get shortVideoSpacePublishAssemblyNoScriptsHeadline =>
      'No script / storyboard assembly data yet.';

  @override
  String shortVideoSpacePublishAssemblyHeadlineScripts(
    int count,
    int shots,
    int seconds,
    String formatted,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scripts',
      one: '1 script',
    );
    return '$_temp0 · $shots shots (export path snapshot)\nTotal duration: ${seconds}s ($formatted)';
  }

  @override
  String get shortVideoSpacePublishAssemblyVoiceProfileNotSet =>
      'Voice profile: Not set';

  @override
  String shortVideoSpacePublishAssemblyVoiceProfile(String profile) {
    return 'Voice profile: $profile';
  }

  @override
  String get shortVideoSpacePublishAssemblySubtitleDefault =>
      'Subtitle: Default';

  @override
  String shortVideoSpacePublishAssemblySubtitle(String style) {
    return 'Subtitle: $style';
  }

  @override
  String get shortVideoSpacePublishAssemblyBgmNotSpecified =>
      'BGM: Not specified';

  @override
  String shortVideoSpacePublishAssemblyBgm(String strategy) {
    return 'BGM: $strategy';
  }

  @override
  String shortVideoSpacePublishAssemblyEffectiveTts(String voice) {
    return 'Effective TTS (queue/worker): $voice';
  }

  @override
  String shortVideoSpacePublishAssemblyScriptTitle(int id) {
    return 'Script #$id';
  }

  @override
  String shortVideoSpacePublishAssemblyScriptTitleNamed(int id, String name) {
    return 'Script #$id · $name';
  }

  @override
  String shortVideoSpacePublishAssemblyScriptSummary(
    String title,
    int shots,
    int withMedia,
    int voReady,
  ) {
    return '$title · $shots shots · Final selected $withMedia · Voiceover ready $voReady';
  }

  @override
  String get shortVideoSpacePublishAssemblyShotPreviewYes => 'Preview✓';

  @override
  String get shortVideoSpacePublishAssemblyShotPreviewNo => 'Preview×';

  @override
  String get shortVideoSpacePublishAssemblyShotDurationUnknown => 'Duration?';

  @override
  String get shortVideoSpacePublishAssemblyShotSubtitleYes => 'Subtitle✓';

  @override
  String get shortVideoSpacePublishAssemblyShotSubtitleNo => 'Subtitle×';

  @override
  String get shortVideoSpacePublishAssemblyShotVoiceoverYes => 'Voiceover✓';

  @override
  String get shortVideoSpacePublishAssemblyShotVoiceoverNo => 'Voiceover×';

  @override
  String get shortVideoSpacePublishAssemblyShotBgmDefault => 'Default';

  @override
  String shortVideoSpacePublishAssemblyShotDetail(
    String order,
    String preview,
    String duration,
    String subtitle,
    String voiceover,
    String bgm,
  ) {
    return 'Shot[$order] · $preview · $duration · $subtitle · $voiceover · BGM $bgm';
  }

  @override
  String shortVideoSpacePublishAssemblyMoreShots(int count) {
    return '…$count more shots, view in production workspace timeline';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityProjectBadCase(int count) {
    return 'Project-level bad cases pending review: $count (same source as production overview)';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityAssemblyReviews(
    int total,
    int badCase,
    int shots,
  ) {
    return 'Reviews on current assembly storyboards: $total · Bad cases $badCase · Affected storyboards $shots';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityLateStageBadCase(int count) {
    return 'Late-stage bad cases (storyboard panel/video prompt): $count';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityByStage(String stages) {
    return 'By stage: $stages';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityStageBadCase(
    String stage,
    int count,
  ) {
    return '$stage · Bad cases $count';
  }

  @override
  String get shortVideoSpacePublishAssemblyQualityTaskCenterHint =>
      'In task center, you can filter quality review list by project; storyboard-level targets match assembly.';

  @override
  String shortVideoSpacePublishAssemblyMultiTrackEstimate(
    int subtitle,
    int voiceover,
    int bgm,
    int total,
  ) {
    return 'Track usage estimate: Video 1 + Subtitle $subtitle + Voiceover $voiceover + BGM $bgm = $total tracks.';
  }

  @override
  String shortVideoSpacePublishAssemblyMaterialReady(
    int video,
    int subtitle,
    int voiceover,
    int totalShots,
  ) {
    return 'Materials ready: Video shots $video/$totalShots, Subtitle shots $subtitle/$totalShots, Voiceover shots $voiceover/$totalShots.';
  }

  @override
  String shortVideoSpacePublishAssemblyDurationEstimate(
    int known,
    int total,
    String minutes,
  ) {
    return 'Duration estimate: Identified $known/$total shots, total duration ~$minutes minutes.';
  }

  @override
  String get shortVideoSpacePublishAssemblyExportDecisionProfessional =>
      'Export decision: Exceeds limited multi-track boundary (>4 tracks or complex duration), recommend professional platform (Requirement 8.2).';

  @override
  String get shortVideoSpacePublishAssemblyExportDecisionLimited =>
      'Export decision: Maintain limited multi-track (<=4 tracks) path, can continue export in current pipeline.';

  @override
  String get shortVideoSpacePublishAssemblyBoundaryNote =>
      'Boundary note: Space only covers \"video + single subtitle track + voiceover + BGM\" limited mixing, not a replacement for professional NLE.';

  @override
  String get shortVideoSpacePublishAssemblyDetail =>
      'Read-only editing desk: Shows shot order, duration, subtitle, voiceover, BGM and preview readiness summary; export blocking conclusions see \"Export Pre-check\" below.';

  @override
  String get shortVideoSpacePublishExportCheckLoadingHeadline =>
      'Loading export pre-check…';

  @override
  String get shortVideoSpacePublishExportCheckLoadingDetail =>
      'Aggregates storyboard blocking and warnings; quality gate observation fields are placeholder display only.';

  @override
  String get shortVideoSpacePublishExportCheckUnavailableHeadline =>
      'Export pre-check unavailable.';

  @override
  String get shortVideoSpacePublishExportCheckUnavailableDetail =>
      'Please refresh page later, or confirm storyboards in production workspace.';

  @override
  String get shortVideoSpacePublishExportCheckReadyHeadline =>
      'Server found no blocking issues (still need to confirm final in production).';

  @override
  String get shortVideoSpacePublishExportCheckBlockingHeadline =>
      'Blocking items exist: Recommend completing fields in production workspace before export / final.';

  @override
  String get shortVideoSpacePublishExportCheckMetricStoryboards =>
      'Storyboards';

  @override
  String get shortVideoSpacePublishExportCheckMetricBlocking => 'Blocking';

  @override
  String get shortVideoSpacePublishExportCheckMetricWarning => 'Warning';

  @override
  String get shortVideoSpacePublishExportCheckMetricExportable => 'Exportable';

  @override
  String get shortVideoSpacePublishExportCheckMetricYes => 'Yes';

  @override
  String get shortVideoSpacePublishExportCheckMetricNo => 'No';

  @override
  String get shortVideoSpacePublishExportCheckQualityGateOff =>
      'Quality gate: Off (no quality check).';

  @override
  String get shortVideoSpacePublishExportCheckQualityGateWarnNoBadCase =>
      'Quality gate: Warn mode - No pending review bad cases (export allowed).';

  @override
  String shortVideoSpacePublishExportCheckQualityGateWarnWithBadCase(
    int count,
  ) {
    return 'Quality gate: Warn mode - $count pending review bad cases (export allowed but recommend fixing).';
  }

  @override
  String shortVideoSpacePublishExportCheckQualityGateBlockEnforcedWithBadCase(
    int count,
  ) {
    return 'Quality gate: Block mode - $count pending review bad cases (blocks export, must fix first).';
  }

  @override
  String
  shortVideoSpacePublishExportCheckQualityGateBlockNotEnforcedWithBadCase(
    int count,
  ) {
    return 'Quality gate: Block mode - $count pending review bad cases (not enforced yet).';
  }

  @override
  String get shortVideoSpacePublishExportCheckQualityGateBlockNoBadCase =>
      'Quality gate: Block mode - No pending review bad cases (export allowed).';

  @override
  String shortVideoSpacePublishExportCheckQualityGateUnknown(String strategy) {
    return 'Quality gate: Unknown strategy \"$strategy\".';
  }

  @override
  String shortVideoSpacePublishExportCheckBlockingIssue(
    int scriptId,
    int sbId,
    String sbIndex,
    String label,
    String detail,
  ) {
    return 'Script #$scriptId · Storyboard #$sbId$sbIndex · $label · $detail';
  }

  @override
  String get shortVideoSpacePublishExportCheckDetailReady =>
      'Blocking count is 0, indicating no hard blocking on server aggregation path (still subject to actual export pipeline).';

  @override
  String get shortVideoSpacePublishExportCheckDetailBlocking =>
      'Below lists some blocking items; for complete list, check each shot in production workspace.';

  @override
  String get shortVideoSpacePublishCandidateLoadingHeadline =>
      'Loading project assets…';

  @override
  String get shortVideoSpacePublishCandidateLoadingDetail =>
      'Used to count candidate workflow: pending / linked / ignored (consistent with PATCH asset).';

  @override
  String get shortVideoSpacePublishCandidateUnavailableHeadline =>
      'Candidate asset summary unavailable.';

  @override
  String get shortVideoSpacePublishCandidateUnavailableDetail =>
      'Please refresh page later, or go to project area to view and edit assets.';

  @override
  String get shortVideoSpacePublishCandidateNoTrackedHeadline =>
      'No pending / linked / ignored marked yet; can PATCH candidate_status on shot candidates and other assets in project area.';

  @override
  String get shortVideoSpacePublishCandidateTrackedHeadline =>
      'Candidate status aggregated by project (counts below include unmarked):';

  @override
  String shortVideoSpacePublishCandidateDetail(int total) {
    return 'Project has $total assets; counts aggregated by server in one go (no pagination). Can update via PATCH candidate_status in project area.';
  }

  @override
  String get shortVideoSpacePublishPanelLoadingHeadline =>
      'Loading export check and publish domain…';

  @override
  String get shortVideoSpacePublishPanelLoadingDetail =>
      'Backend path: `/api/v1/projects/:id/publish/*` (profiles / drafts / jobs).';

  @override
  String get shortVideoSpacePublishPanelUnavailableHeadline =>
      'Publish domain interface unavailable (database migration may not be executed yet).';

  @override
  String get shortVideoSpacePublishPanelUnavailableExportGateMissing =>
      'Export check data missing, publish panel shows placeholder only.';

  @override
  String get shortVideoSpacePublishPanelUnavailableExportGateNoBlocking =>
      'Export check: Currently no blocking items.';

  @override
  String shortVideoSpacePublishPanelUnavailableExportGateBlocking(int count) {
    return 'Export check: Still $count blocking items.';
  }

  @override
  String get shortVideoSpacePublishPanelUnavailableDetail =>
      'Confirm Supabase has applied `app_publish_*` migrations then retry; Rust worker will digest publish job queue in background.';

  @override
  String get shortVideoSpacePublishPanelExportGateUnavailable =>
      'Export check data unavailable; can still try creating publish draft and validate.';

  @override
  String get shortVideoSpacePublishPanelExportGateReady =>
      'Export check: No blocking items (**E13**: Can enter publish preparation from final pipeline).';

  @override
  String shortVideoSpacePublishPanelExportGateBlocking(int count) {
    return 'Export check: Still $count blocking items; can complete fields first then submit job.';
  }

  @override
  String shortVideoSpacePublishPanelHeadline(int drafts, int jobs) {
    return 'Connected to publish API: $drafts drafts · $jobs jobs.';
  }

  @override
  String shortVideoSpacePublishPanelCurrentDraft(String title) {
    return 'Current draft: $title';
  }

  @override
  String get shortVideoSpacePublishPanelCurrentDraftUntitled =>
      'Current draft: (Untitled)';

  @override
  String get shortVideoSpacePublishPanelSelectDraftWarning =>
      '⚠️ Please explicitly select draft (no longer auto-use first one)';

  @override
  String get shortVideoSpacePublishPanelPrepareCheckOk =>
      'Validation: ✓ Current draft meets placeholder rules (still needs real final reference to actually go live).';

  @override
  String get shortVideoSpacePublishPanelPrepareCheckMultipleDrafts =>
      'When multiple drafts exist, please select one in \"Current Operation Draft\" first, then show prepare-check.';

  @override
  String get shortVideoSpacePublishPanelPrepareCheckSelectFirst =>
      'After selecting draft, will show prepare-check validation result.';

  @override
  String get shortVideoSpacePublishPanelPrepareCheckNoDraft =>
      'No draft yet or prepare-check not completed.';

  @override
  String get shortVideoSpacePublishPanelDraftNoTitle => '(Untitled)';

  @override
  String get shortVideoSpacePublishPanelDraftMissingVideo =>
      ' · Missing video reference';

  @override
  String shortVideoSpacePublishPanelDraftScheduled(String time) {
    return ' · Scheduled $time';
  }

  @override
  String shortVideoSpacePublishPanelJobShortId(String id) {
    return '$id…';
  }

  @override
  String shortVideoSpacePublishPanelJobError(String error) {
    return ' · $error';
  }

  @override
  String shortVideoSpacePublishPanelOverviewSucceeded(int count) {
    return 'Succeeded jobs: $count';
  }

  @override
  String shortVideoSpacePublishPanelOverviewFailed(int count) {
    return 'Failed/Partial failed: $count';
  }

  @override
  String shortVideoSpacePublishPanelOverviewAwaiting(int count) {
    return 'Awaiting confirmation: $count';
  }

  @override
  String shortVideoSpacePublishPanelOverviewScheduled(
    int scheduled,
    int total,
  ) {
    return 'Scheduled drafts: $scheduled/$total';
  }

  @override
  String shortVideoSpacePublishPanelOverviewDeliveryModes(String modes) {
    return 'Delivery modes: $modes';
  }

  @override
  String shortVideoSpacePublishPanelOverviewPerformanceAlerts(int count) {
    return 'Low performance alerts: $count (recommend troubleshooting in task center and rewriting copy)';
  }

  @override
  String shortVideoSpacePublishPanelOverviewPerformanceAlert(
    String platform,
    int views,
    String rate,
  ) {
    return '$platform · Views $views · Completion $rate%';
  }

  @override
  String shortVideoSpacePublishPanelOverviewAudit(
    String platform,
    String status,
    String mode,
  ) {
    return 'Audit: $platform · $status · mode=$mode';
  }

  @override
  String shortVideoSpacePublishPanelOverviewTargetAutomation(String modes) {
    return 'Target automation: $modes';
  }

  @override
  String get shortVideoSpacePublishPanelDetail =>
      'Semi-auto jobs need \"Confirm\" when in `awaiting_confirmation`; worker skeleton will write `publish_attempts` placeholder success records.';

  @override
  String get shortVideoSpaceProductionAssemblyExportCompleted =>
      'Export completed.';

  @override
  String get shortVideoSpaceProductionAssemblyExportNotCompleted =>
      'Export not completed or cancelled.';

  @override
  String shortVideoSpaceProductionAssemblyExportStartFailed(String error) {
    return 'Export start failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyReplaceVideoTitle =>
      'Replace current video version';

  @override
  String get shortVideoSpaceProductionAssemblyVideoUrlLabel => 'Video URL';

  @override
  String get shortVideoSpaceProductionAssemblyVideoUrlHint => 'https://...';

  @override
  String get shortVideoSpaceProductionAssemblyCancel => 'Cancel';

  @override
  String get shortVideoSpaceProductionAssemblyWriteBackVersion =>
      'Write back current version';

  @override
  String shortVideoSpaceProductionAssemblyShotDisabled(int storyboardId) {
    return 'Shot #$storyboardId paused (cleared current video).';
  }

  @override
  String shortVideoSpaceProductionAssemblyDisableFailed(String error) {
    return 'Pause failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyNoVideoUrl =>
      'No available video URL, please enter replacement address first.';

  @override
  String shortVideoSpaceProductionAssemblyShotWriteBack(int storyboardId) {
    return 'Shot #$storyboardId wrote back current video version.';
  }

  @override
  String shortVideoSpaceProductionAssemblyWriteBackFailed(String error) {
    return 'Write back failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyReorderPersisted =>
      'Persisted shot reorder (wrote back timeline and shot numbers by script).';

  @override
  String shortVideoSpaceProductionAssemblyReorderFailed(String error) {
    return 'Reorder persistence failed: $error';
  }

  @override
  String shortVideoSpaceProductionAssemblyShotAligned(
    int storyboardId,
    int duration,
  ) {
    return 'Shot #$storyboardId aligned to ${duration}s.';
  }

  @override
  String shortVideoSpaceProductionAssemblyAlignFailed(String error) {
    return 'Duration alignment failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblySubtitleExistsDurationMissing =>
      'Subtitle exists, but duration not explicit (suggest aligning duration first).';

  @override
  String get shortVideoSpaceProductionAssemblyDurationSetSubtitleEmpty =>
      'Duration is set, but subtitle is empty (possible subtitle track gap).';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleExistsDurationAbnormal =>
      'Subtitle exists, but duration is abnormal (<=0).';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleDurationNoMismatch =>
      'No obvious subtitle-duration mismatch.';

  @override
  String get shortVideoSpaceProductionAssemblyBasicOpsTitle =>
      'Basic shot operations';

  @override
  String get shortVideoSpaceProductionAssemblyBasicOpsDescription =>
      'Supports basic reordering (this panel view), enable/disable, and replace current video version.';

  @override
  String get shortVideoSpaceProductionAssemblyBasicOpsNote =>
      'Enable/disable/replace writes back directly to J media slot; reorder is for this troubleshooting view only.';

  @override
  String shortVideoSpaceProductionAssemblyTotalDuration(
    int seconds,
    String formatted,
  ) {
    return 'Total finished duration: ${seconds}s ($formatted)';
  }

  @override
  String get shortVideoSpaceProductionAssemblySaveReorder => 'Save reorder';

  @override
  String get shortVideoSpaceProductionAssemblyUndoToOpen => 'Undo to open time';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverTasks =>
      'Voiceover tasks';

  @override
  String get shortVideoSpaceProductionAssemblyClose => 'Close';

  @override
  String get shortVideoSpaceProductionAssemblyNoShotsFiltered =>
      'No shots under current filter conditions, try clearing search or relaxing criteria.';

  @override
  String shortVideoSpaceProductionAssemblyScriptShotOrder(
    int scriptId,
    int storyboardId,
    int order,
  ) {
    return 'Script #$scriptId · Shot #$storyboardId · Order $order';
  }

  @override
  String get shortVideoSpaceProductionAssemblyStatusPaused => 'Status: Paused';

  @override
  String shortVideoSpaceProductionAssemblyStatusEnabled(String kind) {
    return 'Status: Enabled ($kind)';
  }

  @override
  String get shortVideoSpaceProductionAssemblyDurationLabel => 'Duration:';

  @override
  String get shortVideoSpaceProductionAssemblyDurationNotSet => 'Not set';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleLabel => 'Subtitle:';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleEmpty => 'Empty';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverScriptReady =>
      'Voiceover script: ✓ Ready';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverScriptNotReady =>
      'Voiceover script: ✗ Not ready';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverAssetReady =>
      'Voiceover asset: ✓ Ready';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverAssetNotReady =>
      'Voiceover asset: ✗ Not ready';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverStatusLabel =>
      'Voiceover status:';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverAudioLabel =>
      'Voiceover audio:';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverErrorLabel =>
      'Voiceover error:';

  @override
  String get shortVideoSpaceProductionAssemblyMismatchCheckLabel =>
      'Mismatch check:';

  @override
  String get shortVideoSpaceProductionAssemblyMoveUp => 'Move up';

  @override
  String get shortVideoSpaceProductionAssemblyMoveDown => 'Move down';

  @override
  String get shortVideoSpaceProductionAssemblyEnable => 'Enable';

  @override
  String get shortVideoSpaceProductionAssemblyPause => 'Pause';

  @override
  String get shortVideoSpaceProductionAssemblyAlignDuration => 'Align duration';

  @override
  String get shortVideoSpaceProductionAssemblyReplaceVersion =>
      'Replace current version';

  @override
  String get shortVideoSpaceProductionAssemblyGenerateVoiceover =>
      'Generate voiceover';

  @override
  String get shortVideoSpaceProductionAssemblyPreviewVoiceover =>
      'Preview voiceover';

  @override
  String get shortVideoSpaceProductionAssemblySingleShotDurationTitle =>
      'Single shot duration alignment';

  @override
  String get shortVideoSpaceProductionAssemblySingleShotDurationLabel =>
      'Duration (seconds)';

  @override
  String get shortVideoSpaceProductionAssemblySingleShotDurationHint =>
      'Enter 1~300';

  @override
  String get shortVideoSpaceProductionAssemblyAlignAndWriteBack =>
      'Align and write back';

  @override
  String get shortVideoSpaceProductionAssemblyAssemblyStyleTitle =>
      'Assembly-level style adjustment';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleStyleLabel =>
      'Subtitle style subtitle_style';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleStyleHint =>
      'e.g. cinematic_cn_v2 (leave empty to fall back to default)';

  @override
  String get shortVideoSpaceProductionAssemblyBgmStrategyLabel =>
      'BGM strategy bgm_strategy';

  @override
  String get shortVideoSpaceProductionAssemblyBgmStrategyHint =>
      'e.g. pulse_light (leave empty to fall back to default)';

  @override
  String get shortVideoSpaceProductionAssemblyStyleNote =>
      'After saving, will write back D7 default configuration and refresh effective values in assembly snapshot.';

  @override
  String get shortVideoSpaceProductionAssemblySaveAndRefresh =>
      'Save and refresh';

  @override
  String shortVideoSpaceProductionAssemblyStyleUpdated(
    String subtitle,
    String bgm,
  ) {
    return 'Updated assembly-level defaults: subtitle $subtitle · BGM $bgm';
  }

  @override
  String get shortVideoSpaceProductionAssemblyStyleDefault => 'default';

  @override
  String shortVideoSpaceProductionAssemblyStyleWriteBackFailed(String error) {
    return 'Assembly style write back failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverTaskCenterTitle =>
      'Voiceover task center';

  @override
  String get shortVideoSpaceProductionAssemblyAllStatus => 'All status';

  @override
  String get shortVideoSpaceProductionAssemblyRefresh => 'Refresh';

  @override
  String get shortVideoSpaceProductionAssemblyGroupByShot => 'Group by shot';

  @override
  String shortVideoSpaceProductionAssemblyBatchRetryFailed(int count) {
    return 'Batch retry failed ($count)';
  }

  @override
  String get shortVideoSpaceProductionAssemblyFilterTaskIdScriptShot =>
      'Filter: Task ID / Script # / Shot #';

  @override
  String shortVideoSpaceProductionAssemblyTaskSummary(
    int total,
    int queued,
    int running,
    int succeeded,
    int failed,
    int cancelled,
    int filtered,
    int visible,
  ) {
    return 'Total $total · queued $queued · running $running · succeeded $succeeded · failed $failed · cancelled $cancelled · Showing $filtered/$visible';
  }

  @override
  String get shortVideoSpaceProductionAssemblyNoVoiceoverTasks =>
      'No voiceover tasks yet';

  @override
  String shortVideoSpaceProductionAssemblyTaskEntry(
    String prefix,
    String taskId,
    String status,
  ) {
    return '$prefix $taskId · Status $status';
  }

  @override
  String get shortVideoSpaceProductionAssemblyLatestTask => 'Latest task';

  @override
  String get shortVideoSpaceProductionAssemblyTask => 'Task';

  @override
  String shortVideoSpaceProductionAssemblyTaskSubtitle(
    String scriptId,
    String shotId,
    String audio,
    String error,
  ) {
    return 'Script #$scriptId · Shot #$shotId$audio$error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyTaskSubtitleAudioReady =>
      ' · Audio ready';

  @override
  String shortVideoSpaceProductionAssemblyTaskSubtitleError(String error) {
    return ' · Error: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyPreviewAudio => 'Preview audio';

  @override
  String get shortVideoSpaceProductionAssemblyCopyAudioLink =>
      'Copy audio link';

  @override
  String get shortVideoSpaceProductionAssemblyAudioLinkCopied =>
      'Audio link copied';

  @override
  String get shortVideoSpaceProductionAssemblyCancelTask => 'Cancel';

  @override
  String shortVideoSpaceProductionAssemblyTaskCancelled(String taskId) {
    return 'Cancelled voiceover task $taskId';
  }

  @override
  String shortVideoSpaceProductionAssemblyCancelFailed(String error) {
    return 'Cancel failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyRetryTask => 'Retry';

  @override
  String shortVideoSpaceProductionAssemblyTaskRetried(String taskId) {
    return 'Retried, task $taskId queued';
  }

  @override
  String shortVideoSpaceProductionAssemblyRetryFailed(String error) {
    return 'Retry failed: $error';
  }

  @override
  String shortVideoSpaceProductionAssemblyBatchRetryCompleted(
    int succeeded,
    int failed,
  ) {
    return 'Batch retry completed: succeeded $succeeded, failed $failed';
  }

  @override
  String shortVideoSpaceProductionAssemblyLoadFailed(String error) {
    return 'Load failed: $error';
  }
}
