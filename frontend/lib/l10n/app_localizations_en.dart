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
}
