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
  String get shortVideoSpaceUndoRedoOperationDefault => 'Operation';

  @override
  String shortVideoSpaceUndoSucceeded(String description) {
    return 'Undone: $description';
  }

  @override
  String shortVideoSpaceUndoFailed(String error) {
    return 'Undo failed: $error';
  }

  @override
  String shortVideoSpaceRedoSucceeded(String description) {
    return 'Redone: $description';
  }

  @override
  String shortVideoSpaceRedoFailed(String error) {
    return 'Redo failed: $error';
  }

  @override
  String get shortVideoSpacePreviewVideoLoadFailed => 'Failed to load video';

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
  String globalSearchNovelEventNavigated(String eventId) {
    return 'Located project. Please open \"Novels & Events\" in project details to view the outline event (event #$eventId).';
  }

  @override
  String globalSearchNovelChapterNavigated(String chapterIndex) {
    return 'Located project. Please open \"Novels & Events\" in project details to view the chapter (chapter index $chapterIndex).';
  }

  @override
  String accountDeletedSummary(
    int workspaceCount,
    int projectCount,
    int jobCount,
  ) {
    return 'Account deleted: workspace $workspaceCount · project $projectCount · job $jobCount';
  }

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
  String get projectMembersTitle => 'Project member ACL';

  @override
  String get projectMembersAclEnabledIntro =>
      'This project has explicit ACL enabled: regular members will only have access according to viewer / editor rows; workspace owner/admin still have full permissions.';

  @override
  String get projectMembersAclInheritedIntro =>
      'This project is in workspace inheritance mode: regular members inherit original project access permissions. Adding the first explicit ACL row will switch the project to restricted mode.';

  @override
  String get projectMembersChipMode => 'Mode';

  @override
  String get projectMembersChipExplicitMembers => 'Explicit members';

  @override
  String get projectMembersChipCandidates => 'Candidate workspace members';

  @override
  String get projectMembersForbiddenTitle =>
      'Current account cannot manage project ACL';

  @override
  String get projectMembersForbiddenBody =>
      'Only workspace owner/admin or project owner can view and modify explicit project members. If you only need to continue editing other content, the current project will still work normally according to existing workspace / project permissions.';

  @override
  String get projectMembersAddSectionTitle => 'Add explicit member';

  @override
  String get projectMembersAddSectionIntro =>
      'Prefer selecting from current workspace members; if you cannot access the workspace member list at the moment, you can also directly enter a user UUID for controlled supplementation.';

  @override
  String get projectMembersFieldGrantRole => 'Grant role';

  @override
  String get projectMembersRoleViewer => 'viewer';

  @override
  String get projectMembersRoleEditor => 'editor';

  @override
  String get projectMembersLoadingWorkspaceMembers =>
      'Loading workspace members...';

  @override
  String get projectMembersForbiddenWorkspaceMembers =>
      'Current account does not have permission to read workspace member list; you can still directly enter user UUID for explicit ACL management.';

  @override
  String get projectMembersNoWorkspaceContext =>
      'This project temporarily has no available workspace context, manual UUID entry is retained.';

  @override
  String get projectMembersNoCandidates =>
      'Currently no regular workspace members can be directly added. owner/admin already have natural project access permissions, members with explicit rows are listed below.';

  @override
  String get projectMembersFieldSelectFromWorkspace =>
      'Add from workspace members';

  @override
  String get projectMembersButtonAdd => 'Add';

  @override
  String get projectMembersFieldManualUserId => 'Manually enter user UUID';

  @override
  String get projectMembersFieldManualUserIdHint =>
      '00000000-0000-0000-0000-000000000000';

  @override
  String get projectMembersButtonAddByUuid => 'Add by UUID';

  @override
  String get projectMembersExplicitSectionTitle => 'Explicit ACL rows';

  @override
  String get projectMembersExplicitEmptyIntro =>
      'Currently no explicit project members. Project still works in workspace inheritance mode.';

  @override
  String get projectMembersExplicitNonEmptyIntro =>
      'These rows are the viewer/editor rules actually enabled for the current project. After removing the last row, the project will return to inherited mode.';

  @override
  String get projectMembersExplicitEmptyState => 'No explicit ACL rows';

  @override
  String get projectMembersTooltipCopyUserId => 'Copy user UUID';

  @override
  String get projectMembersTagExplicitRole => 'Explicit role';

  @override
  String get projectMembersTagWorkspaceRole => 'workspace role';

  @override
  String get projectMembersTagUpdatedAt => 'Updated at';

  @override
  String get projectMembersFieldUpdateRole => 'Update role';

  @override
  String get projectMembersTooltipSaveRole => 'Save role';

  @override
  String get projectMembersTooltipRemoveAcl => 'Remove explicit ACL';

  @override
  String get projectMembersButtonRefresh => 'Refresh';

  @override
  String get projectMembersSnackInvalidUuid => 'Please enter a valid user UUID';

  @override
  String get projectMembersSnackNoCandidates =>
      'Currently no workspace members can be directly added';

  @override
  String get projectMembersSnackMemberAdded => 'Project member added';

  @override
  String get projectMembersSnackRoleUpdated => 'Role updated';

  @override
  String get projectMembersSnackAclRemoved => 'Explicit ACL removed';

  @override
  String get projectMembersSnackUserIdCopied => 'User UUID copied';

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
  String qualityReviewsDashboardStatsScopePrefix(String scope) {
    return 'scope=$scope · ';
  }

  @override
  String qualityReviewsDashboardTargetStatRow(
    String targetType,
    int totalReviews,
    String passPct,
    String avgScore,
  ) {
    return '$targetType: total=$totalReviews, pass=$passPct%, avg=$avgScore';
  }

  @override
  String qualityReviewsDashboardStagePassRateRow(
    String date,
    String targetType,
    String passPct,
    int totalReviews,
  ) {
    return '$date $targetType: pass=$passPct%, total=$totalReviews';
  }

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
  String get adminConsoleDailyQuotaInputExample => 'e.g. 100';

  @override
  String get adminConsoleDailyQuotaInputDisabledHint => 'Unlimited';

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
  String projectEditorScriptsSectionCountLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scripts',
      one: '1 script',
      zero: '0 scripts',
    );
    return '$_temp0';
  }

  @override
  String get projectEditorScriptsSectionIntroBody =>
      'Manage scripts under this project and open a script to edit content and storyboards.';

  @override
  String get projectEditorScriptsSectionBatchWorkbenchTitle =>
      'Script batch workbench';

  @override
  String get projectEditorScriptsSectionBatchWorkbenchDescription =>
      'Brings project-level script context reads, batch export, extract polling, asset extraction, and batch creation into one workbench instead of relying only on shortcut buttons.';

  @override
  String get projectEditorScriptsSectionOpenBatchWorkbench =>
      'Open script batch workbench';

  @override
  String get projectEditorScriptsSectionOpenPlanWorkbench =>
      'Open plan workbench';

  @override
  String get projectEditorScriptsSectionSuggestionsTitle =>
      'Current batch suggestions';

  @override
  String get projectEditorScriptsSectionBatchAdd => 'Batch add scripts';

  @override
  String get projectEditorScriptsSectionExportAll => 'Export all scripts';

  @override
  String get projectEditorScriptsSectionPollAllExtract =>
      'Poll extract state for all';

  @override
  String get projectEditorScriptsSectionExtractAllMaterials =>
      'Extract materials for all scripts';

  @override
  String get projectEditorScriptsSectionCreateEmpty => 'Create empty script';

  @override
  String get projectEditorScriptsSectionCompatibilityTile =>
      'Compatibility checks';

  @override
  String get projectEditorScriptsSectionCompatibilitySubtitle =>
      'Legacy script APIs plus export/extract regression hooks; collapsed by default.';

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
  String get projectEditorProbeGeneralBusyLabel => 'general…';

  @override
  String get projectEditorProbeGeneralButtonGetSingleProject =>
      'compat getSingleProject';

  @override
  String get projectEditorProbeGeneralButtonUpdateProject =>
      'compat updateProject';

  @override
  String get projectEditorProbeGeneralButtonPatchProjectNameNoop =>
      'PATCH …/projects (name noop)';

  @override
  String get projectEditorProbeGeneralGetSingleZeroRows => '0 rows';

  @override
  String projectEditorProbeGeneralGetSingleSnack(String line) {
    return 'compat getSingleProject (GET …/projects filter numeric_id): $line';
  }

  @override
  String projectEditorProbeGeneralUpdateProjectSnack(
    String probeMsg,
    String restoreMsg,
  ) {
    return 'compat updateProject (PATCH …/projects): $probeMsg → restored ($restoreMsg)';
  }

  @override
  String projectEditorProbeGeneralPatchNameNoopSnack(String name) {
    return 'PATCH …/projects name noop → $name';
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
  String get projectEditorNovelsSummaryNoChapters => 'No novel chapters yet';

  @override
  String projectEditorNovelsSummaryChaptersLine(
    int count,
    String visible,
    String suffix,
  ) {
    return '$count chapters · $visible$suffix';
  }

  @override
  String get projectEditorNovelsSummaryIntakeEmptyBaseline =>
      'Intake admitted 0 / pending 0 / rejected 0 · source manual 0 / import 0 / crawler_client 0 / crawler_server 0';

  @override
  String projectEditorNovelsSummaryIntakeCounts(
    int admitted,
    int pending,
    int rejected,
    int manual,
    int bookImport,
    int crawlerClient,
    int crawlerServer,
  ) {
    return 'Intake admitted $admitted / pending $pending / rejected $rejected · source manual $manual / import $bookImport / crawler_client $crawlerClient / crawler_server $crawlerServer';
  }

  @override
  String get projectEditorNovelsSummaryNoEvents => 'No novel events yet';

  @override
  String projectEditorNovelsSummaryEventsLine(
    int count,
    String visible,
    String suffix,
  ) {
    return '$count events · $visible$suffix';
  }

  @override
  String get projectEditorAssetsWorkbenchNoAssetsYet =>
      'This project has no assets yet. You can create one here.';

  @override
  String get projectEditorAssetsSectionListNotLoaded =>
      'Asset list not loaded yet.';

  @override
  String projectEditorNovelsWorkbenchDefaultNewChapterTitle(int stamp) {
    return 'Chapter_$stamp';
  }

  @override
  String get projectEditorNovelsWorkbenchDefaultNewChapterBody =>
      'Enter chapter body here.';

  @override
  String get projectEditorStylePackTagArt => 'Art';

  @override
  String get projectEditorStylePackTagStory => 'Story';

  @override
  String get projectEditorStylePackNoDescriptionFallback =>
      'No description yet';

  @override
  String get projectEditorNovelImportCrawlerBodyFallbackTitle => 'Fetched body';

  @override
  String projectEditorNovelImportFallbackChapterTitle(int index) {
    return 'Imported chapter $index';
  }

  @override
  String get projectEditorNovelImportQualityNoChaptersBlocker =>
      'No importable body chapters';

  @override
  String projectEditorNovelImportQualityTotalCharsTooLowBlocker(
    int totalChars,
  ) {
    return 'Body text too short ($totalChars characters); extraction may have failed';
  }

  @override
  String projectEditorNovelImportQualityAvgCharsTooLowBlocker(int avgChars) {
    return 'Average chapter length too low ($avgChars characters); check chapter splits';
  }

  @override
  String projectEditorNovelImportQualityDuplicateHighBlocker(
    int duplicateRatioPercent,
  ) {
    return 'Chapter body duplicate ratio too high ($duplicateRatioPercent%)';
  }

  @override
  String projectEditorNovelImportQualityDuplicatePartialWarning(
    int duplicateRatioPercent,
  ) {
    return 'Some duplicate body text detected ($duplicateRatioPercent%)';
  }

  @override
  String get projectEditorNovelImportQualitySingleChapterWarning =>
      'Only 1 chapter detected; the book may not be split correctly';

  @override
  String projectEditorNovelImportQualityManyChaptersWarning(int count) {
    return 'Many chapters ($count); spot-check split accuracy';
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
  String get projectEditorNovelsIntakeStatusValueDraft => 'Draft';

  @override
  String get projectEditorNovelsIntakeStatusValuePendingReview =>
      'Pending review';

  @override
  String get projectEditorNovelsIntakeStatusValueAdmitted => 'Admitted';

  @override
  String get projectEditorNovelsIntakeStatusValueRejected => 'Rejected';

  @override
  String get projectEditorNovelsIntakeSourceValueManual => 'Manual';

  @override
  String get projectEditorNovelsIntakeSourceValueWholeBookImport =>
      'Whole book import';

  @override
  String get projectEditorNovelsIntakeSourceValueCrawlerClient =>
      'Crawler (client)';

  @override
  String get projectEditorNovelsIntakeSourceValueCrawlerServer =>
      'Crawler (server)';

  @override
  String get projectEditorNovelsProbeMutationGenerateEventsButton =>
      'POST generate-events (top 3)';

  @override
  String get projectEditorNovelsProbeMutationAddNovelEmptyButton =>
      'POST add-novel []';

  @override
  String get projectEditorNovelsProbeMutationBatchDeleteEmptyButton =>
      'POST batch-delete []';

  @override
  String get projectEditorNovelsProbeMutationDeleteNovelZeroButton =>
      'POST delete-novel id=0';

  @override
  String get projectEditorNovelsProbeMutationUpdateNovelNoopButton =>
      'POST update-novel (noop)';

  @override
  String projectEditorNovelsProbeMutationGenerateEventsSnackbar(String detail) {
    return 'POST …/novel-events/generate-events: $detail';
  }

  @override
  String projectEditorNovelsProbeMutationAddNovelEmptySnackbar(String detail) {
    return 'POST …/novels/add-novel (empty body): $detail';
  }

  @override
  String get projectEditorNovelsProbeMutationBatchDeleteUnexpected200Snackbar =>
      'POST …/novels/batch-delete: unexpected 200 OK';

  @override
  String get projectEditorNovelsProbeMutationBatchDeleteExpected400Snackbar =>
      'POST …/novels/batch-delete [] → 400 (expected)';

  @override
  String get projectEditorNovelsProbeMutationDeleteNovelUnexpected200Snackbar =>
      'POST …/novels/delete-novel: unexpected 200 OK';

  @override
  String get projectEditorNovelsProbeMutationDeleteNovelExpected400Snackbar =>
      'POST …/novels/delete-novel id=0 → 400 (expected)';

  @override
  String projectEditorNovelsProbeMutationUpdateNovelNoopSnackbar(
    int id,
    String detail,
  ) {
    return 'POST …/novels/update-novel noop #$id: $detail';
  }

  @override
  String get projectEditorNovelsCompatibilitySectionTitle =>
      'Compatibility checks';

  @override
  String get projectEditorNovelsCompatibilitySectionSubtitle =>
      'Keeps legacy Electron-shaped endpoints and event regression hooks; collapsed by default.';

  @override
  String get projectEditorNovelsCompatibilitySectionProbeHint =>
      'Novels HTTP probe checks';

  @override
  String get projectEditorNovelsProbeReadGetNovelButton => 'POST get-novel';

  @override
  String projectEditorNovelsProbeReadGetNovelSnackbarWithFirst(
    int total,
    int id,
    String chapter,
  ) {
    return 'POST …/novels/get-novel: total=$total · first #$id $chapter';
  }

  @override
  String projectEditorNovelsProbeReadGetNovelSnackbarTotalOnly(int total) {
    return 'POST …/novels/get-novel: total=$total';
  }

  @override
  String get projectEditorNovelsProbeReadGetNovelDataButton =>
      'POST get-novel-data';

  @override
  String projectEditorNovelsProbeReadGetNovelDataSnackbar(int count) {
    return 'POST …/novels/get-novel-data: $count row(s)';
  }

  @override
  String get projectEditorNovelsProbeReadGetNovelIndexButton =>
      'POST get-novel-index';

  @override
  String projectEditorNovelsProbeReadGetNovelIndexSnackbar(int count) {
    return 'POST …/novels/get-novel-index: $count row(s)';
  }

  @override
  String get projectEditorNovelsProbeReadGetNovelEventStateButton =>
      'POST get-novel-event-state';

  @override
  String projectEditorNovelsProbeReadGetNovelEventStateSnackbar(int count) {
    return 'POST …/novels/get-novel-event-state: $count row(s) with non-zero state';
  }

  @override
  String get projectEditorNovelsProbeEventsGetEventsButton =>
      'POST events/get-events';

  @override
  String get projectEditorNovelsProbeEventsBatchDeleteEmptyButton =>
      'POST events/batch-delete []';

  @override
  String projectEditorNovelsProbeEventsGetEventsSnackbarWithFirst(
    int total,
    int id,
    String eventName,
  ) {
    return 'POST …/novels/events/get-events: total=$total · first #$id $eventName';
  }

  @override
  String projectEditorNovelsProbeEventsGetEventsSnackbarTotalOnly(int total) {
    return 'POST …/novels/events/get-events: total=$total';
  }

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
  String get scriptEditorStoryboardAddDialogTitle => 'Add storyboard';

  @override
  String get scriptEditorStoryboardAddPromptLabel => 'Shot prompt';

  @override
  String get scriptEditorStoryboardAddPromptHelper =>
      'Describe this shot\'s visuals or motion.';

  @override
  String get scriptEditorStoryboardAddDurationOptionalLabel =>
      'Duration (optional)';

  @override
  String get scriptEditorStoryboardAddDurationOptionalHelper =>
      'Whole seconds; leave empty for backend default.';

  @override
  String get scriptEditorStoryboardAddConfirmButton => 'Add';

  @override
  String get scriptEditorStoryboardAddPromptRequiredSnackBar =>
      'Storyboard prompt cannot be empty.';

  @override
  String get scriptEditorStoryboardDurationMustBeIntegerSnackBar =>
      'Duration must be an integer.';

  @override
  String get scriptEditorStoryboardDurationMustBePositiveSnackBar =>
      'Duration must be a positive integer.';

  @override
  String scriptEditorStoryboardAddFollowUpSummary(int storyboardId) {
    return 'Added storyboard #$storyboardId.';
  }

  @override
  String get scriptEditorStoryboardBatchAddDialogTitle =>
      'Batch add storyboards';

  @override
  String get scriptEditorStoryboardBatchAddPromptsLabel =>
      'One prompt per line';

  @override
  String get scriptEditorStoryboardBatchAddPromptsHelper =>
      'Empty lines are skipped; shots are created in input order.';

  @override
  String get scriptEditorStoryboardBatchAddUnifiedDurationLabel =>
      'Shared duration (optional)';

  @override
  String get scriptEditorStoryboardBatchAddUnifiedDurationHelper =>
      'If set, applies to every shot added in this batch.';

  @override
  String get scriptEditorStoryboardBatchAddConfirmButton => 'Batch add';

  @override
  String get scriptEditorStoryboardBatchAddNeedOnePromptSnackBar =>
      'Enter at least one storyboard prompt.';

  @override
  String
  get scriptEditorStoryboardBatchAddUnifiedDurationMustBeIntegerSnackBar =>
      'Shared duration must be an integer.';

  @override
  String
  get scriptEditorStoryboardBatchAddUnifiedDurationMustBePositiveSnackBar =>
      'Shared duration must be a positive integer.';

  @override
  String scriptEditorStoryboardBatchAddFollowUpSummary(int count) {
    return 'Batch-added $count storyboards.';
  }

  @override
  String scriptEditorStoryboardsDialogTitle(int count) {
    return 'Storyboards ($count)';
  }

  @override
  String get scriptEditorStoryboardsIntroEmpty =>
      'This script has no storyboards yet. Add one or paste one prompt per line to import a batch.';

  @override
  String get scriptEditorStoryboardsIntroHasBoards =>
      'Manage shot order, prompts, and status for this script; tap a row to edit a single storyboard.';

  @override
  String get scriptEditorStoryboardsProductionSummaryPending =>
      'Production view summary not loaded yet.';

  @override
  String scriptEditorStoryboardsRecommendedActionLine(String action) {
    return 'Recommended action: $action';
  }

  @override
  String get scriptEditorStoryboardsBusy => 'Working…';

  @override
  String get scriptEditorStoryboardsRefreshList => 'Refresh list';

  @override
  String get scriptEditorStoryboardsRefreshing => 'Refreshing…';

  @override
  String get scriptEditorStoryboardsOpenImageWorkbench =>
      'Storyboard image workbench';

  @override
  String get scriptEditorStoryboardsRefreshProductionView =>
      'Refresh production view';

  @override
  String get scriptEditorStoryboardsLoadingProductionView =>
      'Loading production view…';

  @override
  String get scriptEditorStoryboardsEmptyList => 'No storyboards';

  @override
  String scriptEditorStoryboardsRowOrder(int index) {
    return 'Order $index';
  }

  @override
  String scriptEditorStoryboardsRowState(String state) {
    return 'State $state';
  }

  @override
  String scriptEditorStoryboardsRowDuration(String duration) {
    return 'Duration $duration';
  }

  @override
  String get scriptEditorStoryboardsStateFallback => 'unknown';

  @override
  String get scriptEditorStoryboardsNarrationExplicit =>
      'Explicit narration is set';

  @override
  String get scriptEditorStoryboardsNarrationPromptFallback =>
      'Falls back to storyboard prompt';

  @override
  String get scriptEditorStoryboardsNarrationPlaceholder =>
      'Still placeholder text';

  @override
  String get scriptEditorStoryboardsVideoRecommendSyncProductionData =>
      'Sync current shot production data';

  @override
  String get scriptEditorStoryboardsVideoRecommendReadCurrentPreview =>
      'Read current preview';

  @override
  String get scriptEditorStoryboardsVideoRecommendPrepareVideoTrack =>
      'Prepare video track';

  @override
  String get scriptEditorStoryboardsVideoRecommendGenerateDefaultVideoPrompt =>
      'Generate default video prompt';

  @override
  String get scriptEditorStoryboardsVideoRecommendRefreshVideoData =>
      'Refresh video data';

  @override
  String get scriptEditorStoryboardsVideoRecommendSubmitVideoGeneration =>
      'Generate video';

  @override
  String get scriptEditorStoryboardsVideoGenerating => 'Generating…';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNeedProductionSummary =>
      'This shot is not synced to the production view yet.';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNeedProductionDetail =>
      'Sync production data for this shot first so images, tracks, and prompts are available before continuing video.';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoFrameSummary =>
      'This shot has no usable frame yet.';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoFrameDetail =>
      'Read the current preview or paste an image URL so the video workbench has a clear visual input.';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoTracksSummary =>
      'No usable video tracks for this shot yet.';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoTracksDetail =>
      'Prepare a video track before submitting generation.';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoTrackSelectedSummary =>
      'No video track is selected for this shot.';

  @override
  String scriptEditorStoryboardsVideoDiagnosisPickTrackDetail(String trackIds) {
    return 'Tracks found: $trackIds. Enter a track ID before generating video.';
  }

  @override
  String
  get scriptEditorStoryboardsVideoDiagnosisIncompleteVideoParamsSummary =>
      'Video parameters are not complete yet.';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisIncompleteVideoParamsDetail =>
      'Generate a default video prompt and confirm duration; then you can generate video in one step.';

  @override
  String scriptEditorStoryboardsVideoDiagnosisJobsRunningSummary(int count) {
    return '$count video job(s) are still running for this script.';
  }

  @override
  String scriptEditorStoryboardsVideoDiagnosisJobsRunningDetailNoVideos(
    String suffix,
  ) {
    return 'Refresh video data to see whether this shot already has new output before submitting again.$suffix';
  }

  @override
  String scriptEditorStoryboardsVideoDiagnosisJobsRunningDetailHasVideos(
    String suffix,
  ) {
    return 'Refresh video data and review existing candidates for this shot before submitting again.$suffix';
  }

  @override
  String scriptEditorStoryboardsVideoDiagnosisJobsPendingSuffix(int pending) {
    return ' About $pending shot(s) still have in-flight jobs without media write-back detected.';
  }

  @override
  String scriptEditorStoryboardsVideoDiagnosisHasVideoCandidatesSummary(
    int count,
  ) {
    return 'This shot already has $count video candidate(s).';
  }

  @override
  String get scriptEditorStoryboardsVideoDiagnosisHasVideoCandidatesDetail =>
      'Review existing videos and pick a current one; submit again only if you still need a new render.';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisAllReadySummary =>
      'Image, track, and video parameters look ready.';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisAllReadyDetail =>
      'You can generate video in one step; the system will refresh prompts, trim suggestions, and refresh results.';

  @override
  String get scriptEditorStoryboardsVideoErrorNoExtraDetail =>
      'No additional error details.';

  @override
  String scriptEditorStoryboardsVideoFailureReasonDetail(
    String reason,
    String fallback,
  ) {
    return 'Failure reason: $reason. $fallback';
  }

  @override
  String get scriptEditorStoryboardsVoiceoverCompleted =>
      'Voiceover audio ready';

  @override
  String get scriptEditorStoryboardsVoiceoverQueued => 'Voiceover queued';

  @override
  String get scriptEditorStoryboardsVoiceoverFailed => 'Voiceover failed';

  @override
  String scriptEditorStoryboardsVoiceoverFailedWithError(String error) {
    return 'Voiceover failed: $error';
  }

  @override
  String get scriptEditorStoryboardsCurrentFrame => 'Current frame';

  @override
  String get scriptEditorStoryboardsNoSelectedFrame => 'No frame loaded';

  @override
  String scriptEditorStoryboardsPreviewLoadFailed(String url) {
    return 'Preview failed to load: $url';
  }

  @override
  String scriptEditorStoryboardsSubtitleNarration(String text) {
    return 'Subtitle / narration: $text';
  }

  @override
  String scriptEditorStoryboardsAudioDelivery(String line) {
    return 'Audio: $line';
  }

  @override
  String get scriptEditorStoryboardsReadinessBasicSlot => 'Timeline slot';

  @override
  String get scriptEditorStoryboardsReadinessPromptContext =>
      'Script / prompt context';

  @override
  String get scriptEditorStoryboardsReadinessReferenceVisual =>
      'Reference visual';

  @override
  String get scriptEditorStoryboardsReadinessCandidateCleared =>
      'Candidate cleared';

  @override
  String get scriptEditorStoryboardsReadinessNoBlockingJob => 'No blocking job';

  @override
  String get scriptEditorStoryboardsReadinessTitle => 'Short video readiness';

  @override
  String get scriptEditorStoryboardsReadinessReady => 'Ready';

  @override
  String get scriptEditorStoryboardsReadinessIncomplete => 'Incomplete';

  @override
  String get scriptEditorStoryboardsReadinessSummaryReady =>
      'Short video: checks passed; ready to generate.';

  @override
  String get scriptEditorStoryboardsReadinessSummaryPending =>
      'Short video: still needs review.';

  @override
  String scriptEditorStoryboardsReadinessSummaryBlocked(String items) {
    return 'Short video: still need $items';
  }

  @override
  String get scriptEditorStoryboardsReadinessBlockingMissingBasicSlot =>
      'Timeline slot';

  @override
  String get scriptEditorStoryboardsReadinessBlockingMissingPromptContext =>
      'Script / prompt';

  @override
  String get scriptEditorStoryboardsReadinessBlockingMissingReferenceVisual =>
      'Reference image';

  @override
  String
  get scriptEditorStoryboardsReadinessBlockingMissingLiveActionReferenceShot =>
      'Live-action reference shot';

  @override
  String
  get scriptEditorStoryboardsReadinessBlockingMissingLiveActionPerformanceNotes =>
      'Performance / delivery notes';

  @override
  String get scriptEditorStoryboardsReadinessBlockingCandidatePending =>
      'Candidate confirmation';

  @override
  String get scriptEditorStoryboardsReadinessBlockingBlockingJob =>
      'Generation job running';

  @override
  String get scriptEditorEditImageWorkbenchTitle => 'Edit image workbench';

  @override
  String get scriptEditorEditImageWorkbenchIntro =>
      'Manage the edit-image flow inside the script workbench—upload a source image and start generation instead of relying only on production probes.';

  @override
  String get scriptEditorEditImageWorkbenchSyncing => 'Syncing…';

  @override
  String get scriptEditorEditImageWorkbenchResyncFlow => 'Resync flow';

  @override
  String scriptEditorEditImageWorkbenchDefaultModelLine(
    String model,
    String resolution,
  ) {
    return 'Default model $model · $resolution';
  }

  @override
  String get scriptEditorEditImageWorkbenchUploadLabel =>
      'Source image base64 / data URI';

  @override
  String get scriptEditorEditImageWorkbenchUploadHelper =>
      'Paste data:image/png;base64,... or raw base64; used for upload-image.';

  @override
  String get scriptEditorEditImageWorkbenchBusy => 'Working…';

  @override
  String get scriptEditorEditImageWorkbenchUploadSource =>
      'Upload source image';

  @override
  String get scriptEditorEditImageWorkbenchFlowIdLabel => 'Flow ID';

  @override
  String get scriptEditorEditImageWorkbenchModelOptionalLabel =>
      'Generation model (optional)';

  @override
  String get scriptEditorEditImageWorkbenchPromptLabel => 'Generation prompt';

  @override
  String get scriptEditorEditImageWorkbenchGenerate => 'Generate from flow';

  @override
  String get scriptEditorEditImageWorkbenchSaveFlow => 'Save current flow';

  @override
  String get scriptEditorEditImageWorkbenchStepsHeading => 'Step status';

  @override
  String get scriptEditorEditImageWorkbenchStepsEmpty =>
      'No steps yet—tap Resync flow first.';

  @override
  String scriptEditorEditImageWorkbenchStepLine(String stepId, String status) {
    return '$stepId · $status';
  }

  @override
  String get scriptEditorEditImageWorkbenchStepIdLabel => 'Step ID';

  @override
  String get scriptEditorEditImageWorkbenchNewStatusLabel => 'New status';

  @override
  String get scriptEditorEditImageWorkbenchNewStatusHelper =>
      'e.g. pending / completed / failed';

  @override
  String get scriptEditorEditImageWorkbenchUpdateStep => 'Update step status';

  @override
  String scriptEditorEditImageWorkbenchFlowLoaded(
    String flowId,
    int stepCount,
    String model,
  ) {
    return 'Loaded flow $flowId, $stepCount steps, default model $model.';
  }

  @override
  String scriptEditorEditImageWorkbenchLoadFailed(String error) {
    return 'Failed to load edit-image workbench: $error';
  }

  @override
  String get scriptEditorEditImageWorkbenchErrPasteSource =>
      'Paste source image base64 or data URI first.';

  @override
  String get scriptEditorEditImageWorkbenchErrFlowAndPromptEmpty =>
      'Flow ID and generation prompt are required.';

  @override
  String get scriptEditorEditImageWorkbenchSourceUploaded =>
      'Source image uploaded; URL returned—you can continue flow generation.';

  @override
  String scriptEditorEditImageWorkbenchJobEnqueued(
    String jobId,
    String status,
  ) {
    return 'Generation job enqueued: $jobId · $status';
  }

  @override
  String get scriptEditorEditImageWorkbenchErrFlowIdEmpty =>
      'Flow ID is required.';

  @override
  String scriptEditorEditImageWorkbenchFlowSaved(String flowId) {
    return 'Flow $flowId saved.';
  }

  @override
  String get scriptEditorEditImageWorkbenchErrFlowStepStatusEmpty =>
      'Flow ID, step ID, and new status are required.';

  @override
  String scriptEditorEditImageWorkbenchStepUpdated(String stepId) {
    return 'Step $stepId updated.';
  }

  @override
  String get skillsHarnessTitle => 'Harness / skills';

  @override
  String get skillsHarnessPrefsTooltip =>
      'Local client preferences (debug shell; same overflow menu as other panel titles).';

  @override
  String skillsHarnessToolsLabel(String line) {
    return 'tools: $line';
  }

  @override
  String skillsHarnessUserWasmValidateLabel(String line) {
    return 'user-wasm validate: $line';
  }

  @override
  String skillsHarnessUserWasmPersistLabel(String line) {
    return 'user-wasm persist: $line';
  }

  @override
  String skillsHarnessUserWasmListLabel(String line) {
    return 'user-wasm list: $line';
  }

  @override
  String skillsHarnessUserWasmRevokeLabel(String line) {
    return 'user-wasm revoke: $line';
  }

  @override
  String skillsHarnessSummaryLabel(String line) {
    return 'summary: $line';
  }

  @override
  String get skillsHarnessPathLabel => 'Skill relative path';

  @override
  String get skillsHarnessPathHelper =>
      'POST needs a path that does not exist yet under data/skills';

  @override
  String get skillsHarnessBodyLabel => 'Body for PUT / POST';

  @override
  String get skillsHarnessRollingBack => 'Rolling back…';

  @override
  String get skillsHarnessVersions => 'Version history / rollback';

  @override
  String get skillsHarnessWsRecent => 'Recent WebSocket messages:';

  @override
  String skillsHarnessPreviewTruncated(String preview) {
    return '$preview\n\n(Preview truncated at 12,000 characters.)';
  }

  @override
  String get skillsHarnessPreviewClose => 'Close';

  @override
  String skillsHarnessVersionDialogTitle(String path) {
    return 'Version history · $path';
  }

  @override
  String get skillsHarnessVersionEmpty => 'No recorded versions for this path.';

  @override
  String skillsHarnessVersionCountHint(int count) {
    return '$count versions';
  }

  @override
  String skillsHarnessVersionHash(String hash) {
    return 'hash $hash';
  }

  @override
  String skillsHarnessVersionTitle(int index) {
    return 'Version $index';
  }

  @override
  String skillsHarnessRollbackVersionTitle(int index) {
    return 'Rollback snapshot $index';
  }

  @override
  String get skillsHarnessDiffTitle => 'Diff (current vs selected)';

  @override
  String get skillsHarnessConfirmRollbackTitle => 'Confirm rollback';

  @override
  String skillsHarnessConfirmRollbackBody(String time, String hash) {
    return 'Rollback to the snapshot from $time (hash $hash)?';
  }

  @override
  String get skillsHarnessCancel => 'Cancel';

  @override
  String get skillsHarnessConfirmRollback => 'Rollback';

  @override
  String get skillsHarnessRollbackToVersion => 'Rollback to this version';

  @override
  String skillsHarnessPutResult(String path, int length) {
    return 'PUT succeeded: $path ($length chars written)';
  }

  @override
  String skillsHarnessPostResult(String path, int length) {
    return 'POST succeeded: $path ($length chars written)';
  }

  @override
  String skillsHarnessDeleteResult(String path) {
    return 'DELETE succeeded: $path';
  }

  @override
  String get skillsHarnessRollbackSummary => 'Rollback via harness UI';

  @override
  String skillsHarnessRollbackResult(String path, String hash) {
    return 'Rolled back $path · hash $hash';
  }

  @override
  String get skillsHarnessRollbackDone => 'Rollback completed.';

  @override
  String skillsHarnessValidateResult(String validated, int sizeBytes) {
    return 'validated=$validated, size_bytes=$sizeBytes (embedded probe)';
  }

  @override
  String skillsHarnessPersistResult(
    String id,
    String sha,
    int sizeBytes,
    String createdAt,
  ) {
    return 'stored id=$id, sha256=$sha, size=$sizeBytes, at=$createdAt';
  }

  @override
  String get skillsHarnessStoredModulesEmpty => '0 stored modules';

  @override
  String skillsHarnessStoredModulesSummary(
    int count,
    String preview,
    String suffix,
  ) {
    return '$count stored modules — $preview$suffix';
  }

  @override
  String skillsHarnessRevokeResult(String id, String revokedAt) {
    return 'revoked id=$id, revoked_at=$revokedAt';
  }

  @override
  String skillsHarnessAggregateResult(
    String scope,
    int markdownCount,
    int totalBytes,
  ) {
    return 'scope=$scope · $markdownCount markdown files, $totalBytes bytes total';
  }

  @override
  String skillsHarnessListSummary(int count, String sample) {
    return '$count files; sample: $sample';
  }

  @override
  String get skillsHarnessListSampleEmpty => '—';

  @override
  String get storyboardWorkbenchErrNoExportJobSubmitted =>
      'No submitted export job yet.';

  @override
  String get storyboardWorkbenchExportCompletedSyncedProduction =>
      'Export finished; production data for this shot was synced automatically.';

  @override
  String get storyboardWorkbenchSyncProductionLoadingSummary =>
      'Syncing production data for this shot.';

  @override
  String get storyboardWorkbenchSyncProductionLoadingDetail =>
      'When sync completes, the current frame, tracks, and available video settings will refresh.';

  @override
  String get storyboardWorkbenchSyncProductionFailedSummary =>
      'Failed to sync production data for this shot.';

  @override
  String get storyboardWorkbenchSyncProductionFailedFallbackDetail =>
      'Check that this shot exists on the production side, then try syncing again.';

  @override
  String get storyboardWorkbenchRefreshVideoLoadingSummary =>
      'Refreshing video data for this shot.';

  @override
  String get storyboardWorkbenchRefreshVideoLoadingDetail =>
      'When refresh completes, model info, rendered videos, and in-flight jobs will update.';

  @override
  String get storyboardWorkbenchRefreshVideoFailedSummary =>
      'Failed to refresh video data for this shot.';

  @override
  String get storyboardWorkbenchRefreshVideoFailedFallbackDetail =>
      'Try again later, or continue editing images and tracks first.';

  @override
  String get storyboardWorkbenchProductionMetaNotLoaded =>
      'Production view not loaded yet';

  @override
  String storyboardWorkbenchProductionMetaSbIndex(int sbIndex) {
    return 'Index $sbIndex';
  }

  @override
  String storyboardWorkbenchProductionMetaState(String state) {
    return 'State $state';
  }

  @override
  String storyboardWorkbenchProductionMetaDuration(String duration) {
    return 'Duration $duration';
  }

  @override
  String storyboardWorkbenchProductionMetaTrack(int trackId) {
    return 'Track $trackId';
  }

  @override
  String get storyboardWorkbenchProductionMetaLoadedEmpty =>
      'Production view loaded';

  @override
  String storyboardEditorDialogTitle(int numericId) {
    return 'Storyboard editor #$numericId';
  }

  @override
  String get storyboardEditorPromptLabelClearEmpty =>
      'Shot prompt (leave empty to clear)';

  @override
  String get storyboardEditorStateLabelClearEmpty =>
      'Status (leave empty to clear)';

  @override
  String get storyboardEditorVideoDescLabelClearEmpty =>
      'Video description (leave empty to clear)';

  @override
  String get storyboardEditorSbIndexLabelClearEmpty =>
      'Shot index (leave empty to clear)';

  @override
  String get storyboardEditorShouldGenerateImageLabelClearEmpty =>
      'Generate image flag (leave empty to clear)';

  @override
  String get storyboardEditorDeleteConfirmTitle => 'Delete this storyboard?';

  @override
  String storyboardEditorDeleteConfirmBody(int id) {
    return '确定要删除分镜 $id 吗？';
  }

  @override
  String get storyboardEditorDialogCancel => 'Cancel';

  @override
  String get storyboardEditorDialogConfirmDelete => 'Delete';

  @override
  String get storyboardEditorDeletedSnack => 'Storyboard deleted';

  @override
  String get storyboardEditorSbIndexMustBeInteger =>
      'Shot index must be an integer';

  @override
  String get storyboardEditorShouldGenerateImageMustBeInteger =>
      'Generate-image flag must be an integer';

  @override
  String get storyboardEditorDeleteStoryboard => 'Delete storyboard';

  @override
  String get storyboardEditorSaving => 'Saving…';

  @override
  String get storyboardEditorSaveChanges => 'Save changes';

  @override
  String get storyboardVideoWorkbenchTitle => 'Video workbench';

  @override
  String get storyboardVideoWorkbenchTrackIdLabel => 'Track ID';

  @override
  String get storyboardVideoWorkbenchTrackIdHelperNoTracks =>
      'No known tracks yet—you can create one first.';

  @override
  String storyboardVideoWorkbenchTrackIdHelperKnown(String ids) {
    return '已知轨道 ID：$ids';
  }

  @override
  String get storyboardVideoWorkbenchNewTrackNameLabel => 'New track name';

  @override
  String get storyboardVideoWorkbenchNewTrackNameHelper =>
      'After adding, the track ID will be filled in automatically.';

  @override
  String get storyboardVideoWorkbenchAddTrack => 'Add track';

  @override
  String get storyboardVideoWorkbenchDeleteTrack => 'Delete track';

  @override
  String get storyboardVideoWorkbenchGenerateDefaultPrompt =>
      'Generate default prompt manually';

  @override
  String get storyboardVideoWorkbenchPatchRegeneration => 'Partial rework';

  @override
  String get storyboardVideoWorkbenchApplyPromptRepairs =>
      'Apply pre-generation suggestions manually';

  @override
  String get storyboardVideoWorkbenchRefreshing => 'Refreshing…';

  @override
  String get storyboardVideoWorkbenchRefreshVideoDataManual =>
      'Refresh video data manually';

  @override
  String get storyboardVideoWorkbenchPrimaryHint =>
      'Prefer “Generate video” below—the system fills prompts, trims low-value fragments, dedupes negative constraints, and refreshes results. The buttons above are for manual intervention.';

  @override
  String get storyboardVideoWorkbenchPatchAttributionHint =>
      'Partial rework submits the smallest fix scope; attribution mode returns upstream hints so you don’t treat a single-shot issue as a full rerun.';

  @override
  String get storyboardVideoWorkbenchQualityReviewCheckboxTitle =>
      'Record quality-review samples when generating';

  @override
  String get storyboardVideoWorkbenchQualityReviewCheckboxSubtitle =>
      'Used to track pass rates and bad-case trends for “performance/delivery memory priority”.';

  @override
  String get storyboardVideoWorkbenchSubtitleLabel =>
      'Subtitle / voiceover script';

  @override
  String get storyboardVideoWorkbenchSubtitleHelper =>
      'SRT export, timeline captions, and the default video prompt prefer this text.';

  @override
  String get storyboardVideoWorkbenchSaveSubtitle =>
      'Save subtitle / voiceover script';

  @override
  String get storyboardVideoWorkbenchRegenerateVoiceover =>
      'Regenerate voiceover';

  @override
  String get storyboardVideoWorkbenchGenerateVoiceover => 'Generate voiceover';

  @override
  String get storyboardVideoWorkbenchLiveActionRefsLabel =>
      'Live-action reference shot URLs (one per line)';

  @override
  String get storyboardVideoWorkbenchLiveActionRefsHelper =>
      'Live-action mode includes these in readiness; animated mode can leave empty.';

  @override
  String get storyboardVideoWorkbenchPerformanceNotesLabel =>
      'Performance / delivery constraints';

  @override
  String get storyboardVideoWorkbenchPerformanceNotesHelper =>
      'e.g. pauses, emotional intensity, realism, lip-sync emphasis.';

  @override
  String get storyboardVideoWorkbenchSaveLiveAction =>
      'Save live-action refs & performance constraints';

  @override
  String get storyboardVideoWorkbenchVideoPromptLabel =>
      'Video generation prompt';

  @override
  String storyboardVideoWorkbenchRepairSuggestionsPrefix(String items) {
    return 'Pre-generation suggestions: $items';
  }

  @override
  String get storyboardVideoWorkbenchNegativePromptLabel => 'Negative prompt';

  @override
  String get storyboardVideoWorkbenchNegativePromptHelper =>
      'Auto-filled from this shot’s failure constraints; trim or extend as needed.';

  @override
  String get storyboardVideoWorkbenchDurationSecondsLabel =>
      'Duration (seconds)';

  @override
  String get storyboardVideoWorkbenchResolutionLabel => 'Resolution';

  @override
  String get storyboardVideoWorkbenchModeLabel => 'Generation mode';

  @override
  String get storyboardVideoWorkbenchModelLabel => 'Model';

  @override
  String get storyboardVideoWorkbenchModelLoading => 'Loading model info…';

  @override
  String get storyboardVideoWorkbenchIncludeAudioTitle =>
      'Include audio in generated video';

  @override
  String get storyboardVideoWorkbenchGenerating => 'Generating…';

  @override
  String get storyboardVideoWorkbenchGenerateVideoOneClick => 'Generate video';

  @override
  String get storyboardVideoWorkbenchExportCurrentVideoJob =>
      'Export current video (job)';

  @override
  String get storyboardVideoWorkbenchRefreshingExportJob =>
      'Refreshing export job…';

  @override
  String get storyboardVideoWorkbenchRefreshExportJobStatus =>
      'Refresh export job status';

  @override
  String get storyboardVideoWorkbenchSingleTrackHint =>
      'If only one usable track is detected, it will be auto-filled on submit; with multiple tracks you still pick manually to avoid wrong renders.';

  @override
  String storyboardVideoWorkbenchLatestExportJobLine(
    int taskId,
    String status,
    String updatedAt,
  ) {
    return 'Latest export job: #$taskId · $status · $updatedAt';
  }

  @override
  String get storyboardVideoWorkbenchExportLinkPrefix => 'Export URL:';

  @override
  String get storyboardVideoWorkbenchExportErrorPrefix => 'Export error:';

  @override
  String get storyboardVideoWorkbenchSelectedVideoHeading => 'Selected video';

  @override
  String get storyboardVideoWorkbenchSelectedVideoDetailSelected =>
      'This is the version used for export and reuse on this shot.';

  @override
  String get storyboardVideoWorkbenchSelectedVideoDetailEmpty =>
      'No selected video yet—pick one from candidates below, then continue rework or export.';

  @override
  String get storyboardVideoWorkbenchExportSelectedVideo =>
      'Export current video';

  @override
  String get storyboardVideoWorkbenchContinuePatch => 'Continue partial rework';

  @override
  String get storyboardVideoWorkbenchDeleteSelectedVideo =>
      'Remove selected video';

  @override
  String get storyboardVideoWorkbenchPickCandidateFirst =>
      'Pick a candidate below first—rework will be more focused.';

  @override
  String get storyboardVideoWorkbenchCandidatesHeading =>
      'Video candidates for this shot';

  @override
  String get storyboardVideoWorkbenchCandidatesEmpty =>
      'No generated videos linked to this storyboard yet.';

  @override
  String get storyboardVideoWorkbenchCandidatesDetail =>
      'Shows videos for this storyboard; set one as current or continue partial rework.';

  @override
  String get storyboardVideoWorkbenchVideoUrlMissing => 'Video URL missing';

  @override
  String get storyboardVideoWorkbenchCandidateMetaCurrent => 'Active';

  @override
  String storyboardVideoWorkbenchCandidateMetaState(String state) {
    return 'Status $state';
  }

  @override
  String storyboardVideoWorkbenchCandidateMetaTrack(int trackId) {
    return 'Track $trackId';
  }

  @override
  String storyboardVideoWorkbenchCandidateMetaDuration(String duration) {
    return 'Duration $duration';
  }

  @override
  String get storyboardVideoWorkbenchCurrentSelectedBadge => 'Current';

  @override
  String get storyboardVideoWorkbenchSetAsCurrentVideo =>
      'Set as current video';

  @override
  String get storyboardVideoWorkbenchPatchShort => 'Partial rework';

  @override
  String get storyboardVideoWorkbenchPatchContinue => 'Continue partial rework';

  @override
  String get storyboardVideoWorkbenchInFlightJobsHeading =>
      'In-flight video jobs';

  @override
  String storyboardVideoWorkbenchWritebackSummaryNoPending(
    int scriptCount,
    int persistedCount,
    int inFlightCount,
  ) {
    return 'Writeback summary: this script mirror has $scriptCount shots; persisted media paths for $persistedCount; in-flight tasks tied to $inFlightCount shots.';
  }

  @override
  String storyboardVideoWorkbenchWritebackSummaryWithPending(
    int scriptCount,
    int persistedCount,
    int inFlightCount,
    int pendingCount,
  ) {
    return 'Writeback summary: this script mirror has $scriptCount shots; persisted media paths for $persistedCount; in-flight tasks tied to $inFlightCount shots; ~$pendingCount shots still pending worker writeback.';
  }

  @override
  String storyboardVideoWorkbenchJobSubtitle(String status, String updatedAt) {
    return 'Status $status · $updatedAt';
  }

  @override
  String get storyboardActionFollowUpPreviewMissing =>
      'This shot has no readable preview image yet.';

  @override
  String get storyboardActionFollowUpPreviewRead =>
      'Loaded preview for this shot.';

  @override
  String get storyboardActionErrImageUrlRequired =>
      'Image URL cannot be empty.';

  @override
  String get storyboardActionFollowUpImageUrlSaved =>
      'Saved current image URL.';

  @override
  String get storyboardActionFollowUpLiveActionCleared =>
      'Cleared live-action reference shots and performance constraints.';

  @override
  String storyboardActionFollowUpLiveActionSaved(int count) {
    return 'Saved $count live-action reference shot(s) and synced performance/delivery constraints.';
  }

  @override
  String get storyboardActionFollowUpFrameCleared =>
      'Cleared current shot frame.';

  @override
  String get storyboardActionErrTrackNameRequired =>
      'Track name cannot be empty.';

  @override
  String storyboardActionFollowUpTrackAdded(int trackId) {
    return 'Added track #$trackId.';
  }

  @override
  String get storyboardActionErrTrackIdInvalid => 'Enter a valid track ID.';

  @override
  String storyboardActionFollowUpTrackDeleted(int trackId) {
    return 'Deleted track #$trackId.';
  }

  @override
  String get storyboardActionFollowUpVideoSelectedBase =>
      'Set this candidate as the shot video.';

  @override
  String get storyboardActionFollowUpVideoDeletedBase =>
      'Removed the selected shot video.';

  @override
  String get storyboardActionFollowUpTrackReady =>
      'Current track ID is ready for video generation.';

  @override
  String storyboardActionFollowUpTrackBackfilled(int trackId) {
    return 'Filled track $trackId; continue confirming video settings.';
  }

  @override
  String storyboardActionFollowUpTrackNamePrefilled(int storyId) {
    return 'Shot $storyId video track';
  }

  @override
  String get storyboardActionFollowUpTrackNameHint =>
      'Prefilled a new track name—you can add the track next.';

  @override
  String get storyboardActionFollowUpSyncProduction =>
      'Synced production data for this shot.';

  @override
  String get storyboardActionFollowUpRefreshVideo =>
      'Refreshed video data for this shot.';

  @override
  String get storyboardMemorySelectedPerfDistilled =>
      'Distilled private performance memory for this shot.';

  @override
  String storyboardMemorySelectedPrivateParts(String parts) {
    return 'Distilled private memory: $parts.';
  }

  @override
  String get storyboardMemoryPrivateScopeFooter =>
      'Scoped to the current user, project, and script—reused preferentially without leaking to other shorts.';

  @override
  String get storyboardMemoryRejectedHeadEmpty =>
      'Wrote private bad-case constraints for this shot.';

  @override
  String storyboardMemoryRejectedHeadAvoid(String avoid) {
    return 'Wrote private bad-case constraints: $avoid.';
  }

  @override
  String storyboardMemoryRejectedFailures(int count) {
    return 'failures stacked $count times';
  }

  @override
  String storyboardMemoryRejectedRisks(String tags) {
    return 'risk focus $tags';
  }

  @override
  String get storyboardMemoryRejectedNegativeFooter =>
      'Later generations will prefer negative memory scoped to this user, project, and script.';

  @override
  String get storyboardAutoNegativeSourceReview =>
      'Auto-negative from latest review bad cases.';

  @override
  String get storyboardAutoNegativeSourceRejectedMemory =>
      'Auto-negative from private bad-case memory.';

  @override
  String get storyboardAutoNegativeSourceBoth =>
      'Auto-negative uses both review bad cases and private memory.';

  @override
  String get storyboardAutoNegativeSourcePendingObservation =>
      'Auto-negative from latest reject observation fallback.';

  @override
  String get storyboardAutoNegativeSourcePendingNoteOnly =>
      'No formal negative lines yet—pending observation note only.';

  @override
  String get storyboardAutoNegativeSourceNone =>
      'No extra automatic negative sources.';

  @override
  String storyboardMemoryScopeProject(int count) {
    return 'project $count';
  }

  @override
  String storyboardMemoryScopeScript(int count) {
    return 'script $count';
  }

  @override
  String storyboardMemoryScopeRole(int count) {
    return 'role $count';
  }

  @override
  String get storyboardPromptGenDefaultFilledDuration =>
      'Generated default video prompt and filled duration.';

  @override
  String storyboardPromptGenHitMemory(String scope) {
    return 'Matched $scope memory.';
  }

  @override
  String storyboardPromptGenNegativeTrimmed(int fragCount, int chars) {
    return 'Trimmed $fragCount negative constraint(s) / $chars chars.';
  }

  @override
  String storyboardPromptSourceMemorySlim(
    int rows,
    int low,
    int dup,
    int visual,
  ) {
    return 'Memory slim -$rows rows (low-signal $low / dup $dup / visual $visual)';
  }

  @override
  String storyboardPromptSourceNegativeSlim(int fragCount, int chars) {
    return 'Negative slim $fragCount / $chars chars';
  }

  @override
  String storyboardPromptSourceReviewFrags(int count) {
    return 'Review fragments $count';
  }

  @override
  String storyboardPromptSourceMemoryFrags(int count) {
    return 'Memory fragments $count';
  }

  @override
  String storyboardPromptAnchorRole(int count) {
    return 'Role anchors $count';
  }

  @override
  String storyboardPromptAnchorScene(int count) {
    return 'Scene anchors $count';
  }

  @override
  String storyboardPromptAnchorTool(int count) {
    return 'Prop anchors $count';
  }

  @override
  String storyboardPromptAnchorStyle(int count) {
    return 'Style anchors $count';
  }

  @override
  String storyboardPromptAnchorPrivateMemory(int count) {
    return 'Private memory $count';
  }

  @override
  String storyboardPromptAnchorContinuity(int count) {
    return 'Continuity notes $count';
  }

  @override
  String get storyboardPromptAnchorReferenceFrame => 'Reference frame attached';

  @override
  String get storyboardPromptAnchorEmpty =>
      'No extra anchors or memory matched yet.';

  @override
  String storyboardDiagPromptChars(int chars) {
    return 'Prompt $chars chars';
  }

  @override
  String storyboardDiagNegativeLine(int chars, String tier) {
    return 'Negative $chars ($tier)';
  }

  @override
  String storyboardDiagObservation(int chars) {
    return 'Observation $chars';
  }

  @override
  String storyboardDiagMemoryStyle(int chars) {
    return 'Memory $chars';
  }

  @override
  String storyboardDiagNegativeSlimSaved(int chars) {
    return 'Negative slim -$chars';
  }

  @override
  String storyboardDiagMemorySlimRemoved(int chars) {
    return 'Memory slim -$chars';
  }

  @override
  String get storyboardDiagDeliveryPriority => 'Delivery-priority ✅';

  @override
  String storyboardDiagMemoryTier(String tier) {
    return 'Memory tier $tier';
  }

  @override
  String get storyboardBudgetHintNoReferenceFrame =>
      'The prompt is not bound to the current frame yet—attach a reference frame before trimming further; more stable results.';

  @override
  String get storyboardBudgetHintOptimizationKeptDelivery =>
      'Before this run we removed duplicate/visual-only private memory and kept performance & tone anchors; when adding more text, don\'t refill the saved budget with generic style filler.';

  @override
  String get storyboardBudgetHintProjectMemoryHeavy =>
      'This shot mainly hit project-level memory—shorten generic style lines first and reserve budget for performance and shot continuity.';

  @override
  String get storyboardBudgetHintRoleVsProject =>
      'Role-level memory is active—when compressing, trim project-level generic text first; don\'t delete role performance and emotion anchors together.';

  @override
  String get storyboardBudgetHintDeliveryExpanded =>
      'Performance/tone priority memory is locked in—don\'t delete it first; trim repeated scene/style and continuity fluff first to avoid monotone delivery.';

  @override
  String storyboardBudgetHintSuppressedBucket(String bucket) {
    return 'Private memory already suppressed many repeated $bucket-type fragments—trim those generics first before touching role performance memory.';
  }

  @override
  String get storyboardBudgetHintPromptLong =>
      'The prompt is quite long—remove duplicate scene/style lines first; keep role and key prop anchors.';

  @override
  String get storyboardBudgetHintPrivateMemoryHeavy =>
      'Private memory already takes a large share—merge generic style lines first; don\'t delete role performance memory first.';

  @override
  String get storyboardBudgetHintRiskyShotExpanded =>
      'This shot is flagged high-risk—keep role performance and continuity memory before trimming other generics.';

  @override
  String get storyboardBudgetHintNearLongPrompt =>
      'The prompt is approaching long-prompt territory—check whether style anchors and continuity notes duplicate before adding more.';

  @override
  String get storyboardBudgetHintContinuityLong =>
      'Continuity memory is already long—compress repeated bridge text into shorter action or performance anchors.';

  @override
  String get storyboardBudgetHintNegativeExpanded =>
      'Continuity constraints switched to expanded—keep identity and shot continuity before trimming generic negatives.';

  @override
  String get storyboardBudgetHintNegativeLeanLong =>
      'Negative constraints are already long—merge repeated mood/lighting warnings first; keep identity consistency constraints.';

  @override
  String get storyboardBudgetHintAutoNegativeDup =>
      'Negatives already include review + private bad cases—check for redundant wording before adding manually.';

  @override
  String get storyboardBudgetHintPendingObservation =>
      'Latest failure observation was inherited automatically—wait for retry results before stacking more synonymous negatives.';

  @override
  String get storyboardBudgetHintNoAnchors =>
      'The prompt relies mostly on storyboard text without role/scene anchors—visuals may drift.';

  @override
  String get storyboardBudgetHintHealthy =>
      'Prompt budget still healthy—keep prioritizing performance, key props, and emotion.';

  @override
  String get storyboardRepairSuggestReferenceFrame =>
      'Attach the current reference frame before trimming—faces, wardrobe, and blocking stay steadier.';

  @override
  String get storyboardRepairSuggestContinuity =>
      'Reduce continuity to 1–2 hard rules: camera, wardrobe, and character placement only.';

  @override
  String get storyboardRepairSuggestDelivery =>
      'Keep performance/tone memory—write emotion as playable action, not monotone read-through.';

  @override
  String get storyboardRepairSuggestTrimGeneric =>
      'Trim motion/lighting fluff first and budget for lip sync, micro-expressions, and identity consistency.';

  @override
  String get storyboardRepairSuggestNegativeReuse =>
      'Reuse auto bad-case negatives—dedupe before manual additions to avoid burning tokens on synonyms.';

  @override
  String get storyboardRepairSuggestMemoryReuse =>
      'Private bad-case memory already matched—reuse it instead of stacking another long shared memory layer.';

  @override
  String get storyboardRepairSuggestProjectMemoryTrim =>
      'Project-level generic memory is doing most of the work—shorten generic style lines when trimming further.';

  @override
  String get storyboardRepairSuggestRoleMemoryKeep =>
      'Role-level private memory matched—protect emotion and lip sync from being buried by project-wide text.';

  @override
  String get storyboardRepairSuggestAnchors =>
      'Add role, scene, or key prop anchors—otherwise shots drift and continuity breaks.';

  @override
  String get storyboardRepairSuggestHealthy =>
      'Budget still healthy—keep performance, key props, and emotional detail.';

  @override
  String get storyboardActionRepairAppliedSummary =>
      'Applied current pre-generation suggestions.';

  @override
  String get storyboardActionRepairNoChangeSummary =>
      'Suggestions are already applied; nothing else to trim.';

  @override
  String storyboardActionRepairDetailTrimmed(
    int promptRemoved,
    int negRemoved,
  ) {
    return 'Removed $promptRemoved low-value prompt fragment(s) and $negRemoved duplicate negative fragment(s).';
  }

  @override
  String get storyboardActionRepairDetailLean =>
      'Prompt / negative prompt is already lean—continue generation.';

  @override
  String get storyboardActionOperationFailedSummary => 'Shot action failed.';

  @override
  String get storyboardActionOperationFailedDetail =>
      'Finish the recommended step, then retry.';

  @override
  String get storyboardActionErrNeedSourceImageOrPreview =>
      'Provide an image URL or a current preview before generating video.';

  @override
  String get storyboardActionErrTrackIdRequired =>
      'Enter a valid track ID before generating video.';

  @override
  String get storyboardActionErrDurationPositiveInteger =>
      'Duration must be a positive integer.';

  @override
  String get storyboardActionErrVideoPromptEmpty =>
      'Video prompt cannot be empty.';

  @override
  String storyboardActionVideoJobsSubmittedTotalOnly(int total) {
    return 'Submitted $total video job(s).';
  }

  @override
  String storyboardActionVideoJobsSubmittedRepairOnly(
    int total,
    int pRm,
    int nRm,
  ) {
    return 'Submitted $total video job(s); auto-trimmed $pRm low-value prompt fragment(s) and $nRm duplicate negative fragment(s) before submit.';
  }

  @override
  String storyboardActionVideoJobsSubmittedDedupeOnly(int total, int deduped) {
    return 'Submitted $total video job(s); deduped $deduped duplicate negative fragment(s).';
  }

  @override
  String storyboardActionVideoJobsSubmittedRepairFinal(
    int total,
    int pRm,
    int nRm,
  ) {
    return 'Submitted $total video job(s); trimmed $pRm prompt fragment(s) and $nRm negative fragment(s) before submit; final negative prompt filled back.';
  }

  @override
  String storyboardActionVideoJobsSubmittedDedupeFinal(int total, int deduped) {
    return 'Submitted $total video job(s); deduped $deduped negative fragment(s); final negative prompt filled back.';
  }

  @override
  String storyboardActionVideoJobsSubmittedFinalOnly(int total) {
    return 'Submitted $total video job(s); final negative prompt filled back.';
  }

  @override
  String storyboardActionVoiceoverJobsSubmitted(int total) {
    return 'Submitted $total voiceover job(s); refresh production data later for status.';
  }

  @override
  String storyboardActionVoiceoverJobsSubmittedWithJob(
    int total,
    String jobId,
  ) {
    return 'Submitted $total voiceover job(s) (job=$jobId); refresh production data later for status.';
  }

  @override
  String get storyboardActionVideoDescCleared =>
      'Cleared subtitle/voiceover text—export falls back to shot prompt.';

  @override
  String get storyboardActionVideoDescSaved =>
      'Saved subtitle/voiceover text—default video prompt and export captions prefer it.';

  @override
  String get storyboardActionErrNoExportableVideoUrl =>
      'No exportable selected or candidate video URL for this shot.';

  @override
  String storyboardActionExportJobEnqueued(String jobId) {
    return 'Video export job submitted (job=$jobId). URL will write back when complete—refresh production data later.';
  }

  @override
  String get storyboardPatchDialogTitle => 'Partial rework';

  @override
  String get storyboardPatchScopeLabel => 'scope';

  @override
  String get storyboardPatchScopeHelper =>
      'episode / scene / storyboard_item / video_prompt / derive_asset';

  @override
  String get storyboardPatchModelTierLabel => 'model tier';

  @override
  String get storyboardPatchModelTierHelper =>
      'low for format fixes; high for content-quality fixes';

  @override
  String get storyboardPatchTargetIdsLabel => 'target ids';

  @override
  String get storyboardPatchTargetIdsHelper =>
      'Comma-separated. Defaults to current storyboard numeric ID.';

  @override
  String get storyboardPatchReasonLabel => 'Reason';

  @override
  String get storyboardPatchReasonHelper =>
      'Spell out character, emotion, shot, continuity, lines, or visible continuity breaks.';

  @override
  String get storyboardPatchScopeHint =>
      'Prefer the smallest scope; for performance, lens, or prompt issues on this shot only, use storyboard_item / video_prompt before escalating to the whole episode.';

  @override
  String get storyboardPatchAttributionLabel => 'attribution mode:';

  @override
  String get storyboardPatchRepairPriorityHeading => 'Rework priority:';

  @override
  String get storyboardPatchSnackNeedTargetId =>
      'Enter at least one valid target id.';

  @override
  String get storyboardPatchSnackNeedReason => 'Enter a rework reason.';

  @override
  String storyboardPatchSubmitLine(
    String patchId,
    String scope,
    String ids,
    String modelTier,
    String status,
    int failures,
    int tokens,
    String memorySuffix,
  ) {
    return 'Submitted patch #$patchId · scope=$scope · ids=$ids · model=$modelTier · status=$status · consecutive failures $failures · est. saved $tokens tokens$memorySuffix';
  }

  @override
  String get storyboardPatchMemoryWrittenSuffix =>
      ' · attribution memory saved';

  @override
  String get storyboardPatchAttributionUpstreamHint =>
      'This request entered attribution mode—fix upstream causes first.';

  @override
  String get storyboardPatchFollowUpAttribution =>
      'Partial rework submitted—attribution mode on. Follow P1/P2 order in the panel; don’t rerun the whole timeline.';

  @override
  String get storyboardPatchFollowUpQueued =>
      'Partial rework submitted—queued at minimal scope.';

  @override
  String get storyboardPatchSubmitting => 'Submitting…';

  @override
  String get storyboardPatchSubmit => 'Submit rework';

  @override
  String get storyboardPatchDefaultReason =>
      'Fix content quality, continuity, or emotional delivery for this shot.';

  @override
  String get shortVideoReadinessNoPayloadHeadline =>
      'Shot readiness data is not available yet.';

  @override
  String get shortVideoReadinessEmptyProjectHeadline =>
      'This project has no storyboard rows yet; split shots on the script side first to see the rollup.';

  @override
  String shortVideoReadinessRollupHeadline(int ready, int total, int blocked) {
    return '$ready/$total shots ready; $blocked blocked.';
  }

  @override
  String shortVideoReadinessReasonRollupLine(String reasonLabel, int count) {
    return '$reasonLabel ($count shots)';
  }

  @override
  String shortVideoReadinessStoryboardDetailPrefix(int storyboardNumericId) {
    return 'Shot #$storyboardNumericId';
  }

  @override
  String shortVideoReadinessScriptSuffix(int scriptId) {
    return ' · Script #$scriptId';
  }

  @override
  String shortVideoReadinessSlotSuffix(int sbIndex) {
    return ' · Slot $sbIndex';
  }

  @override
  String shortVideoReadinessBlockedShotDetail(String lead, String reasons) {
    return '$lead: $reasons';
  }

  @override
  String get shortVideoCandidateCompareReadinessNoData =>
      'Readiness data unavailable for this shot.';

  @override
  String get shortVideoCandidateCompareReadinessReady =>
      'Ready to continue generating or exporting.';

  @override
  String shortVideoCandidateCompareReadinessBlocked(String items) {
    return 'Needs $items';
  }

  @override
  String get shortVideoMetricStoryboardReadiness => 'Storyboard readiness';

  @override
  String get shortVideoShotReadinessSelectProjectHint =>
      'Select a short drama project to see server-side shot blocking rollup.';

  @override
  String get shortVideoTaskUnnamed => 'Unnamed task';

  @override
  String get shortVideoBadCaseUncategorized => 'Uncategorized';

  @override
  String get shortVideoTaskStatusQueued => 'Queued';

  @override
  String get shortVideoTaskStatusRunning => 'Running';

  @override
  String get shortVideoTaskStatusSucceeded => 'Succeeded';

  @override
  String get shortVideoTaskStatusFailed => 'Failed';

  @override
  String get shortVideoTaskStatusCancelled => 'Cancelled';

  @override
  String get shortVideoQualityNoSignalAnimated =>
      'Quality reviews have not surfaced strong signals yet; we will highlight style consistency, character continuity, and pacing risks here.';

  @override
  String get shortVideoQualityNoSignalLive =>
      'Quality reviews have not surfaced strong signals yet; we will highlight performance naturalness, realism, and voiceover pacing here.';

  @override
  String shortVideoQualityInsightAnimated(String passRate, int badCount) {
    return 'Auto/manual review pass rate is about $passRate%; $badCount bad cases logged—keep focusing on character consistency, visual continuity, and shot rhythm.';
  }

  @override
  String shortVideoQualityInsightLive(String passRate, int badCount) {
    return 'Auto/manual review pass rate is about $passRate%; $badCount bad cases logged—keep focusing on performance naturalness, scene realism, and voiceover shot quality.';
  }

  @override
  String get shortVideoReadinessGapAllReadyAnimated =>
      'Animated short-drama basics are in place—you can move forward with script, production, and QA loops.';

  @override
  String get shortVideoReadinessGapAllReadyLive =>
      'Live-action basics are in place—you can continue shot generation, voiceover, and final review.';

  @override
  String shortVideoReadinessGapAndMore(int count) {
    return ' and $count more';
  }

  @override
  String shortVideoReadinessGapMissing(String labels, String more) {
    return 'Still missing $labels$more. Complete these preparation items in the project area first.';
  }

  @override
  String get shortVideoReadinessLabelScriptBase => 'Script foundation';

  @override
  String shortVideoReadinessDetailScriptsHas(int count) {
    return '$count script(s) on file';
  }

  @override
  String get shortVideoReadinessDetailScriptsMissing =>
      'No first-draft script yet';

  @override
  String get shortVideoReadinessAnimLabelRoleAssets => 'Character assets';

  @override
  String shortVideoReadinessDetailRolesHas(int count) {
    return '$count character asset(s)';
  }

  @override
  String get shortVideoReadinessDetailRolesMissingAnim =>
      'Character assets still missing';

  @override
  String get shortVideoReadinessLiveLabelRoleSetup => 'Character setup';

  @override
  String get shortVideoReadinessDetailRolesMissingLive =>
      'Character setup / assets still missing';

  @override
  String get shortVideoReadinessLabelSceneAssets => 'Scene assets';

  @override
  String shortVideoReadinessDetailScenesHas(int count) {
    return '$count scene asset(s)';
  }

  @override
  String get shortVideoReadinessDetailScenesMissingAnim =>
      'Scene assets still missing';

  @override
  String get shortVideoReadinessDetailScenesMissingLive =>
      'Live scene references still missing';

  @override
  String get shortVideoReadinessAnimLabelVisualStyle => 'Visual style signal';

  @override
  String shortVideoReadinessDetailVisualConfigured(String name) {
    return 'Configured: $name';
  }

  @override
  String get shortVideoReadinessDetailVisualMissingAnim =>
      'Visual style not locked yet';

  @override
  String get shortVideoReadinessLiveLabelVisualManual => 'Visual manual';

  @override
  String get shortVideoReadinessDetailVisualMissingLive =>
      'Live visual style not locked yet';

  @override
  String get shortVideoReadinessFallbackStylePack => 'style pack';

  @override
  String get shortVideoReadinessFallbackDirectorPack =>
      'director manual or story style pack';

  @override
  String get shortVideoReadinessFallbackLiveVisualPack =>
      'visual style or style pack';

  @override
  String get shortVideoReadinessAnimLabelDirectorManual => 'Director manual';

  @override
  String get shortVideoReadinessLiveLabelPerformanceManual =>
      'Performance / voiceover manual';

  @override
  String shortVideoReadinessDetailDirectorConfigured(String name) {
    return 'Configured: $name';
  }

  @override
  String get shortVideoReadinessDetailDirectorMissingAnim =>
      'Director manual not locked yet';

  @override
  String get shortVideoReadinessDetailPerformanceMissingLive =>
      'Voiceover tone / director manual not locked yet';

  @override
  String get shortVideoReadinessAnimLabelStoryboardBase =>
      'Storyboard foundation';

  @override
  String shortVideoReadinessDetailStoryboardsHas(int count) {
    return '$count storyboard row(s)';
  }

  @override
  String get shortVideoReadinessDetailStoryboardsMissing =>
      'No storyboard structure yet';

  @override
  String get shortVideoReadinessLiveLabelClipRefs => 'Shot / clip references';

  @override
  String shortVideoReadinessDetailClipsHas(int count) {
    return '$count clip reference(s)';
  }

  @override
  String get shortVideoReadinessDetailClipsMissing =>
      'Live shots / clip references still missing';

  @override
  String get shortVideoAssetTypeRole => 'Role';

  @override
  String get shortVideoAssetTypeScene => 'Scene';

  @override
  String get shortVideoAssetTypeTool => 'Prop';

  @override
  String get shortVideoAssetTypeClip => 'Shot';

  @override
  String get shortVideoAssetTypeOther => 'Other';

  @override
  String get shortVideoAssetsOverviewLoadingHeadline =>
      'Loading assets overview…';

  @override
  String get shortVideoAssetsOverviewLoadingDetail =>
      'Counts by asset type with linked script IDs (app_script_asset).';

  @override
  String get shortVideoAssetsOverviewUnavailableHeadline =>
      'Assets overview is temporarily unavailable.';

  @override
  String get shortVideoAssetsOverviewUnavailableDetail =>
      'Refresh later, or maintain assets and script links in the project area.';

  @override
  String get shortVideoAssetsOverviewNoLinkedScripts => 'No linked scripts';

  @override
  String get shortVideoAssetsOverviewScriptsPrefix => 'Scripts ';

  @override
  String get shortVideoAssetsOverviewScriptsEllipsis => '…';

  @override
  String shortVideoAssetsOverviewTypeLine(
    String type,
    int count,
    String scriptPart,
  ) {
    return '$type · $count items · $scriptPart';
  }

  @override
  String shortVideoAssetsOverviewHeadline(int total) {
    return '$total assets total, grouped by type (per-row script summary shows experimental script linkage).';
  }

  @override
  String get shortVideoAssetsOverviewFooter =>
      'Read-only aggregate API; candidate state is still maintained via PATCH in the project area.';

  @override
  String get shortVideoCandidateCompareLoadingHeadline =>
      'Preparing shot candidates and current versions…';

  @override
  String get shortVideoCandidateCompareLoadingDetail =>
      'Aggregates reference frames, current video, readiness, and quality summaries per shot.';

  @override
  String get shortVideoCandidateCompareUnavailableHeadline =>
      'No comparable shot candidates yet.';

  @override
  String get shortVideoCandidateCompareUnavailableDetail =>
      'Generate shots or add reference frames in production, then return to Space.';

  @override
  String get shortVideoCandidateQualityNoReviewsLive =>
      'No QA records yet—watch performance naturalness, realism, and voiceover shot quality.';

  @override
  String get shortVideoCandidateQualityNoReviewsAnimated =>
      'No QA records yet—watch character consistency, visual continuity, and shot rhythm.';

  @override
  String shortVideoCandidateQualitySummary(int total, int passed, int bad) {
    return '$total reviews · $passed passed · $bad bad cases';
  }

  @override
  String shortVideoCandidateCompareHeadline(int count) {
    return 'Compare current version, references, and QA for $count prioritized shots.';
  }

  @override
  String get shortVideoCandidateCompareDetailLive =>
      'Live mode shows reference shots and performance constraints so you can lock realism first.';

  @override
  String get shortVideoCandidateCompareDetailAnimated =>
      'See which shots lack references, video, or too many bad cases before partial rework in production.';

  @override
  String get shortVideoSpaceModeTitleAnimated => 'Animated short drama';

  @override
  String get shortVideoSpaceModeTitleLive => 'Live-action short drama';

  @override
  String get shortVideoSpaceModeSummaryAnimated =>
      'The main pipeline is closer to animated short drama, so we emphasize style, character consistency, storyboard images, and continuity.';

  @override
  String get shortVideoSpaceModeSummaryLive =>
      'Live-action should be a first-class mode in the same Space; focus shifts to performance, scene realism, reference shots, and voiceover quality.';

  @override
  String get shortVideoSpaceModeAdviceAnimated =>
      'Prepare visual style, art manuals, and character assets before script and production.';

  @override
  String get shortVideoSpaceModeAdviceLive =>
      'Prepare live references, character setup, shot language, and visual manuals before script and production.';

  @override
  String get shortVideoProjectOptionUnnamed => 'Unnamed project';

  @override
  String get shortVideoMetricScript => 'Scripts';

  @override
  String get shortVideoMetricStoryboard => 'Storyboards';

  @override
  String get shortVideoMetricRole => 'Roles';

  @override
  String get shortVideoMetricNovel => 'Novels';

  @override
  String get shortVideoMetricVideo => 'Videos';

  @override
  String get shortVideoMetricRecentTasks => 'Recent tasks';

  @override
  String get shortVideoMetricGenerationJobs => 'Generation jobs';

  @override
  String get shortVideoMetricInProgress => 'In progress';

  @override
  String get shortVideoMetricFailed => 'Failed';

  @override
  String get shortVideoMetricBadCases => 'Bad cases';

  @override
  String get shortVideoMetricPassRate => 'Pass rate';

  @override
  String get shortVideoMetricScenes => 'Scenes';

  @override
  String get shortVideoMetricClips => 'Clips';

  @override
  String get shortVideoReadinessIntroAnimated =>
      'Animated mode prioritizes style, characters, and storyboard continuity.';

  @override
  String get shortVideoReadinessIntroLive =>
      'Live-action mode prioritizes character setup, scene references, clip footage, and voiceover manuals.';

  @override
  String get shortVideoSpacePageTitle => 'Short video Space';

  @override
  String get shortVideoSpacePageSubtitle =>
      'Inspired by MoneyPrinterTurbo-style pipelines, this entry gathers the path from theme to finished cuts, then wires script, assets, narration, subtitles, and QA into one flow.';

  @override
  String get shortVideoSpaceSectionCreativeMode => 'Creative mode';

  @override
  String get shortVideoSpaceSectionModeReadiness => 'Mode readiness';

  @override
  String get shortVideoSpaceReadinessReadyChip => 'Ready';

  @override
  String get shortVideoSpaceSectionShotReadinessServer =>
      'Shot generation readiness (server)';

  @override
  String get shortVideoSpaceShotReadinessLoading =>
      'Loading shot readiness rollup…';

  @override
  String get shortVideoSpaceShotReadinessUnavailableHint =>
      'Shot readiness summary is unavailable; other overview data still applies.';

  @override
  String get shortVideoSpaceShotReadinessPriorityShots => 'Shots to prioritize';

  @override
  String get shortVideoSpaceOpenProductionBoardButton =>
      'Open storyboards in production workspace';

  @override
  String get shortVideoSpaceSectionSuggestedNext => 'Suggested next step';

  @override
  String get shortVideoSpaceSectionMigrationOrder =>
      'Suggested migration order';

  @override
  String get shortVideoSpaceNavProjects => 'Projects';

  @override
  String get shortVideoSpaceNavScriptWorkspace => 'Script workspace';

  @override
  String get shortVideoSpaceNavProductionWorkspace => 'Production workspace';

  @override
  String get shortVideoSpaceNavTaskCenter => 'Task center';

  @override
  String get shortVideoSpaceNavQualityReviews => 'Quality reviews';

  @override
  String shortVideoCandidateCompareStoryboardOnly(int id) {
    return 'Storyboard #$id';
  }

  @override
  String shortVideoCandidateCompareStoryboardWithScript(
    int storyboardId,
    int scriptId,
  ) {
    return 'Storyboard #$storyboardId · Script #$scriptId';
  }

  @override
  String get shortVideoCandidateReferenceImageNotPreviewable =>
      'Reference image cannot be previewed';

  @override
  String shortVideoCandidateLiveRefShotCount(int count) {
    return '$count live reference shots';
  }

  @override
  String get shortVideoCandidateCurrentVideo => 'Current video';

  @override
  String get shortVideoCandidateSetCurrent => 'Set as current';

  @override
  String get shortVideoCandidatePartialRework => 'Partial rework';

  @override
  String get shortVideoDeliveryModeLive => 'Live ✓';

  @override
  String get shortVideoDeliveryModeSandbox => 'Sandbox ⚠️';

  @override
  String get shortVideoDeliveryModeManualBridge => 'Manual 👤';

  @override
  String get shortVideoDeliveryModeUnknown => 'Unknown';

  @override
  String get shortVideoPublishPlatformDouyin => 'Douyin';

  @override
  String get shortVideoPublishPlatformBilibili => 'Bilibili';

  @override
  String get shortVideoPublishPlatformXiaohongshu => 'Xiaohongshu';

  @override
  String get shortVideoPublishPlatformWeixinChannels => 'Weixin Channels';

  @override
  String get shortVideoPublishPlatformKuaishou => 'Kuaishou';

  @override
  String get shortVideoPublishPlatformTiktok => 'TikTok';

  @override
  String get shortVideoPublishPlatformYoutubeShorts => 'YouTube Shorts';

  @override
  String get shortVideoPublishPlatformInstagramReels => 'Instagram Reels';

  @override
  String get shortVideoPublishPlatformFacebookReels => 'Facebook Reels';

  @override
  String get shortVideoSpaceAspectRatioPortrait916 => 'Portrait 9:16';

  @override
  String get shortVideoSpaceAspectRatioLandscape169 => 'Landscape 16:9';

  @override
  String get shortVideoSpaceAspectRatioSquare11 => 'Square 1:1';

  @override
  String get shortVideoSpacePublishMarketPlatformTitle =>
      'Default publish market / platforms';

  @override
  String get shortVideoSpaceTargetMarketLabel => 'Target market';

  @override
  String get shortVideoSpaceTargetMarketDomestic => 'Domestic';

  @override
  String get shortVideoSpaceTargetMarketOverseas => 'Overseas';

  @override
  String get shortVideoSpaceTargetMarketBoth => 'Both';

  @override
  String get shortVideoSpaceTargetPlatformsHint =>
      'Pick at least one target platform (saved on the project for distribution and validation).';

  @override
  String get shortVideoSpaceDurationStrategyTitle => 'Duration strategy';

  @override
  String get shortVideoSpaceDurationShort => 'Short';

  @override
  String get shortVideoSpaceDurationMedium => 'Medium';

  @override
  String get shortVideoSpaceDurationLong => 'Long';

  @override
  String get shortVideoSpaceVoiceSubtitleBgmTitle =>
      'Voiceover / subtitles / BGM (project defaults)';

  @override
  String get shortVideoSpaceVoiceProfileLabel =>
      'Voice profile (voice_profile)';

  @override
  String get shortVideoSpaceVoiceProfileHint =>
      'e.g. default_narrator (optional)';

  @override
  String get shortVideoSpaceSubtitleStyleLabel =>
      'Subtitle style (subtitle_style)';

  @override
  String get shortVideoSpaceBgmStrategyLabel => 'BGM strategy (bgm_strategy)';

  @override
  String get shortVideoSpaceCreatingProject => 'Creating…';

  @override
  String get shortVideoSpaceCreateProjectDirect => 'Create short drama project';

  @override
  String get shortVideoSpaceSavingProjectConfig => 'Saving…';

  @override
  String get shortVideoSpaceSaveProjectConfigWriteback =>
      'Save back to project';

  @override
  String get shortVideoSpaceOpenProjectsRefine => 'Open projects to refine';

  @override
  String get shortVideoSpaceLoadingProjectReadiness =>
      'Loading project readiness…';

  @override
  String get shortVideoSpaceMetricChipVisual => 'Visual';

  @override
  String get shortVideoSpaceMetricChipManual => 'Manual';

  @override
  String get scriptEditorStoryboardsProductionEmptyData =>
      'Production view has no storyboard rows yet.';

  @override
  String scriptEditorStoryboardsProductionSummaryLine(
    int count,
    String preview,
    String ellipsis,
  ) {
    return 'Production view · $count rows · $preview$ellipsis';
  }

  @override
  String scriptEditorStoryboardsProductionReadFailed(String error) {
    return 'Failed to read production view: $error';
  }

  @override
  String get scriptEditorStoryboardsDiagnosisEmptySummary =>
      'This script has no storyboards yet.';

  @override
  String get scriptEditorStoryboardsDiagnosisEmptyDetail =>
      'Add a single shot or batch-import prompts, then sync the production view or start image generation.';

  @override
  String scriptEditorStoryboardsDiagnosisProductionNotSyncedSummary(int count) {
    return 'Maintaining $count storyboards, but the production view is not synced.';
  }

  @override
  String get scriptEditorStoryboardsDiagnosisProductionNotSyncedDetail =>
      'Refresh the production view first to confirm production-side rows exist, then decide whether to continue batch generation.';

  @override
  String scriptEditorStoryboardsDiagnosisNoPromptsSummary(int count) {
    return '$count storyboards exist, but none have a usable prompt.';
  }

  @override
  String get scriptEditorStoryboardsDiagnosisNoPromptsDetail =>
      'Open individual storyboards to fill prompts before the image workbench is reliable.';

  @override
  String scriptEditorStoryboardsDiagnosisReadyBatchSummary(
    int ready,
    int total,
  ) {
    return '$ready/$total storyboards can enter the image-generation flow.';
  }

  @override
  String get scriptEditorStoryboardsDiagnosisReadyBatchDetail =>
      'Open the storyboard image workbench to read the production view, generate previews, and export selected images in batch.';

  @override
  String get scriptEditorStoryboardsRecommendAddStoryboard =>
      'Keep adding storyboards';

  @override
  String get scriptEditorStoryboardsRecommendRefreshProduction =>
      'Refresh production view';

  @override
  String get scriptEditorStoryboardsRecommendOpenBatchWorkbench =>
      'Open storyboard image workbench';

  @override
  String get scriptEditorStoryboardsRecommendEditPrompts =>
      'Fill in storyboard prompts';

  @override
  String scriptEditorStoryboardsFollowUpLine(
    String actionSummary,
    String nextAction,
    String detail,
  ) {
    return '$actionSummary Suggested next step: $nextAction. $detail';
  }

  @override
  String scriptEditorStoryboardBatchFollowUpLine(
    String actionSummary,
    String nextAction,
    String detail,
  ) {
    return '$actionSummary Suggested next step: $nextAction. $detail';
  }

  @override
  String get scriptEditorStoryboardBatchRecommendSyncProduction =>
      'Sync production view';

  @override
  String get scriptEditorStoryboardBatchRecommendSelectReady =>
      'Select all image-ready shots';

  @override
  String get scriptEditorStoryboardBatchRecommendGenerateSelected =>
      'Batch-generate images';

  @override
  String get scriptEditorStoryboardBatchRecommendPreviewSelected =>
      'Read current preview';

  @override
  String get scriptEditorStoryboardBatchReadDownloadLink =>
      'Read download link';

  @override
  String get scriptEditorStoryboardBatchRecommendExportSelected =>
      'Export selected ZIP';

  @override
  String get scriptEditorStoryboardBatchDiagnosisNoSelectionSummary =>
      'No storyboards selected for processing.';

  @override
  String scriptEditorStoryboardBatchDiagnosisNoSelectionWithReadyDetail(
    int readyCount,
  ) {
    return '$readyCount shots already have usable prompts; batch generate can auto-pick ready shots and enqueue them.';
  }

  @override
  String get scriptEditorStoryboardBatchDiagnosisNoSelectionSyncFirstDetail =>
      'Sync the production view first to confirm production rows and prompts, then choose your next step.';

  @override
  String scriptEditorStoryboardBatchDiagnosisPartialProductionSummary(
    int count,
  ) {
    return '$count selected shot(s) are not all synced to the production view.';
  }

  @override
  String get scriptEditorStoryboardBatchDiagnosisPartialProductionDetail =>
      'Refresh the production view to fill production snapshots before preview, download links, or export.';

  @override
  String get scriptEditorStoryboardBatchDiagnosisNoPromptsSummary =>
      'Selected shots are missing usable image prompts.';

  @override
  String get scriptEditorStoryboardBatchDiagnosisNoPromptsDetail =>
      'Return to storyboard editing to add prompts, or sync production to reuse production-side prompts.';

  @override
  String get scriptEditorStoryboardBatchDiagnosisSingleHasImageSummary =>
      'The selected shot already has an image.';

  @override
  String get scriptEditorStoryboardBatchDiagnosisSingleHasImageDetail =>
      'Read the current preview first to see if it is reusable before re-generating.';

  @override
  String scriptEditorStoryboardBatchDiagnosisAllHaveImagesSummary(int count) {
    return 'All $count selected shots already have images.';
  }

  @override
  String get scriptEditorStoryboardBatchDiagnosisAllHaveImagesDetail =>
      'Export a ZIP for review, or return to a single storyboard to re-run generation if needed.';

  @override
  String scriptEditorStoryboardBatchDiagnosisMixedReadySummary(
    int selected,
    int ready,
  ) {
    return '$selected selected; $ready can start image generation now.';
  }

  @override
  String get scriptEditorStoryboardBatchDiagnosisMixedReadyDetail =>
      'Submit batch generate first, then return here for preview or download links.';

  @override
  String get scriptEditorStoryboardBatchDialogTitle =>
      'Storyboard image workbench';

  @override
  String get scriptEditorStoryboardBatchDialogIntro =>
      'Batch-generate images, read previews, download links, and export ZIP from the script storyboard area—without relying only on production probes.';

  @override
  String get scriptEditorStoryboardBatchHasImage => 'Has image';

  @override
  String get scriptEditorStoryboardBatchMetaIncomplete =>
      'Shot details incomplete';

  @override
  String get scriptEditorStoryboardBatchSyncProductionEmpty =>
      'Production view has no storyboard rows yet; you can still start batch generate from script prompts.';

  @override
  String scriptEditorStoryboardBatchSyncProductionCount(int count) {
    return 'Synced $count production storyboard row(s).';
  }

  @override
  String scriptEditorStoryboardBatchLoadProductionFailed(String error) {
    return 'Failed to load production view: $error';
  }

  @override
  String scriptEditorStoryboardBatchGenerateAutoSelected(
    int readyCount,
    int total,
    int enqueued,
  ) {
    return 'Auto-selected $readyCount image-ready shot(s); created tasks for $total shot(s); enqueued $enqueued.';
  }

  @override
  String scriptEditorStoryboardBatchGenerateSubmitted(int total, int enqueued) {
    return 'Created tasks for $total shot(s); enqueued $enqueued.';
  }

  @override
  String get scriptEditorStoryboardBatchSelectAllReady =>
      'Selected all shots that can generate images.';

  @override
  String get scriptEditorStoryboardBatchClearSelection => 'Cleared selection.';

  @override
  String get scriptEditorStoryboardBatchNoPreview =>
      'This shot has no preview image yet.';

  @override
  String scriptEditorStoryboardBatchPreviewLoaded(int storyboardId) {
    return 'Read current preview for shot #$storyboardId.';
  }

  @override
  String scriptEditorStoryboardBatchDownloadReady(int storyboardId) {
    return 'Generated download link for shot #$storyboardId.';
  }

  @override
  String scriptEditorStoryboardBatchExportDone(
    int count,
    String filename,
    String durationLabel,
  ) {
    return 'Exported $count shot(s), file $filename, total duration $durationLabel.';
  }

  @override
  String get scriptEditorStoryboardBatchNoPromptsError =>
      'No selected shots have usable prompts; cannot start batch image generation.';

  @override
  String get scriptEditorStoryboardBatchSyncing => 'Syncing…';

  @override
  String get scriptEditorStoryboardBatchClearSelectionButton =>
      'Clear selection';

  @override
  String get scriptEditorStoryboardBatchPromptSuffixLabel =>
      'Prompt suffix (optional)';

  @override
  String get scriptEditorStoryboardBatchPromptSuffixHelper =>
      'Appended to each shot\'s base prompt.';

  @override
  String get scriptEditorStoryboardBatchNegativePromptLabel =>
      'Negative prompt (optional)';

  @override
  String get scriptEditorStoryboardBatchModelLabel => 'Model (optional)';

  @override
  String get scriptEditorStoryboardBatchResolutionLabel =>
      'Resolution (optional)';

  @override
  String get scriptEditorStoryboardBatchQuickGenerateHint =>
      'With no manual selection, batch generate auto-picks shots that already have usable prompts. Preview and export still need an explicit selection.';

  @override
  String get scriptEditorStoryboardBatchNoResolvablePrompt =>
      'No usable prompt';

  @override
  String get scriptEditorStoryboardBatchPreviewExportHeading =>
      'Preview and export';

  @override
  String get scriptEditorStoryboardBatchSelectOneForPreview =>
      'Select exactly one shot to read preview and download link.';

  @override
  String scriptEditorStoryboardBatchViewingShot(int id) {
    return 'Viewing shot #$id';
  }

  @override
  String get scriptEditorStoryboardBatchExportEstimateHeading =>
      'Export bundle estimate';

  @override
  String scriptEditorStoryboardBatchExportEstimateContent(
    int shotCount,
    String sidecar,
  ) {
    return 'Contents: $shotCount storyboard image(s) + $sidecar';
  }

  @override
  String scriptEditorStoryboardBatchExportEstimateEntries(
    int entryCount,
    String durationLabel,
  ) {
    return 'Estimated entries: $entryCount · total duration $durationLabel';
  }

  @override
  String scriptEditorStoryboardBatchDownloadLinkLine(String url) {
    return 'Download link: $url';
  }

  @override
  String get scriptEditorStoryboardBatchLastExportHeading =>
      'Latest export bundle';

  @override
  String scriptEditorStoryboardBatchExportFileLine(String filename) {
    return 'File: $filename';
  }

  @override
  String scriptEditorStoryboardBatchExportContentLine(
    int shotCount,
    String sidecar,
  ) {
    return 'Contents: $shotCount storyboard image(s) + $sidecar';
  }

  @override
  String scriptEditorStoryboardBatchExportDetailWithSize(
    int entryCount,
    String durationLabel,
    String size,
  ) {
    return 'Estimated entries: $entryCount · total duration $durationLabel · size $size';
  }

  @override
  String scriptEditorStoryboardBatchExportShotIds(String ids) {
    return 'Shot IDs: $ids';
  }

  @override
  String get scriptEditorStoryboardBatchPreviewPlaceholder =>
      'Preview image appears here.';

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
  String get projectScriptPlanCoverageNoChaptersNoEvents =>
      'No chapters or events yet. Import from the content area and generate events first.';

  @override
  String projectScriptPlanCoverageChaptersNoEventsYet(int chapterCount) {
    return 'This project has $chapterCount chapter(s) but no events yet. Generate events before refining the skeleton.';
  }

  @override
  String get projectScriptPlanCoverageChaptersNotLoaded =>
      'Chapters not loaded';

  @override
  String projectScriptPlanCoverageChaptersProgress(int covered, int total) {
    return '$covered/$total chapters covered';
  }

  @override
  String projectScriptPlanCoverageEventsSummary(
    int eventCount,
    String coverage,
    String sampleSuffix,
  ) {
    return '$eventCount events · $coverage$sampleSuffix';
  }

  @override
  String get projectScriptPlanDraftsSummaryEmpty =>
      'No script draft packets yet. Add chapters or events first.';

  @override
  String projectScriptPlanDraftsSummary(
    int draftCount,
    int chapterCount,
    String sampleSuffix,
  ) {
    return 'Generated $draftCount draft packet(s), covering $chapterCount chapter(s)$sampleSuffix';
  }

  @override
  String get projectScriptPlanGuidanceSummaryEmpty =>
      'No structured rewrite guidance yet. Generate draft packets first or add chapters/events.';

  @override
  String projectScriptPlanGuidanceSummary(
    int guidanceCount,
    String sampleSuffix,
  ) {
    return 'Generated $guidanceCount structured rewrite guidance row(s)$sampleSuffix';
  }

  @override
  String get projectScriptPlanSkeletonOpeningHookLabel => 'Cold open hook:';

  @override
  String get projectScriptPlanSkeletonOpeningHookZeroChapters =>
      'In one line, establish the protagonist\'s predicament and throw an abnormal action or danger signal in the first 30 seconds.';

  @override
  String projectScriptPlanSkeletonOpeningHookWithChapters(int chapterSpan) {
    return 'Use the first $chapterSpan chapters to quickly establish the situation and land a strong hook on the first screen.';
  }

  @override
  String get projectScriptPlanSkeletonCorePushLabel => 'Core momentum:';

  @override
  String get projectScriptPlanSkeletonCoreEmptyLine1 =>
      '- Extract 3–5 key beats from chapters and order them as \"escalation → misread → reversal\".';

  @override
  String get projectScriptPlanSkeletonCoreEmptyLine2 =>
      '- Keep only actions that move relationships or the situation; do not retell the prose.';

  @override
  String projectScriptPlanSkeletonEventLine(
    String name,
    String chapterIndexes,
    String detail,
  ) {
    return '- $name (chapters $chapterIndexes): $detail';
  }

  @override
  String get projectScriptPlanSkeletonEventDetailFallback =>
      'Explain how this beat changes the character\'s situation and their next goal.';

  @override
  String get projectScriptPlanSkeletonClosingLabel => 'End flip:';

  @override
  String get projectScriptPlanSkeletonClosingBullet =>
      '- Leave the last beat with unpaid emotional debt or greater external pressure to drive the next episode.';

  @override
  String get projectScriptPlanAdaptPeopleLabel => 'Character strategy:';

  @override
  String get projectScriptPlanAdaptPeopleLine1 =>
      '- Give the lead stepped emotional shifts; every reaction should map to a concrete stimulus.';

  @override
  String get projectScriptPlanAdaptPeopleLine2 =>
      '- Keep only supporting characters who increase the pressure on the lead\'s choices; drop exposition-only walk-ons.';

  @override
  String get projectScriptPlanAdaptPacingLabel => 'Pacing strategy:';

  @override
  String get projectScriptPlanAdaptPacingNoEvents =>
      '- Slice chapters into 3–5 strong action beats, then compress to short-drama pacing.';

  @override
  String projectScriptPlanAdaptPacingWithEvents(int eventCount) {
    return '- With $eventCount events on file, prioritize beats with strong conflict, identity shifts, and emotional contrast.';
  }

  @override
  String get projectScriptPlanAdaptPacingNoChapters =>
      '- Each episode solves one core problem and pushes the larger crisis to the tail.';

  @override
  String projectScriptPlanAdaptPacingWithChapters(int chapterCount) {
    return '- With $chapterCount chapters, avoid flat narration; release information as \"fast open → sustained pressure → late flip\".';
  }

  @override
  String get projectScriptPlanAdaptVoiceLabel => 'Voice strategy:';

  @override
  String get projectScriptPlanAdaptVoiceLine1 =>
      '- Dialogue should sound spoken and purposeful; avoid explaining plot the audience can already read from action.';

  @override
  String get projectScriptPlanAdaptVoiceLine2 =>
      '- Favor shots and action that serve emotional state; avoid empty montage stacking.';

  @override
  String projectScriptPlanDraftEpisodeNumbered(int episodeNumber) {
    return 'Episode $episodeNumber';
  }

  @override
  String get projectScriptPlanDraftChapterPendingSummary =>
      'Chapter references TBD';

  @override
  String projectScriptPlanDraftChapterSummaryPlainIndex(int index) {
    return 'Chapter $index';
  }

  @override
  String projectScriptPlanDraftChapterSummaryTitled(int index, String title) {
    return 'Chapter $index《$title》';
  }

  @override
  String get projectScriptPlanDraftSkeletonFallback =>
      'Hook fast in the first block, keep pressure rising in the middle, leave a bigger emotional IOU at the end.';

  @override
  String get projectScriptPlanDraftStrategyFallback =>
      'Spoken dialogue, emotion carried by action, exposition only through conflict.';

  @override
  String projectScriptPlanDraftBeatFromChapterPlain(int index) {
    return '- Pull one beat from chapter $index that moves relationship or situation.';
  }

  @override
  String projectScriptPlanDraftBeatFromChapterTitled(String title) {
    return '- Pull one beat from 《$title》 that moves relationship or situation.';
  }

  @override
  String get projectScriptPlanDraftEventNameFallback => 'Key beat';

  @override
  String get projectScriptPlanDraftEventDetailFallback =>
      'Add the emotional shift, choice, and situation change this beat causes.';

  @override
  String projectScriptPlanDraftEventBeat(String name, String detail) {
    return '- $name: $detail';
  }

  @override
  String get projectScriptPlanDraftEndingNoEvents =>
      'After the last action, add an unfinished discovery, misunderstanding, or prelude to a counterattack.';

  @override
  String projectScriptPlanDraftEndingAfterEvent(String eventName) {
    return 'Leave the aftershock of \"$eventName\" at the ending—characters think they are safe, but danger grows.';
  }

  @override
  String get projectScriptPlanDraftHdrPositioning => '【Series positioning】';

  @override
  String projectScriptPlanDraftPositioningBody(
    String packetName,
    String chapterSummary,
  ) {
    return '$packetName: compress one short-drama episode around $chapterSummary; open with conflict and end on a hook.';
  }

  @override
  String get projectScriptPlanDraftHdrSkeleton => '【Skeleton guardrails】';

  @override
  String get projectScriptPlanDraftHdrAdaptation => '【Adaptation stance】';

  @override
  String get projectScriptPlanDraftHdrBeats => '【Beat sheet】';

  @override
  String get projectScriptPlanDraftHdrScenes => '【Scene prompts】';

  @override
  String get projectScriptPlanDraftHdrDialogue => '【Dialogue requirements】';

  @override
  String get projectScriptPlanDraftDialogueLine1 =>
      '- Every line has intent; do not explain what action already shows.';

  @override
  String get projectScriptPlanDraftDialogueLine2 =>
      '- Emotions arc: hold, push, then reveal; avoid one-note delivery.';

  @override
  String get projectScriptPlanDraftHdrEnding => '【Closing hook】';

  @override
  String get projectScriptPlanDraftSceneDefault1 =>
      '- Scene 1: open with an abnormal action or external threat that forces a choice.';

  @override
  String get projectScriptPlanDraftSceneDefault2 =>
      '- Scene 2: unbalance the key relationship; do not explain conflict in narration.';

  @override
  String get projectScriptPlanDraftSceneDefault3 =>
      '- Scene 3: end on an emotional flip and a must-watch cliffhanger.';

  @override
  String projectScriptPlanDraftSceneChapterOnly(
    int sceneNumber,
    int chapterIndex,
  ) {
    return '- Scene $sceneNumber: chapter $chapterIndex.';
  }

  @override
  String projectScriptPlanDraftSceneTitleNoExcerpt(
    int sceneNumber,
    String title,
  ) {
    return '- Scene $sceneNumber: 《$title》.';
  }

  @override
  String projectScriptPlanDraftSceneTitleWithExcerpt(
    int sceneNumber,
    String title,
    String excerpt,
  ) {
    return '- Scene $sceneNumber: 《$title》, turn the action and emotion in \"$excerpt\" into shootable beats.';
  }

  @override
  String get projectScriptPlanRewriteSkeletonFallback =>
      'Put the lead\'s trap and biggest conflict up front; do not front-load flat exposition.';

  @override
  String get projectScriptPlanRewriteStrategyFallback =>
      'Spoken dialogue, externalized emotion, information rides on conflict.';

  @override
  String get projectScriptPlanRewriteChapterWhenNoIndexes =>
      '- Rewrite around the strongest conflict first; compress undramatic explanatory prose.';

  @override
  String projectScriptPlanRewriteChapterPlainEmptyExcerpt(int index) {
    return '- Chapter $index: keep only actions that move conflict or relationships.';
  }

  @override
  String projectScriptPlanRewriteChapterPlainWithExcerpt(
    int index,
    String excerpt,
  ) {
    return '- Chapter $index: turn \"$excerpt\" into shootable action and emotional clashes.';
  }

  @override
  String projectScriptPlanRewriteChapterTitledEmptyExcerpt(
    int index,
    String title,
  ) {
    return '- Chapter $index《$title》: keep only actions that move conflict or relationships.';
  }

  @override
  String projectScriptPlanRewriteChapterTitledWithExcerpt(
    int index,
    String title,
    String excerpt,
  ) {
    return '- Chapter $index《$title》: turn \"$excerpt\" into shootable action and emotional clashes.';
  }

  @override
  String get projectScriptPlanRewriteEventDefault =>
      '- Add three nodes: hook, rising pressure, tail reversal or suspense.';

  @override
  String projectScriptPlanRewriteEventNamed(String name) {
    return '- Event \"$name\" must change emotion or the board; no pure info dumps.';
  }

  @override
  String get projectScriptPlanRewriteHdrGoal => '【Rewrite goal】';

  @override
  String get projectScriptPlanRewriteHdrStrategy => '【Rewrite strategy】';

  @override
  String get projectScriptPlanRewriteHdrChapters => '【Chapter compression】';

  @override
  String get projectScriptPlanRewriteHdrEvents => '【Event rewrite】';

  @override
  String get projectScriptPlanRewriteHdrPeople => '【Character emotion】';

  @override
  String get projectScriptPlanRewritePeopleLine1 =>
      '- Every scene gives the lead a clear stimulus, reaction, and next move; avoid flat emotion all episode.';

  @override
  String get projectScriptPlanRewritePeopleLine2 =>
      '- Supporting lines should force the lead\'s choices—no empty exposition dialogue.';

  @override
  String get projectScriptPlanRewriteHdrDeAi => '【Anti-LLM polish】';

  @override
  String get projectScriptPlanRewriteDeAiLine1 =>
      '- Cut summary lines, moralizing, and bookish connectors; replace with spoken conflict.';

  @override
  String get projectScriptPlanRewriteDeAiLine2 =>
      '- Lead with action, gaze, pauses, and sources of pressure before adding necessary dialogue.';

  @override
  String get projectScriptPlanRewriteDeAiLine3 =>
      '- Do not stack three straight lines explaining background; hide intel in probing, misunderstanding, and pressure.';

  @override
  String get projectScriptPlanWorkbenchTitle =>
      'Story skeleton & adaptation strategy';

  @override
  String projectScriptPlanWorkbenchPlanMountedLine(
    String planId,
    int count,
    String namesSuffix,
  ) {
    return 'planId $planId · $count script row(s) mounted$namesSuffix';
  }

  @override
  String get projectScriptPlanWorkbenchFillSkeletonFromEvents =>
      'Fill skeleton draft from events';

  @override
  String get projectScriptPlanWorkbenchFillStrategyFromEvents =>
      'Fill strategy draft from events';

  @override
  String get projectScriptPlanWorkbenchGenerateDraftPackets =>
      'Generate script draft packets';

  @override
  String get projectScriptPlanWorkbenchGenerateStructuredGuidance =>
      'Generate structured rewrite guidance';

  @override
  String get projectScriptPlanWorkbenchWriteScriptDrafts =>
      'Write script drafts';

  @override
  String get projectScriptPlanWorkbenchStorySkeletonLabel => 'Story Skeleton';

  @override
  String get projectScriptPlanWorkbenchStorySkeletonHelper =>
      'Focus on story spine, main conflict, turning points, and resolution path';

  @override
  String get projectScriptPlanWorkbenchAdaptationStrategyLabel =>
      'Adaptation Strategy';

  @override
  String get projectScriptPlanWorkbenchAdaptationStrategyHelper =>
      'Capture adaptation trade-offs, character arcs, pacing, and style constraints';

  @override
  String get projectScriptPlanWorkbenchScriptDraftPreviewTitle =>
      'Script draft preview';

  @override
  String get projectScriptPlanWorkbenchNoDraftPacketsHint =>
      'No draft packets yet. Refine skeleton/strategy first, then generate.';

  @override
  String get projectScriptPlanWorkbenchStructuredGuidanceTitle =>
      'Structured rewrite guidance';

  @override
  String get projectScriptPlanWorkbenchNoGuidanceHint =>
      'No structured guidance yet. Run before and after drafts to constrain revisions.';

  @override
  String get projectScriptPlanWorkbenchChaptersPrefix => 'Chapters';

  @override
  String get projectScriptPlanWorkbenchTbd => 'TBD';

  @override
  String get projectScriptPlanWorkbenchReloadPlan => 'Reload plan';

  @override
  String get projectScriptPlanWorkbenchSavePlan => 'Save plan';

  @override
  String get projectScriptPlanWorkbenchRefreshing => 'Refreshing…';

  @override
  String get projectScriptPlanWorkbenchSaving => 'Saving…';

  @override
  String get projectScriptPlanWorkbenchLoadingInitial => 'Loading plan…';

  @override
  String get projectScriptPlanWorkbenchRefreshingPlan => 'Refreshing plan…';

  @override
  String projectScriptPlanWorkbenchLoadedPlan(String planId, int scriptCount) {
    return 'Loaded plan $planId · $scriptCount script row(s)';
  }

  @override
  String projectScriptPlanWorkbenchLoadFailed(String error) {
    return 'Failed to load plan: $error';
  }

  @override
  String get projectScriptPlanWorkbenchSkeletonDraftGenerated =>
      'Story skeleton draft filled from events.';

  @override
  String get projectScriptPlanWorkbenchStrategyDraftGenerated =>
      'Adaptation strategy draft filled from events.';

  @override
  String get projectScriptPlanWorkbenchNoDraftsNoEvents =>
      'No draft packets (add events/novels or refine skeleton/strategy).';

  @override
  String projectScriptPlanWorkbenchDraftsGenerated(int count) {
    return 'Generated $count script draft packet(s).';
  }

  @override
  String get projectScriptPlanWorkbenchNoGuidanceNoEvents =>
      'No structured guidance (add events/novels or refine skeleton/strategy).';

  @override
  String projectScriptPlanWorkbenchGuidanceGenerated(int count) {
    return 'Generated $count structured guidance row(s).';
  }

  @override
  String get projectScriptPlanWorkbenchSavingPlan => 'Saving plan…';

  @override
  String projectScriptPlanWorkbenchSaveFailedHttp(int status) {
    return 'Save failed (HTTP $status)';
  }

  @override
  String get projectScriptPlanWorkbenchPlanSaved => 'Plan saved.';

  @override
  String projectScriptPlanWorkbenchSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get projectScriptPlanWorkbenchNeedDraftsFirst =>
      'Generate draft packets first.';

  @override
  String get projectScriptPlanWorkbenchWritingDrafts =>
      'Writing script drafts…';

  @override
  String projectScriptPlanWorkbenchWriteFailedHttp(int status) {
    return 'Write failed (HTTP $status)';
  }

  @override
  String projectScriptPlanWorkbenchDraftsWritten(int count) {
    return 'Wrote drafts; refreshed with $count packet(s) pending.';
  }

  @override
  String projectScriptPlanWorkbenchWriteDraftsFailed(String error) {
    return 'Write drafts failed: $error';
  }

  @override
  String shortVideoUndoEnableShot(int storyboardId) {
    return 'Enable shot #$storyboardId';
  }

  @override
  String shortVideoUndoDisableShot(int storyboardId) {
    return 'Disable shot #$storyboardId';
  }

  @override
  String shortVideoUndoSetShotDuration(int storyboardId, int seconds) {
    return 'Set shot #$storyboardId duration to ${seconds}s';
  }

  @override
  String shortVideoUndoReplaceShotVideo(int storyboardId) {
    return 'Replace shot #$storyboardId video';
  }

  @override
  String shortVideoUndoBatchEnable(int count) {
    return 'Batch enable $count shot(s)';
  }

  @override
  String shortVideoUndoBatchDisable(int count) {
    return 'Batch disable $count shot(s)';
  }

  @override
  String shortVideoUndoBatchAlignDuration(int count) {
    return 'Batch align duration for $count shot(s)';
  }

  @override
  String shortVideoUndoBatchReplaceVideo(int count) {
    return 'Batch replace video for $count shot(s)';
  }

  @override
  String shortVideoUndoTooltipWithDescription(String description) {
    return 'Undo: $description (Ctrl+Z / Cmd+Z)';
  }

  @override
  String get shortVideoUndoTooltipEmpty => 'Nothing to undo';

  @override
  String shortVideoRedoTooltipWithDescription(String description) {
    return 'Redo: $description (Ctrl+Shift+Z / Cmd+Shift+Z)';
  }

  @override
  String get shortVideoRedoTooltipEmpty => 'Nothing to redo';

  @override
  String get shortVideoOperationHistoryToolbarTooltip =>
      'View operation history';

  @override
  String get shortVideoOperationHistoryTitle => 'Operation history';

  @override
  String get shortVideoOperationHistorySummaryHeading => 'Summary';

  @override
  String shortVideoOperationHistoryUndoStack(int count) {
    return 'Undo stack: $count';
  }

  @override
  String shortVideoOperationHistoryRedoStack(int count) {
    return 'Redo stack: $count';
  }

  @override
  String shortVideoOperationHistoryLimitLine(int max) {
    return 'History limit: $max entries';
  }

  @override
  String get shortVideoOperationHistoryEmpty => 'No operations yet';

  @override
  String get shortVideoOperationHistoryOperationsHeading =>
      'Operations (newest first)';

  @override
  String get shortVideoOperationHistoryLatestChip => 'Latest';

  @override
  String get shortVideoOperationHistoryClear => 'Clear history';

  @override
  String get shortVideoOperationHistoryClearedSnackbar =>
      'Operation history cleared';

  @override
  String shortVideoOperationHistoryRelativeSecondsAgo(int count) {
    return '${count}s ago';
  }

  @override
  String shortVideoOperationHistoryRelativeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String shortVideoOperationHistoryRelativeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get shortVideoPreviewPlaylistComplete => 'Finished playing all shots';

  @override
  String get shortVideoBatchThrottleMessage =>
      'You\'re doing that too often. Wait a moment and try again.';

  @override
  String get shortVideoBatchSelectAll => 'Select all';

  @override
  String get shortVideoBatchDeselectAll => 'Deselect all';

  @override
  String shortVideoBatchSelectedCount(int selected, int total) {
    return 'Selected: $selected / $total';
  }

  @override
  String get shortVideoBatchOpEnable => 'Batch enable';

  @override
  String get shortVideoBatchOpDisable => 'Batch disable';

  @override
  String get shortVideoBatchOpDurationAlign => 'Duration align';

  @override
  String get shortVideoBatchOpReplace => 'Batch replace URL';

  @override
  String get shortVideoBatchOpVoiceover => 'Batch voiceover';

  @override
  String shortVideoBatchProgressCompletedTotal(int completed, int total) {
    return 'Progress: $completed / $total';
  }

  @override
  String shortVideoBatchProgressSucceededLabel(int count) {
    return 'Succeeded: $count';
  }

  @override
  String shortVideoBatchProgressFailedLabel(int count) {
    return 'Failed: $count';
  }

  @override
  String get shortVideoBatchProgressFailedHeading => 'Failed items:';

  @override
  String shortVideoBatchProgressStoryboardLine(int id) {
    return 'Storyboard #$id';
  }

  @override
  String get shortVideoBatchProgressCancel => 'Cancel';

  @override
  String get shortVideoBatchProgressRetryFailed => 'Retry failed';

  @override
  String get shortVideoBatchProgressClose => 'Close';

  @override
  String shortVideoBatchErrorCode(String code) {
    return 'Error code: $code';
  }

  @override
  String shortVideoBatchOperationRetryTitle(String title) {
    return '$title (retry)';
  }

  @override
  String get shortVideoBatchSelectShotsToEnableFirst =>
      'Select shots to enable first.';

  @override
  String get shortVideoBatchNoShotsWithVideoUrl =>
      'None of the selected shots have a usable video URL.';

  @override
  String get shortVideoBatchEnableTitle => 'Batch enable shots';

  @override
  String shortVideoBatchEnableFinished(int successful, int failed) {
    return 'Batch enable finished: succeeded $successful, failed $failed';
  }

  @override
  String shortVideoBatchEnableFailedStatus(String code) {
    return 'Batch enable failed: $code';
  }

  @override
  String shortVideoBatchEnableFailedError(String error) {
    return 'Batch enable failed: $error';
  }

  @override
  String get shortVideoBatchSelectShotsToDisableFirst =>
      'Select shots to disable first.';

  @override
  String get shortVideoBatchDisableTitle => 'Batch disable shots';

  @override
  String shortVideoBatchDisableFinished(int successful, int failed) {
    return 'Batch disable finished: succeeded $successful, failed $failed';
  }

  @override
  String shortVideoBatchDisableFailedStatus(String code) {
    return 'Batch disable failed: $code';
  }

  @override
  String shortVideoBatchDisableFailedError(String error) {
    return 'Batch disable failed: $error';
  }

  @override
  String get shortVideoBatchSelectShotsDurationFirst =>
      'Select shots to align duration first.';

  @override
  String get shortVideoBatchDurationDialogTitle => 'Batch duration align';

  @override
  String get shortVideoBatchDurationLabel => 'Duration (seconds)';

  @override
  String get shortVideoBatchDurationHint => 'Enter 1–300';

  @override
  String get shortVideoBatchAlignAndSave => 'Align and save';

  @override
  String get shortVideoBatchDurationProgressTitle => 'Batch duration align';

  @override
  String shortVideoBatchDurationFinished(int successful, int failed) {
    return 'Batch duration align finished: succeeded $successful, failed $failed';
  }

  @override
  String get shortVideoBatchSelectShotsReplaceFirst =>
      'Select shots to replace first.';

  @override
  String get shortVideoBatchReplaceDialogTitle => 'Batch replace video URLs';

  @override
  String get shortVideoBatchReplaceFindPatternLabel =>
      'Find pattern (regex supported)';

  @override
  String get shortVideoBatchReplaceFindPatternHint => 'e.g. /v1/';

  @override
  String get shortVideoBatchReplaceWithLabel => 'Replace with';

  @override
  String get shortVideoBatchReplaceWithHint => 'e.g. /v2/';

  @override
  String get shortVideoBatchReplaceUrlDescription =>
      'Find-and-replace runs on each selected shot video URL.';

  @override
  String get shortVideoBatchApplyReplacement => 'Apply replacement';

  @override
  String get shortVideoBatchReplaceNoMatch =>
      'No shots to replace (pattern did not match).';

  @override
  String shortVideoBatchReplaceFinished(int successful, int failed) {
    return 'Batch replace finished: succeeded $successful, failed $failed';
  }

  @override
  String shortVideoBatchReplaceFailedStatus(String code) {
    return 'Batch replace failed: $code';
  }

  @override
  String shortVideoBatchReplaceFailedError(String error) {
    return 'Batch replace failed: $error';
  }

  @override
  String get shortVideoBatchCannotLoadProject => 'Cannot load project.';

  @override
  String get shortVideoBatchSelectShotsVoiceoverFirst =>
      'Select shots to generate voiceover first.';

  @override
  String get shortVideoBatchNoVoiceoverTextSelected =>
      'None of the selected shots have usable voiceover text.';

  @override
  String get shortVideoBatchGenerateVoiceoverTitle =>
      'Batch generate voiceover';

  @override
  String shortVideoBatchVoiceoverQueueProgress(
    int done,
    int total,
    String percent,
  ) {
    return 'Progress: $done / $total ($percent%)';
  }

  @override
  String shortVideoBatchVoiceoverQueueStats(int succeeded, int failed) {
    return 'Succeeded: $succeeded · failed: $failed';
  }

  @override
  String get shortVideoBatchVoiceoverQueueFailedHeading => 'Failed items:';

  @override
  String shortVideoBatchVoiceoverQueueFailedLine(int id, String message) {
    return 'Shot #$id: $message';
  }

  @override
  String get shortVideoBatchVoiceoverQueueDone => 'Done';

  @override
  String shortVideoBatchVoiceoverGenFailedStatus(String code) {
    return 'Batch voiceover generation failed: $code';
  }

  @override
  String shortVideoBatchVoiceoverGenFailedError(String error) {
    return 'Batch voiceover generation failed: $error';
  }

  @override
  String shortVideoBatchVoiceoverDoneJobs(int count) {
    return 'Batch voiceover done: enqueued jobs for $count shot(s).';
  }

  @override
  String shortVideoBatchVoiceoverDonePartial(int succeeded, int failed) {
    return 'Batch voiceover done: succeeded $succeeded, failed $failed';
  }

  @override
  String get shortVideoBatchShotNoVoiceoverText =>
      'This shot has no usable voiceover text.';

  @override
  String get shortVideoBatchGeneratingVoiceover => 'Generating voiceover…';

  @override
  String shortVideoBatchVoiceoverJobEnqueued(int id) {
    return 'Shot #$id voiceover job enqueued.';
  }

  @override
  String get shortVideoBatchVoiceoverCouldNotCreateTask =>
      'Voiceover generation failed: could not create task.';

  @override
  String shortVideoBatchVoiceoverSingleFailedStatus(
    String code,
    String message,
  ) {
    return 'Voiceover generation failed: $code — $message';
  }

  @override
  String shortVideoBatchVoiceoverSingleFailedError(String error) {
    return 'Voiceover generation failed: $error';
  }

  @override
  String get shortVideoRustApiUnknownError => 'unknown error';

  @override
  String get shortVideoCandidateAssetConfirmationTitle =>
      'Candidate asset confirmation';

  @override
  String get shortVideoCandidateMetricPending => 'Pending';

  @override
  String get shortVideoCandidateMetricLinked => 'Linked';

  @override
  String get shortVideoCandidateMetricIgnored => 'Ignored';

  @override
  String get shortVideoCandidateMetricUnset => 'Unset';

  @override
  String get shortVideoCandidateBatchGenerateSubmitting =>
      'Submitting candidate clip batch jobs…';

  @override
  String get shortVideoCandidateBatchGenerateLabel =>
      'Batch-generate candidate clips (project defaults)';

  @override
  String get shortVideoCandidateOpenProjectsForAssets =>
      'Open projects to manage assets';

  @override
  String get shortVideoCandidateCompareSectionTitle => 'Candidate compare';

  @override
  String get projectEditorAssetFilterDialogTitle => 'Advanced asset filter';

  @override
  String get projectEditorAssetFilterByScript => 'Filter by script';

  @override
  String get projectEditorAssetFilterAllScripts => '(All scripts)';

  @override
  String get projectEditorAssetFilterAssetTypeOptional =>
      'Asset type (optional)';

  @override
  String get projectEditorAssetFilterAssetTypeHint => 'role / clip / props';

  @override
  String get projectEditorAssetFilterNameContainsOptional =>
      'Name contains (optional)';

  @override
  String get projectEditorAssetFilterPage => 'page';

  @override
  String get projectEditorAssetFilterLimit => 'limit';

  @override
  String get projectEditorAssetFilterApply => 'Apply filter';

  @override
  String get projectEditorAssetFilterSnackbarPageLimitPositive =>
      'page and limit must be positive integers';

  @override
  String projectEditorAssetFilterSnackbarApplied(int shown, int total) {
    return 'Filter applied: $shown/$total rows';
  }

  @override
  String get projectEditorAssetCrudCreateTitle => 'Create asset';

  @override
  String get projectEditorAssetCrudEditTitle => 'Edit asset';

  @override
  String get projectEditorAssetCrudFieldNameLabel => 'Asset name';

  @override
  String get projectEditorAssetCrudFieldTypeLabel => 'Asset type';

  @override
  String get projectEditorAssetCrudFieldTypeHelperCreate =>
      'Examples: role / clip / props';

  @override
  String get projectEditorAssetCrudFieldDescriptionLabel =>
      'Description (optional)';

  @override
  String get projectEditorAssetCrudEditTargetLabel => 'Target asset';

  @override
  String get projectEditorAssetCrudCancel => 'Cancel';

  @override
  String get projectEditorAssetCrudCreate => 'Create';

  @override
  String get projectEditorAssetCrudSave => 'Save';

  @override
  String get projectEditorAssetCrudCreateNameTypeRequiredSnack =>
      'Name and type cannot be empty.';

  @override
  String get projectEditorAssetCrudCreateSuccessSnack => 'Asset created.';

  @override
  String get projectEditorAssetCrudEditNoneSnack =>
      'No assets available to edit.';

  @override
  String get projectEditorAssetCrudEditEmptyPatchSnack =>
      'Change at least one field before saving.';

  @override
  String projectEditorAssetCrudEditSuccessSnack(int id) {
    return 'Updated asset #$id';
  }

  @override
  String get projectEditorBasicsStylePackPickerNone => 'None selected';

  @override
  String projectEditorBasicsStylePackPickerCurrentConfigRow(String path) {
    return '$path · Current configuration';
  }

  @override
  String get projectEditorBasicsStylePackFootnoteNone => 'None selected';

  @override
  String get projectEditorBasicsStylePackFootnoteLegacy =>
      'This project uses a legacy pack path or a pack not listed in the catalog.';

  @override
  String get projectEditorBasicsHomeSectionTitle => 'Project home';

  @override
  String projectEditorBasicsHomeReadinessLine(int score, String summary) {
    return 'Readiness $score/100 · $summary';
  }

  @override
  String projectEditorBasicsHomeNextStep(String step) {
    return 'Next step: $step';
  }

  @override
  String get projectEditorBasicsFieldNameClearLabel => 'Name (empty = clear)';

  @override
  String get projectEditorBasicsFieldIntroClearLabel => 'Intro (empty = clear)';

  @override
  String get projectEditorBasicsFieldPremise => 'Premise';

  @override
  String get projectEditorBasicsFieldTargetAudience => 'Target audience';

  @override
  String get projectEditorBasicsFieldEmotionalTone => 'Emotional tone';

  @override
  String get projectEditorBasicsFieldCoreHook => 'Core hook';

  @override
  String get projectEditorBasicsFieldVisualDirection => 'Visual direction';

  @override
  String get projectEditorBasicsFieldBrandName => 'Brand name';

  @override
  String get projectEditorBasicsFieldBrandPromise => 'Brand promise';

  @override
  String get projectEditorBasicsFieldVisualMotifsOnePerLine =>
      'Visual motifs (one per line)';

  @override
  String get projectEditorBasicsFieldForbiddenOnePerLine =>
      'Forbidden elements (one per line)';

  @override
  String get projectEditorBasicsFieldContinuityRulesOnePerLine =>
      'Continuity rules (one per line)';

  @override
  String get projectEditorBasicsPitchSectionTitle => 'Project pitch';

  @override
  String get projectEditorBasicsBrandSectionTitle => 'Brand bible';

  @override
  String get projectEditorBasicsLabelArtStylePack => 'Art style pack';

  @override
  String get projectEditorBasicsLabelStoryStylePack => 'Story style pack';

  @override
  String get projectEditorBasicsCompatTitle => 'Compatibility checks';

  @override
  String get projectEditorBasicsCompatSubtitle =>
      'Legacy general / project / tasks API regression entry points; collapsed by default.';

  @override
  String projectEditorBasicsStatsLine(
    int scriptCount,
    int storyboardCount,
    int novelCount,
    int roleCount,
    int videoCount,
  ) {
    return 'GET …/stats: scripts $scriptCount · storyboards $storyboardCount · novels $novelCount · roles/videos $roleCount/$videoCount';
  }

  @override
  String get projectEditorBasicsStatsNotLoaded => 'GET …/stats not loaded yet';

  @override
  String get projectEditorAuditTitle => 'Project activity';

  @override
  String get projectEditorAuditSubtitle =>
      'Project configuration and ACL changes — see who changed this project.';

  @override
  String get projectEditorAuditActionFilterLabel => 'Action filter';

  @override
  String get projectEditorAuditActionAll => 'All';

  @override
  String get projectEditorAuditActionProjectUpdated => 'Project updated';

  @override
  String get projectEditorAuditActionMemberAdded => 'Member added (ACL)';

  @override
  String get projectEditorAuditActionMemberRoleChanged => 'Member role changed';

  @override
  String get projectEditorAuditActionMemberRemoved => 'Member removed (ACL)';

  @override
  String get projectEditorAuditActionProjectCreated => 'Project created';

  @override
  String get projectEditorAuditActionProjectDeleted => 'Project deleted';

  @override
  String get projectEditorAuditSearchLabel =>
      'Search actor / target / fields / project name';

  @override
  String get projectEditorAuditEmpty => 'No project activity to display.';

  @override
  String get projectEditorAuditLoadMore => 'Load more';

  @override
  String get projectEditorAuditRefresh => 'Refresh';

  @override
  String get projectEditorShortDramaTargetsSectionTitle =>
      'Short-video targets';

  @override
  String get projectEditorShortDramaTargetsSectionBody =>
      'PATCH the same project-level fields as Short Video Space; adjust here from the project dialog.\nFrom home, use the short-drama production chain shortcut to jump to script / production / tasks / jobs / quality / short video.';

  @override
  String get projectEditorShortDramaTargetsFlavorLabel => 'Short-drama format';

  @override
  String get projectEditorShortDramaTargetsFlavorAnimated =>
      'Animated short drama';

  @override
  String get projectEditorShortDramaTargetsFlavorLiveAction =>
      'Live-action short drama';

  @override
  String get projectEditorShortDramaTargetsAspectLabel => 'Aspect ratio';

  @override
  String get projectEditorShortDramaTargetsRatioPortrait916 => 'Portrait 9:16';

  @override
  String get projectEditorShortDramaTargetsRatioLandscape169 =>
      'Landscape 16:9';

  @override
  String get projectEditorShortDramaTargetsRatioSquare11 => 'Square 1:1';

  @override
  String get projectEditorShortDramaTargetsSaveBusy => 'Saving…';

  @override
  String get projectEditorShortDramaTargetsSaveButton =>
      'Save short-drama settings';

  @override
  String projectEditorShortDramaTargetsSaveSuccess(
    String flavor,
    String ratio,
  ) {
    return 'Saved short-drama settings: $flavor · $ratio';
  }

  @override
  String projectEditorShortDramaTargetsSaveFailedHttp(String code) {
    return 'Save failed: HTTP $code';
  }

  @override
  String projectEditorShortDramaTargetsSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get projectEditorAssetEditImageNeedScriptSnack =>
      'Create a script before uploading an edit image.';

  @override
  String get projectEditorAssetEditImageDialogTitle => 'Upload edit image';

  @override
  String get projectEditorAssetEditImageTargetScriptLabel => 'Target script';

  @override
  String get projectEditorAssetEditImageDataUriLabel => 'Image data URI';

  @override
  String get projectEditorAssetEditImageDataUriHelper =>
      'Supports base64 data URIs for jpeg/jpg/png.';

  @override
  String get projectEditorAssetEditImageUploadButton => 'Upload';

  @override
  String get projectEditorAssetEditImageEmptyDataUriSnack =>
      'Base64 data URI cannot be empty.';

  @override
  String projectEditorAssetEditImageUploadSuccess(String url) {
    return 'Upload succeeded: $url';
  }

  @override
  String get projectEditorAssetLinkNeedScriptAndAssetSnack =>
      'Prepare at least one script and one asset first.';

  @override
  String get projectEditorAssetLinkDialogTitleLink => 'Link script and asset';

  @override
  String get projectEditorAssetLinkDialogTitleUnlink =>
      'Unlink script and asset';

  @override
  String get projectEditorAssetLinkScriptLabel => 'Script';

  @override
  String get projectEditorAssetLinkAssetLabel => 'Asset';

  @override
  String get projectEditorAssetLinkConfirmLink => 'Confirm link';

  @override
  String get projectEditorAssetLinkConfirmUnlink => 'Unlink';

  @override
  String projectEditorAssetLinkSuccessLinked(int scriptId, int assetId) {
    return 'Linked script #$scriptId · asset #$assetId';
  }

  @override
  String projectEditorAssetLinkSuccessUnlinked(int scriptId, int assetId) {
    return 'Unlinked script #$scriptId · asset #$assetId';
  }

  @override
  String get projectEditorAssetGenWorkbenchNeedAssetsSnack =>
      'Load the asset list before opening the image generation workbench.';

  @override
  String get projectEditorAssetGenWorkbenchNeedScriptSnack =>
      'Create a script before starting asset image generation.';

  @override
  String get projectEditorAssetGenWorkbenchSyncSummaryBusy => 'Syncing…';

  @override
  String get projectEditorAssetGenWorkbenchSyncSummary =>
      'Sync workbench summary';

  @override
  String get projectEditorAssetGenWorkbenchLoadMaterialContext =>
      'Load material context';

  @override
  String get projectEditorAssetGenWorkbenchLoadBatchCandidates =>
      'Load batch candidates';

  @override
  String get projectEditorAssetGenWorkbenchSelectAllVisible =>
      'Select all visible assets';

  @override
  String get projectEditorAssetGenWorkbenchRebuildSelectionByType =>
      'Rebuild selection by type';

  @override
  String get projectEditorAssetGenWorkbenchClearSelection => 'Clear selection';

  @override
  String get projectEditorAssetGenWorkbenchMutationBusy => 'Working…';

  @override
  String get projectEditorAssetGenWorkbenchBatchGenerate =>
      'Batch-generate images';

  @override
  String get projectEditorAssetGenWorkbenchPollImageStatuses =>
      'Poll image statuses';

  @override
  String get projectEditorAssetGenWorkbenchPollPromptStatuses =>
      'Poll prompt statuses';

  @override
  String get projectEditorAssetGenWorkbenchDeleteDerivatives =>
      'Clear derivative images';

  @override
  String get projectEditorAssetGenWorkbenchUpdateCoverUrl => 'Update cover URL';

  @override
  String get projectEditorAssetGenWorkbenchScriptLabel =>
      'Script for generation';

  @override
  String get projectEditorAssetGenWorkbenchScriptHelper =>
      'Batch generation sends selected assets to this script context.';

  @override
  String get projectEditorAssetGenWorkbenchAssetTypeLabel =>
      'Asset type filter';

  @override
  String get projectEditorAssetGenWorkbenchAssetTypeHelper =>
      'Affects both production summary reads and the visible selection set.';

  @override
  String get projectEditorAssetGenWorkbenchAssetTypeAll => 'All types';

  @override
  String get projectEditorAssetGenWorkbenchModelOptionalLabel =>
      'Model (optional)';

  @override
  String get projectEditorAssetGenWorkbenchResolutionOptionalLabel =>
      'Resolution (optional)';

  @override
  String get projectEditorAssetGenWorkbenchBatchNameFilterOptionalLabel =>
      'Batch candidate name filter (optional)';

  @override
  String get projectEditorAssetGenWorkbenchBatchLimitLabel => 'Candidate limit';

  @override
  String get projectEditorAssetGenWorkbenchCoverUrlLabel =>
      'Cover URL update (single selection)';

  @override
  String get projectEditorAssetGenWorkbenchCoverUrlHelper =>
      'Used with production/assets/update-assets-url';

  @override
  String get projectEditorAssetGenWorkbenchSelectionScopeGlobal =>
      'Operating on all project assets. Switch to \"filter by script\" in the main view before opening the workbench if you need script scope.';

  @override
  String projectEditorAssetGenWorkbenchSelectionScopeFiltered(int scriptId) {
    return 'Main view is filtered by script #$scriptId; the workbench uses this visible set by default.';
  }

  @override
  String get projectEditorAssetGenWorkbenchAssetNoDescription =>
      'No description';

  @override
  String get projectEditorAssetDeleteDialogNoAssetsSnack =>
      'No assets available to delete.';

  @override
  String get projectEditorAssetDeleteDialogTitle => 'Delete asset';

  @override
  String get projectEditorAssetDeleteDialogTargetLabel => 'Target asset';

  @override
  String get projectEditorAssetDeleteDialogCancel => 'Cancel';

  @override
  String get projectEditorAssetDeleteDialogConfirm => 'Delete';

  @override
  String projectEditorAssetDeleteSuccessSnack(int id) {
    return 'Deleted asset #$id';
  }

  @override
  String get projectEditorAssetClipUploadDialogTitle => 'Upload clip asset';

  @override
  String get projectEditorAssetClipUploadNameLabel => 'Asset name';

  @override
  String get projectEditorAssetClipUploadNameHelper =>
      'Use a traceable business name.';

  @override
  String get projectEditorAssetClipUploadTypeLabel => 'Asset type';

  @override
  String get projectEditorAssetClipUploadTypeHelper =>
      'Defaults to clip; backend currently accepts clip only.';

  @override
  String get projectEditorAssetClipUploadImageDataLabel =>
      'Image data URI / base64';

  @override
  String get projectEditorAssetClipUploadImageDataHelper =>
      'Supports data URIs or raw base64 (validated by backend).';

  @override
  String get projectEditorAssetClipUploadCancel => 'Cancel';

  @override
  String get projectEditorAssetClipUploadUpload => 'Upload';

  @override
  String get projectEditorAssetClipUploadFieldsRequiredSnack =>
      'Name, type, and image data cannot be empty.';

  @override
  String projectEditorAssetClipUploadSuccessSnack(String message) {
    return 'Upload succeeded: $message';
  }

  @override
  String get projectEditorAssetsProbeCreateTestAssetButton =>
      'Create test asset';

  @override
  String get projectEditorAssetsProbeCreateTestAssetSnack =>
      'Probe test asset created.';

  @override
  String get projectEditorAssetsProbeFetchFirstAssetButton =>
      'Fetch first asset';

  @override
  String projectEditorAssetsProbeFetchFirstAssetSnack(
    int id,
    String name,
    String assetType,
  ) {
    return 'Fetched asset #$id: $name ($assetType)';
  }

  @override
  String get projectEditorAssetsProbePatchFirstNameButton =>
      'PATCH first asset name';

  @override
  String get projectEditorAssetsProbePatchFirstNameSnack =>
      'Patched first asset name.';

  @override
  String get projectEditorAssetsProbeDeleteLastAssetButton =>
      'Delete last asset';

  @override
  String get projectEditorAssetsProbeLinkFirstPairButton =>
      'Link first script & first asset';

  @override
  String get projectEditorAssetsProbeUnlinkFirstPairButton =>
      'Unlink first script–asset pair';

  @override
  String get projectEditorAssetsCompatibilityPanelTitle => 'Asset probe';

  @override
  String get projectEditorAssetsCompatibilityPanelSubtitle =>
      'For asset polling, history images, and workbench-style checks; collapsed by default.';

  @override
  String get projectEditorAssetsCompatibilityImagesSectionLabel =>
      'Asset images / workbench-style polling checks';

  @override
  String get projectEditorAssetsProbeImagesCornerScapeButton =>
      'POST corner-scape';

  @override
  String get projectEditorAssetsProbeImagesCornerScapeSnackZero =>
      'POST …/assets/corner-scape: 0 rows';

  @override
  String projectEditorAssetsProbeImagesCornerScapeSnack(
    int count,
    int history,
    String previewSuffix,
  ) {
    return 'POST …/assets/corner-scape: $count rows, first asset history_images=$history$previewSuffix';
  }

  @override
  String get projectEditorAssetsProbeImagesCornerScapePreviewSuffix =>
      ' (preview)';

  @override
  String get projectEditorAssetsProbeImagesPostFirstButton =>
      'POST first asset image';

  @override
  String projectEditorAssetsProbeImagesPostFirstSnack(
    int assetId,
    String imageIdPrefix,
  ) {
    return 'POST …/assets/$assetId/images: $imageIdPrefix…';
  }

  @override
  String get projectEditorAssetsProbeImagesGetOneButton =>
      'GET asset image (single)';

  @override
  String get projectEditorAssetsProbeImagesGetEmptySnack =>
      'GET …/images: 0 items. Create an image with \"POST first asset image\" first.';

  @override
  String projectEditorAssetsProbeImagesGetOneSnack(
    String idShort,
    int sortIndex,
    String state,
    String filePart,
  ) {
    return 'GET …/images/$idShort: sort=$sortIndex state=$state$filePart';
  }

  @override
  String get projectEditorAssetsProbeImagesPatchDelButton =>
      'POST→PATCH→DEL image';

  @override
  String projectEditorAssetsProbeImagesPatchDelSnack(
    int sortBefore,
    int sortAfter,
    String state,
  ) {
    return 'POST→PATCH→DEL image: sort $sortBefore→$sortAfter, state=$state, deleted';
  }

  @override
  String get projectEditorAssetsCornerScapeLoadingAll =>
      'Loading corner-scape assets (all types)…';

  @override
  String projectEditorAssetsCornerScapeLoadingTypes(String types) {
    return 'Loading corner-scape assets (types: $types)…';
  }

  @override
  String projectEditorAssetsCornerScapeLoadFailed(String error) {
    return 'Failed to load corner-scape assets: $error';
  }

  @override
  String projectEditorAssetsWorkbenchFocusAssetSummary(
    int id,
    String name,
    String type,
  ) {
    return 'Focused asset: #$id $name · $type';
  }

  @override
  String get projectEditorAssetsWorkbenchFocusAssetEmptyOption => '(No assets)';

  @override
  String get projectEditorAssetsWorkbenchFocusAssetLabel => 'Focused asset';

  @override
  String get projectEditorAssetsWorkbenchFocusAssetHelper =>
      'Quick view of the current focus; edit in the actions below.';

  @override
  String get projectEditorAssetsWorkbenchFocusScriptEmptyOption =>
      '(No scripts)';

  @override
  String get projectEditorAssetsWorkbenchFocusScriptLabel => 'Focused script';

  @override
  String get projectEditorAssetsWorkbenchFocusScriptHelper =>
      'Used for script–asset linking actions.';

  @override
  String get projectEditorAssetsProbeWbGetImageButton => 'POST get-image';

  @override
  String get projectEditorAssetsProbeWbUploadClipButton => 'POST upload-clip';

  @override
  String get projectEditorAssetsProbeWbMaterialDataButton =>
      'POST get-material-data';

  @override
  String get projectEditorAssetsProbeWbBatchGenDataButton =>
      'POST batch-generation-data';

  @override
  String get projectEditorAssetsProbeWbGetAssetsApiButton =>
      'POST get-assets-api';

  @override
  String get projectEditorAssetsProbeWbPollingImageButton =>
      'POST polling-image-assets';

  @override
  String get projectEditorAssetsProbeWbPollingPromptButton =>
      'POST polling-prompt-assets';

  @override
  String projectEditorAssetsProbeWbGetImageSnack(
    int tempAssets,
    String imageId,
  ) {
    return 'POST …/workbench/image-bundle: tempAssets=$tempAssets imageId=$imageId';
  }

  @override
  String projectEditorAssetsProbeWbUploadClipSnack(String message) {
    return 'POST …/workbench/upload-clip: $message';
  }

  @override
  String projectEditorAssetsProbeWbMaterialDataSnack(
    int clips,
    int videos,
    String suffix,
  ) {
    return 'POST …/workbench/material-data: clips=$clips videos=$videos$suffix';
  }

  @override
  String projectEditorAssetsProbeWbMaterialDataFirstClipSuffix(String name) {
    return ' first=$name';
  }

  @override
  String projectEditorAssetsProbeWbBatchGenSnack(
    int rows,
    int total,
    String suffix,
  ) {
    return 'POST …/workbench/batch-generation-data: rows=$rows/$total$suffix';
  }

  @override
  String projectEditorAssetsProbeWbBatchGenFirstSuffix(
    String name,
    String assetType,
  ) {
    return ' first=$name($assetType)';
  }

  @override
  String projectEditorAssetsProbeWbNestedSnack(
    int parents,
    int total,
    String suffix,
  ) {
    return 'POST …/workbench/nested: parents=$parents/$total$suffix';
  }

  @override
  String projectEditorAssetsProbeWbNestedFirstSuffix(int count) {
    return ' firstChildren=$count';
  }

  @override
  String get projectEditorAssetsProbeWbPollingImageZeroSnack =>
      'POST …/workbench/polling-image-assets: 0 rows';

  @override
  String projectEditorAssetsProbeWbPollingImageRowSnack(
    String state,
    String filePath,
  ) {
    return 'POST …/workbench/polling-image-assets: state=$state filePath=$filePath';
  }

  @override
  String get projectEditorAssetsProbeWbPollingPromptZeroSnack =>
      'POST …/workbench/polling-prompt-assets: 0 rows';

  @override
  String projectEditorAssetsProbeWbPollingPromptRowSnack(
    String promptState,
    String assetType,
  ) {
    return 'POST …/workbench/polling-prompt-assets: promptState=$promptState type=$assetType';
  }

  @override
  String get projectEditorAssetsProbeQueryPageButton =>
      'GET paged assets (page=1, limit=2)';

  @override
  String get projectEditorAssetsProbeQueryFilterButton =>
      'GET assets (type+name filter)';

  @override
  String get projectEditorAssetsProbeQueryScriptScopedButton =>
      'GET assets (current script + paging)';

  @override
  String projectEditorAssetsProbeQueryPageSnack(
    int total,
    int pageCount,
    String idPart,
  ) {
    return 'GET …/assets?page=1&limit=2: total=$total, this page $pageCount$idPart';
  }

  @override
  String projectEditorAssetsProbeQueryFilterSnack(
    int total,
    int returned,
    String idPart,
  ) {
    return 'GET …/assets?asset_type=role&name=probe: total=$total, returned $returned$idPart';
  }

  @override
  String projectEditorAssetsProbeQueryScriptSnack(
    int scriptId,
    int total,
    int pageCount,
    String idPart,
  ) {
    return 'GET …/assets?script_numeric_id=$scriptId&page=1&limit=2: total=$total, this page $pageCount$idPart';
  }

  @override
  String get projectEditorDeleteProjectTitle => 'Delete project?';

  @override
  String projectEditorDeleteProjectBody(int id) {
    return 'Deletes project #$id, related scripts/storyboards (DB cascade), and clears agent memory for this project.';
  }

  @override
  String get projectEditorDeleteProjectSnackbar => 'Project deleted';

  @override
  String get projectEditorDeleteProjectButton => 'DELETE';

  @override
  String get projectEditorSavePatch => 'Save (PATCH)';

  @override
  String get projectEditorSavingEllipsis => 'Saving…';

  @override
  String get projectEditorPublishSectionTitle => 'Publish';

  @override
  String get projectEditorPublishSectionBody =>
      'Drafts, scheduling, jobs, and audit live under Short Video Space → Publish.';

  @override
  String get projectEditorPublishOpenWorkspace => 'Open publish workspace';

  @override
  String projectEditorPublishOverviewSnackbar(int drafts, int jobs) {
    return 'Publish overview: drafts=$drafts jobs=$jobs';
  }

  @override
  String get projectEditorPublishViewOverview => 'View publish overview';

  @override
  String projectEditorPublishOverviewFailed(String error) {
    return 'Failed to load publish overview: $error';
  }

  @override
  String get projectEditorStoryboardImageWorkbenchTitle => 'Image workbench';

  @override
  String get projectEditorStoryboardImageUrlLabel =>
      'Current image URL / data URI';

  @override
  String get projectEditorStoryboardImageUrlHelper =>
      'HTTP URL or data:image/...;base64.';

  @override
  String get projectEditorStoryboardImageLoadPreview => 'Load current preview';

  @override
  String get projectEditorStoryboardImageWorking => 'Working…';

  @override
  String get projectEditorStoryboardImageSaveUrl => 'Save image URL';

  @override
  String get projectEditorStoryboardImageClearFrame => 'Clear frame';

  @override
  String get projectEditorStoryboardImageRefreshProduction =>
      'Refresh production data';

  @override
  String get projectEditorStoryboardImageRefreshing => 'Refreshing…';

  @override
  String get projectEditorNovelsEventsWorkbenchEmptyDetail =>
      'Manage events via explicit forms (search/create/update/delete/bulk) instead of relying on HTTP probe buttons.';

  @override
  String projectEditorNovelsEventsWorkbenchSummaryFirst(
    String summaryLine,
    int id,
    String name,
  ) {
    return '$summaryLine; first #$id $name.';
  }

  @override
  String get projectEditorNovelsEventsOpenWorkbench => 'Open events workbench';

  @override
  String get projectEditorNovelsEventsRefresh => 'Refresh events';

  @override
  String get projectEditorNovelsEventsRefreshing => 'Refreshing events…';

  @override
  String get projectEditorAssetsMainWorkbenchTitle => 'Asset main workbench';

  @override
  String get projectEditorAssetsOverviewCardIntro =>
      'Consolidates asset CRUD, script linking, filtering, and uploads into one primary entry so the main area no longer stacks a row of fragmented buttons.';

  @override
  String get projectEditorAssetsMainWorkbenchDialogIntro =>
      'Consolidates asset CRUD, script linking, filtering, and upload entry points into one formal workbench so the main area no longer stacks a row of console-style buttons.';

  @override
  String get projectEditorAssetsOverviewFilteringByScript =>
      'Filtering assets by script…';

  @override
  String get projectEditorAssetsOverviewScriptAssetsNotLoaded =>
      'This script\'s scoped assets are not loaded yet.';

  @override
  String get projectEditorAssetsOverviewFilterHint =>
      'Filter asset list by script';

  @override
  String get projectEditorAssetsOverviewFilterOptionAll =>
      'All (no script filter)';

  @override
  String get projectEditorAssetsOverviewRefreshBusy => 'Refreshing assets…';

  @override
  String get projectEditorAssetsOverviewRefresh => 'Refresh assets';

  @override
  String get projectEditorAssetsOverviewOpenMainWorkbench =>
      'Open asset main workbench';

  @override
  String get projectEditorAssetsSpecializedWorkbenchesTitle =>
      'Specialized workbenches';

  @override
  String get projectEditorAssetsSpecializedWorkbenchesSubtitle =>
      'Image management, image generation, and history queries are linked here too; the asset main area keeps a single formal entry.';

  @override
  String get projectEditorAssetsMainWorkbenchRefreshBusy => 'Working…';

  @override
  String get projectEditorAssetsMainWorkbenchRefresh => 'Refresh workbench';

  @override
  String get projectEditorAssetsMainWorkbenchClose => 'Close';

  @override
  String get projectEditorAssetsWorkbenchNewAsset => 'New asset';

  @override
  String get projectEditorAssetsWorkbenchEditAsset => 'Edit asset';

  @override
  String get projectEditorAssetsWorkbenchDeleteAsset => 'Delete asset';

  @override
  String get projectEditorAssetsWorkbenchFilterAssets => 'Filter assets';

  @override
  String get projectEditorAssetsWorkbenchLinkScript => 'Link script & assets';

  @override
  String get projectEditorAssetsWorkbenchUnlink => 'Unlink';

  @override
  String get projectEditorAssetsWorkbenchUploadEditImage => 'Upload edit image';

  @override
  String get projectEditorAssetsWorkbenchUploadClipAsset => 'Upload clip asset';

  @override
  String get projectEditorAssetImagesWorkbenchDialogTitle =>
      'Asset images workbench';

  @override
  String get projectEditorAssetImagesFieldTargetAsset => 'Target asset';

  @override
  String get projectEditorAssetImagesNewFilePathOptional =>
      'New file_path (optional)';

  @override
  String get projectEditorAssetImagesNewStateOptional => 'New state (optional)';

  @override
  String get projectEditorAssetImagesNewSortOptional =>
      'New sort_index (optional)';

  @override
  String get projectEditorAssetImagesAddImage => 'Add image';

  @override
  String get projectEditorAssetImagesEditFilePathMayClear =>
      'Edit file_path (may clear)';

  @override
  String get projectEditorAssetImagesEditStateMayClear =>
      'Edit state (may clear)';

  @override
  String get projectEditorAssetImagesEditSortOptional =>
      'Edit sort_index (optional)';

  @override
  String get projectEditorAssetImagesSaveCurrentImage => 'Save current image';

  @override
  String get projectEditorAssetImagesDeleteCurrentImage =>
      'Delete current image';

  @override
  String get projectEditorAssetImagesLoadImageList => 'Load image list';

  @override
  String get projectEditorAssetImagesLoadingEllipsis => 'Loading…';

  @override
  String get projectEditorAssetImagesPreviewImage => 'Preview image';

  @override
  String get projectEditorAssetImagesLoadingPreview => 'Loading preview…';

  @override
  String get projectEditorAssetImagesFieldImages => 'Images';

  @override
  String projectEditorAssetGenUseMaterialContext(int count) {
    return 'Use material context ($count rows)';
  }

  @override
  String projectEditorAssetGenUseBatchCandidates(int count) {
    return 'Use batch candidates ($count rows)';
  }

  @override
  String get projectEditorAssetGenBatchCandidatesNeedAssetType =>
      'Batch candidate read requires a valid asset type.';

  @override
  String get projectEditorAssetGenBatchCandidatesLimitPositive =>
      'Candidate limit must be greater than 0.';

  @override
  String projectEditorAssetGenLeadBatchGenerate(int total, int enqueuedCount) {
    return 'Created image tasks for $total assets; $enqueuedCount queued.';
  }

  @override
  String projectEditorAssetGenLeadDeleteDerivatives(
    int deleted,
    String assetIds,
  ) {
    return 'Deleted $deleted derivative image record(s); assets $assetIds.';
  }

  @override
  String projectEditorAssetGenLeadUpdateImageUrl(int assetId, String message) {
    return 'Updated asset #$assetId cover URL: $message';
  }

  @override
  String projectEditorAssetGenSyncSnapshotFailed(String error) {
    return 'Failed to sync workbench summary: $error';
  }

  @override
  String get projectEditorAssetGenSelectionLabelSelectAllVisible =>
      'Selected all visible assets';

  @override
  String get projectEditorAssetGenSelectionLabelRebuildAllTypes =>
      'Rebuilt selection for all types';

  @override
  String projectEditorAssetGenSelectionLabelRebuildForType(String assetType) {
    return 'Rebuilt selection for type $assetType';
  }

  @override
  String get projectEditorAssetGenSelectionLabelClear => 'Cleared selection';

  @override
  String projectEditorAssetGenSelectionLabelRebuildImageState(String state) {
    return 'Rebuilt selection by image state $state';
  }

  @override
  String get projectEditorAssetGenSelectionLabelRebuildMaterialContext =>
      'Rebuilt selection from material context';

  @override
  String get projectEditorAssetGenSelectionLabelRebuildBatchCandidates =>
      'Rebuilt selection from batch candidates';

  @override
  String projectEditorAssetGenSelectionLabelRebuildPromptState(String state) {
    return 'Rebuilt selection by prompt state $state';
  }

  @override
  String projectEditorAssetGenWorkbenchSelectionLineEmpty(String label) {
    return '$label: no selectable assets';
  }

  @override
  String projectEditorAssetGenWorkbenchSelectionLineCount(
    String label,
    int count,
  ) {
    return '$label: selected $count assets';
  }

  @override
  String projectEditorAssetGenWorkbenchScopedSelectionLineEmpty(String label) {
    return '$label: no matches among visible assets';
  }

  @override
  String get projectEditorAssetGenSwitchingTypeAll =>
      'Switching to all types; syncing workbench summary…';

  @override
  String projectEditorAssetGenSwitchingTypeNamed(String assetType) {
    return 'Switching to $assetType; syncing workbench summary…';
  }

  @override
  String projectEditorAssetGenSnapshotLoadingWithLead(String lead) {
    return '$lead; syncing workbench summary…';
  }

  @override
  String projectEditorAssetGenBatchCandidatesStatusWithType(
    String summary,
    String assetType,
  ) {
    return '$summary · type=$assetType';
  }

  @override
  String get projectEditorAssetSummaryWorkbenchPartsSeparator => '; ';

  @override
  String get projectEditorAssetImagesCreateAssetFirst =>
      'Create an asset before managing images';

  @override
  String get projectEditorAssetImagesDiagnosisNotLoadedSummary =>
      'Image list for this asset has not been loaded yet.';

  @override
  String get projectEditorAssetImagesDiagnosisNotLoadedDetail =>
      'Sync the image list first to see whether history images exist, then preview or add a new image.';

  @override
  String get projectEditorAssetImagesDiagnosisNoImagesSummary =>
      'This asset has no images yet.';

  @override
  String get projectEditorAssetImagesDiagnosisNoImagesDetail =>
      'Add an image to create the first editable history row for this asset.';

  @override
  String projectEditorAssetImagesDiagnosisPreviewPendingSummary(int count) {
    return 'Loaded $count image(s); preview not loaded yet.';
  }

  @override
  String get projectEditorAssetImagesDiagnosisPreviewPendingDetail =>
      'Load the current image preview and verify file_path and state before editing or deleting.';

  @override
  String get projectEditorAssetImagesDiagnosisReadySummary =>
      'Current image is ready to edit.';

  @override
  String projectEditorAssetImagesDiagnosisReadyDetail(int sortIndex) {
    return 'Focused image sort=$sortIndex; you can update file_path, state, or sort_index, then delete if needed.';
  }

  @override
  String get projectEditorAssetImagesUnknownState => 'unknown state';

  @override
  String get projectEditorAssetImagesSelectionNoImages =>
      'This asset has no images.';

  @override
  String get projectEditorAssetImagesSelectionCoverNone => 'No cover image';

  @override
  String projectEditorAssetImagesSelectionCoverNumeric(int id) {
    return 'Cover numeric image #$id';
  }

  @override
  String projectEditorAssetImagesSelectionFocusLine(int sort, String state) {
    return 'Focus sort=$sort · $state';
  }

  @override
  String projectEditorAssetImagesSelectionSummary(
    int count,
    String coverLine,
    String focusLine,
  ) {
    return 'Loaded $count image(s); $coverLine; $focusLine.';
  }

  @override
  String projectEditorAssetImagesFollowUp(
    String actionSummary,
    String nextAction,
    String detail,
  ) {
    return '$actionSummary Next step: $nextAction. $detail';
  }

  @override
  String projectEditorAssetImagesFailureNotice(
    String actionSummary,
    String nextAction,
    String reason,
    String fallbackDetail,
  ) {
    return '$actionSummary Next step: $nextAction. Reason: $reason. $fallbackDetail';
  }

  @override
  String get projectEditorAssetImagesNoErrorDetail =>
      'No additional error detail.';

  @override
  String get projectEditorAssetImagesRecommendedLoadList => 'Load image list';

  @override
  String get projectEditorAssetImagesRecommendedAddImage => 'Add image';

  @override
  String get projectEditorAssetImagesRecommendedLoadPreview =>
      'Load current preview';

  @override
  String get projectEditorAssetImagesRecommendedSaveImage =>
      'Save current image';

  @override
  String get projectEditorAssetImagesMutationCreateSuccess =>
      'Asset image created.';

  @override
  String get projectEditorAssetImagesMutationCreateFailure =>
      'Failed to create asset image.';

  @override
  String get projectEditorAssetImagesMutationCreateFallback =>
      'Check file_path, state, or sort_index and try again.';

  @override
  String get projectEditorAssetImagesMutationPatchSuccess =>
      'Current image updated.';

  @override
  String get projectEditorAssetImagesMutationPatchFailure =>
      'Failed to update current image.';

  @override
  String get projectEditorAssetImagesMutationPatchFallback =>
      'Reload preview, verify the selected image, then edit again.';

  @override
  String get projectEditorAssetImagesMutationDeleteSuccess =>
      'Current image deleted.';

  @override
  String get projectEditorAssetImagesMutationDeleteFailure =>
      'Failed to delete current image.';

  @override
  String get projectEditorAssetImagesMutationDeleteFallback =>
      'Refresh the image list, verify the selection, then delete again.';

  @override
  String get projectEditorAssetImagesPreviewLoadFailed =>
      'Failed to load current image preview.';

  @override
  String get projectEditorAssetImagesPreviewLoadFailedFallback =>
      'Verify file_path or switch to another image, then retry.';

  @override
  String get projectEditorAssetImagesListLoadFailed =>
      'Failed to load image list for current asset.';

  @override
  String get projectEditorAssetImagesListLoadFailedFallback =>
      'Retry syncing the image list and confirm this asset has images.';

  @override
  String get projectEditorAssetImagesNoPreviewCleared =>
      'No image available to preview; preview cleared.';

  @override
  String get projectEditorAssetImagesPreviewLoaded =>
      'Loaded current image preview.';

  @override
  String get projectEditorAssetImagesListSynced =>
      'Synced image list for current asset.';

  @override
  String get projectEditorAssetImagesCreateSortMustBePositive =>
      'sort_index for create must be a positive integer.';

  @override
  String get projectEditorAssetImagesPatchSortMustBePositive =>
      'sort_index for edit must be a positive integer.';

  @override
  String get projectEditorAssetImagesSelectImageToEdit =>
      'Select an image to edit first.';

  @override
  String get projectEditorAssetImagesSelectImageToDelete =>
      'Select an image to delete first.';

  @override
  String projectEditorAssetImagesSwitchingAsset(int id) {
    return 'Switching to asset #$id and loading images…';
  }

  @override
  String get projectEditorAssetImagesSwitchingImagePreview =>
      'Switching image and refreshing preview…';

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

  @override
  String get accountSectionTitle => 'Account section title';

  @override
  String get accountRiskyPrefsTooltip => 'Account risky prefs tooltip';

  @override
  String get accountSectionSubtitle => 'Account section subtitle';

  @override
  String get accountExportTitle => 'Account export title';

  @override
  String get accountExportCreate => 'Account export create';

  @override
  String get accountExportIncludeAuditLogs =>
      'Account export include audit logs';

  @override
  String get accountExportIncludeNotifications =>
      'Account export include notifications';

  @override
  String accountExportActiveCount(int count) {
    return '进行中 $count';
  }

  @override
  String get accountExportCopyLastSavedPath =>
      'Account export copy last saved path';

  @override
  String get accountExportEmpty => 'Account export empty';

  @override
  String accountExportDefaultFileName(int numericTaskId) {
    return '账户导出 #$numericTaskId';
  }

  @override
  String accountExportTaskLine(int numericTaskId, String createdAt) {
    return 'Task #$numericTaskId · $createdAt';
  }

  @override
  String accountExportSizeLine(String size) {
    return '大小 $size';
  }

  @override
  String accountExportSavedSnack(String path) {
    return '已保存到 $path';
  }

  @override
  String get accountExportDownload => 'Account export download';

  @override
  String get accountExportCopyFileName => 'Account export copy file name';

  @override
  String get accountDeleteTitle => 'Account delete title';

  @override
  String get accountDeleteDescription => 'Account delete description';

  @override
  String get accountDeleteConfirmLabel => 'Account delete confirm label';

  @override
  String get accountDeleteIrreversibleAck => 'Account delete irreversible ack';

  @override
  String accountDeleteLastResponse(
    int workspaceCount,
    int projectCount,
    int jobCount,
  ) {
    return 'Account deleted: $workspaceCount workspaces, $projectCount projects, $jobCount jobs';
  }

  @override
  String get accountDeleteButton => 'Account delete button';

  @override
  String get accountExportStatusQueued => 'Account export status queued';

  @override
  String get accountExportStatusRunning => 'Account export status running';

  @override
  String get accountExportStatusSucceeded => 'Account export status succeeded';

  @override
  String get accountExportStatusFailed => 'Account export status failed';

  @override
  String adminConsoleMembershipItem(
    String workspaceName,
    String workspaceType,
    String role,
    String archivedSuffix,
  ) {
    return '$workspaceName · $workspaceType · $role$archivedSuffix';
  }

  @override
  String adminConsoleRecentJobItem(
    String kind,
    String status,
    String projectId,
    String ownerEmail,
  ) {
    return '$kind · $status · project $projectId · $ownerEmail';
  }

  @override
  String adminConsoleAuditListItem(
    String createdAt,
    String actorLabel,
    String summary,
  ) {
    return '$createdAt · $actorLabel · $summary';
  }

  @override
  String get adminConsoleDailyQuotaLabel => 'Daily quota';

  @override
  String adminConsoleChipMember(int count) {
    return '成员 $count';
  }

  @override
  String get adminConsoleArchivedLabel => 'Admin console archived label';

  @override
  String adminConsoleMemberListItem(
    String email,
    String role,
    String joinedAt,
  ) {
    return '$email · $role · joined $joinedAt';
  }

  @override
  String adminConsoleRecentProjectItem(
    int numericId,
    String name,
    String detail,
  ) {
    return '#$numericId $name · $detail';
  }

  @override
  String adminConsoleChipScript(int count) {
    return '剧本 $count';
  }

  @override
  String adminConsoleChipAsset(int count) {
    return '资产 $count';
  }

  @override
  String adminConsoleChipJob(int count) {
    return '作业 $count';
  }

  @override
  String adminConsoleAclMemberItem(
    String email,
    String workspaceRole,
    String projectRole,
    String detail,
  ) {
    return '$email · workspace $workspaceRole · project $projectRole · $detail';
  }

  @override
  String adminConsoleWorkspaceCandidateItem(
    String email,
    String workspaceRole,
    String explicitProjectRole,
  ) {
    return '$email · $workspaceRole · explicit project role $explicitProjectRole';
  }

  @override
  String adminConsoleProjectRecentJobItem(
    String kind,
    String status,
    String ownerEmail,
    String createdAt,
  ) {
    return '$kind · $status · $ownerEmail · $createdAt';
  }

  @override
  String adminConsoleAuditUserSummary(String status, String quota) {
    return 'status=$status · quota=$quota';
  }

  @override
  String adminConsoleAuditWorkspaceMembership(
    String action,
    String userId,
    String role,
    String workspaceId,
    String detail,
  ) {
    return 'action=$action · user=$userId · role=$role · workspace=$workspaceId · detail=$detail';
  }

  @override
  String adminConsoleAuditOwnerTransfer(
    String previousOwner,
    String newOwner,
    String role,
    String reset,
  ) {
    return 'owner transfer: $previousOwner → $newOwner · role=$role · reset=$reset';
  }

  @override
  String adminConsoleAuditArchiveNote(String archivedAt, String note) {
    return 'archived $archivedAt · note $note';
  }

  @override
  String adminConsoleAuditProjectOwnerTransfer(
    String previousOwner,
    String newOwner,
    String projectId,
  ) {
    return 'project owner transfer: $previousOwner → $newOwner · $projectId';
  }

  @override
  String get adminConsoleFieldUserId => 'User ID';

  @override
  String get adminConsoleFieldCreatedAt => 'Admin console field created at';

  @override
  String get adminConsoleFieldUpdatedAt => 'Admin console field updated at';

  @override
  String get adminConsoleFieldOperationalStatus =>
      'Admin console field operational status';

  @override
  String get adminConsoleFieldBillingProvider =>
      'Admin console field billing provider';

  @override
  String get adminConsoleFieldSubscription =>
      'Admin console field subscription';

  @override
  String get adminConsoleFieldCurrentWorkspace =>
      'Admin console field current workspace';

  @override
  String get adminConsoleFieldWorkspaceId => 'Admin console field workspace id';

  @override
  String get adminConsoleFieldOwner => 'Admin console field owner';

  @override
  String get adminConsoleFieldArchivedAt => 'Admin console field archived at';

  @override
  String get adminConsoleFieldOpsNote => 'Admin console field ops note';

  @override
  String get adminConsoleFieldProjectId => 'Admin console field project id';

  @override
  String get adminConsoleFieldWorkspace => 'Admin console field workspace';

  @override
  String get adminConsoleFieldProjectArchivedAt =>
      'Admin console field project archived at';

  @override
  String get adminConsoleFieldAclMode => 'Admin console field acl mode';

  @override
  String get adminConsoleFieldEditorCount => 'Admin console field editor count';

  @override
  String get adminConsoleFieldViewerCount => 'Admin console field viewer count';

  @override
  String get agentWorkspaceProductionPromptLabel =>
      'Agent workspace production prompt label';

  @override
  String get agentWorkspaceProductionPromptHelper =>
      'Agent workspace production prompt helper';

  @override
  String get agentWorkspaceProductionRunWorkflow =>
      'Agent workspace production run workflow';

  @override
  String get agentWorkspaceProductionDomainToolLabel =>
      'Agent workspace production domain tool label';

  @override
  String get agentWorkspaceProductionFlowKeyLabel =>
      'Agent workspace production flow key label';

  @override
  String get agentWorkspaceProductionFlowKeyHelper =>
      'Agent workspace production flow key helper';

  @override
  String get agentWorkspaceProductionArgsLabel =>
      'Agent workspace production args label';

  @override
  String get agentWorkspaceProductionArgsHelper =>
      'Agent workspace production args helper';

  @override
  String get agentWorkspaceProductionReadTool =>
      'Agent workspace production read tool';

  @override
  String get agentWorkspaceProductionSubAgentToolLabel =>
      'Agent workspace production sub agent tool label';

  @override
  String get agentWorkspaceProductionSubAgentArgsLabel =>
      'Agent workspace production sub agent args label';

  @override
  String get agentWorkspaceProductionSubAgentArgsHelper =>
      'Agent workspace production sub agent args helper';

  @override
  String get agentWorkspaceProductionRunSubAgent =>
      'Agent workspace production run sub agent';

  @override
  String get agentWorkspaceProductionWritebackToolResult =>
      'Agent workspace production writeback tool result';

  @override
  String get agentWorkspaceProductionArgumentTemplates =>
      'Agent workspace production argument templates';

  @override
  String get agentWorkspaceProductionCurrentCandidateArgs =>
      'Agent workspace production current candidate args';

  @override
  String agentWorkspaceProductionCandidateIds(int count, String preview) {
    return 'candidates $count: $preview';
  }

  @override
  String get agentWorkspaceProductionPromptPreviewTitle =>
      'Agent workspace production prompt preview title';

  @override
  String get agentWorkspaceProductionStagesTitle =>
      'Agent workspace production stages title';

  @override
  String agentWorkspaceProductionFlowChip(String flowKey) {
    return 'flow=$flowKey';
  }

  @override
  String get agentWorkspaceProductionApplyStage =>
      'Agent workspace production apply stage';

  @override
  String get agentWorkspaceProductionDiagnosisTitle =>
      'Agent workspace production diagnosis title';

  @override
  String agentWorkspaceProductionToolChip(String tool) {
    return 'tool=$tool';
  }

  @override
  String agentWorkspaceProductionAgentChip(String agent) {
    return 'agent=$agent';
  }

  @override
  String get agentWorkspaceProductionApplySuggestion =>
      'Agent workspace production apply suggestion';

  @override
  String get agentWorkspaceProductionStepPullAssetsFlow =>
      'Agent workspace production step pull assets flow';

  @override
  String get agentWorkspaceProductionStepRunAssetsSubAgent =>
      'Agent workspace production step run assets sub agent';

  @override
  String get agentWorkspaceProductionStepPullStoryboardFlow =>
      'Agent workspace production step pull storyboard flow';

  @override
  String get agentWorkspaceProductionStepWritebackFlow =>
      'Agent workspace production step writeback flow';

  @override
  String get agentWorkspaceProductionStepRunStoryboardSubAgent =>
      'Agent workspace production step run storyboard sub agent';

  @override
  String get agentWorkspaceProductionStepRunDirectorPlanSubAgent =>
      'Agent workspace production step run director plan sub agent';

  @override
  String get agentWorkspaceProductionPromptFlowDown =>
      'Agent workspace production prompt flow down';

  @override
  String agentWorkspaceProductionPromptRewriteFocus(String focus) {
    return '改写焦点：$focus';
  }

  @override
  String agentWorkspaceProductionPromptVisualPacing(String pacing) {
    return '视觉节奏：$pacing';
  }

  @override
  String agentWorkspaceProductionPromptExtraConstraint(String constraint) {
    return '额外约束：$constraint';
  }

  @override
  String agentWorkspaceProductionPromptAssetFocus(String scope) {
    return '资产焦点：$scope';
  }

  @override
  String get agentWorkspaceProductionPromptExecutionOrder =>
      'Agent workspace production prompt execution order';

  @override
  String get agentWorkspaceProductionStoryboardPriorityMissing =>
      'Priority: show missing frame shots';

  @override
  String agentWorkspaceProductionCollapsedRows(int count) {
    return '$count more rows collapsed';
  }

  @override
  String agentWorkspaceProductionReviewTarget(String target) {
    return '目标：$target';
  }

  @override
  String agentWorkspaceProductionReviewGrade(String grade) {
    return '等级：$grade';
  }

  @override
  String agentWorkspaceProductionReviewIssues(
    int severe,
    int medium,
    int minor,
  ) {
    return 'issues: severe $severe, medium $medium, minor $minor';
  }

  @override
  String agentWorkspaceProductionReviewNextStep(String nextAction) {
    return '下一步：$nextAction';
  }

  @override
  String agentWorkspaceProductionReviewAssetIds(String assetIds) {
    return '资产：$assetIds';
  }

  @override
  String agentWorkspaceProductionReviewAssetScope(String scope) {
    return '资产范围：$scope';
  }

  @override
  String agentWorkspaceProductionReviewStoryboardIds(String ids) {
    return '镜头：$ids';
  }

  @override
  String agentWorkspaceProductionReviewSummary(String summary) {
    return '结论：$summary';
  }

  @override
  String agentWorkspaceProductionShotLabel(int id) {
    return '镜头 $id';
  }

  @override
  String agentWorkspaceProductionSceneLabel(String scene) {
    return '场景 $scene';
  }

  @override
  String agentWorkspaceProductionDurationLabel(String duration) {
    return '时长 $duration';
  }

  @override
  String agentWorkspaceProductionAssetsLabel(String assets) {
    return '资产 $assets';
  }

  @override
  String agentWorkspaceProductionStateLabel(String state) {
    return '状态 $state';
  }

  @override
  String get agentWorkspaceProductionModeTextOnly =>
      'Agent workspace production mode text only';

  @override
  String get agentWorkspaceProductionResultHasImage =>
      'Agent workspace production result has image';

  @override
  String agentWorkspaceProductionResultMissingImage(String assets) {
    return '缺少图片 $assets';
  }

  @override
  String agentWorkspaceProductionContextFromTool(String toolName) {
    return '来自工具 $toolName';
  }

  @override
  String get agentWorkspaceProductionContextDerivedRewrite =>
      'Agent workspace production context derived rewrite';

  @override
  String get agentWorkspaceProductionContextDerivedRewriteSubtitle =>
      'Agent workspace production context derived rewrite subtitle';

  @override
  String get agentWorkspaceProductionContextReturnList =>
      'Agent workspace production context return list';

  @override
  String get agentWorkspaceProductionContextToolText =>
      'Agent workspace production context tool text';

  @override
  String get agentWorkspaceProductionContextReviewSummary =>
      'Agent workspace production context review summary';

  @override
  String get agentWorkspaceProductionContextSnapshotTitle =>
      'Agent workspace production context snapshot title';

  @override
  String agentWorkspaceSummaryReturnedList(int count) {
    return '返回列表 $count 项';
  }

  @override
  String agentWorkspaceSummaryReturnedText(int chars) {
    return '返回文本 $chars 字';
  }

  @override
  String agentWorkspaceProductionSummaryItems(int count) {
    return '返回 items $count 项';
  }

  @override
  String agentWorkspaceProductionSummaryReviewHeadline(
    String target,
    String grade,
  ) {
    return 'focused $target: grade $grade';
  }

  @override
  String agentWorkspaceProductionSummaryIssueBreakdown(
    int severe,
    int medium,
    int minor,
  ) {
    return 'issues: severe $severe, medium $medium, minor $minor';
  }

  @override
  String agentWorkspaceProductionSummaryFocusedAssets(int count) {
    return 'focused assets $count';
  }

  @override
  String agentWorkspaceProductionSummaryFocusedAssetScope(String scope) {
    return '聚焦资产范围 $scope';
  }

  @override
  String agentWorkspaceProductionSummaryFocusedShots(int count) {
    return '聚焦镜头 $count 项';
  }

  @override
  String agentWorkspaceSummaryReturnedObjectKeys(String keys) {
    return '返回对象 keys=$keys';
  }

  @override
  String get agentWorkspaceProductionSummaryFlowEmpty =>
      'Agent workspace production summary flow empty';

  @override
  String get agentWorkspaceProductionSummaryFlowEmptyString =>
      'Agent workspace production summary flow empty string';

  @override
  String agentWorkspaceProductionSummaryTextChars(int chars) {
    return 'text $chars chars';
  }

  @override
  String agentWorkspaceProductionSummaryLineCount(int count) {
    return 'line count $count';
  }

  @override
  String agentWorkspaceProductionSummaryPlanSections(int count) {
    return '计划章节 $count';
  }

  @override
  String get agentWorkspaceProductionSummaryRewriteInherited =>
      'Rewrite constraints inherited';

  @override
  String agentWorkspaceProductionSummaryStoryboardRows(int count) {
    return 'storyboard $count rows';
  }

  @override
  String agentWorkspaceProductionSummaryLinkedAssets(int count) {
    return 'linked assets $count';
  }

  @override
  String agentWorkspaceProductionSummaryListCount(int count) {
    return '列表 $count 项';
  }

  @override
  String agentWorkspaceProductionSummaryPrompts(int count) {
    return '提示词 $count';
  }

  @override
  String agentWorkspaceProductionSummaryMediaUrls(int count) {
    return '媒体 URL $count';
  }

  @override
  String agentWorkspaceProductionSummaryNeedImages(int count) {
    return '需要图片 $count';
  }

  @override
  String agentWorkspaceProductionSummaryMissingFrames(int count) {
    return 'missing frames $count';
  }

  @override
  String agentWorkspaceProductionSummaryTextOnlyCount(int count) {
    return '纯文本 $count';
  }

  @override
  String agentWorkspaceProductionSummaryStateTypes(int count) {
    return 'state types $count';
  }

  @override
  String agentWorkspaceProductionSummaryObjectKeyCount(int count) {
    return '对象 keys=$count 个';
  }

  @override
  String agentWorkspaceProductionSummaryObjectListEntry(String key, int count) {
    return '$key: $count items';
  }

  @override
  String agentWorkspaceProductionSummaryObjectTextEntry(String key, int chars) {
    return '$key: $chars chars';
  }

  @override
  String agentWorkspaceProductionSummaryReturnedType(String type) {
    return '返回 $type';
  }

  @override
  String get agentWorkspaceProductionIdleHint =>
      'Agent workspace production idle hint';

  @override
  String agentWorkspaceProductionLatestToolResult(String detail) {
    return 'Latest tool result: $detail';
  }

  @override
  String get agentWorkspaceProductionResultSummary =>
      'Agent workspace production result summary';

  @override
  String agentWorkspaceProductionSuggestedFlowKey(String flowKey) {
    return 'Suggested writeback key: $flowKey';
  }

  @override
  String get agentWorkspaceProductionUseSuggestedFlowKey =>
      'Agent workspace production use suggested flow key';

  @override
  String get agentWorkspaceProductionWritebackStrategy =>
      'Agent workspace production writeback strategy';

  @override
  String get agentWorkspaceScriptStepFetchPlanData =>
      'Agent workspace script step fetch plan data';

  @override
  String get agentWorkspaceScriptStepFetchContent =>
      'Agent workspace script step fetch content';

  @override
  String get agentWorkspaceScriptStepGenerateDraft =>
      'Agent workspace script step generate draft';

  @override
  String get agentWorkspaceScriptStepWriteback =>
      'Agent workspace script step writeback';

  @override
  String get agentWorkspaceScriptPromptLabel =>
      'Agent workspace script prompt label';

  @override
  String get agentWorkspaceScriptPromptHelper =>
      'Agent workspace script prompt helper';

  @override
  String get agentWorkspaceScriptRunWorkflow =>
      'Agent workspace script run workflow';

  @override
  String get agentWorkspaceScriptDomainToolLabel =>
      'Agent workspace script domain tool label';

  @override
  String get agentWorkspaceScriptReadContext =>
      'Agent workspace script read context';

  @override
  String get agentWorkspaceScriptArgsLabel =>
      'Agent workspace script args label';

  @override
  String get agentWorkspaceScriptArgsHelper =>
      'Agent workspace script args helper';

  @override
  String get agentWorkspaceScriptSubAgentToolLabel =>
      'Agent workspace script sub agent tool label';

  @override
  String get agentWorkspaceScriptRunSubAgent =>
      'Agent workspace script run sub agent';

  @override
  String get agentWorkspaceScriptWritebackPlanData =>
      'Agent workspace script writeback plan data';

  @override
  String get agentWorkspaceScriptWritebackUpdateData =>
      'Agent workspace script writeback update data';

  @override
  String get agentWorkspaceScriptStagesTitle =>
      'Agent workspace script stages title';

  @override
  String get agentWorkspaceScriptApplyStage =>
      'Agent workspace script apply stage';

  @override
  String get agentWorkspaceScriptAdvanceStage =>
      'Agent workspace script advance stage';

  @override
  String get agentWorkspaceScriptDiagnosisTitle =>
      'Agent workspace script diagnosis title';

  @override
  String agentWorkspaceScriptToolChip(String tool) {
    return 'tool=$tool';
  }

  @override
  String agentWorkspaceScriptAgentChip(String agent) {
    return 'agent=$agent';
  }

  @override
  String get agentWorkspaceScriptApplySuggestion =>
      'Agent workspace script apply suggestion';

  @override
  String agentWorkspaceScriptContextSkeletonFocus(String focus) {
    return '骨架焦点：$focus';
  }

  @override
  String agentWorkspaceScriptContextAdaptationFocus(String focus) {
    return '改编焦点：$focus';
  }

  @override
  String get agentWorkspaceScriptContextExecutionOrder =>
      'Agent workspace script context execution order';

  @override
  String get agentWorkspaceScriptContextDialogueConstraint =>
      'Agent workspace script context dialogue constraint';

  @override
  String get agentWorkspaceScriptContextStorySkeleton =>
      'Agent workspace script context story skeleton';

  @override
  String get agentWorkspaceScriptContextFromPlanData =>
      'Agent workspace script context from plan data';

  @override
  String get agentWorkspaceScriptContextAdaptationStrategy =>
      'Agent workspace script context adaptation strategy';

  @override
  String get agentWorkspaceScriptContextRewriteConstraints =>
      'Agent workspace script context rewrite constraints';

  @override
  String get agentWorkspaceScriptContextRewriteConstraintsSubtitle =>
      'Agent workspace script context rewrite constraints subtitle';

  @override
  String get agentWorkspaceScriptContextUntitledScript =>
      'Agent workspace script context untitled script';

  @override
  String get agentWorkspaceScriptContextNoBody =>
      'Agent workspace script context no body';

  @override
  String get agentWorkspaceScriptContextPlanDrafts =>
      'Agent workspace script context plan drafts';

  @override
  String get agentWorkspaceScriptContextPlanDraftsSubtitle =>
      'Agent workspace script context plan drafts subtitle';

  @override
  String get agentWorkspaceScriptContextCurrentScriptBody =>
      'Agent workspace script context current script body';

  @override
  String get agentWorkspaceScriptContextFromScriptContent =>
      'Agent workspace script context from script content';

  @override
  String get agentWorkspaceScriptContextUntitledChapter =>
      'Agent workspace script context untitled chapter';

  @override
  String agentWorkspaceScriptContextChapterPrefix(
    int chapterIndex,
    String chapter,
  ) {
    return 'Chapter $chapterIndex · $chapter';
  }

  @override
  String get agentWorkspaceScriptContextNovelChapters =>
      'Agent workspace script context novel chapters';

  @override
  String get agentWorkspaceScriptContextNovelChaptersSubtitle =>
      'Agent workspace script context novel chapters subtitle';

  @override
  String get agentWorkspaceScriptContextUntitledEvent =>
      'Agent workspace script context untitled event';

  @override
  String get agentWorkspaceScriptContextNovelEvents =>
      'Agent workspace script context novel events';

  @override
  String get agentWorkspaceScriptContextNovelEventsSubtitle =>
      'Agent workspace script context novel events subtitle';

  @override
  String get agentWorkspaceScriptContextSnapshotTitle =>
      'Agent workspace script context snapshot title';

  @override
  String get agentWorkspaceScriptLatestAssistantResult =>
      'Agent workspace script latest assistant result';

  @override
  String agentWorkspaceScriptWritebackSource(String source) {
    return 'Writeback source: $source';
  }

  @override
  String get agentWorkspaceScriptSummaryReviewReturned =>
      'Agent workspace script summary review returned';

  @override
  String agentWorkspaceScriptSummaryReviewLine(
    String target,
    String grade,
    int issueCount,
    String summary,
  ) {
    return 'review $target: grade $grade, $issueCount issues$summary';
  }

  @override
  String get agentWorkspaceScriptSummaryPlanDataMissing =>
      'Agent workspace script summary plan data missing';

  @override
  String get agentWorkspaceScriptSummaryStorySkeletonReady =>
      'Agent workspace script summary story skeleton ready';

  @override
  String get agentWorkspaceScriptSummaryAdaptationReady =>
      'Agent workspace script summary adaptation ready';

  @override
  String agentWorkspaceScriptSummaryPlanScripts(int count) {
    return 'plan scripts $count';
  }

  @override
  String get agentWorkspaceScriptSummaryRewriteReady =>
      'Agent workspace script summary rewrite ready';

  @override
  String get agentWorkspaceScriptSummaryPlanDataReturned =>
      'Agent workspace script summary plan data returned';

  @override
  String agentWorkspaceScriptSummaryScriptEmpty(int chars) {
    return '剧本正文 $chars 字';
  }

  @override
  String agentWorkspaceScriptSummaryScriptChars(int chars) {
    return 'script $chars chars';
  }

  @override
  String agentWorkspaceScriptSummaryNovelTextEmpty(int count) {
    return '章节材料 $count 条';
  }

  @override
  String agentWorkspaceScriptSummaryNovelTextCount(int count) {
    return 'novel text $count';
  }

  @override
  String agentWorkspaceScriptSummaryNovelEventsEmpty(int count) {
    return '小说事件 $count 条';
  }

  @override
  String agentWorkspaceScriptSummaryNovelEventsCount(int count) {
    return 'novel events $count';
  }

  @override
  String get agentWorkspaceScopeProjectIdLabel =>
      'Agent workspace scope project id label';

  @override
  String get agentWorkspaceScopeScriptIdLabel =>
      'Agent workspace scope script id label';

  @override
  String get agentWorkspaceScopeProjectUuidLabel =>
      'Agent workspace scope project uuid label';

  @override
  String get agentWorkspaceScopeScriptUuidLabel =>
      'Agent workspace scope script uuid label';

  @override
  String get agentWorkspaceScopeWorkspaceUuidLabel =>
      'Agent workspace scope workspace uuid label';

  @override
  String get agentWorkspacePaneScript => 'Agent workspace pane script';

  @override
  String get agentWorkspacePaneProduction => 'Agent workspace pane production';

  @override
  String get agentWorkspacePaneActivity => 'Agent workspace pane activity';

  @override
  String get agentWorkspaceActivityTitle => 'Agent workspace activity title';

  @override
  String agentWorkspaceActivityLatest(String eventType) {
    return '最新：$eventType';
  }

  @override
  String agentWorkspaceActivityLatestToolResult(String detail) {
    return 'Latest tool result: $detail';
  }

  @override
  String get agentWorkspaceActivityLatestAssistantText =>
      'Agent workspace activity latest assistant text';

  @override
  String get agentWorkspaceActivityNoWsEvents =>
      'Agent workspace activity no ws events';

  @override
  String get agentWorkspaceProductionCardTitle =>
      'Agent workspace production card title';

  @override
  String get agentWorkspaceGuidedTasksTitle =>
      'Agent workspace guided tasks title';

  @override
  String get agentWorkspaceScriptWritebackSourceAssistant =>
      'Agent workspace script writeback source assistant';

  @override
  String agentWorkspaceScriptPlanHint(int pid) {
    return 'Plan $pid';
  }

  @override
  String agentWorkspaceScriptPlanWritebackReady(
    String planHint,
    int scriptCount,
  ) {
    return '计划回写就绪：$planHint，$scriptCount 条剧本';
  }

  @override
  String get agentWorkspaceScriptRunningWorkflow =>
      'Agent workspace script running workflow';

  @override
  String get agentWorkspaceScriptRunningReadContext =>
      'Agent workspace script running read context';

  @override
  String get agentWorkspaceScriptRunningSubAgent =>
      'Agent workspace script running sub agent';

  @override
  String get agentWorkspaceScriptRunningWriteback =>
      'Agent workspace script running writeback';

  @override
  String get agentWorkspaceScriptRunningWritebackPlan =>
      'Agent workspace script running writeback plan';

  @override
  String get agentWorkspaceScriptCardTitle =>
      'Agent workspace script card title';

  @override
  String get agentWorkspaceSectionTitle => 'Agent workspace section title';

  @override
  String get agentWorkspaceSectionDescription =>
      'Agent workspace section description';

  @override
  String get contentComplianceTargetProject =>
      'Content compliance target project';

  @override
  String get contentComplianceTargetScript =>
      'Content compliance target script';

  @override
  String get contentComplianceTargetStoryboard =>
      'Content compliance target storyboard';

  @override
  String get contentComplianceTargetAsset => 'Content compliance target asset';

  @override
  String get contentComplianceTargetNovel => 'Content compliance target novel';

  @override
  String get contentComplianceTargetUser => 'Content compliance target user';

  @override
  String get contentComplianceOptionAll => 'Content compliance option all';

  @override
  String get contentComplianceCategoryCopyright =>
      'Content compliance category copyright';

  @override
  String get contentComplianceCategorySafety =>
      'Content compliance category safety';

  @override
  String get contentComplianceCategoryHarassment =>
      'Content compliance category harassment';

  @override
  String get contentComplianceCategoryAdult =>
      'Content compliance category adult';

  @override
  String get contentComplianceCategoryViolence =>
      'Content compliance category violence';

  @override
  String get contentComplianceCategorySpam =>
      'Content compliance category spam';

  @override
  String get contentComplianceCategoryOther =>
      'Content compliance category other';

  @override
  String get contentComplianceSeverityLow => 'Content compliance severity low';

  @override
  String get contentComplianceSeverityMedium =>
      'Content compliance severity medium';

  @override
  String get contentComplianceSeverityHigh =>
      'Content compliance severity high';

  @override
  String get contentComplianceSeverityCritical =>
      'Content compliance severity critical';

  @override
  String get contentComplianceStatusPending =>
      'Content compliance status pending';

  @override
  String get contentComplianceStatusClaimed =>
      'Content compliance status claimed';

  @override
  String get contentComplianceStatusResolved =>
      'Content compliance status resolved';

  @override
  String get contentComplianceStatusDismissed =>
      'Content compliance status dismissed';

  @override
  String contentComplianceSlaOpenOver24h(int count) {
    return 'open>24h $count';
  }

  @override
  String contentComplianceSlaOpenOver72h(int count) {
    return 'open>72h $count';
  }

  @override
  String contentComplianceSlaClaimedOver24h(int count) {
    return 'claimed>24h $count';
  }

  @override
  String get contentComplianceFieldTargetType =>
      'Content compliance field target type';

  @override
  String get contentComplianceFieldCategory =>
      'Content compliance field category';

  @override
  String get contentComplianceFieldSeverity =>
      'Content compliance field severity';

  @override
  String get contentComplianceFieldTargetUuid =>
      'Content compliance field target uuid';

  @override
  String get contentComplianceFieldStatus => 'Content compliance field status';

  @override
  String contentComplianceSlaChip(String bucket) {
    return 'SLA: $bucket';
  }

  @override
  String contentComplianceMetricPending(int count) {
    return '待处理 $count';
  }

  @override
  String contentComplianceMetricClaimed(int count) {
    return '已认领 $count';
  }

  @override
  String contentComplianceMetricResolved(int count) {
    return 'resolved $count';
  }

  @override
  String contentComplianceMetricDismissed(int count) {
    return 'dismissed $count';
  }

  @override
  String contentComplianceMetricCritical(int count) {
    return 'critical $count';
  }

  @override
  String contentComplianceMetricHigh(int count) {
    return '高优先级 $count';
  }

  @override
  String contentComplianceOldestHours(int hours) {
    return '最旧 ${hours}h';
  }

  @override
  String contentComplianceCapacityPerReviewer(int capacity) {
    return '容量 $capacity/reviewer';
  }

  @override
  String contentComplianceOwnerCounts(int pending, int claimed) {
    return '待处理 $pending · 已认领 $claimed';
  }

  @override
  String contentComplianceOwnerDetail(String detail) {
    return 'detail $detail';
  }

  @override
  String contentComplianceWorkspaceCounts(int open, int pending, int claimed) {
    return 'open $open · pending $pending · claimed $claimed';
  }

  @override
  String contentComplianceWorkspaceDetail(int critical, int high, String sla) {
    return 'critical $critical · high $high · SLA $sla';
  }

  @override
  String contentComplianceReportInfo(
    String reporter,
    String reportedAt,
    String detail,
  ) {
    return 'reporter $reporter · $reportedAt · $detail';
  }

  @override
  String contentComplianceResolutionLine(String note) {
    return 'resolution: $note';
  }

  @override
  String get contentComplianceActionClaim => 'Content compliance action claim';

  @override
  String get contentComplianceActionResolve =>
      'Content compliance action resolve';

  @override
  String get contentComplianceActionDismiss =>
      'Content compliance action dismiss';

  @override
  String get contentComplianceFieldDisposition =>
      'Content compliance field disposition';

  @override
  String get contentComplianceDispositionNone =>
      'Content compliance disposition none';

  @override
  String get contentComplianceDispositionArchiveProject =>
      'Content compliance disposition archive project';

  @override
  String get contentComplianceDispositionSuspendUser =>
      'Content compliance disposition suspend user';

  @override
  String get contentComplianceFieldResolutionNote =>
      'Content compliance field resolution note';

  @override
  String get jobsEmptyValue => 'Jobs empty value';

  @override
  String jobsKindCountEntry(String kind, int jobCount) {
    return '$kind: $jobCount';
  }

  @override
  String jobsStatusCountEntry(String status, int jobCount) {
    return '$status: $jobCount';
  }

  @override
  String jobsIdempotencyMismatch(String firstId, String secondId) {
    return 'POST /api/v1/jobs idempotency: expected same id, got $firstId vs $secondId';
  }

  @override
  String jobsUpdatedAt(String updatedAt) {
    return 'updated $updatedAt';
  }

  @override
  String jobsClaimedBy(String claimedBy) {
    return '认领者：$claimedBy';
  }

  @override
  String jobsFailedReason(String reason) {
    return '失败原因：$reason';
  }

  @override
  String get jobsTitle => 'Jobs title';

  @override
  String get jobsPrefsTooltip => 'Jobs prefs tooltip';

  @override
  String get jobsSubtitle => 'Jobs subtitle';

  @override
  String get jobsLoadList => 'Jobs load list';

  @override
  String get jobsLoadFailed => 'Jobs load failed';

  @override
  String get jobsLoadKinds => 'Jobs load kinds';

  @override
  String get jobsLoadKindSummary => 'Jobs load kind summary';

  @override
  String get jobsLoadStatusSummary => 'Jobs load status summary';

  @override
  String get jobsCompatTitle => 'Jobs compat title';

  @override
  String get jobsCompatSubtitle => 'Jobs compat subtitle';

  @override
  String get jobsCompatHttpProbeFilters => 'Jobs compat http probe filters';

  @override
  String get jobsFilterFlutterProbe => 'Jobs filter flutter probe';

  @override
  String get jobsFilterFlutterProbeQueued => 'Jobs filter flutter probe queued';

  @override
  String get jobsCreateProbeJob => 'Jobs create probe job';

  @override
  String get jobsJobIdLabel => 'Jobs job id label';

  @override
  String get jobsFetchDetail => 'Jobs fetch detail';

  @override
  String jobsDetailLabel(String detail) {
    return '作业详情：$detail';
  }

  @override
  String jobsKindsLabel(String kinds) {
    return '作业类型：$kinds';
  }

  @override
  String jobsKindSummaryLabel(String summary) {
    return '类型汇总：$summary';
  }

  @override
  String jobsStatusSummaryLabel(String summary) {
    return '状态汇总：$summary';
  }

  @override
  String jobsCountLabel(int count) {
    return '$count 条作业';
  }

  @override
  String get jobsRetry => 'Jobs retry';

  @override
  String get jobsCancel => 'Jobs cancel';

  @override
  String get notificationsRealtimeDisconnected =>
      'Notifications realtime disconnected';

  @override
  String get notificationsPlatformStatusRecovered =>
      'Notifications platform status recovered';

  @override
  String get notificationsPlatformStatusDegraded =>
      'Notifications platform status degraded';

  @override
  String get notificationsPlatformStatusRecoveredMessage =>
      'Notifications platform status recovered message';

  @override
  String get notificationsPlatformStatusDegradedMessage =>
      'Notifications platform status degraded message';

  @override
  String notificationsPlatformStatusAffectedEndpoints(String endpoints) {
    return 'Affected endpoints: $endpoints';
  }

  @override
  String notificationsComplianceAlertTitle(String title) {
    return 'Content compliance alert: $title';
  }

  @override
  String notificationsDownloadUnsupported(String fileName, int bytes) {
    return 'Downloads are not supported on this platform: $fileName ($bytes bytes)';
  }

  @override
  String get notificationsComplianceSharedAsyncExportCompleted =>
      'Notifications compliance shared async export completed';

  @override
  String notificationsComplianceSharedAsyncExportCancelled(int taskId) {
    return 'Workspace shared audit background export cancelled (task #$taskId).';
  }

  @override
  String notificationsComplianceSharedAsyncExportFailed(int taskId) {
    return 'Workspace shared audit background export failed (task #$taskId).';
  }

  @override
  String notificationsComplianceSharedAsyncExportFailedWithDetail(
    int taskId,
    String detail,
  ) {
    return 'Workspace shared audit background export failed (task #$taskId): $detail';
  }

  @override
  String get notificationsComplianceSharedAsyncExportTimedOut =>
      'Notifications compliance shared async export timed out';

  @override
  String get notificationsImportJsonObjectRequired =>
      'Notifications import json object required';

  @override
  String notificationsImportJsonParseFailed(String message) {
    return 'Failed to parse imported JSON: $message';
  }

  @override
  String notificationsUnknownTemplate(String templateId) {
    return 'Unknown template: $templateId';
  }

  @override
  String platformStatusChipLabel(String title, String value) {
    return '$title: $value';
  }

  @override
  String opsWhActivityEntryTitle(String action, String webhookId) {
    return '$action · $webhookId';
  }

  @override
  String opsWhFieldId(String id) {
    return 'ID: $id';
  }

  @override
  String opsWhFieldCreatedAt(String createdAt) {
    return '创建时间: $createdAt';
  }

  @override
  String opsWhFieldUpdatedAt(String updatedAt) {
    return '更新时间: $updatedAt';
  }

  @override
  String opsWhApiEventTypes(String eventTypes) {
    return 'API: $eventTypes';
  }

  @override
  String get billingAuditEventTypeLabel => 'Billing audit event type label';

  @override
  String get billingAuditProviderEventIdLabel =>
      'Billing audit provider event id label';

  @override
  String get billingAuditRawEventIdLabel => 'Billing audit raw event id label';

  @override
  String get billingAuditProviderEventIdPrefixLabel =>
      'Billing audit provider event id prefix label';

  @override
  String get billingAuditRawEventIdPrefixLabel =>
      'Billing audit raw event id prefix label';

  @override
  String get billingAuditEventCreatedFromLabel =>
      'Billing audit event created from label';

  @override
  String get billingAuditEventCreatedToLabel =>
      'Billing audit event created to label';

  @override
  String get billingAuditCreatedFromLabel => 'Billing audit created from label';

  @override
  String get billingAuditCreatedToLabel => 'Billing audit created to label';

  @override
  String notificationsFilterCount(int count) {
    return '筛选 $count';
  }

  @override
  String notificationsUnreadCount(int count) {
    return '未读 $count';
  }

  @override
  String get apiKeysSnackFillName => 'Please enter a key name first.';

  @override
  String get apiKeysSnackPickExpiry => 'Please choose an expiry date first.';

  @override
  String get apiKeysDatePickerHelp => 'Choose expiry date';

  @override
  String apiKeysRotateTitle(String displayName) {
    return 'Rotate $displayName';
  }

  @override
  String get apiKeysRotateBody =>
      'Rotation immediately invalidates the old secret and shows the new plaintext token only once.';

  @override
  String get apiKeysExpiryPolicy => 'Expiry policy';

  @override
  String get apiKeysExpiryKeepCurrent => 'Keep current';

  @override
  String get apiKeysExpiryClearExpiry => 'Clear expiry';

  @override
  String get apiKeysExpirySevenDays => '7 days';

  @override
  String get apiKeysExpiryThirtyDays => '30 days';

  @override
  String get apiKeysExpiryNinetyDays => '90 days';

  @override
  String get apiKeysExpiryCustomDate => 'Custom date';

  @override
  String apiKeysExpiresAtUtc(String date) {
    return 'Expires $date at 23:59 UTC';
  }

  @override
  String get apiKeysActionRotate => 'Rotate';

  @override
  String apiKeysRevokeTitle(String displayName) {
    return 'Revoke $displayName';
  }

  @override
  String get apiKeysRevokeBody =>
      'After revocation the existing token stops working until you restore or rotate again.';

  @override
  String get apiKeysRevokeReasonLabel => 'Reason (optional)';

  @override
  String get apiKeysRevokeReasonHint =>
      'e.g. credential leak, env retired, bot disabled';

  @override
  String get apiKeysActionRevoke => 'Revoke';

  @override
  String get apiKeysSectionTitle => 'API keys';

  @override
  String get apiKeysRiskyPrefsTooltip =>
      'Local client preferences (confirmations for key rotation/deletion and reset).';

  @override
  String get apiKeysIntroBody =>
      'Issue user-level credentials for server automation, CLI, CI/CD, and internal integrations. Read-only keys may call GET/HEAD/OPTIONS only; read-write keys may call mutating REST endpoints.';

  @override
  String get apiKeysCreateNewTitle => 'Issue new key';

  @override
  String get apiKeysRefresh => 'Refresh';

  @override
  String get apiKeysDisplayNameLabel => 'Name';

  @override
  String get apiKeysDisplayNameHint =>
      'e.g. CI deploy / data export / internal bot';

  @override
  String get apiKeysPermissionTitle => 'Permissions';

  @override
  String get apiKeysScopeReadOnly => 'Read-only';

  @override
  String get apiKeysScopeReadWrite => 'Read-write';

  @override
  String get apiKeysExpiryNever => 'Never expires';

  @override
  String get apiKeysCreating => 'Creating…';

  @override
  String get apiKeysCreateButton => 'Create API key';

  @override
  String get apiKeysPlaintextOnceTitle => 'One-time plaintext';

  @override
  String get apiKeysPlaintextOnceBody =>
      'This secret is shown only once. Copy it immediately to your secret manager, CI secret, or integration config.';

  @override
  String get apiKeysCopiedPlaintextSnack => 'Copied one-time plaintext API key';

  @override
  String get apiKeysCopyPlaintext => 'Copy plaintext';

  @override
  String get apiKeysHidePlaintext => 'Hide';

  @override
  String get apiKeysExistingKeysTitle => 'Existing keys';

  @override
  String get apiKeysEmptyList => 'No API keys yet.';

  @override
  String get apiKeysChipUsable => 'Usable';

  @override
  String get apiKeysChipUnusable => 'Not usable';

  @override
  String get apiKeysChipActive => 'Active';

  @override
  String get apiKeysChipRevoked => 'Revoked';

  @override
  String get apiKeysChipExpired => 'Expired';

  @override
  String get apiKeysCopyPublicIdTooltip => 'Copy publicId';

  @override
  String get apiKeysCopiedPublicIdSnack => 'Copied publicId';

  @override
  String apiKeysMetaLine(String createdAt, String updatedAt, int useCount) {
    return 'Created $createdAt · Updated $updatedAt · Used $useCount times';
  }

  @override
  String apiKeysLastUsedLine(String lastUsedAt, String method, String path) {
    return 'Last used $lastUsedAt · $method $path';
  }

  @override
  String apiKeysSourceLine(String source) {
    return 'Source $source';
  }

  @override
  String apiKeysExpiresAtLine(String expiresAt) {
    return 'Expires at $expiresAt';
  }

  @override
  String apiKeysRotatedAtLine(String rotatedAt) {
    return 'Last rotated $rotatedAt';
  }

  @override
  String apiKeysRevokedAtLine(String revokedAt) {
    return 'Revoked at $revokedAt';
  }

  @override
  String get apiKeysExpiredNeedsRotate => 'Expired — rotate';

  @override
  String get apiKeysRestore => 'Restore';

  @override
  String get apiKeysDeleteTitle => 'Delete API key';

  @override
  String apiKeysDeleteBody(String displayName, String keyHint) {
    return 'About to delete $displayName\n$keyHint';
  }

  @override
  String get apiKeysDelete => 'Delete';

  @override
  String get apiKeysAuditTitle => 'Admin audit';

  @override
  String get apiKeysAuditEmpty => 'No API key lifecycle records yet.';

  @override
  String get statusPageTitle => 'Toonflow Status';

  @override
  String get statusPageRefreshTooltip => 'Refresh';

  @override
  String get statusPageHeadline => 'Public read-only status';

  @override
  String get statusPageIntroBase =>
      'Aggregates /health, /api/v1/health, /api/v1/ready, and /api/v1/version.';

  @override
  String get statusPageIntroInternalSuffix =>
      ' INTERNAL_OPS_TOKEN is set via dart-define, so internal queue stats are included.';

  @override
  String get statusPageRefreshing => 'Refreshing…';

  @override
  String get statusPageRefreshAction => 'Refresh status';

  @override
  String statusPageLastUpdated(String time) {
    return 'Last refreshed: $time';
  }

  @override
  String get statusPageRequestFailed => 'Request failed';

  @override
  String get statusPageVersionSectionTitle => 'Version';

  @override
  String get statusPageInternalQueueSectionTitle => 'Internal queue stats';

  @override
  String statusPageApiBaseLabel(String baseUrl) {
    return 'API: $baseUrl';
  }

  @override
  String get benchmarkSectionTitle => 'Quality baseline & experiments';

  @override
  String get benchmarkIntroBody =>
      'Manage sample pools, experiment runs, human review, ROI, release gates, and trends in one place instead of relying on gut feel alone.';

  @override
  String get benchmarkActionFetchSamplePool => 'Fetch sample pool';

  @override
  String get benchmarkActionFetchExperiments => 'Fetch experiments';

  @override
  String get benchmarkActionFetchReviewQueue => 'Fetch review queue';

  @override
  String get benchmarkActionFetchMemoryTier => 'Fetch memory profiles';

  @override
  String get benchmarkActionFetchTrends => 'Fetch trends';

  @override
  String get benchmarkActionPromoteFromReview => 'Promote from review';

  @override
  String get benchmarkActionFetchExperimentDetail => 'Fetch experiment detail';

  @override
  String get benchmarkActionStartExperiment => 'Start experiment';

  @override
  String get benchmarkActionCancelExperiment => 'Cancel experiment';

  @override
  String get benchmarkActionFetchRoi => 'Fetch ROI';

  @override
  String get benchmarkActionFetchGate => 'Fetch gate';

  @override
  String get benchmarkActionCreateExperiment => 'Create experiment';

  @override
  String get benchmarkActionSubmitReview => 'Submit review';

  @override
  String get benchmarkActionSkipReview => 'Skip review';

  @override
  String get benchmarkActionSubmitGateDecision => 'Submit gate decision';

  @override
  String get benchmarkActionRunAbCompare => 'Run A/B comparison';

  @override
  String get benchmarkActionSaveRunAbCompare => 'Save and run A/B comparison';

  @override
  String get benchmarkActionFetchAbHistory => 'Fetch A/B history';

  @override
  String get benchmarkActionFetchAbDetail => 'Fetch A/B detail';

  @override
  String get benchmarkActionReplaySave => 'Replay params and save';

  @override
  String benchmarkStatusNeedSignIn(String action) {
    return 'Not signed in; cannot run $action';
  }

  @override
  String benchmarkStatusRunning(String action) {
    return 'Running: $action';
  }

  @override
  String benchmarkStatusCompleted(String action) {
    return 'Completed: $action';
  }

  @override
  String benchmarkStatusFailedHttp(
    String action,
    String statusCode,
    String message,
  ) {
    return 'Failed: $action ($statusCode $message)';
  }

  @override
  String benchmarkStatusFailed(String action, String error) {
    return 'Failed: $action ($error)';
  }

  @override
  String get benchmarkProjectIdOptional =>
      'Project ID (optional, for sample filter)';

  @override
  String benchmarkCaseRowSubtitle(String summary, String weight, String tags) {
    return '$summary · weight $weight · tags $tags';
  }

  @override
  String benchmarkExperimentRowSubtitle(
    String sampleTier,
    String stages,
    String id,
  ) {
    return '$sampleTier · stages $stages · $id';
  }

  @override
  String benchmarkMemoryProfilesLine(String tiers) {
    return 'Memory profiles: $tiers';
  }

  @override
  String benchmarkExperimentDetailHeader(String name, int variantCount) {
    return 'Experiment detail: $name · $variantCount variants';
  }

  @override
  String benchmarkRoiHeader(String conclusion, String rationale) {
    return 'ROI: $conclusion · $rationale';
  }

  @override
  String benchmarkRoiVariantLine(
    String variantLabel,
    String scoreDelta,
    String tokenDeltaPct,
  ) {
    return '$variantLabel · scoreΔ $scoreDelta · tokenΔ $tokenDeltaPct%';
  }

  @override
  String benchmarkGateAssessmentRow(
    String variantLabel,
    String decision,
    String scoreDelta,
    String severe,
  ) {
    return '$variantLabel · $decision · scoreΔ $scoreDelta · severeGuard $severe';
  }

  @override
  String benchmarkTrendWeekRow(
    String weekStart,
    String quality,
    String tokens,
    String approved,
    String blocked,
  ) {
    return '$weekStart · quality $quality · token $tokens · approved $approved / blocked $blocked';
  }

  @override
  String get benchmarkAbOutcomePassed => 'passed';

  @override
  String get benchmarkAbOutcomeFailed => 'failed';

  @override
  String benchmarkAbAggregateSummary(
    String outcome,
    int passedCases,
    int totalCases,
    String tokenPct,
    String qualityDiff,
  ) {
    return 'A/B summary: $outcome · passed $passedCases/$totalCases · avg token reduction $tokenPct% · avg quality diff $qualityDiff';
  }

  @override
  String benchmarkHistoryReplay(String nameOrId, String createdAt) {
    return 'Replay: $nameOrId · $createdAt';
  }

  @override
  String get benchmarkPromoteCardTitle => 'Promote sample from quality review';

  @override
  String get benchmarkLabelQualityReviewId => 'Quality review ID';

  @override
  String get benchmarkLabelSampleType => 'Sample type';

  @override
  String get benchmarkLabelSampleSummary => 'Sample summary';

  @override
  String get benchmarkLabelTagsCommaSeparated => 'Tags (comma-separated)';

  @override
  String get benchmarkButtonPromoteToSample => 'Promote to sample';

  @override
  String get benchmarkExperimentCardTitle => 'Experiment runs';

  @override
  String get benchmarkLabelExperimentId => 'Experiment ID';

  @override
  String get benchmarkButtonLoadDetail => 'Load detail';

  @override
  String get benchmarkButtonStart => 'Start';

  @override
  String get benchmarkButtonCancel => 'Cancel';

  @override
  String get benchmarkLabelNewExperimentName => 'New experiment name';

  @override
  String get benchmarkLabelSampleTierSet => 'Sample tier';

  @override
  String get benchmarkLabelStageScopeComma => 'Stage scope (comma-separated)';

  @override
  String get benchmarkLabelBaselineVariantLabel => 'Baseline variant label';

  @override
  String get benchmarkLabelVariantsJsonArray => 'Variants JSON (array)';

  @override
  String get benchmarkButtonCreateExperiment => 'Create experiment';

  @override
  String get benchmarkReviewCardTitle => 'Human review';

  @override
  String get benchmarkLabelReviewQueueId => 'Review queue ID';

  @override
  String get benchmarkLabelSubmittedScoreJson => 'Submitted score JSON';

  @override
  String get benchmarkLabelSkipReasonOptional => 'Skip reason (optional)';

  @override
  String get benchmarkGateCardTitle => 'Gate decision';

  @override
  String get benchmarkLabelGateVariantId => 'Variant ID';

  @override
  String get benchmarkLabelGateDecisionOptionalAuto =>
      'Decision (empty uses auto decision)';

  @override
  String get benchmarkLabelGateDecisionNote => 'Decision note';

  @override
  String get benchmarkGatePromoteBaselineTitle =>
      'Also promote as new baseline';

  @override
  String get benchmarkGatePromoteBaselineSubtitle =>
      'Only applies to approved / approved_limited';

  @override
  String get benchmarkAbCardTitle => 'A/B comparison';

  @override
  String get benchmarkLabelAbSaveNameOptional => 'Save name (optional)';

  @override
  String get benchmarkLabelAbCaseLines =>
      'Cases (one per line: testCaseId,baselineJobId,optimizedJobId)';

  @override
  String get benchmarkLabelAbMinTokenReductionPct => 'Min token reduction %';

  @override
  String get benchmarkLabelAbMaxQualityDrop => 'Max quality drop';

  @override
  String get benchmarkLabelAbMinQualityScore => 'Min quality score';

  @override
  String get benchmarkLabelAbSignificanceP => 'Significance threshold p';

  @override
  String get benchmarkButtonRunAbCompare => 'Run A/B comparison';

  @override
  String get benchmarkButtonSaveAndRun => 'Save and run';

  @override
  String get benchmarkButtonFetchHistory => 'Fetch history';

  @override
  String get benchmarkButtonLoadDetailAndFill => 'Load detail and fill form';

  @override
  String get benchmarkButtonReplaySave => 'Replay params and save';

  @override
  String benchmarkErrorInvalidCaseRow(String line) {
    return 'Invalid case line: $line';
  }

  @override
  String get benchmarkErrorAbThresholdFormat =>
      'Invalid A/B threshold parameter format';

  @override
  String get benchmarkErrorVariantsMustBeJsonArray =>
      'variants JSON must be an array';

  @override
  String get benchmarkErrorSubmittedScoreMustBeObject =>
      'submittedScore must be a JSON object';

  @override
  String get benchmarkSummaryCasesEmpty => 'No baseline samples loaded';

  @override
  String benchmarkSummaryCases(int count, String preview) {
    return '$count samples · $preview';
  }

  @override
  String get benchmarkSummaryExperimentsEmpty => 'No experiment runs loaded';

  @override
  String benchmarkSummaryExperiments(int count, String preview) {
    return '$count experiments · $preview';
  }

  @override
  String get benchmarkSummaryReviewQueueEmpty => 'No review queue loaded';

  @override
  String benchmarkSummaryReviewQueue(int total, int pending) {
    return '$total review items · $pending pending';
  }

  @override
  String get benchmarkSummaryGateEmpty => 'Gate results not loaded';

  @override
  String benchmarkSummaryGate(
    int count,
    int approved,
    int limited,
    int blocked,
  ) {
    return '$count gate assessments · approved $approved / limited $limited / blocked $blocked';
  }

  @override
  String get benchmarkSummaryTrendsEmpty => 'Trends not loaded';

  @override
  String benchmarkSummaryTrends(
    int weeks,
    String weekStart,
    String quality,
    String tokens,
  ) {
    return '$weeks weeks · latest $weekStart quality $quality / token $tokens';
  }
}
