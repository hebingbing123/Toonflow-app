import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenFlow'**
  String get appTitle;

  /// No description provided for @localeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Display language'**
  String get localeSectionTitle;

  /// No description provided for @localeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get localeSystem;

  /// No description provided for @localeEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeEnglish;

  /// No description provided for @localeChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get localeChinese;

  /// No description provided for @workspaceModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace mode'**
  String get workspaceModeTitle;

  /// No description provided for @workspaceModeProduct.
  ///
  /// In en, this message translates to:
  /// **'Product workspace'**
  String get workspaceModeProduct;

  /// No description provided for @workspaceModeDebug.
  ///
  /// In en, this message translates to:
  /// **'Ops and debug'**
  String get workspaceModeDebug;

  /// No description provided for @workspaceModeDescriptionProduct.
  ///
  /// In en, this message translates to:
  /// **'Focused on user workflows: projects, agent workspaces, tasks, and quality.'**
  String get workspaceModeDescriptionProduct;

  /// No description provided for @workspaceModeDescriptionDebug.
  ///
  /// In en, this message translates to:
  /// **'Focused on ops probes: Harness tooling, WebSocket diagnostics, and system checks.'**
  String get workspaceModeDescriptionDebug;

  /// No description provided for @errorLine.
  ///
  /// In en, this message translates to:
  /// **'Error: {detail}'**
  String errorLine(String detail);

  /// No description provided for @workspaceContextLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading workspace…'**
  String get workspaceContextLoading;

  /// No description provided for @workspaceContextNoWorkspace.
  ///
  /// In en, this message translates to:
  /// **'No workspace'**
  String get workspaceContextNoWorkspace;

  /// No description provided for @workspaceContextNoProject.
  ///
  /// In en, this message translates to:
  /// **'No project selected'**
  String get workspaceContextNoProject;

  /// No description provided for @workspaceBillingTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace billing'**
  String get workspaceBillingTitle;

  /// No description provided for @workspaceBillingUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get workspaceBillingUnlimited;

  /// No description provided for @workspaceBillingUnknownTier.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get workspaceBillingUnknownTier;

  /// No description provided for @workspaceBillingPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan: {tier}'**
  String workspaceBillingPlan(String tier);

  /// No description provided for @workspaceBillingDailyQuota.
  ///
  /// In en, this message translates to:
  /// **'Daily quota: {quota}'**
  String workspaceBillingDailyQuota(String quota);

  /// No description provided for @workspaceBillingPercentUsed.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String workspaceBillingPercentUsed(String percent);

  /// No description provided for @shortVideoSpaceCannotSaveNoProject.
  ///
  /// In en, this message translates to:
  /// **'Cannot save: no project selected or not logged in'**
  String get shortVideoSpaceCannotSaveNoProject;

  /// No description provided for @shortVideoSpaceSavingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Saving in progress, please wait...'**
  String get shortVideoSpaceSavingInProgress;

  /// No description provided for @shortVideoSpaceSelectAllAvailable.
  ///
  /// In en, this message translates to:
  /// **'Select all shortcut (Ctrl+A / Cmd+A) is available in the shot operation panel'**
  String get shortVideoSpaceSelectAllAvailable;

  /// No description provided for @shortVideoSpaceSearchFocused.
  ///
  /// In en, this message translates to:
  /// **'Search box focused'**
  String get shortVideoSpaceSearchFocused;

  /// No description provided for @shortVideoSpaceSearchNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Search box not available (please open shot operation panel first)'**
  String get shortVideoSpaceSearchNotAvailable;

  /// No description provided for @shortVideoSpaceSaveProjectConfig.
  ///
  /// In en, this message translates to:
  /// **'Save project configuration'**
  String get shortVideoSpaceSaveProjectConfig;

  /// No description provided for @shortVideoSpaceSelectAllShots.
  ///
  /// In en, this message translates to:
  /// **'Select all shots (in batch operation mode)'**
  String get shortVideoSpaceSelectAllShots;

  /// No description provided for @shortVideoSpaceFocusSearch.
  ///
  /// In en, this message translates to:
  /// **'Focus search box'**
  String get shortVideoSpaceFocusSearch;

  /// No description provided for @shortVideoSpaceUndoOperation.
  ///
  /// In en, this message translates to:
  /// **'Undo last operation'**
  String get shortVideoSpaceUndoOperation;

  /// No description provided for @shortVideoSpaceRedoOperation.
  ///
  /// In en, this message translates to:
  /// **'Redo last operation'**
  String get shortVideoSpaceRedoOperation;

  /// No description provided for @shortVideoSpaceFileOperations.
  ///
  /// In en, this message translates to:
  /// **'File Operations'**
  String get shortVideoSpaceFileOperations;

  /// No description provided for @shortVideoSpaceSelectionOperations.
  ///
  /// In en, this message translates to:
  /// **'Selection Operations'**
  String get shortVideoSpaceSelectionOperations;

  /// No description provided for @shortVideoSpaceNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get shortVideoSpaceNavigation;

  /// No description provided for @shortVideoSpaceEditOperations.
  ///
  /// In en, this message translates to:
  /// **'Edit Operations'**
  String get shortVideoSpaceEditOperations;

  /// No description provided for @shortVideoSpaceKeyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get shortVideoSpaceKeyboardShortcuts;

  /// No description provided for @shortVideoSpaceClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get shortVideoSpaceClose;

  /// No description provided for @shortVideoSpaceCurrentProjectOverview.
  ///
  /// In en, this message translates to:
  /// **'Current Project Overview'**
  String get shortVideoSpaceCurrentProjectOverview;

  /// No description provided for @shortVideoSpaceRecentBadCaseTrends.
  ///
  /// In en, this message translates to:
  /// **'Recent Bad Case Trends'**
  String get shortVideoSpaceRecentBadCaseTrends;

  /// No description provided for @shortVideoSpaceRecentTaskFlow.
  ///
  /// In en, this message translates to:
  /// **'Recent Task Flow'**
  String get shortVideoSpaceRecentTaskFlow;

  /// No description provided for @shortVideoSpaceAssetsOverview.
  ///
  /// In en, this message translates to:
  /// **'Assets Overview'**
  String get shortVideoSpaceAssetsOverview;

  /// No description provided for @shortVideoSpaceAssemblySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Assembly Snapshot'**
  String get shortVideoSpaceAssemblySnapshot;

  /// No description provided for @shortVideoSpaceQualityReview.
  ///
  /// In en, this message translates to:
  /// **'Quality Review (Quality Acceptance)'**
  String get shortVideoSpaceQualityReview;

  /// No description provided for @shortVideoSpaceMultiTrackExportDecision.
  ///
  /// In en, this message translates to:
  /// **'Limited Multi-track Export Decision (K5)'**
  String get shortVideoSpaceMultiTrackExportDecision;

  /// No description provided for @shortVideoSpaceOpenProductionWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open Production Workspace'**
  String get shortVideoSpaceOpenProductionWorkspace;

  /// No description provided for @shortVideoSpaceBasicShotOperations.
  ///
  /// In en, this message translates to:
  /// **'Basic Shot Operations'**
  String get shortVideoSpaceBasicShotOperations;

  /// No description provided for @shortVideoSpaceAssemblyStyleAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Assembly Style Adjustment'**
  String get shortVideoSpaceAssemblyStyleAdjustment;

  /// No description provided for @shortVideoSpaceExportPreCheck.
  ///
  /// In en, this message translates to:
  /// **'Export Pre-check'**
  String get shortVideoSpaceExportPreCheck;

  /// No description provided for @shortVideoSpaceQualityGateBlockingReasons.
  ///
  /// In en, this message translates to:
  /// **'Quality Gate Blocking Reasons'**
  String get shortVideoSpaceQualityGateBlockingReasons;

  /// No description provided for @shortVideoSpaceBlockingItems.
  ///
  /// In en, this message translates to:
  /// **'Blocking Items (Selected by Interface Order)'**
  String get shortVideoSpaceBlockingItems;

  /// No description provided for @shortVideoSpaceWarningItems.
  ///
  /// In en, this message translates to:
  /// **'Warning Items (Selected by Interface Order)'**
  String get shortVideoSpaceWarningItems;

  /// No description provided for @shortVideoSpaceExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get shortVideoSpaceExporting;

  /// No description provided for @shortVideoSpaceStartExport.
  ///
  /// In en, this message translates to:
  /// **'Start Export'**
  String get shortVideoSpaceStartExport;

  /// No description provided for @shortVideoSpaceExportHistory.
  ///
  /// In en, this message translates to:
  /// **'Export History'**
  String get shortVideoSpaceExportHistory;

  /// No description provided for @shortVideoSpacePublishJobs.
  ///
  /// In en, this message translates to:
  /// **'Publish Jobs'**
  String get shortVideoSpacePublishJobs;

  /// No description provided for @shortVideoSpaceScheduleCalendar.
  ///
  /// In en, this message translates to:
  /// **'Schedule Calendar (counted by local calendar days; click a day to batch write timing)'**
  String get shortVideoSpaceScheduleCalendar;

  /// No description provided for @shortVideoSpaceTargetConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Short Video Target Configuration'**
  String get shortVideoSpaceTargetConfiguration;

  /// No description provided for @shortVideoSpaceConfigurationDescription.
  ///
  /// In en, this message translates to:
  /// **'Write the creation mode and aspect ratio directly back to the project, so that subsequent scripts and production processes can continue to work based on the same project configuration.'**
  String get shortVideoSpaceConfigurationDescription;

  /// No description provided for @shortVideoSpaceTargetProject.
  ///
  /// In en, this message translates to:
  /// **'Target Project'**
  String get shortVideoSpaceTargetProject;

  /// No description provided for @shortVideoSpaceLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get shortVideoSpaceLoading;

  /// No description provided for @shortVideoSpaceRefreshProjects.
  ///
  /// In en, this message translates to:
  /// **'Refresh Projects'**
  String get shortVideoSpaceRefreshProjects;

  /// No description provided for @shortVideoSpaceRestoreRiskyConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Restore High-Risk Confirmation Prompts'**
  String get shortVideoSpaceRestoreRiskyConfirmation;

  /// No description provided for @shortVideoSpacePortrait916.
  ///
  /// In en, this message translates to:
  /// **'Portrait 9:16'**
  String get shortVideoSpacePortrait916;

  /// No description provided for @shortVideoSpaceLandscape169.
  ///
  /// In en, this message translates to:
  /// **'Landscape 16:9'**
  String get shortVideoSpaceLandscape169;

  /// No description provided for @notificationsCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsCenterTitle;

  /// No description provided for @notificationsCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Aggregates job completion, workspace invites, skill changes, and read state.'**
  String get notificationsCenterSubtitle;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsRiskyPrefsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Local client preferences (for example \"don\'t ask again\" on short-video risky actions).'**
  String get notificationsRiskyPrefsTooltip;

  /// No description provided for @notificationsFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread {count}'**
  String notificationsFilterUnread(int count);

  /// No description provided for @notificationsTypeFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get notificationsTypeFilterLabel;

  /// No description provided for @notificationsTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsTypeAll;

  /// No description provided for @notificationsTypeJob.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get notificationsTypeJob;

  /// No description provided for @notificationsTypeWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get notificationsTypeWorkspace;

  /// No description provided for @notificationsTypeSkill.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get notificationsTypeSkill;

  /// No description provided for @notificationsTypeCompliance.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get notificationsTypeCompliance;

  /// No description provided for @notificationsSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search title / body / file / job'**
  String get notificationsSearchLabel;

  /// No description provided for @notificationsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get notificationsRefresh;

  /// No description provided for @notificationsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get notificationsLoadMore;

  /// No description provided for @notificationsEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No notifications match the current filters.'**
  String get notificationsEmptyFiltered;

  /// No description provided for @notificationsUnreadBadge.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnreadBadge;

  /// No description provided for @notificationsMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get notificationsMarkRead;

  /// No description provided for @notificationsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationsOpen;

  /// No description provided for @notificationsRecordJobSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Job completed'**
  String get notificationsRecordJobSucceeded;

  /// No description provided for @notificationsRecordJobFailed.
  ///
  /// In en, this message translates to:
  /// **'Job failed'**
  String get notificationsRecordJobFailed;

  /// No description provided for @notificationsRecordJobCancelled.
  ///
  /// In en, this message translates to:
  /// **'Job cancelled'**
  String get notificationsRecordJobCancelled;

  /// No description provided for @notificationsRecordWorkspaceInviteCreated.
  ///
  /// In en, this message translates to:
  /// **'Invite created'**
  String get notificationsRecordWorkspaceInviteCreated;

  /// No description provided for @notificationsRecordWorkspaceInviteResent.
  ///
  /// In en, this message translates to:
  /// **'Invite resent'**
  String get notificationsRecordWorkspaceInviteResent;

  /// No description provided for @notificationsRecordWorkspaceInviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invite revoked'**
  String get notificationsRecordWorkspaceInviteRevoked;

  /// No description provided for @notificationsRecordWorkspaceInviteAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invite accepted'**
  String get notificationsRecordWorkspaceInviteAccepted;

  /// No description provided for @notificationsRecordSkillChange.
  ///
  /// In en, this message translates to:
  /// **'Skill change'**
  String get notificationsRecordSkillChange;

  /// No description provided for @notificationsRecordContentComplianceAlert.
  ///
  /// In en, this message translates to:
  /// **'Content compliance alert'**
  String get notificationsRecordContentComplianceAlert;

  /// No description provided for @notificationsRecordContentComplianceCleared.
  ///
  /// In en, this message translates to:
  /// **'Content compliance cleared'**
  String get notificationsRecordContentComplianceCleared;

  /// No description provided for @notificationsComplianceClearedThrottleTitle.
  ///
  /// In en, this message translates to:
  /// **'Compliance cleared throttle (minutes)'**
  String get notificationsComplianceClearedThrottleTitle;

  /// No description provided for @notificationsComplianceMinutesHint.
  ///
  /// In en, this message translates to:
  /// **'1–1440'**
  String get notificationsComplianceMinutesHint;

  /// No description provided for @notificationsComplianceSavePolicy.
  ///
  /// In en, this message translates to:
  /// **'Save policy'**
  String get notificationsComplianceSavePolicy;

  /// No description provided for @notificationsComplianceSaveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get notificationsComplianceSaveAsTemplate;

  /// No description provided for @notificationsComplianceSaveToWorkspaceShared.
  ///
  /// In en, this message translates to:
  /// **'Save to workspace shared'**
  String get notificationsComplianceSaveToWorkspaceShared;

  /// No description provided for @notificationsComplianceExportTemplatesJson.
  ///
  /// In en, this message translates to:
  /// **'Export templates JSON'**
  String get notificationsComplianceExportTemplatesJson;

  /// No description provided for @notificationsComplianceImportTemplatesJson.
  ///
  /// In en, this message translates to:
  /// **'Import templates JSON'**
  String get notificationsComplianceImportTemplatesJson;

  /// No description provided for @notificationsComplianceClearedHelpShort.
  ///
  /// In en, this message translates to:
  /// **'At most one cleared per stage within the window to reduce noise.'**
  String get notificationsComplianceClearedHelpShort;

  /// No description provided for @notificationsComplianceCustomTemplatesOnly.
  ///
  /// In en, this message translates to:
  /// **'Custom templates only'**
  String get notificationsComplianceCustomTemplatesOnly;

  /// No description provided for @notificationsComplianceTemplateChip.
  ///
  /// In en, this message translates to:
  /// **'Template: {name}'**
  String notificationsComplianceTemplateChip(String name);

  /// No description provided for @notificationsComplianceSharedChip.
  ///
  /// In en, this message translates to:
  /// **'Shared: {name}'**
  String notificationsComplianceSharedChip(String name);

  /// No description provided for @notificationsComplianceTooltipMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get notificationsComplianceTooltipMoveUp;

  /// No description provided for @notificationsComplianceTooltipMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get notificationsComplianceTooltipMoveDown;

  /// No description provided for @notificationsComplianceTooltipEditTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit template'**
  String get notificationsComplianceTooltipEditTemplate;

  /// No description provided for @notificationsComplianceTooltipDeleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get notificationsComplianceTooltipDeleteTemplate;

  /// No description provided for @notificationsComplianceWorkspaceSharedHeader.
  ///
  /// In en, this message translates to:
  /// **'Workspace shared templates'**
  String get notificationsComplianceWorkspaceSharedHeader;

  /// No description provided for @notificationsComplianceTooltipEditSharedTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit shared template'**
  String get notificationsComplianceTooltipEditSharedTemplate;

  /// No description provided for @notificationsComplianceTooltipDeleteSharedTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete shared template'**
  String get notificationsComplianceTooltipDeleteSharedTemplate;

  /// No description provided for @notificationsComplianceStageOverrideLabel.
  ///
  /// In en, this message translates to:
  /// **'{stage} override'**
  String notificationsComplianceStageOverrideLabel(String stage);

  /// No description provided for @notificationsComplianceStageOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'Empty = follow global'**
  String get notificationsComplianceStageOverrideHint;

  /// No description provided for @notificationsComplianceSharedAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared template audit'**
  String get notificationsComplianceSharedAuditTitle;

  /// No description provided for @notificationsComplianceFilterTemplateId.
  ///
  /// In en, this message translates to:
  /// **'Template ID filter'**
  String get notificationsComplianceFilterTemplateId;

  /// No description provided for @notificationsComplianceFilterAction.
  ///
  /// In en, this message translates to:
  /// **'Action filter'**
  String get notificationsComplianceFilterAction;

  /// No description provided for @notificationsComplianceFilterStartIso.
  ///
  /// In en, this message translates to:
  /// **'Start time (ISO 8601)'**
  String get notificationsComplianceFilterStartIso;

  /// No description provided for @notificationsComplianceFilterEndIso.
  ///
  /// In en, this message translates to:
  /// **'End time (ISO 8601)'**
  String get notificationsComplianceFilterEndIso;

  /// No description provided for @notificationsComplianceApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get notificationsComplianceApplyFilters;

  /// No description provided for @notificationsComplianceDownloadAuditJson.
  ///
  /// In en, this message translates to:
  /// **'Download audit JSON'**
  String get notificationsComplianceDownloadAuditJson;

  /// No description provided for @notificationsComplianceDownloadAuditCsv.
  ///
  /// In en, this message translates to:
  /// **'Download audit CSV'**
  String get notificationsComplianceDownloadAuditCsv;

  /// No description provided for @notificationsComplianceAsyncJson.
  ///
  /// In en, this message translates to:
  /// **'Async JSON'**
  String get notificationsComplianceAsyncJson;

  /// No description provided for @notificationsComplianceAsyncCsv.
  ///
  /// In en, this message translates to:
  /// **'Async CSV'**
  String get notificationsComplianceAsyncCsv;

  /// No description provided for @notificationsComplianceCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get notificationsComplianceCloseTooltip;

  /// No description provided for @notificationsComplianceExportHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Export history'**
  String get notificationsComplianceExportHistoryTitle;

  /// No description provided for @notificationsComplianceExportFormatFilter.
  ///
  /// In en, this message translates to:
  /// **'Export format filter'**
  String get notificationsComplianceExportFormatFilter;

  /// No description provided for @notificationsComplianceExportedStartIso.
  ///
  /// In en, this message translates to:
  /// **'Exported from (ISO)'**
  String get notificationsComplianceExportedStartIso;

  /// No description provided for @notificationsComplianceExportedEndIso.
  ///
  /// In en, this message translates to:
  /// **'Exported to (ISO)'**
  String get notificationsComplianceExportedEndIso;

  /// No description provided for @notificationsComplianceFilterExports.
  ///
  /// In en, this message translates to:
  /// **'Filter export history'**
  String get notificationsComplianceFilterExports;

  /// No description provided for @notificationsComplianceReuseExportFiltersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reuse this export’s filters above'**
  String get notificationsComplianceReuseExportFiltersTooltip;

  /// No description provided for @notificationsComplianceMoreExportRecords.
  ///
  /// In en, this message translates to:
  /// **'More export records'**
  String get notificationsComplianceMoreExportRecords;

  /// No description provided for @notificationsComplianceLoadMoreAudit.
  ///
  /// In en, this message translates to:
  /// **'Load more audit'**
  String get notificationsComplianceLoadMoreAudit;

  /// No description provided for @notificationsComplianceThrottleInvalidGlobal.
  ///
  /// In en, this message translates to:
  /// **'Enter an integer from 1 to 1440 minutes.'**
  String get notificationsComplianceThrottleInvalidGlobal;

  /// No description provided for @notificationsComplianceThrottleStageInvalid.
  ///
  /// In en, this message translates to:
  /// **'{stage}: enter 1–1440 minutes, or leave blank.'**
  String notificationsComplianceThrottleStageInvalid(String stage);

  /// No description provided for @notificationsDialogSaveClearedTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Save cleared template'**
  String get notificationsDialogSaveClearedTemplateTitle;

  /// No description provided for @notificationsDialogSaveWorkspaceSharedTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Save workspace shared template'**
  String get notificationsDialogSaveWorkspaceSharedTemplateTitle;

  /// No description provided for @notificationsDialogEditTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit template: {id}'**
  String notificationsDialogEditTemplateTitle(String id);

  /// No description provided for @notificationsDialogDeleteTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete template: {label}'**
  String notificationsDialogDeleteTemplateTitle(String label);

  /// No description provided for @notificationsDialogDeleteTemplateBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Continue?'**
  String get notificationsDialogDeleteTemplateBody;

  /// No description provided for @notificationsDialogDeleteSharedTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete shared template: {label}'**
  String notificationsDialogDeleteSharedTemplateTitle(String label);

  /// No description provided for @notificationsDialogDeleteSharedTemplateBody.
  ///
  /// In en, this message translates to:
  /// **'This affects all members in the workspace. Continue?'**
  String get notificationsDialogDeleteSharedTemplateBody;

  /// No description provided for @notificationsDialogEditSharedTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit shared template: {id}'**
  String notificationsDialogEditSharedTemplateTitle(String id);

  /// No description provided for @notificationsFieldTemplateIdAscii.
  ///
  /// In en, this message translates to:
  /// **'Template ID (ASCII)'**
  String get notificationsFieldTemplateIdAscii;

  /// No description provided for @notificationsFieldTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get notificationsFieldTemplateName;

  /// No description provided for @notificationsFieldTemplateDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get notificationsFieldTemplateDescription;

  /// No description provided for @notificationsFieldImportMode.
  ///
  /// In en, this message translates to:
  /// **'Import mode'**
  String get notificationsFieldImportMode;

  /// No description provided for @notificationsFieldPasteTemplatesJson.
  ///
  /// In en, this message translates to:
  /// **'Paste templates JSON'**
  String get notificationsFieldPasteTemplatesJson;

  /// No description provided for @notificationsImportModeReplace.
  ///
  /// In en, this message translates to:
  /// **'replace (overwrite)'**
  String get notificationsImportModeReplace;

  /// No description provided for @notificationsImportModeMerge.
  ///
  /// In en, this message translates to:
  /// **'merge'**
  String get notificationsImportModeMerge;

  /// No description provided for @notificationsActionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get notificationsActionCancel;

  /// No description provided for @notificationsActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get notificationsActionSave;

  /// No description provided for @notificationsActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get notificationsActionDelete;

  /// No description provided for @notificationsActionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get notificationsActionImport;

  /// No description provided for @notificationsSnackTemplateIdAndNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Template ID and name cannot be empty.'**
  String get notificationsSnackTemplateIdAndNameRequired;

  /// No description provided for @notificationsSnackExportFiltersReused.
  ///
  /// In en, this message translates to:
  /// **'Reused that export’s filters and refreshed the audit list.'**
  String get notificationsSnackExportFiltersReused;

  /// No description provided for @notificationsSnackDownloadedByHistory.
  ///
  /// In en, this message translates to:
  /// **'Downloaded with history filters: {path}'**
  String notificationsSnackDownloadedByHistory(String path);

  /// No description provided for @notificationsSnackExportQueued.
  ///
  /// In en, this message translates to:
  /// **'Background export queued (task #{taskId}). History refreshes when it completes.'**
  String notificationsSnackExportQueued(int taskId);

  /// No description provided for @notificationsSnackSharedAuditJsonSaved.
  ///
  /// In en, this message translates to:
  /// **'Shared audit JSON saved: {path}'**
  String notificationsSnackSharedAuditJsonSaved(String path);

  /// No description provided for @notificationsSnackSharedAuditCsvSaved.
  ///
  /// In en, this message translates to:
  /// **'Shared audit CSV saved: {path}'**
  String notificationsSnackSharedAuditCsvSaved(String path);

  /// No description provided for @notificationsSnackTemplatesJsonCopied.
  ///
  /// In en, this message translates to:
  /// **'Templates JSON copied to clipboard.'**
  String get notificationsSnackTemplatesJsonCopied;

  /// No description provided for @notificationsDialogImportTemplatesJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'Import templates JSON'**
  String get notificationsDialogImportTemplatesJsonTitle;

  /// No description provided for @notificationsSnackImportDone.
  ///
  /// In en, this message translates to:
  /// **'Import finished: {count} templates.'**
  String notificationsSnackImportDone(int count);

  /// No description provided for @notificationsUnknownTime.
  ///
  /// In en, this message translates to:
  /// **'Unknown time'**
  String get notificationsUnknownTime;

  /// No description provided for @notificationsPrefsAuditUpdatedLine.
  ///
  /// In en, this message translates to:
  /// **'Policy last updated: {time} · {by} · {source}'**
  String notificationsPrefsAuditUpdatedLine(
    String time,
    String by,
    String source,
  );

  /// No description provided for @notificationsAuditActionUpsert.
  ///
  /// In en, this message translates to:
  /// **'Upsert'**
  String get notificationsAuditActionUpsert;

  /// No description provided for @notificationsAuditActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get notificationsAuditActionDelete;

  /// No description provided for @notificationsAuditAllActions.
  ///
  /// In en, this message translates to:
  /// **'All actions'**
  String get notificationsAuditAllActions;

  /// No description provided for @notificationsAuditAllTemplates.
  ///
  /// In en, this message translates to:
  /// **'All templates'**
  String get notificationsAuditAllTemplates;

  /// No description provided for @notificationsExportRecordLeadIn.
  ///
  /// In en, this message translates to:
  /// **'Export record:'**
  String get notificationsExportRecordLeadIn;

  /// No description provided for @notificationsExportDownloadAsyncArtifact.
  ///
  /// In en, this message translates to:
  /// **'Download the async export artifact'**
  String get notificationsExportDownloadAsyncArtifact;

  /// No description provided for @notificationsExportRedownloadSync.
  ///
  /// In en, this message translates to:
  /// **'Download again with the same filters (sync)'**
  String get notificationsExportRedownloadSync;

  /// No description provided for @notificationsExportDeliveryAsync.
  ///
  /// In en, this message translates to:
  /// **' · Async'**
  String get notificationsExportDeliveryAsync;

  /// No description provided for @notificationsExportDeliveryAsyncWithJob.
  ///
  /// In en, this message translates to:
  /// **' · Async (job: {jobId})'**
  String notificationsExportDeliveryAsyncWithJob(String jobId);

  /// No description provided for @notificationsExportDeliverySync.
  ///
  /// In en, this message translates to:
  /// **' · Sync'**
  String get notificationsExportDeliverySync;

  /// No description provided for @riskyPrefsMenuDefaultTooltip.
  ///
  /// In en, this message translates to:
  /// **'Local client preferences'**
  String get riskyPrefsMenuDefaultTooltip;

  /// No description provided for @riskyPrefsTooltipSameAsMainPanelHeaders.
  ///
  /// In en, this message translates to:
  /// **'Local client preferences (same ⋯ menu as beside each main panel title)'**
  String get riskyPrefsTooltipSameAsMainPanelHeaders;

  /// No description provided for @riskyPrefsMenuViewSilencesTitle.
  ///
  /// In en, this message translates to:
  /// **'View silenced high-risk confirmations'**
  String get riskyPrefsMenuViewSilencesTitle;

  /// No description provided for @riskyPrefsMenuViewSilencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read-only list; does not change settings'**
  String get riskyPrefsMenuViewSilencesSubtitle;

  /// No description provided for @riskyPrefsMenuResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore high-risk confirmation prompts'**
  String get riskyPrefsMenuResetTitle;

  /// No description provided for @riskyPrefsMenuResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This device only; unrelated to server settings'**
  String get riskyPrefsMenuResetSubtitle;

  /// No description provided for @riskyPrefsSummaryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Silenced high-risk confirmations'**
  String get riskyPrefsSummaryDialogTitle;

  /// No description provided for @riskyPrefsSummaryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No \"don\'t ask again\" choices are saved on this device.'**
  String get riskyPrefsSummaryEmptyBody;

  /// No description provided for @riskyPrefsSummaryNonEmptyIntro.
  ///
  /// In en, this message translates to:
  /// **'These actions will skip confirmation dialogs on this device (you can clear them anytime with \"Restore high-risk confirmation prompts\"):'**
  String get riskyPrefsSummaryNonEmptyIntro;

  /// No description provided for @riskyPrefsSummaryClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get riskyPrefsSummaryClose;

  /// No description provided for @riskyPrefsResetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore confirmation dialogs'**
  String get riskyPrefsResetDialogTitle;

  /// No description provided for @riskyPrefsResetBody.
  ///
  /// In en, this message translates to:
  /// **'This clears local \"don\'t ask again\" choices. Deletes, archive/publish, cancel export, and similar actions will show confirmations again (this app on this device only).'**
  String get riskyPrefsResetBody;

  /// No description provided for @riskyPrefsResetNoSavedLabel.
  ///
  /// In en, this message translates to:
  /// **'No saved \"don\'t ask again\" entries. You can still clear any leftover keys.'**
  String get riskyPrefsResetNoSavedLabel;

  /// No description provided for @riskyPrefsResetHasItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Currently silenced:'**
  String get riskyPrefsResetHasItemsLabel;

  /// No description provided for @riskyPrefsResetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get riskyPrefsResetCancel;

  /// No description provided for @riskyPrefsResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear and restore'**
  String get riskyPrefsResetConfirm;

  /// No description provided for @riskyPrefsResetSuccessSnack.
  ///
  /// In en, this message translates to:
  /// **'Cleared local \"don\'t ask again\" preferences for high-risk actions; confirmations will show again.'**
  String get riskyPrefsResetSuccessSnack;

  /// No description provided for @riskyPrefsLabelDeleteVersion.
  ///
  /// In en, this message translates to:
  /// **'Delete finished version'**
  String get riskyPrefsLabelDeleteVersion;

  /// No description provided for @riskyPrefsLabelBatchDisable.
  ///
  /// In en, this message translates to:
  /// **'Batch disable shots'**
  String get riskyPrefsLabelBatchDisable;

  /// No description provided for @riskyPrefsLabelRestoreDraft.
  ///
  /// In en, this message translates to:
  /// **'Restore draft overwrite'**
  String get riskyPrefsLabelRestoreDraft;

  /// No description provided for @riskyPrefsLabelCancelExport.
  ///
  /// In en, this message translates to:
  /// **'Cancel finished export'**
  String get riskyPrefsLabelCancelExport;

  /// No description provided for @riskyPrefsLabelBatchArchivePublish.
  ///
  /// In en, this message translates to:
  /// **'Batch archive/publish drafts'**
  String get riskyPrefsLabelBatchArchivePublish;

  /// No description provided for @platformConfigSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform configuration'**
  String get platformConfigSectionTitle;

  /// No description provided for @platformConfigSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage product shell feature switches and ops-facing visibility. effective merges as defaults <- plan override <- current workspace override <- user override.'**
  String get platformConfigSectionSubtitle;

  /// No description provided for @platformConfigLocalPrefsDescription.
  ///
  /// In en, this message translates to:
  /// **'These items affect only local storage for this app on this device, not server-side platform settings. To restore confirmations for deletes, archive, export, etc., use the ⋯ menu in the header above.'**
  String get platformConfigLocalPrefsDescription;

  /// No description provided for @platformConfigButtonRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get platformConfigButtonRefreshing;

  /// No description provided for @platformConfigButtonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Reload configuration'**
  String get platformConfigButtonRefresh;

  /// No description provided for @platformConfigButtonSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get platformConfigButtonSaving;

  /// No description provided for @platformConfigButtonSaveUser.
  ///
  /// In en, this message translates to:
  /// **'Save user overrides'**
  String get platformConfigButtonSaveUser;

  /// No description provided for @platformConfigButtonResetUser.
  ///
  /// In en, this message translates to:
  /// **'Reset user overrides'**
  String get platformConfigButtonResetUser;

  /// No description provided for @platformConfigButtonSaveWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Save workspace configuration'**
  String get platformConfigButtonSaveWorkspace;

  /// No description provided for @platformConfigButtonResetWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Reset workspace overrides'**
  String get platformConfigButtonResetWorkspace;

  /// No description provided for @platformConfigButtonCopyJson.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON'**
  String get platformConfigButtonCopyJson;

  /// No description provided for @platformConfigToggleHelpHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Help Hub'**
  String get platformConfigToggleHelpHubTitle;

  /// No description provided for @platformConfigToggleHelpHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show or hide help / documentation entry points'**
  String get platformConfigToggleHelpHubSubtitle;

  /// No description provided for @platformConfigToggleQualityMainTitle.
  ///
  /// In en, this message translates to:
  /// **'Quality dashboard'**
  String get platformConfigToggleQualityMainTitle;

  /// No description provided for @platformConfigToggleQualityMainSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quality ops board and main summary areas'**
  String get platformConfigToggleQualityMainSubtitle;

  /// No description provided for @platformConfigToggleQualityRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Quality refresh controls'**
  String get platformConfigToggleQualityRefreshTitle;

  /// No description provided for @platformConfigToggleQualityRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Materialized read-model refresh buttons and entry points'**
  String get platformConfigToggleQualityRefreshSubtitle;

  /// No description provided for @platformConfigTogglePlatformStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform status'**
  String get platformConfigTogglePlatformStatusTitle;

  /// No description provided for @platformConfigTogglePlatformStatusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Health / Ready / SLI / Metrics entry points'**
  String get platformConfigTogglePlatformStatusSubtitle;

  /// No description provided for @platformConfigToggleWorkspaceActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace activity'**
  String get platformConfigToggleWorkspaceActivityTitle;

  /// No description provided for @platformConfigToggleWorkspaceActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Agent workspace activity navigation entry'**
  String get platformConfigToggleWorkspaceActivitySubtitle;

  /// No description provided for @platformConfigToggleBenchmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Benchmark baseline'**
  String get platformConfigToggleBenchmarkTitle;

  /// No description provided for @platformConfigToggleBenchmarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Benchmark / evaluation product entry points'**
  String get platformConfigToggleBenchmarkSubtitle;

  /// No description provided for @platformConfigToggleJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'Jobs panel'**
  String get platformConfigToggleJobsTitle;

  /// No description provided for @platformConfigToggleJobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Jobs panel navigation entry'**
  String get platformConfigToggleJobsSubtitle;

  /// No description provided for @platformConfigPlanLayerIntro.
  ///
  /// In en, this message translates to:
  /// **'Plan tier is a read-only overlay from server environment config; use it to layer defaults before workspace / user fine-tuning.'**
  String get platformConfigPlanLayerIntro;

  /// No description provided for @platformConfigPlanStateActive.
  ///
  /// In en, this message translates to:
  /// **'Status: plan override is active'**
  String get platformConfigPlanStateActive;

  /// No description provided for @platformConfigPlanStateInactive.
  ///
  /// In en, this message translates to:
  /// **'Status: no plan override; inherits defaults'**
  String get platformConfigPlanStateInactive;

  /// No description provided for @platformConfigWorkspaceEnterpriseIntro.
  ///
  /// In en, this message translates to:
  /// **'Shared overlay for the current enterprise workspace; applied before personal settings in effective merge.'**
  String get platformConfigWorkspaceEnterpriseIntro;

  /// No description provided for @platformConfigWorkspaceViewOnlyIntro.
  ///
  /// In en, this message translates to:
  /// **'Shared overlay is shown read-only; only enterprise owner/admin can edit.'**
  String get platformConfigWorkspaceViewOnlyIntro;

  /// No description provided for @platformConfigWorkspaceStateWritten.
  ///
  /// In en, this message translates to:
  /// **'Status: workspace override is saved'**
  String get platformConfigWorkspaceStateWritten;

  /// No description provided for @platformConfigWorkspaceStateInherit.
  ///
  /// In en, this message translates to:
  /// **'Status: inherits defaults, then personal overrides'**
  String get platformConfigWorkspaceStateInherit;

  /// No description provided for @platformConfigWorkspaceNoDraftEnterprise.
  ///
  /// In en, this message translates to:
  /// **'No editable shared overlay for this workspace. Switch to an enterprise owner/admin account, or wait for shared overlay to be provisioned.'**
  String get platformConfigWorkspaceNoDraftEnterprise;

  /// No description provided for @platformConfigWorkspaceNoDraftPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal workspaces do not support a shared workspace-level overlay; only enterprise workspaces do.'**
  String get platformConfigWorkspaceNoDraftPersonal;

  /// No description provided for @platformConfigUserOverrideIntro.
  ///
  /// In en, this message translates to:
  /// **'Personal overlay is applied last—use it for your own ops view and tool preferences.'**
  String get platformConfigUserOverrideIntro;

  /// No description provided for @platformConfigUserStateWritten.
  ///
  /// In en, this message translates to:
  /// **'Status: user override is saved'**
  String get platformConfigUserStateWritten;

  /// No description provided for @platformConfigUserStateInherit.
  ///
  /// In en, this message translates to:
  /// **'Status: inherits workspace / defaults'**
  String get platformConfigUserStateInherit;

  /// No description provided for @platformConfigSnackUserSaved.
  ///
  /// In en, this message translates to:
  /// **'User platform configuration saved.'**
  String get platformConfigSnackUserSaved;

  /// No description provided for @platformConfigSnackUserReset.
  ///
  /// In en, this message translates to:
  /// **'User override cleared.'**
  String get platformConfigSnackUserReset;

  /// No description provided for @platformConfigSnackWorkspaceSaved.
  ///
  /// In en, this message translates to:
  /// **'Workspace platform configuration saved.'**
  String get platformConfigSnackWorkspaceSaved;

  /// No description provided for @platformConfigSnackWorkspaceReset.
  ///
  /// In en, this message translates to:
  /// **'Workspace override cleared.'**
  String get platformConfigSnackWorkspaceReset;

  /// No description provided for @platformConfigSnackCopyJsonDone.
  ///
  /// In en, this message translates to:
  /// **'Platform configuration JSON copied.'**
  String get platformConfigSnackCopyJsonDone;

  /// No description provided for @platformConfigPleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first'**
  String get platformConfigPleaseSignIn;

  /// No description provided for @productNavSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Product navigation'**
  String get productNavSectionTitle;

  /// No description provided for @productNavShortVideoSpace.
  ///
  /// In en, this message translates to:
  /// **'Short-video Space'**
  String get productNavShortVideoSpace;

  /// No description provided for @productNavProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get productNavProjects;

  /// No description provided for @productNavAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get productNavAccount;

  /// No description provided for @productNavApiKeys.
  ///
  /// In en, this message translates to:
  /// **'API keys'**
  String get productNavApiKeys;

  /// No description provided for @productNavNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get productNavNotifications;

  /// No description provided for @productNavContentCompliance.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get productNavContentCompliance;

  /// No description provided for @productNavPlatformStatus.
  ///
  /// In en, this message translates to:
  /// **'Platform status'**
  String get productNavPlatformStatus;

  /// No description provided for @productNavTeamWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Team workspaces'**
  String get productNavTeamWorkspaces;

  /// No description provided for @productNavScriptWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Script workspace'**
  String get productNavScriptWorkspace;

  /// No description provided for @productNavProductionWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Production workspace'**
  String get productNavProductionWorkspace;

  /// No description provided for @productNavWorkspaceActivity.
  ///
  /// In en, this message translates to:
  /// **'Workspace activity'**
  String get productNavWorkspaceActivity;

  /// No description provided for @productNavBenchmark.
  ///
  /// In en, this message translates to:
  /// **'Benchmark'**
  String get productNavBenchmark;

  /// No description provided for @productNavTasks.
  ///
  /// In en, this message translates to:
  /// **'Task center'**
  String get productNavTasks;

  /// No description provided for @productNavJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get productNavJobs;

  /// No description provided for @productNavQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get productNavQuality;

  /// No description provided for @productNavPlatformConfig.
  ///
  /// In en, this message translates to:
  /// **'Platform configuration'**
  String get productNavPlatformConfig;

  /// No description provided for @productNavHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get productNavHelp;

  /// No description provided for @productAgentScriptWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Script workspace'**
  String get productAgentScriptWorkspaceTitle;

  /// No description provided for @productAgentScriptWorkspaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Script Agent flow: context probes, sub-agent orchestration, and body/plan writeback.'**
  String get productAgentScriptWorkspaceSubtitle;

  /// No description provided for @productAgentProductionWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Production workspace'**
  String get productAgentProductionWorkspaceTitle;

  /// No description provided for @productAgentProductionWorkspaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Production Agent flow: flow data reads, asset/storyboard tools, and safe writeback.'**
  String get productAgentProductionWorkspaceSubtitle;

  /// No description provided for @productAgentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get productAgentActivityTitle;

  /// No description provided for @productAgentActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent WebSocket events, tool receipts, and writeback status in one execution log panel.'**
  String get productAgentActivitySubtitle;

  /// No description provided for @productPaneDisabledHelpHub.
  ///
  /// In en, this message translates to:
  /// **'Help Hub is disabled by platform configuration. Re-enable it under Platform configuration.'**
  String get productPaneDisabledHelpHub;

  /// No description provided for @productPaneDisabledQuality.
  ///
  /// In en, this message translates to:
  /// **'The quality dashboard is disabled by platform configuration. Re-enable it under Platform configuration.'**
  String get productPaneDisabledQuality;

  /// No description provided for @productPaneDisabledPlatformStatus.
  ///
  /// In en, this message translates to:
  /// **'Platform status is disabled by platform configuration. Re-enable it under Platform configuration.'**
  String get productPaneDisabledPlatformStatus;

  /// No description provided for @productPaneDisabledWorkspaceActivity.
  ///
  /// In en, this message translates to:
  /// **'Workspace activity is disabled by platform configuration. Re-enable it under Platform configuration.'**
  String get productPaneDisabledWorkspaceActivity;

  /// No description provided for @productPaneDisabledBenchmark.
  ///
  /// In en, this message translates to:
  /// **'Benchmark baseline is disabled by platform configuration. Re-enable it under Platform configuration.'**
  String get productPaneDisabledBenchmark;

  /// No description provided for @productPaneDisabledJobs.
  ///
  /// In en, this message translates to:
  /// **'The Jobs panel is disabled by platform configuration. Re-enable it under Platform configuration.'**
  String get productPaneDisabledJobs;

  /// No description provided for @productComplianceSnackAccountPanel.
  ///
  /// In en, this message translates to:
  /// **'Switched to Account panel. For user administration, prefer your internal admin console.'**
  String get productComplianceSnackAccountPanel;

  /// No description provided for @productComplianceSnackNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in; cannot open the target context.'**
  String get productComplianceSnackNotSignedIn;

  /// No description provided for @productComplianceTeamContext.
  ///
  /// In en, this message translates to:
  /// **'Switched to team workspace context: {detail}'**
  String productComplianceTeamContext(String detail);

  /// No description provided for @productComplianceNoProjectContext.
  ///
  /// In en, this message translates to:
  /// **'This report has no project context to open.'**
  String get productComplianceNoProjectContext;

  /// No description provided for @productComplianceOpenTargetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open target: {detail}'**
  String productComplianceOpenTargetFailed(String detail);

  /// No description provided for @platformConfigPlanOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan override'**
  String get platformConfigPlanOverrideTitle;

  /// No description provided for @platformConfigWorkspaceOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace override'**
  String get platformConfigWorkspaceOverrideTitle;

  /// No description provided for @platformConfigUserOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'User override'**
  String get platformConfigUserOverrideTitle;

  /// No description provided for @helpHubDocsTitle.
  ///
  /// In en, this message translates to:
  /// **'Help / docs'**
  String get helpHubDocsTitle;

  /// No description provided for @helpHubLocalRiskLine.
  ///
  /// In en, this message translates to:
  /// **'On this device: to restore high-risk confirmations (delete, archive, cancel export), use the ⋯ menu in the header (unrelated to server settings).'**
  String get helpHubLocalRiskLine;

  /// No description provided for @helpHubRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get helpHubRefresh;

  /// No description provided for @helpHubManageEntries.
  ///
  /// In en, this message translates to:
  /// **'Manage links'**
  String get helpHubManageEntries;

  /// No description provided for @helpHubLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get helpHubLoading;

  /// No description provided for @helpHubSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search help links (title / id / url)'**
  String get helpHubSearchLabel;

  /// No description provided for @helpHubNoEffectiveLinks.
  ///
  /// In en, this message translates to:
  /// **'No help links are available. Check settings/help/hub configuration.'**
  String get helpHubNoEffectiveLinks;

  /// No description provided for @helpHubSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No links match your search. Try different keywords.'**
  String get helpHubSearchEmpty;

  /// No description provided for @helpHubCopyLinkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get helpHubCopyLinkTooltip;

  /// No description provided for @helpHubCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied.'**
  String get helpHubCopied;

  /// No description provided for @helpHubCopyTitleUrlTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy title + URL'**
  String get helpHubCopyTitleUrlTooltip;

  /// No description provided for @helpHubCopiedHandoff.
  ///
  /// In en, this message translates to:
  /// **'Copied document handoff.'**
  String get helpHubCopiedHandoff;

  /// No description provided for @helpHubManageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage help links (personal / workspace)'**
  String get helpHubManageDialogTitle;

  /// No description provided for @helpHubManagePrecedence.
  ///
  /// In en, this message translates to:
  /// **'Effective order: personal override > workspace override > environment defaults.'**
  String get helpHubManagePrecedence;

  /// No description provided for @helpHubManageWorkspaceLocked.
  ///
  /// In en, this message translates to:
  /// **' (This workspace cannot configure workspace-level links; personal override only.)'**
  String get helpHubManageWorkspaceLocked;

  /// No description provided for @helpHubTabPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal override'**
  String get helpHubTabPersonal;

  /// No description provided for @helpHubTabWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace override'**
  String get helpHubTabWorkspace;

  /// No description provided for @helpHubFieldId.
  ///
  /// In en, this message translates to:
  /// **'id (dedupe / override key)'**
  String get helpHubFieldId;

  /// No description provided for @helpHubFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get helpHubFieldTitle;

  /// No description provided for @helpHubFieldUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get helpHubFieldUrl;

  /// No description provided for @helpHubHintId.
  ///
  /// In en, this message translates to:
  /// **'runbook-quality'**
  String get helpHubHintId;

  /// No description provided for @helpHubHintUrl.
  ///
  /// In en, this message translates to:
  /// **'https://docs.example.com/runbook'**
  String get helpHubHintUrl;

  /// No description provided for @helpHubAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get helpHubAdd;

  /// No description provided for @helpHubValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'id, title, and url are required.'**
  String get helpHubValidationRequired;

  /// No description provided for @helpHubNoCustomInScope.
  ///
  /// In en, this message translates to:
  /// **'No custom links in this scope.'**
  String get helpHubNoCustomInScope;

  /// No description provided for @helpHubDialogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get helpHubDialogClose;

  /// No description provided for @helpHubSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get helpHubSave;

  /// No description provided for @helpHubSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get helpHubSaving;

  /// No description provided for @helpHubCategoryRunbook.
  ///
  /// In en, this message translates to:
  /// **'Runbook'**
  String get helpHubCategoryRunbook;

  /// No description provided for @helpHubCategoryBillingWebhook.
  ///
  /// In en, this message translates to:
  /// **'Billing / Webhook'**
  String get helpHubCategoryBillingWebhook;

  /// No description provided for @helpHubCategoryWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get helpHubCategoryWorkspace;

  /// No description provided for @helpHubCategoryQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get helpHubCategoryQuality;

  /// No description provided for @helpHubCategoryStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get helpHubCategoryStatus;

  /// No description provided for @helpHubCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get helpHubCategoryGeneral;

  /// No description provided for @helpHubSummary.
  ///
  /// In en, this message translates to:
  /// **'Total {total} · Filtered {filtered}{extra}'**
  String helpHubSummary(int total, int filtered, String extra);

  /// No description provided for @helpHubSummaryCategoryCount.
  ///
  /// In en, this message translates to:
  /// **'{name}:{count}'**
  String helpHubSummaryCategoryCount(String name, int count);

  /// No description provided for @opsWhSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Outbound webhooks'**
  String get opsWhSectionTitle;

  /// No description provided for @opsWhErrorUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'URL is required.'**
  String get opsWhErrorUrlRequired;

  /// No description provided for @opsWhErrorWorkspaceId.
  ///
  /// In en, this message translates to:
  /// **'workspaceId must be a valid UUID or empty.'**
  String get opsWhErrorWorkspaceId;

  /// No description provided for @opsWhErrorWorkspaceIdPatch.
  ///
  /// In en, this message translates to:
  /// **'workspaceId must be a valid UUID, or clear the field to use global scope.'**
  String get opsWhErrorWorkspaceIdPatch;

  /// No description provided for @opsWhSnackCreated.
  ///
  /// In en, this message translates to:
  /// **'Created; secret copied to clipboard.'**
  String get opsWhSnackCreated;

  /// No description provided for @opsWhSnackEventsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Subscription events updated.'**
  String get opsWhSnackEventsUpdated;

  /// No description provided for @opsWhSnackDeliverOk.
  ///
  /// In en, this message translates to:
  /// **'Delivered (HTTP {status})'**
  String opsWhSnackDeliverOk(String status);

  /// No description provided for @opsWhSnackDeliverFail.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed: {detail}'**
  String opsWhSnackDeliverFail(String detail);

  /// No description provided for @opsWhSnackScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Scope set to global (no workspace filter).'**
  String get opsWhSnackScopeGlobal;

  /// No description provided for @opsWhSnackScopeWorkspaceUpdated.
  ///
  /// In en, this message translates to:
  /// **'workspaceId updated.'**
  String get opsWhSnackScopeWorkspaceUpdated;

  /// No description provided for @opsWhDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete webhook'**
  String get opsWhDeleteTitle;

  /// No description provided for @opsWhDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'You are about to delete webhook: {id}\nThis removes the destination URL.'**
  String opsWhDeleteBody(String id);

  /// No description provided for @opsWhDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get opsWhDeleteConfirm;

  /// No description provided for @opsWhDeleteConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete'**
  String get opsWhDeleteConfirmButton;

  /// No description provided for @opsWhLastTestOk.
  ///
  /// In en, this message translates to:
  /// **'Last test: success (HTTP {status})'**
  String opsWhLastTestOk(String status);

  /// No description provided for @opsWhLastTestFail.
  ///
  /// In en, this message translates to:
  /// **'Last test: failed (HTTP {status}) {error}'**
  String opsWhLastTestFail(String status, String error);

  /// No description provided for @opsWhInventoryLine.
  ///
  /// In en, this message translates to:
  /// **'Total {total} · Filtered {filtered} · Session tests OK {ok} · Failed {fail}{latestPart}'**
  String opsWhInventoryLine(
    int total,
    int filtered,
    int ok,
    int fail,
    String latestPart,
  );

  /// No description provided for @opsWhInventoryLatestPart.
  ///
  /// In en, this message translates to:
  /// **' · Latest: {id}'**
  String opsWhInventoryLatestPart(String id);

  /// No description provided for @opsWhEmptyNone.
  ///
  /// In en, this message translates to:
  /// **'No outbound webhooks yet. Create one above to test delivery and manage lifecycle.'**
  String get opsWhEmptyNone;

  /// No description provided for @opsWhEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No webhooks match your search. Adjust URL / id / createdAt keywords.'**
  String get opsWhEmptyFiltered;

  /// No description provided for @opsWhUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Webhook URL'**
  String get opsWhUrlLabel;

  /// No description provided for @opsWhUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/webhook'**
  String get opsWhUrlHint;

  /// No description provided for @opsWhSecretLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret (optional; server generates if empty)'**
  String get opsWhSecretLabel;

  /// No description provided for @opsWhWorkspaceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'workspaceId (optional)'**
  String get opsWhWorkspaceIdLabel;

  /// No description provided for @opsWhWorkspaceIdHint.
  ///
  /// In en, this message translates to:
  /// **'Only deliver events for this workspace; must be a UUID'**
  String get opsWhWorkspaceIdHint;

  /// No description provided for @opsWhSubscribeHint.
  ///
  /// In en, this message translates to:
  /// **'Subscribed events (select all = default; deselect types you do not need)'**
  String get opsWhSubscribeHint;

  /// No description provided for @opsWhTestEventTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Test eventType'**
  String get opsWhTestEventTypeLabel;

  /// No description provided for @opsWhTestEventTypeHint.
  ///
  /// In en, this message translates to:
  /// **'test.ping'**
  String get opsWhTestEventTypeHint;

  /// No description provided for @opsWhLatestCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest created webhook credentials'**
  String get opsWhLatestCreatedTitle;

  /// No description provided for @opsWhCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy ID'**
  String get opsWhCopyId;

  /// No description provided for @opsWhCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get opsWhCopyUrl;

  /// No description provided for @opsWhCopySecret.
  ///
  /// In en, this message translates to:
  /// **'Copy secret'**
  String get opsWhCopySecret;

  /// No description provided for @opsWhCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get opsWhCreate;

  /// No description provided for @opsWhCreating.
  ///
  /// In en, this message translates to:
  /// **'Requesting…'**
  String get opsWhCreating;

  /// No description provided for @opsWhRefreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get opsWhRefreshList;

  /// No description provided for @opsWhSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search webhooks (URL / id / createdAt)'**
  String get opsWhSearchLabel;

  /// No description provided for @opsWhRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get opsWhRecentActivity;

  /// No description provided for @opsWhCopyActivityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy record'**
  String get opsWhCopyActivityTooltip;

  /// No description provided for @opsWhActivityRecordSuffix.
  ///
  /// In en, this message translates to:
  /// **' webhook activity'**
  String get opsWhActivityRecordSuffix;

  /// No description provided for @opsWhChipLatestCreated.
  ///
  /// In en, this message translates to:
  /// **'Latest created'**
  String get opsWhChipLatestCreated;

  /// No description provided for @opsWhChipDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get opsWhChipDisabled;

  /// No description provided for @opsWhSubscribeHeading.
  ///
  /// In en, this message translates to:
  /// **'Subscribed events'**
  String get opsWhSubscribeHeading;

  /// No description provided for @opsWhScopeHeading.
  ///
  /// In en, this message translates to:
  /// **'Scope workspaceId (empty save = global)'**
  String get opsWhScopeHeading;

  /// No description provided for @opsWhScopeFieldHint.
  ///
  /// In en, this message translates to:
  /// **'UUID; empty means no workspace filter'**
  String get opsWhScopeFieldHint;

  /// No description provided for @opsWhSaveScope.
  ///
  /// In en, this message translates to:
  /// **'Save scope'**
  String get opsWhSaveScope;

  /// No description provided for @opsWhSavingScope.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get opsWhSavingScope;

  /// No description provided for @opsWhClearInput.
  ///
  /// In en, this message translates to:
  /// **'Clear input'**
  String get opsWhClearInput;

  /// No description provided for @opsWhRecentDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Recent deliveries'**
  String get opsWhRecentDeliveries;

  /// No description provided for @opsWhTooltipCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get opsWhTooltipCopyUrl;

  /// No description provided for @opsWhUrlCopiedSnack.
  ///
  /// In en, this message translates to:
  /// **'Webhook URL copied.'**
  String get opsWhUrlCopiedSnack;

  /// No description provided for @opsWhTestDeliver.
  ///
  /// In en, this message translates to:
  /// **'Test delivery'**
  String get opsWhTestDeliver;

  /// No description provided for @opsWhBusy.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get opsWhBusy;

  /// No description provided for @opsWhDeliveryLog.
  ///
  /// In en, this message translates to:
  /// **'Delivery log'**
  String get opsWhDeliveryLog;

  /// No description provided for @opsWhLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get opsWhLoading;

  /// No description provided for @opsWhDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get opsWhDelete;

  /// No description provided for @billingAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing webhook audit'**
  String get billingAuditTitle;

  /// No description provided for @billingAuditProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get billingAuditProviderLabel;

  /// No description provided for @billingAuditAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get billingAuditAll;

  /// No description provided for @billingAuditSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get billingAuditSortLabel;

  /// No description provided for @billingAuditSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get billingAuditSortNewest;

  /// No description provided for @billingAuditSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get billingAuditSortOldest;

  /// No description provided for @billingAuditOnlyInformational.
  ///
  /// In en, this message translates to:
  /// **'Informational only'**
  String get billingAuditOnlyInformational;

  /// No description provided for @billingAuditOnlyStateful.
  ///
  /// In en, this message translates to:
  /// **'Stateful only'**
  String get billingAuditOnlyStateful;

  /// No description provided for @billingAuditEventTypeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. invoice.paid / subscription.expired'**
  String get billingAuditEventTypeHint;

  /// No description provided for @billingAuditProviderEventIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. stripe:evt_123'**
  String get billingAuditProviderEventIdHint;

  /// No description provided for @billingAuditRawEventIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. evt_123'**
  String get billingAuditRawEventIdHint;

  /// No description provided for @billingAuditProviderPrefixHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. stripe:evt_'**
  String get billingAuditProviderPrefixHint;

  /// No description provided for @billingAuditRawPrefixHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. evt_'**
  String get billingAuditRawPrefixHint;

  /// No description provided for @billingAuditEventCreatedFromHint.
  ///
  /// In en, this message translates to:
  /// **'2026-04-01T00:00:00Z'**
  String get billingAuditEventCreatedFromHint;

  /// No description provided for @billingAuditEventCreatedToHint.
  ///
  /// In en, this message translates to:
  /// **'2026-04-30T23:59:59Z'**
  String get billingAuditEventCreatedToHint;

  /// No description provided for @billingAuditQuery.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get billingAuditQuery;

  /// No description provided for @billingAuditQuerying.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get billingAuditQuerying;

  /// No description provided for @billingAuditResetRefresh.
  ///
  /// In en, this message translates to:
  /// **'Reset and refresh'**
  String get billingAuditResetRefresh;

  /// No description provided for @billingAuditCopyCsv.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV'**
  String get billingAuditCopyCsv;

  /// No description provided for @billingAuditCsvCopiedSnack.
  ///
  /// In en, this message translates to:
  /// **'Current billing audit CSV copied.'**
  String get billingAuditCsvCopiedSnack;

  /// No description provided for @billingAuditCopyQuerySummary.
  ///
  /// In en, this message translates to:
  /// **'Copy query summary'**
  String get billingAuditCopyQuerySummary;

  /// No description provided for @billingAuditCopyQueryUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy query URL'**
  String get billingAuditCopyQueryUrl;

  /// No description provided for @billingAuditQueryUrlCopiedSnack.
  ///
  /// In en, this message translates to:
  /// **'Current query URL copied.'**
  String get billingAuditQueryUrlCopiedSnack;

  /// No description provided for @billingAuditCopyFullCsv.
  ///
  /// In en, this message translates to:
  /// **'Copy full CSV'**
  String get billingAuditCopyFullCsv;

  /// No description provided for @billingAuditExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get billingAuditExporting;

  /// No description provided for @billingAuditLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading billing audit…'**
  String get billingAuditLoading;

  /// No description provided for @billingAuditPageStats.
  ///
  /// In en, this message translates to:
  /// **'total={total} · loaded={loaded} · has_more={hasMore}'**
  String billingAuditPageStats(int total, int loaded, String hasMore);

  /// No description provided for @billingEmptyQuery.
  ///
  /// In en, this message translates to:
  /// **'No billing webhook events match this query. Adjust provider, event id, time window, or informational filters.'**
  String get billingEmptyQuery;

  /// No description provided for @billingAuditQuerySummaryCopied.
  ///
  /// In en, this message translates to:
  /// **'Query summary copied.'**
  String get billingAuditQuerySummaryCopied;

  /// No description provided for @billingAuditSnapshotCopied.
  ///
  /// In en, this message translates to:
  /// **'Audit snapshot copied.'**
  String get billingAuditSnapshotCopied;

  /// No description provided for @billingCopiedWithLabel.
  ///
  /// In en, this message translates to:
  /// **'Copied {label}.'**
  String billingCopiedWithLabel(String label);

  /// No description provided for @billingAuditFullCsvCopied.
  ///
  /// In en, this message translates to:
  /// **'Full billing audit CSV copied ({count} rows).'**
  String billingAuditFullCsvCopied(int count);

  /// No description provided for @billingSnapLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded: {count}'**
  String billingSnapLoaded(int count);

  /// No description provided for @billingSnapInformational.
  ///
  /// In en, this message translates to:
  /// **'Informational: {count}'**
  String billingSnapInformational(int count);

  /// No description provided for @billingSnapStateful.
  ///
  /// In en, this message translates to:
  /// **'Stateful: {count}'**
  String billingSnapStateful(int count);

  /// No description provided for @billingSnapProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers: {list}'**
  String billingSnapProviders(String list);

  /// No description provided for @billingSnapEventTypes.
  ///
  /// In en, this message translates to:
  /// **'Event types: {list}'**
  String billingSnapEventTypes(String list);

  /// No description provided for @billingAuditCurrentLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Current load summary'**
  String get billingAuditCurrentLoadTitle;

  /// No description provided for @billingAuditCopySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Copy audit snapshot'**
  String get billingAuditCopySnapshot;

  /// No description provided for @billingAuditCopyProviderEventId.
  ///
  /// In en, this message translates to:
  /// **'Copy provider_event_id'**
  String get billingAuditCopyProviderEventId;

  /// No description provided for @billingAuditCopyRawEventId.
  ///
  /// In en, this message translates to:
  /// **'Copy raw_event_id'**
  String get billingAuditCopyRawEventId;

  /// No description provided for @billingAuditFilterByProvider.
  ///
  /// In en, this message translates to:
  /// **'Filter by {provider}'**
  String billingAuditFilterByProvider(String provider);

  /// No description provided for @billingAuditFilterByEventType.
  ///
  /// In en, this message translates to:
  /// **'Filter by {eventType}'**
  String billingAuditFilterByEventType(String eventType);

  /// No description provided for @billingAuditOnlyThisEvent.
  ///
  /// In en, this message translates to:
  /// **'Only this event'**
  String get billingAuditOnlyThisEvent;

  /// No description provided for @billingAuditLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get billingAuditLoadMore;

  /// No description provided for @billingMetaProvider.
  ///
  /// In en, this message translates to:
  /// **'provider={value}'**
  String billingMetaProvider(String value);

  /// No description provided for @billingMetaType.
  ///
  /// In en, this message translates to:
  /// **'type={value}'**
  String billingMetaType(String value);

  /// No description provided for @billingMetaCreated.
  ///
  /// In en, this message translates to:
  /// **'created={value}'**
  String billingMetaCreated(String value);

  /// No description provided for @billingMetaEventCreated.
  ///
  /// In en, this message translates to:
  /// **'event_created={value}'**
  String billingMetaEventCreated(String value);

  /// No description provided for @billingMetaInformational.
  ///
  /// In en, this message translates to:
  /// **'informational'**
  String get billingMetaInformational;

  /// No description provided for @billingMetaStateful.
  ///
  /// In en, this message translates to:
  /// **'stateful'**
  String get billingMetaStateful;

  /// No description provided for @billingRowRawEventId.
  ///
  /// In en, this message translates to:
  /// **'raw_event_id={value}'**
  String billingRowRawEventId(String value);

  /// No description provided for @billingRowId.
  ///
  /// In en, this message translates to:
  /// **'id={value}'**
  String billingRowId(String value);

  /// No description provided for @billingChipCount.
  ///
  /// In en, this message translates to:
  /// **'{label} {count}'**
  String billingChipCount(String label, int count);

  /// No description provided for @projectsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsListTitle;

  /// No description provided for @projectsListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Load projects, summaries, art styles, and creative manuals, then open a project to keep editing.'**
  String get projectsListSubtitle;

  /// No description provided for @projectsSnackProjectCreated.
  ///
  /// In en, this message translates to:
  /// **'Project created'**
  String get projectsSnackProjectCreated;

  /// No description provided for @projectsSnackSignInArtStyles.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to load art styles.'**
  String get projectsSnackSignInArtStyles;

  /// No description provided for @projectsSnackSignInCreativeManuals.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to load creative manuals.'**
  String get projectsSnackSignInCreativeManuals;

  /// No description provided for @projectsSnackSignInAgentMemory.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to load Agent memory.'**
  String get projectsSnackSignInAgentMemory;

  /// No description provided for @projectsEnterpriseEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No projects in this team workspace yet'**
  String get projectsEnterpriseEmptyTitle;

  /// No description provided for @projectsEnterpriseEmptyUnnamedFallback.
  ///
  /// In en, this message translates to:
  /// **'This enterprise workspace'**
  String get projectsEnterpriseEmptyUnnamedFallback;

  /// No description provided for @projectsEnterpriseEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'{displayName} has no projects yet. Create an empty project as a team starting point, then open Team workspaces to invite members and assign collaboration scope.'**
  String projectsEnterpriseEmptyBody(String displayName);

  /// No description provided for @projectsCreateFirstEmpty.
  ///
  /// In en, this message translates to:
  /// **'Create an empty project'**
  String get projectsCreateFirstEmpty;

  /// No description provided for @projectsOpenTeamWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Open team workspaces'**
  String get projectsOpenTeamWorkspaces;

  /// No description provided for @projectsLoadProjectList.
  ///
  /// In en, this message translates to:
  /// **'Load projects'**
  String get projectsLoadProjectList;

  /// No description provided for @projectsViewSummary.
  ///
  /// In en, this message translates to:
  /// **'View project summary'**
  String get projectsViewSummary;

  /// No description provided for @projectsLoadArtStyles.
  ///
  /// In en, this message translates to:
  /// **'Load art styles'**
  String get projectsLoadArtStyles;

  /// No description provided for @projectsOpenArtStylesWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Open art styles workbench'**
  String get projectsOpenArtStylesWorkbench;

  /// No description provided for @projectsOpenCreativeManualsWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Open creative manuals workbench'**
  String get projectsOpenCreativeManualsWorkbench;

  /// No description provided for @projectsOpenAgentMemoryWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Open Agent memory workbench'**
  String get projectsOpenAgentMemoryWorkbench;

  /// No description provided for @projectsCreateEmptyProject.
  ///
  /// In en, this message translates to:
  /// **'New empty project'**
  String get projectsCreateEmptyProject;

  /// No description provided for @projectsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get projectsLoading;

  /// No description provided for @projectsCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get projectsCreating;

  /// No description provided for @projectsRequesting.
  ///
  /// In en, this message translates to:
  /// **'Requesting…'**
  String get projectsRequesting;

  /// No description provided for @projectsCompatibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Compatibility check'**
  String get projectsCompatibilityTitle;

  /// No description provided for @projectsCompatibilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keeps the first-project Agent memory probe as a regression entry point (collapsed by default).'**
  String get projectsCompatibilitySubtitle;

  /// No description provided for @projectsCompatibilityProbeMemory.
  ///
  /// In en, this message translates to:
  /// **'Probe first project memory'**
  String get projectsCompatibilityProbeMemory;

  /// No description provided for @projectsSummaryLinePrefix.
  ///
  /// In en, this message translates to:
  /// **'Project summary: '**
  String get projectsSummaryLinePrefix;

  /// No description provided for @projectsArtStylesLinePrefix.
  ///
  /// In en, this message translates to:
  /// **'Art styles: '**
  String get projectsArtStylesLinePrefix;

  /// No description provided for @projectsArtStyleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 art style} other{{count} art styles}}'**
  String projectsArtStyleCount(int count);

  /// No description provided for @projectsArtStylesManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get projectsArtStylesManage;

  /// No description provided for @projectsProjectCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 project} other{{count} projects}}'**
  String projectsProjectCount(int count);

  /// No description provided for @projectsUnnamedProject.
  ///
  /// In en, this message translates to:
  /// **'Project #{numericId}'**
  String projectsUnnamedProject(int numericId);

  /// No description provided for @projectsAgentMemoryPrefix.
  ///
  /// In en, this message translates to:
  /// **'Project memory: '**
  String get projectsAgentMemoryPrefix;

  /// No description provided for @projectsAccessModeRestricted.
  ///
  /// In en, this message translates to:
  /// **'Explicit ACL'**
  String get projectsAccessModeRestricted;

  /// No description provided for @projectsAccessModeInherited.
  ///
  /// In en, this message translates to:
  /// **'Inherited workspace'**
  String get projectsAccessModeInherited;

  /// No description provided for @projectsRoleWorkspaceOwner.
  ///
  /// In en, this message translates to:
  /// **'workspace owner'**
  String get projectsRoleWorkspaceOwner;

  /// No description provided for @projectsRoleWorkspaceAdmin.
  ///
  /// In en, this message translates to:
  /// **'workspace admin'**
  String get projectsRoleWorkspaceAdmin;

  /// No description provided for @projectsRoleProjectOwner.
  ///
  /// In en, this message translates to:
  /// **'project owner'**
  String get projectsRoleProjectOwner;

  /// No description provided for @projectsRoleEditor.
  ///
  /// In en, this message translates to:
  /// **'editor'**
  String get projectsRoleEditor;

  /// No description provided for @projectsRoleViewer.
  ///
  /// In en, this message translates to:
  /// **'viewer'**
  String get projectsRoleViewer;

  /// No description provided for @projectsRoleMember.
  ///
  /// In en, this message translates to:
  /// **'member'**
  String get projectsRoleMember;

  /// No description provided for @projectsDialogCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get projectsDialogCreateTitle;

  /// No description provided for @projectsDialogFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get projectsDialogFieldName;

  /// No description provided for @projectsDialogFieldIntro.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get projectsDialogFieldIntro;

  /// No description provided for @projectsDialogSectionBrief.
  ///
  /// In en, this message translates to:
  /// **'Project brief'**
  String get projectsDialogSectionBrief;

  /// No description provided for @projectsDialogFieldPremise.
  ///
  /// In en, this message translates to:
  /// **'Premise'**
  String get projectsDialogFieldPremise;

  /// No description provided for @projectsDialogFieldTargetAudience.
  ///
  /// In en, this message translates to:
  /// **'Target audience'**
  String get projectsDialogFieldTargetAudience;

  /// No description provided for @projectsDialogFieldEmotionalTone.
  ///
  /// In en, this message translates to:
  /// **'Emotional tone'**
  String get projectsDialogFieldEmotionalTone;

  /// No description provided for @projectsDialogFieldCoreHook.
  ///
  /// In en, this message translates to:
  /// **'Core hook'**
  String get projectsDialogFieldCoreHook;

  /// No description provided for @projectsDialogFieldVisualDirection.
  ///
  /// In en, this message translates to:
  /// **'Visual direction'**
  String get projectsDialogFieldVisualDirection;

  /// No description provided for @projectsDialogSectionBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand bible'**
  String get projectsDialogSectionBrand;

  /// No description provided for @shortVideoSpaceErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timeout{context}, please check network connection and retry.'**
  String shortVideoSpaceErrorTimeout(String context);

  /// No description provided for @shortVideoSpaceErrorOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed{context}: {error}'**
  String shortVideoSpaceErrorOperationFailed(String context, String error);

  /// No description provided for @shortVideoSpaceErrorConcurrentLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Concurrent workspace audit export limit reached, please wait for existing tasks to complete{context}.'**
  String shortVideoSpaceErrorConcurrentLimitExceeded(String context);

  /// No description provided for @shortVideoSpaceErrorRateLimitWithWait.
  ///
  /// In en, this message translates to:
  /// **'Too many requests{context}, {waitText}.'**
  String shortVideoSpaceErrorRateLimitWithWait(String context, String waitText);

  /// No description provided for @shortVideoSpaceErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Record not found{context}.'**
  String shortVideoSpaceErrorNotFound(String context);

  /// No description provided for @shortVideoSpaceErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied{context}, please check login status.'**
  String shortVideoSpaceErrorPermissionDenied(String context);

  /// No description provided for @shortVideoSpaceErrorBadRequest.
  ///
  /// In en, this message translates to:
  /// **'Bad request parameters'**
  String get shortVideoSpaceErrorBadRequest;

  /// No description provided for @shortVideoSpaceErrorBadRequestWithContext.
  ///
  /// In en, this message translates to:
  /// **'{message}{context}'**
  String shortVideoSpaceErrorBadRequestWithContext(
    String message,
    String context,
  );

  /// No description provided for @shortVideoSpaceErrorServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error{context}, please retry later.'**
  String shortVideoSpaceErrorServerError(String context);

  /// No description provided for @shortVideoSpaceErrorDetailedMessage.
  ///
  /// In en, this message translates to:
  /// **'{message}{context}'**
  String shortVideoSpaceErrorDetailedMessage(String message, String context);

  /// No description provided for @shortVideoSpaceErrorDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'Operation failed{context}: {error}'**
  String shortVideoSpaceErrorDefaultMessage(String context, String error);

  /// No description provided for @shortVideoSpaceErrorRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get shortVideoSpaceErrorRetryButton;

  /// No description provided for @shortVideoSpaceDialogExportHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Export History'**
  String get shortVideoSpaceDialogExportHistoryTitle;

  /// No description provided for @shortVideoSpaceDialogExportHistoryRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get shortVideoSpaceDialogExportHistoryRefresh;

  /// No description provided for @shortVideoSpaceDialogExportHistoryStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get shortVideoSpaceDialogExportHistoryStatusLabel;

  /// No description provided for @shortVideoSpaceDialogExportHistoryTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get shortVideoSpaceDialogExportHistoryTimeLabel;

  /// No description provided for @shortVideoSpaceDialogExportHistoryClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get shortVideoSpaceDialogExportHistoryClose;

  /// No description provided for @shortVideoSpaceDialogExportHistoryRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get shortVideoSpaceDialogExportHistoryRetry;

  /// No description provided for @shortVideoSpaceDialogExportHistoryNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No export records'**
  String get shortVideoSpaceDialogExportHistoryNoRecords;

  /// No description provided for @shortVideoSpaceDialogExportHistoryNoRecordsHint.
  ///
  /// In en, this message translates to:
  /// **'Export records will appear here after exporting videos'**
  String get shortVideoSpaceDialogExportHistoryNoRecordsHint;

  /// No description provided for @shortVideoSpaceDialogExportHistoryDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get shortVideoSpaceDialogExportHistoryDownload;

  /// No description provided for @shortVideoSpaceDialogExportHistoryDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get shortVideoSpaceDialogExportHistoryDownloading;

  /// No description provided for @shortVideoSpaceDialogExportHistoryTimeFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get shortVideoSpaceDialogExportHistoryTimeFilterAll;

  /// No description provided for @shortVideoSpaceDialogExportHistoryTimeFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get shortVideoSpaceDialogExportHistoryTimeFilterToday;

  /// No description provided for @shortVideoSpaceDialogExportHistoryTimeFilterWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get shortVideoSpaceDialogExportHistoryTimeFilterWeek;

  /// No description provided for @shortVideoSpaceDialogExportHistoryTimeFilterMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get shortVideoSpaceDialogExportHistoryTimeFilterMonth;

  /// No description provided for @shortVideoSpaceDialogExportHistoryStatusFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All status'**
  String get shortVideoSpaceDialogExportHistoryStatusFilterAll;

  /// No description provided for @shortVideoSpaceDialogExportHistoryStatusFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get shortVideoSpaceDialogExportHistoryStatusFilterCompleted;

  /// No description provided for @shortVideoSpaceDialogExportHistoryStatusFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get shortVideoSpaceDialogExportHistoryStatusFilterFailed;

  /// No description provided for @shortVideoSpaceDialogExportHistoryStatusFilterCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get shortVideoSpaceDialogExportHistoryStatusFilterCancelled;

  /// No description provided for @shortVideoSpaceDialogExportHistoryFileSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get shortVideoSpaceDialogExportHistoryFileSizeUnknown;

  /// No description provided for @shortVideoSpaceDialogExportHistoryFileSizeKB.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String shortVideoSpaceDialogExportHistoryFileSizeKB(String size);

  /// No description provided for @shortVideoSpaceDialogExportHistoryFileSizeMB.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String shortVideoSpaceDialogExportHistoryFileSizeMB(String size);

  /// No description provided for @shortVideoSpaceDialogExportHistoryFileSizeGB.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String shortVideoSpaceDialogExportHistoryFileSizeGB(String size);

  /// No description provided for @shortVideoSpaceDialogExportHistoryDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds'**
  String shortVideoSpaceDialogExportHistoryDurationSeconds(int seconds);

  /// No description provided for @shortVideoSpaceDialogExportHistoryDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String shortVideoSpaceDialogExportHistoryDurationMinutes(int minutes);

  /// No description provided for @shortVideoSpaceDialogExportHistoryDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours {minutes} minutes'**
  String shortVideoSpaceDialogExportHistoryDurationHours(
    int hours,
    int minutes,
  );

  /// No description provided for @shortVideoSpaceDialogExportHistoryCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created: {time}'**
  String shortVideoSpaceDialogExportHistoryCreatedAt(String time);

  /// No description provided for @shortVideoSpaceDialogExportHistoryCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed: {time} · Duration: {duration}'**
  String shortVideoSpaceDialogExportHistoryCompletedAt(
    String time,
    String duration,
  );

  /// No description provided for @shortVideoSpaceDialogExportHistoryFileSize.
  ///
  /// In en, this message translates to:
  /// **'File size: {size}'**
  String shortVideoSpaceDialogExportHistoryFileSize(String size);

  /// No description provided for @shortVideoSpaceDialogExportHistorySettings.
  ///
  /// In en, this message translates to:
  /// **'Settings: {bitrate} · {framerate} FPS'**
  String shortVideoSpaceDialogExportHistorySettings(
    String bitrate,
    int framerate,
  );

  /// No description provided for @shortVideoSpaceDialogExportHistoryLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load export history: {error}'**
  String shortVideoSpaceDialogExportHistoryLoadError(String error);

  /// No description provided for @shortVideoSpaceDialogExportHistorySessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please login again'**
  String get shortVideoSpaceDialogExportHistorySessionExpired;

  /// No description provided for @shortVideoSpaceDialogExportHistoryDownloadLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Download link copied ({format})'**
  String shortVideoSpaceDialogExportHistoryDownloadLinkCopied(String format);

  /// No description provided for @shortVideoSpaceDialogExportHistoryDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String shortVideoSpaceDialogExportHistoryDownloadFailed(String error);

  /// No description provided for @shortVideoSpaceDialogExportHistoryTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get shortVideoSpaceDialogExportHistoryTimeJustNow;

  /// No description provided for @shortVideoSpaceDialogExportHistoryTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes ago'**
  String shortVideoSpaceDialogExportHistoryTimeMinutesAgo(int minutes);

  /// No description provided for @shortVideoSpaceDialogExportHistoryTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours ago'**
  String shortVideoSpaceDialogExportHistoryTimeHoursAgo(int hours);

  /// No description provided for @shortVideoSpaceDialogExportHistoryTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String shortVideoSpaceDialogExportHistoryTimeDaysAgo(int days);

  /// No description provided for @projectsDialogFieldBrandName.
  ///
  /// In en, this message translates to:
  /// **'Brand name'**
  String get projectsDialogFieldBrandName;

  /// No description provided for @projectsDialogFieldBrandPromise.
  ///
  /// In en, this message translates to:
  /// **'Brand promise'**
  String get projectsDialogFieldBrandPromise;

  /// No description provided for @projectsDialogFieldVisualMotifsMultiline.
  ///
  /// In en, this message translates to:
  /// **'Visual motifs (one per line)'**
  String get projectsDialogFieldVisualMotifsMultiline;

  /// No description provided for @projectsDialogFieldForbiddenElementsMultiline.
  ///
  /// In en, this message translates to:
  /// **'Forbidden elements (one per line)'**
  String get projectsDialogFieldForbiddenElementsMultiline;

  /// No description provided for @projectsDialogFieldContinuityRulesMultiline.
  ///
  /// In en, this message translates to:
  /// **'Continuity rules (one per line)'**
  String get projectsDialogFieldContinuityRulesMultiline;

  /// No description provided for @projectsDialogCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get projectsDialogCreateButton;

  /// No description provided for @projectsBusyProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get projectsBusyProcessing;

  /// No description provided for @projectsArtWorkbenchTitle.
  ///
  /// In en, this message translates to:
  /// **'Art styles workbench'**
  String get projectsArtWorkbenchTitle;

  /// No description provided for @projectsArtWorkbenchIntro.
  ///
  /// In en, this message translates to:
  /// **'Refresh the list, inspect covers, edit prompts, and extract prompts from images—beyond list-only probes.'**
  String get projectsArtWorkbenchIntro;

  /// No description provided for @projectsArtWorkbenchReloadList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get projectsArtWorkbenchReloadList;

  /// No description provided for @projectsArtWorkbenchViewCover.
  ///
  /// In en, this message translates to:
  /// **'View cover'**
  String get projectsArtWorkbenchViewCover;

  /// No description provided for @projectsArtWorkbenchReadingCover.
  ///
  /// In en, this message translates to:
  /// **'Reading cover…'**
  String get projectsArtWorkbenchReadingCover;

  /// No description provided for @projectsArtWorkbenchNew.
  ///
  /// In en, this message translates to:
  /// **'New style'**
  String get projectsArtWorkbenchNew;

  /// No description provided for @projectsArtWorkbenchSave.
  ///
  /// In en, this message translates to:
  /// **'Save current style'**
  String get projectsArtWorkbenchSave;

  /// No description provided for @projectsArtWorkbenchDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete current style'**
  String get projectsArtWorkbenchDelete;

  /// No description provided for @projectsArtWorkbenchCurrentStyle.
  ///
  /// In en, this message translates to:
  /// **'Current style'**
  String get projectsArtWorkbenchCurrentStyle;

  /// No description provided for @projectsArtWorkbenchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No styles yet—fill the form below to create one.'**
  String get projectsArtWorkbenchEmptyHint;

  /// No description provided for @projectsArtWorkbenchFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get projectsArtWorkbenchFieldName;

  /// No description provided for @projectsArtWorkbenchFieldTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get projectsArtWorkbenchFieldTags;

  /// No description provided for @projectsArtWorkbenchFieldCoverUrl.
  ///
  /// In en, this message translates to:
  /// **'Cover URL / data URI'**
  String get projectsArtWorkbenchFieldCoverUrl;

  /// No description provided for @projectsArtWorkbenchFieldCoverUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Use a reachable URL or data:image/...;base64,...'**
  String get projectsArtWorkbenchFieldCoverUrlHelper;

  /// No description provided for @projectsArtWorkbenchFieldPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get projectsArtWorkbenchFieldPrompt;

  /// No description provided for @projectsArtWorkbenchExtractTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt extraction'**
  String get projectsArtWorkbenchExtractTitle;

  /// No description provided for @projectsArtWorkbenchExtractImagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Image inputs'**
  String get projectsArtWorkbenchExtractImagesLabel;

  /// No description provided for @projectsArtWorkbenchExtractImagesHelper.
  ///
  /// In en, this message translates to:
  /// **'Separate multiple URLs / data URIs with commas or newlines.'**
  String get projectsArtWorkbenchExtractImagesHelper;

  /// No description provided for @projectsArtWorkbenchExtractButton.
  ///
  /// In en, this message translates to:
  /// **'Extract prompt into editor'**
  String get projectsArtWorkbenchExtractButton;

  /// No description provided for @projectsArtWorkbenchCoverPreview.
  ///
  /// In en, this message translates to:
  /// **'Cover preview'**
  String get projectsArtWorkbenchCoverPreview;

  /// No description provided for @projectsCreativeManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Creative manuals workbench'**
  String get projectsCreativeManualTitle;

  /// No description provided for @projectsCreativeManualIntro.
  ///
  /// In en, this message translates to:
  /// **'Manage director and visual manuals in one place: refresh, create, update, and delete.'**
  String get projectsCreativeManualIntro;

  /// No description provided for @projectsCreativeManualSegmentDirector.
  ///
  /// In en, this message translates to:
  /// **'Director manual'**
  String get projectsCreativeManualSegmentDirector;

  /// No description provided for @projectsCreativeManualSegmentVisual.
  ///
  /// In en, this message translates to:
  /// **'Visual manual'**
  String get projectsCreativeManualSegmentVisual;

  /// No description provided for @projectsCreativeManualReloadAll.
  ///
  /// In en, this message translates to:
  /// **'Reload all manuals'**
  String get projectsCreativeManualReloadAll;

  /// No description provided for @projectsCreativeManualPathDirectorFolder.
  ///
  /// In en, this message translates to:
  /// **'directorManual folder'**
  String get projectsCreativeManualPathDirectorFolder;

  /// No description provided for @projectsCreativeManualPathVisual.
  ///
  /// In en, this message translates to:
  /// **'stylePath'**
  String get projectsCreativeManualPathVisual;

  /// No description provided for @projectsCreativeManualSelectionDirector.
  ///
  /// In en, this message translates to:
  /// **'Current director manual'**
  String get projectsCreativeManualSelectionDirector;

  /// No description provided for @projectsCreativeManualSelectionVisual.
  ///
  /// In en, this message translates to:
  /// **'Current visual manual'**
  String get projectsCreativeManualSelectionVisual;

  /// No description provided for @projectsCreativeManualCreateDirector.
  ///
  /// In en, this message translates to:
  /// **'New director manual'**
  String get projectsCreativeManualCreateDirector;

  /// No description provided for @projectsCreativeManualCreateVisual.
  ///
  /// In en, this message translates to:
  /// **'New visual manual'**
  String get projectsCreativeManualCreateVisual;

  /// No description provided for @projectsCreativeManualSaveDirector.
  ///
  /// In en, this message translates to:
  /// **'Save director manual'**
  String get projectsCreativeManualSaveDirector;

  /// No description provided for @projectsCreativeManualSaveVisual.
  ///
  /// In en, this message translates to:
  /// **'Save visual manual'**
  String get projectsCreativeManualSaveVisual;

  /// No description provided for @projectsCreativeManualDeleteDirector.
  ///
  /// In en, this message translates to:
  /// **'Delete director manual'**
  String get projectsCreativeManualDeleteDirector;

  /// No description provided for @projectsCreativeManualDeleteVisual.
  ///
  /// In en, this message translates to:
  /// **'Delete visual manual'**
  String get projectsCreativeManualDeleteVisual;

  /// No description provided for @projectsCreativeManualEmptyKind.
  ///
  /// In en, this message translates to:
  /// **'No manuals of this type yet—create one with the form below.'**
  String get projectsCreativeManualEmptyKind;

  /// No description provided for @projectsCreativeManualFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get projectsCreativeManualFieldName;

  /// No description provided for @projectsCreativeManualFieldImagesList.
  ///
  /// In en, this message translates to:
  /// **'Images list'**
  String get projectsCreativeManualFieldImagesList;

  /// No description provided for @projectsCreativeManualFieldImagesHelper.
  ///
  /// In en, this message translates to:
  /// **'Separate URLs / paths with commas or newlines.'**
  String get projectsCreativeManualFieldImagesHelper;

  /// No description provided for @projectsCreativeManualFieldSlots.
  ///
  /// In en, this message translates to:
  /// **'Data slots'**
  String get projectsCreativeManualFieldSlots;

  /// No description provided for @projectsCreativeManualFieldSlotsHelper.
  ///
  /// In en, this message translates to:
  /// **'One slot per line: label|value|data'**
  String get projectsCreativeManualFieldSlotsHelper;

  /// No description provided for @projectsCreativeManualSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get projectsCreativeManualSummaryTitle;

  /// No description provided for @projectsCreativeManualSummaryLine.
  ///
  /// In en, this message translates to:
  /// **'{name} · Path {path} · Images {imageCount} · Slots {slotCount}'**
  String projectsCreativeManualSummaryLine(
    String name,
    String path,
    int imageCount,
    int slotCount,
  );

  /// No description provided for @projectsCreativeManualStatusRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing creative manuals…'**
  String get projectsCreativeManualStatusRefreshing;

  /// No description provided for @projectsCreativeManualStatusReloadOk.
  ///
  /// In en, this message translates to:
  /// **'Director {directorCount} · Visual {visualCount} · visual GET/POST={getCount}/{postCount}'**
  String projectsCreativeManualStatusReloadOk(
    int directorCount,
    int visualCount,
    int getCount,
    int postCount,
  );

  /// No description provided for @projectsCreativeManualStatusReloadFail.
  ///
  /// In en, this message translates to:
  /// **'Reload failed: {detail}'**
  String projectsCreativeManualStatusReloadFail(String detail);

  /// No description provided for @projectsCreativeManualStatusCreateNeedFields.
  ///
  /// In en, this message translates to:
  /// **'Create failed: name and path are required.'**
  String get projectsCreativeManualStatusCreateNeedFields;

  /// No description provided for @projectsCreativeManualStatusCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating manual…'**
  String get projectsCreativeManualStatusCreating;

  /// No description provided for @projectsCreativeManualStatusCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {kind}: {path}'**
  String projectsCreativeManualStatusCreated(String kind, String path);

  /// No description provided for @projectsCreativeManualStatusSaveNeedSelect.
  ///
  /// In en, this message translates to:
  /// **'Save failed: select a manual first.'**
  String get projectsCreativeManualStatusSaveNeedSelect;

  /// No description provided for @projectsCreativeManualStatusSaveNeedFields.
  ///
  /// In en, this message translates to:
  /// **'Save failed: name and path are required.'**
  String get projectsCreativeManualStatusSaveNeedFields;

  /// No description provided for @projectsCreativeManualStatusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving manual…'**
  String get projectsCreativeManualStatusSaving;

  /// No description provided for @projectsCreativeManualStatusSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {kind}: {path}'**
  String projectsCreativeManualStatusSaved(String kind, String path);

  /// No description provided for @projectsCreativeManualStatusDeleteNeedSelect.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: select a manual first.'**
  String get projectsCreativeManualStatusDeleteNeedSelect;

  /// No description provided for @projectsCreativeManualStatusDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting manual…'**
  String get projectsCreativeManualStatusDeleting;

  /// No description provided for @projectsCreativeManualStatusDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {kind}: {path}'**
  String projectsCreativeManualStatusDeleted(String kind, String path);

  /// No description provided for @projectsCreativeManualStatusOpFail.
  ///
  /// In en, this message translates to:
  /// **'{verb} failed: {detail}'**
  String projectsCreativeManualStatusOpFail(String verb, String detail);

  /// No description provided for @projectsCreativeManualKindDirector.
  ///
  /// In en, this message translates to:
  /// **'Director manual'**
  String get projectsCreativeManualKindDirector;

  /// No description provided for @projectsCreativeManualKindVisual.
  ///
  /// In en, this message translates to:
  /// **'Visual manual'**
  String get projectsCreativeManualKindVisual;

  /// No description provided for @projectsCreativeManualInvalidSlotLine.
  ///
  /// In en, this message translates to:
  /// **'Invalid slot line (expected label|value|data): {line}'**
  String projectsCreativeManualInvalidSlotLine(String line);

  /// No description provided for @agentMemoryWorkbenchTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent memory workbench'**
  String get agentMemoryWorkbenchTitle;

  /// No description provided for @agentMemoryWorkbenchIntro.
  ///
  /// In en, this message translates to:
  /// **'Query, append, and clear project-scoped script/production Agent memory—without relying on the first-project probe only.'**
  String get agentMemoryWorkbenchIntro;

  /// No description provided for @agentMemoryReloadProjects.
  ///
  /// In en, this message translates to:
  /// **'Reload projects'**
  String get agentMemoryReloadProjects;

  /// No description provided for @agentMemoryQueryMemory.
  ///
  /// In en, this message translates to:
  /// **'Query memory'**
  String get agentMemoryQueryMemory;

  /// No description provided for @agentMemoryLoadCostOverview.
  ///
  /// In en, this message translates to:
  /// **'Load cost overview'**
  String get agentMemoryLoadCostOverview;

  /// No description provided for @agentMemoryOptimizeVideo.
  ///
  /// In en, this message translates to:
  /// **'Optimize video memory'**
  String get agentMemoryOptimizeVideo;

  /// No description provided for @agentMemoryProjectsPreviewLine.
  ///
  /// In en, this message translates to:
  /// **'{count} projects · {preview}{ellipsis}'**
  String agentMemoryProjectsPreviewLine(
    int count,
    String preview,
    String ellipsis,
  );

  /// No description provided for @agentMemoryUnnamedProject.
  ///
  /// In en, this message translates to:
  /// **'Unnamed project'**
  String get agentMemoryUnnamedProject;

  /// No description provided for @agentMemoryFieldProjectNumericId.
  ///
  /// In en, this message translates to:
  /// **'Project numeric ID'**
  String get agentMemoryFieldProjectNumericId;

  /// No description provided for @agentMemoryFieldAgentType.
  ///
  /// In en, this message translates to:
  /// **'Agent type'**
  String get agentMemoryFieldAgentType;

  /// No description provided for @agentMemoryFieldEpisodesIdOptional.
  ///
  /// In en, this message translates to:
  /// **'Episodes id (optional)'**
  String get agentMemoryFieldEpisodesIdOptional;

  /// No description provided for @agentMemoryFieldScopeSignatureOptional.
  ///
  /// In en, this message translates to:
  /// **'scopeSignature JSON (optional)'**
  String get agentMemoryFieldScopeSignatureOptional;

  /// No description provided for @agentMemoryFieldScopeSignatureHelper.
  ///
  /// In en, this message translates to:
  /// **'JSON object; typical keys: episodeId, storyboardIds, focusSections'**
  String get agentMemoryFieldScopeSignatureHelper;

  /// No description provided for @agentMemoryFieldQueryType.
  ///
  /// In en, this message translates to:
  /// **'Query type'**
  String get agentMemoryFieldQueryType;

  /// No description provided for @agentMemoryFieldQueryTypeHelper.
  ///
  /// In en, this message translates to:
  /// **'summary / message / all'**
  String get agentMemoryFieldQueryTypeHelper;

  /// No description provided for @agentMemoryFieldMemoryTier.
  ///
  /// In en, this message translates to:
  /// **'Memory tier'**
  String get agentMemoryFieldMemoryTier;

  /// No description provided for @agentMemoryFieldMemoryTierHelper.
  ///
  /// In en, this message translates to:
  /// **'all / style_bible / stage_summary / delta_memory / message'**
  String get agentMemoryFieldMemoryTierHelper;

  /// No description provided for @agentMemoryFieldAutomationMode.
  ///
  /// In en, this message translates to:
  /// **'Automation mode'**
  String get agentMemoryFieldAutomationMode;

  /// No description provided for @agentMemoryFieldAutomationModeHelper.
  ///
  /// In en, this message translates to:
  /// **'standard / lean / off'**
  String get agentMemoryFieldAutomationModeHelper;

  /// No description provided for @agentMemoryIsolateHint.
  ///
  /// In en, this message translates to:
  /// **'Automatic memory is isolated by project numeric ID + agent type + episodes id.'**
  String get agentMemoryIsolateHint;

  /// No description provided for @agentMemoryOptimizeScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Optimization only affects productionAgent + episodes id scoped selected video memory; it is not shared across users, projects, or shorts.'**
  String get agentMemoryOptimizeScopeHint;

  /// No description provided for @agentMemoryOptimizeEnableHint.
  ///
  /// In en, this message translates to:
  /// **'To enable optimization, set agent type to productionAgent and fill episodes id.'**
  String get agentMemoryOptimizeEnableHint;

  /// No description provided for @agentMemoryRecommendationPrefix.
  ///
  /// In en, this message translates to:
  /// **'Suggestion: '**
  String get agentMemoryRecommendationPrefix;

  /// No description provided for @agentMemoryCopyChecklistTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy execution checklist'**
  String get agentMemoryCopyChecklistTooltip;

  /// No description provided for @agentMemoryChecklistCopiedSnack.
  ///
  /// In en, this message translates to:
  /// **'Execution checklist copied.'**
  String get agentMemoryChecklistCopiedSnack;

  /// No description provided for @agentMemoryAppendSection.
  ///
  /// In en, this message translates to:
  /// **'Append memory'**
  String get agentMemoryAppendSection;

  /// No description provided for @agentMemoryFieldAppendType.
  ///
  /// In en, this message translates to:
  /// **'Append type'**
  String get agentMemoryFieldAppendType;

  /// No description provided for @agentMemoryFieldAppendTypeHelper.
  ///
  /// In en, this message translates to:
  /// **'message / summary'**
  String get agentMemoryFieldAppendTypeHelper;

  /// No description provided for @agentMemoryFieldAppendMemoryTier.
  ///
  /// In en, this message translates to:
  /// **'Append memory tier'**
  String get agentMemoryFieldAppendMemoryTier;

  /// No description provided for @agentMemoryFieldAppendMemoryTierHelper.
  ///
  /// In en, this message translates to:
  /// **'style_bible / stage_summary / delta_memory / message'**
  String get agentMemoryFieldAppendMemoryTierHelper;

  /// No description provided for @agentMemoryFieldRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get agentMemoryFieldRole;

  /// No description provided for @agentMemoryFieldNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get agentMemoryFieldNameOptional;

  /// No description provided for @agentMemoryAppendButton.
  ///
  /// In en, this message translates to:
  /// **'Append with current scope'**
  String get agentMemoryAppendButton;

  /// No description provided for @agentMemoryFieldMemoryContent.
  ///
  /// In en, this message translates to:
  /// **'Memory content'**
  String get agentMemoryFieldMemoryContent;

  /// No description provided for @agentMemoryClearSection.
  ///
  /// In en, this message translates to:
  /// **'Clear memory'**
  String get agentMemoryClearSection;

  /// No description provided for @agentMemoryFieldClearType.
  ///
  /// In en, this message translates to:
  /// **'Clear type'**
  String get agentMemoryFieldClearType;

  /// No description provided for @agentMemoryFieldClearTypeHelper.
  ///
  /// In en, this message translates to:
  /// **'summary / message / all'**
  String get agentMemoryFieldClearTypeHelper;

  /// No description provided for @agentMemoryClearRun.
  ///
  /// In en, this message translates to:
  /// **'Run clear'**
  String get agentMemoryClearRun;

  /// No description provided for @agentMemoryDuplicateChip.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get agentMemoryDuplicateChip;

  /// No description provided for @agentMemoryTierGroupHeader.
  ///
  /// In en, this message translates to:
  /// **'{label} · {count} rows · Last injected {last}'**
  String agentMemoryTierGroupHeader(String label, int count, String last);

  /// No description provided for @agentMemoryMemoryRowCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 memory row} other{{count} memory rows}}'**
  String agentMemoryMemoryRowCount(int count);

  /// No description provided for @agentMemoryCharsAbbr.
  ///
  /// In en, this message translates to:
  /// **'{n} chars'**
  String agentMemoryCharsAbbr(int n);

  /// No description provided for @agentMemorySubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'subject {value}'**
  String agentMemorySubjectLabel(String value);

  /// No description provided for @agentMemorySignalsLabel.
  ///
  /// In en, this message translates to:
  /// **'signals {value}'**
  String agentMemorySignalsLabel(String value);

  /// No description provided for @agentMemoryTierAll.
  ///
  /// In en, this message translates to:
  /// **'All tiers'**
  String get agentMemoryTierAll;

  /// No description provided for @agentMemoryTierStyleBible.
  ///
  /// In en, this message translates to:
  /// **'Style bible'**
  String get agentMemoryTierStyleBible;

  /// No description provided for @agentMemoryTierStageSummary.
  ///
  /// In en, this message translates to:
  /// **'Stage summary'**
  String get agentMemoryTierStageSummary;

  /// No description provided for @agentMemoryTierDeltaMemory.
  ///
  /// In en, this message translates to:
  /// **'Delta memory'**
  String get agentMemoryTierDeltaMemory;

  /// No description provided for @agentMemoryTierMessage.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get agentMemoryTierMessage;

  /// No description provided for @agentMemoryClassNegative.
  ///
  /// In en, this message translates to:
  /// **'Negative constraints'**
  String get agentMemoryClassNegative;

  /// No description provided for @agentMemoryClassDeliveryVisual.
  ///
  /// In en, this message translates to:
  /// **'Delivery + visual'**
  String get agentMemoryClassDeliveryVisual;

  /// No description provided for @agentMemoryClassDeliveryFirst.
  ///
  /// In en, this message translates to:
  /// **'Delivery-first'**
  String get agentMemoryClassDeliveryFirst;

  /// No description provided for @agentMemoryClassVisualHeavy.
  ///
  /// In en, this message translates to:
  /// **'Visual-heavy'**
  String get agentMemoryClassVisualHeavy;

  /// No description provided for @agentMemoryClassVideoMemory.
  ///
  /// In en, this message translates to:
  /// **'Video memory'**
  String get agentMemoryClassVideoMemory;

  /// No description provided for @agentMemoryActionMergeNegative.
  ///
  /// In en, this message translates to:
  /// **'Merge negatives'**
  String get agentMemoryActionMergeNegative;

  /// No description provided for @agentMemoryActionObserve.
  ///
  /// In en, this message translates to:
  /// **'Observe'**
  String get agentMemoryActionObserve;

  /// No description provided for @agentMemoryActionCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get agentMemoryActionCompress;

  /// No description provided for @agentMemoryActionKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get agentMemoryActionKeep;

  /// No description provided for @agentMemoryInsightCore.
  ///
  /// In en, this message translates to:
  /// **'Roles: {roles}{typesPart} · ~{totalChars} chars · longest {longestChars} chars{dupPart}'**
  String agentMemoryInsightCore(
    String roles,
    String typesPart,
    int totalChars,
    int longestChars,
    String dupPart,
  );

  /// No description provided for @agentMemoryInsightTypesPart.
  ///
  /// In en, this message translates to:
  /// **' · Types: {detail}'**
  String agentMemoryInsightTypesPart(String detail);

  /// No description provided for @agentMemoryInsightDupPart.
  ///
  /// In en, this message translates to:
  /// **' · Duplicates: {count}'**
  String agentMemoryInsightDupPart(int count);

  /// No description provided for @agentMemoryVideoInsight.
  ///
  /// In en, this message translates to:
  /// **'Video memory: delivery {dRows}/{dChars} chars · visual {vRows}/{vChars} chars · negative {nRows}/{nChars} chars'**
  String agentMemoryVideoInsight(
    int dRows,
    int dChars,
    int vRows,
    int vChars,
    int nRows,
    int nChars,
  );

  /// No description provided for @agentMemoryEfficiencyInsight.
  ///
  /// In en, this message translates to:
  /// **'Plan: keep {kRows}/{kChars} chars · trim {tRows}/{tChars} chars · merge negatives {mRows}/{mChars} chars'**
  String agentMemoryEfficiencyInsight(
    int kRows,
    int kChars,
    int tRows,
    int tChars,
    int mRows,
    int mChars,
  );

  /// No description provided for @agentMemoryBucketPriorityLine.
  ///
  /// In en, this message translates to:
  /// **'Bucket priority: {detail}'**
  String agentMemoryBucketPriorityLine(String detail);

  /// No description provided for @agentMemoryBucketPriorityItem.
  ///
  /// In en, this message translates to:
  /// **'{action} {name} · {rows} rows / {chars} chars'**
  String agentMemoryBucketPriorityItem(
    String action,
    String name,
    int rows,
    int chars,
  );

  /// No description provided for @agentMemoryCostNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get agentMemoryCostNever;

  /// No description provided for @agentMemoryCostOverviewLine.
  ///
  /// In en, this message translates to:
  /// **'scope={scope} · Cost: style bible {sb} · stage summary {ss} · delta {dm} · messages {msg} · avg injected (30) {avgInj} chars · avg hit tiers (30) {avgHit} · last injected {last}'**
  String agentMemoryCostOverviewLine(
    String scope,
    int sb,
    int ss,
    int dm,
    int msg,
    int avgInj,
    int avgHit,
    String last,
  );

  /// No description provided for @agentMemoryChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Execution checklist:'**
  String get agentMemoryChecklistTitle;

  /// No description provided for @agentMemoryChecklistScope.
  ///
  /// In en, this message translates to:
  /// **'Scope: only memories for {scope}; do not reuse across users, projects, or shorts.'**
  String agentMemoryChecklistScope(String scope);

  /// No description provided for @agentMemoryChecklistScopeFallback.
  ///
  /// In en, this message translates to:
  /// **'current query scope'**
  String get agentMemoryChecklistScopeFallback;

  /// No description provided for @agentMemoryChecklistCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress filler shots/lighting in {name}; keep delivery, tone, emotion, and character consistency.'**
  String agentMemoryChecklistCompress(String name);

  /// No description provided for @agentMemoryChecklistMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge duplicate risk/avoid constraints in {name}; keep the strongest guardrails against continuity breaks.'**
  String agentMemoryChecklistMerge(String name);

  /// No description provided for @agentMemoryChecklistKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep the strongest delivery/emotion anchors in {name}; avoid deleting cues that keep performances natural.'**
  String agentMemoryChecklistKeep(String name);

  /// No description provided for @agentMemoryChecklistObserve.
  ///
  /// In en, this message translates to:
  /// **'Watch new entries in {name}; avoid stacking duplicates.'**
  String agentMemoryChecklistObserve(String name);

  /// No description provided for @agentMemoryChecklistReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder: {text}'**
  String agentMemoryChecklistReminder(String text);

  /// No description provided for @agentMemoryRecDup.
  ///
  /// In en, this message translates to:
  /// **'Duplicates detected—dedupe older memories so constraints are not injected repeatedly.'**
  String get agentMemoryRecDup;

  /// No description provided for @agentMemoryRecVisualOnly.
  ///
  /// In en, this message translates to:
  /// **'Video memory is mostly framing/lighting—add a delivery, tone, or emotion anchor before deleting visual rows.'**
  String get agentMemoryRecVisualOnly;

  /// No description provided for @agentMemoryRecVisualBudget.
  ///
  /// In en, this message translates to:
  /// **'Visual-heavy rows consume budget—trim old framing/lighting entries and reserve chars for delivery and emotion.'**
  String get agentMemoryRecVisualBudget;

  /// No description provided for @agentMemoryRecNegativeMerge.
  ///
  /// In en, this message translates to:
  /// **'Many negative constraints—merge duplicate risk/avoid snippets before negative memory balloons.'**
  String get agentMemoryRecNegativeMerge;

  /// No description provided for @agentMemoryRecBucketHot.
  ///
  /// In en, this message translates to:
  /// **'{name} already has {count} rows—compress that bucket first so it does not dominate budget.'**
  String agentMemoryRecBucketHot(String name, int count);

  /// No description provided for @agentMemoryRecLong.
  ///
  /// In en, this message translates to:
  /// **'Memory is long—compress the longest rows before appending more.'**
  String get agentMemoryRecLong;

  /// No description provided for @agentMemoryRecManyRows.
  ///
  /// In en, this message translates to:
  /// **'Many rows—read summaries or clear old messages to budget for current shots.'**
  String get agentMemoryRecManyRows;

  /// No description provided for @agentMemoryRecAssistantHeavy.
  ///
  /// In en, this message translates to:
  /// **'Many assistant summaries—clear older ones and keep the latest execution constraints.'**
  String get agentMemoryRecAssistantHeavy;

  /// No description provided for @agentMemorySignalSubject.
  ///
  /// In en, this message translates to:
  /// **'subject'**
  String get agentMemorySignalSubject;

  /// No description provided for @agentMemorySignalEmotion.
  ///
  /// In en, this message translates to:
  /// **'emotion'**
  String get agentMemorySignalEmotion;

  /// No description provided for @agentMemorySignalCamera.
  ///
  /// In en, this message translates to:
  /// **'camera'**
  String get agentMemorySignalCamera;

  /// No description provided for @agentMemorySignalVisual.
  ///
  /// In en, this message translates to:
  /// **'visual'**
  String get agentMemorySignalVisual;

  /// No description provided for @agentMemorySignalIdentity.
  ///
  /// In en, this message translates to:
  /// **'identity'**
  String get agentMemorySignalIdentity;

  /// No description provided for @agentMemorySignalDialogue.
  ///
  /// In en, this message translates to:
  /// **'dialogue'**
  String get agentMemorySignalDialogue;

  /// No description provided for @agentMemorySignalPerformance.
  ///
  /// In en, this message translates to:
  /// **'performance'**
  String get agentMemorySignalPerformance;

  /// No description provided for @agentMemorySignalNegative.
  ///
  /// In en, this message translates to:
  /// **'negative{n}'**
  String agentMemorySignalNegative(String n);

  /// No description provided for @agentMemoryStatusProjectsRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Reloaded {count} projects.'**
  String agentMemoryStatusProjectsRefreshed(int count);

  /// No description provided for @agentMemoryErrFillProjectAndAgent.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid project ID (numeric or UUID from the list) and agent type.'**
  String get agentMemoryErrFillProjectAndAgent;

  /// No description provided for @agentMemoryErrFillAgentType.
  ///
  /// In en, this message translates to:
  /// **'Enter agent type.'**
  String get agentMemoryErrFillAgentType;

  /// No description provided for @agentMemoryQuerySummaryLine.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} {memoryType} memories · tier {tier}.'**
  String agentMemoryQuerySummaryLine(int count, String memoryType, String tier);

  /// No description provided for @agentMemoryErrCostOverviewFields.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid project ID and agent type before loading cost overview.'**
  String get agentMemoryErrCostOverviewFields;

  /// No description provided for @agentMemoryStatusCostOverviewLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded memory cost overview.'**
  String get agentMemoryStatusCostOverviewLoaded;

  /// No description provided for @agentMemoryErrAppendProjectFields.
  ///
  /// In en, this message translates to:
  /// **'Enter project ID, agent type, role, and content before appending.'**
  String get agentMemoryErrAppendProjectFields;

  /// No description provided for @agentMemoryErrAppendAgentRoleContent.
  ///
  /// In en, this message translates to:
  /// **'Enter agent type, role, and content before appending.'**
  String get agentMemoryErrAppendAgentRoleContent;

  /// No description provided for @agentMemoryStatusAppended.
  ///
  /// In en, this message translates to:
  /// **'Appended memory {id}.'**
  String agentMemoryStatusAppended(String id);

  /// No description provided for @agentMemoryErrClearProjectFields.
  ///
  /// In en, this message translates to:
  /// **'Enter project ID and agent type before clearing.'**
  String get agentMemoryErrClearProjectFields;

  /// No description provided for @agentMemoryStatusCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared memory: {clearType}.'**
  String agentMemoryStatusCleared(String clearType);

  /// No description provided for @agentMemoryErrOptimizeProjectFields.
  ///
  /// In en, this message translates to:
  /// **'Enter project ID, agent type, and episodes id before optimizing.'**
  String get agentMemoryErrOptimizeProjectFields;

  /// No description provided for @agentMemoryErrOptimizeAgentEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Enter agent type and episodes id before optimizing.'**
  String get agentMemoryErrOptimizeAgentEpisodes;

  /// No description provided for @agentMemoryStatusOptimized.
  ///
  /// In en, this message translates to:
  /// **'Optimized video memory ({mode}): removed {removedRows} rows / {removedChars} chars (duplicates {dupRows}, visual-only {visRows}).'**
  String agentMemoryStatusOptimized(
    String mode,
    int removedRows,
    int removedChars,
    int dupRows,
    int visRows,
  );

  /// No description provided for @agentMemoryErrScopeNotObject.
  ///
  /// In en, this message translates to:
  /// **'scopeSignature must be a JSON object.'**
  String get agentMemoryErrScopeNotObject;

  /// No description provided for @agentMemoryErrScopeNeedsDimension.
  ///
  /// In en, this message translates to:
  /// **'scopeSignature needs at least one non-empty scope dimension.'**
  String get agentMemoryErrScopeNeedsDimension;

  /// No description provided for @agentMemoryErrScopeTierRequires.
  ///
  /// In en, this message translates to:
  /// **'{action} requires non-empty scopeSignature JSON for this tier.'**
  String agentMemoryErrScopeTierRequires(String action);

  /// No description provided for @agentMemoryActionLabelQueryScoped.
  ///
  /// In en, this message translates to:
  /// **'Query scoped memory'**
  String get agentMemoryActionLabelQueryScoped;

  /// No description provided for @agentMemoryActionLabelAppendScoped.
  ///
  /// In en, this message translates to:
  /// **'Append scoped memory'**
  String get agentMemoryActionLabelAppendScoped;

  /// No description provided for @taskCenterErrNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in. Cannot open task center.'**
  String get taskCenterErrNotLoggedIn;

  /// No description provided for @taskCenterProjectsNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Task projects are not loaded yet.'**
  String get taskCenterProjectsNotLoaded;

  /// No description provided for @taskCenterTaskListNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Task list is not loaded yet.'**
  String get taskCenterTaskListNotLoaded;

  /// No description provided for @taskCenterLocalClientPrefs.
  ///
  /// In en, this message translates to:
  /// **'Local client preferences'**
  String get taskCenterLocalClientPrefs;

  /// No description provided for @taskCenterSectionIntro.
  ///
  /// In en, this message translates to:
  /// **'Use the formal workbench for task projects/categories, filtered task listing, and details. The main section no longer depends on first-row or UUID probe buttons.'**
  String get taskCenterSectionIntro;

  /// No description provided for @taskCenterOpenWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Open task workbench'**
  String get taskCenterOpenWorkbench;

  /// No description provided for @taskCenterRefreshSummary.
  ///
  /// In en, this message translates to:
  /// **'Refresh task summary'**
  String get taskCenterRefreshSummary;

  /// No description provided for @taskCenterCompatibilityCheck.
  ///
  /// In en, this message translates to:
  /// **'Compatibility checks'**
  String get taskCenterCompatibilityCheck;

  /// No description provided for @taskCenterCompatibilityHint.
  ///
  /// In en, this message translates to:
  /// **'Keep legacy loading/detail probes as regression entry points; collapsed by default.'**
  String get taskCenterCompatibilityHint;

  /// No description provided for @taskCenterLoadTaskProjects.
  ///
  /// In en, this message translates to:
  /// **'Load task projects'**
  String get taskCenterLoadTaskProjects;

  /// No description provided for @taskCenterLoadTaskCategories.
  ///
  /// In en, this message translates to:
  /// **'Load task categories'**
  String get taskCenterLoadTaskCategories;

  /// No description provided for @taskCenterLoadTaskList.
  ///
  /// In en, this message translates to:
  /// **'Load task list'**
  String get taskCenterLoadTaskList;

  /// No description provided for @taskCenterViewFirstTaskDetails.
  ///
  /// In en, this message translates to:
  /// **'View first task details'**
  String get taskCenterViewFirstTaskDetails;

  /// No description provided for @taskCenterFieldTaskUuidTapToFill.
  ///
  /// In en, this message translates to:
  /// **'Task UUID (tap a row below to fill)'**
  String get taskCenterFieldTaskUuidTapToFill;

  /// No description provided for @taskCenterViewByUuid.
  ///
  /// In en, this message translates to:
  /// **'View details by UUID'**
  String get taskCenterViewByUuid;

  /// No description provided for @taskCenterJobsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks'**
  String taskCenterJobsCount(int count);

  /// No description provided for @taskCenterCategoriesLine.
  ///
  /// In en, this message translates to:
  /// **'Category summary: {line}'**
  String taskCenterCategoriesLine(String line);

  /// No description provided for @taskCenterNumericIdDetailsLine.
  ///
  /// In en, this message translates to:
  /// **'Task details (numeric ID): {line}'**
  String taskCenterNumericIdDetailsLine(String line);

  /// No description provided for @taskCenterUuidDetailsLine.
  ///
  /// In en, this message translates to:
  /// **'UUID details: {line}'**
  String taskCenterUuidDetailsLine(String line);

  /// No description provided for @taskCenterPhasePrep.
  ///
  /// In en, this message translates to:
  /// **'Prep'**
  String get taskCenterPhasePrep;

  /// No description provided for @taskCenterPhaseImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get taskCenterPhaseImage;

  /// No description provided for @taskCenterPhaseVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get taskCenterPhaseVideo;

  /// No description provided for @taskCenterPhaseExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get taskCenterPhaseExport;

  /// No description provided for @taskCenterPhaseQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get taskCenterPhaseQuality;

  /// No description provided for @taskCenterWorkbenchTitle.
  ///
  /// In en, this message translates to:
  /// **'Task workbench'**
  String get taskCenterWorkbenchTitle;

  /// No description provided for @taskCenterWorkbenchIntro.
  ///
  /// In en, this message translates to:
  /// **'Use one dialog to load task projects/categories, filter lists by project/category, and inspect details by numeric task id or UUID.{realtime}'**
  String taskCenterWorkbenchIntro(String realtime);

  /// No description provided for @taskCenterWorkbenchRealtimeConnected.
  ///
  /// In en, this message translates to:
  /// **' Live task updates are connected.'**
  String get taskCenterWorkbenchRealtimeConnected;

  /// No description provided for @taskCenterWorkbenchFilterAndList.
  ///
  /// In en, this message translates to:
  /// **'Filters and list'**
  String get taskCenterWorkbenchFilterAndList;

  /// No description provided for @taskCenterReloadTaskProjects.
  ///
  /// In en, this message translates to:
  /// **'Reload task projects'**
  String get taskCenterReloadTaskProjects;

  /// No description provided for @taskCenterReloadTaskCategories.
  ///
  /// In en, this message translates to:
  /// **'Reload task categories'**
  String get taskCenterReloadTaskCategories;

  /// No description provided for @taskCenterLoadTasksByFilters.
  ///
  /// In en, this message translates to:
  /// **'Load tasks by filters'**
  String get taskCenterLoadTasksByFilters;

  /// No description provided for @taskCenterFieldPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get taskCenterFieldPage;

  /// No description provided for @taskCenterFieldPageSize.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get taskCenterFieldPageSize;

  /// No description provided for @taskCenterFieldProjectNumericIdOptional.
  ///
  /// In en, this message translates to:
  /// **'Project numeric ID (optional)'**
  String get taskCenterFieldProjectNumericIdOptional;

  /// No description provided for @taskCenterFieldTaskClassOptional.
  ///
  /// In en, this message translates to:
  /// **'Task class (optional)'**
  String get taskCenterFieldTaskClassOptional;

  /// No description provided for @taskCenterFieldTaskStatusOptional.
  ///
  /// In en, this message translates to:
  /// **'Task status (optional)'**
  String get taskCenterFieldTaskStatusOptional;

  /// No description provided for @taskCenterFieldProductionPhaseOptional.
  ///
  /// In en, this message translates to:
  /// **'Short-video phase (optional: prep/image/video/export/quality)'**
  String get taskCenterFieldProductionPhaseOptional;

  /// No description provided for @taskCenterFailureReason.
  ///
  /// In en, this message translates to:
  /// **'Failure reason={text}'**
  String taskCenterFailureReason(String text);

  /// No description provided for @taskCenterRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get taskCenterRetry;

  /// No description provided for @taskCenterCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get taskCenterCancel;

  /// No description provided for @taskCenterTaskDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskCenterTaskDetailsSection;

  /// No description provided for @taskCenterFieldNumericTaskId.
  ///
  /// In en, this message translates to:
  /// **'Numeric task id'**
  String get taskCenterFieldNumericTaskId;

  /// No description provided for @taskCenterLoadNumericIdDetails.
  ///
  /// In en, this message translates to:
  /// **'Load task details (numeric ID)'**
  String get taskCenterLoadNumericIdDetails;

  /// No description provided for @taskCenterFieldTaskUuid.
  ///
  /// In en, this message translates to:
  /// **'Task UUID'**
  String get taskCenterFieldTaskUuid;

  /// No description provided for @taskCenterLoadUuidDetails.
  ///
  /// In en, this message translates to:
  /// **'Load UUID details'**
  String get taskCenterLoadUuidDetails;

  /// No description provided for @taskCenterStatusLine.
  ///
  /// In en, this message translates to:
  /// **'Status: {line}'**
  String taskCenterStatusLine(String line);

  /// No description provided for @taskCenterStructuredFailure.
  ///
  /// In en, this message translates to:
  /// **'Structured failure · {label}'**
  String taskCenterStructuredFailure(String label);

  /// No description provided for @taskCenterOpenProductionWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open production workspace'**
  String get taskCenterOpenProductionWorkspace;

  /// No description provided for @taskCenterOpenScriptWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open script workspace'**
  String get taskCenterOpenScriptWorkspace;

  /// No description provided for @taskCenterRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get taskCenterRegenerate;

  /// No description provided for @taskCenterPartialRework.
  ///
  /// In en, this message translates to:
  /// **'Partial rework'**
  String get taskCenterPartialRework;

  /// No description provided for @taskCenterWritebackCompensation.
  ///
  /// In en, this message translates to:
  /// **'Writeback compensation'**
  String get taskCenterWritebackCompensation;

  /// No description provided for @taskCenterOpenSpacePublish.
  ///
  /// In en, this message translates to:
  /// **'Open short-video Space (publish)'**
  String get taskCenterOpenSpacePublish;

  /// No description provided for @taskCenterOpenProductionStoryboard.
  ///
  /// In en, this message translates to:
  /// **'Open production workspace (storyboard)'**
  String get taskCenterOpenProductionStoryboard;

  /// No description provided for @taskCenterOpenScriptScript.
  ///
  /// In en, this message translates to:
  /// **'Open script workspace (script)'**
  String get taskCenterOpenScriptScript;

  /// No description provided for @taskCenterOpenSpaceProject.
  ///
  /// In en, this message translates to:
  /// **'Open short-video Space (project)'**
  String get taskCenterOpenSpaceProject;

  /// No description provided for @taskCenterStatusLoadedTaskProjects.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} task projects.'**
  String taskCenterStatusLoadedTaskProjects(int count);

  /// No description provided for @taskCenterStatusLoadedTaskCategories.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} task categories.'**
  String taskCenterStatusLoadedTaskCategories(int count);

  /// No description provided for @taskCenterStatusRefreshedTasks.
  ///
  /// In en, this message translates to:
  /// **'Refreshed {count} tasks.'**
  String taskCenterStatusRefreshedTasks(int count);

  /// No description provided for @taskCenterErrInvalidNumericTaskId.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid numeric task ID.'**
  String get taskCenterErrInvalidNumericTaskId;

  /// No description provided for @taskCenterErrFillTaskUuid.
  ///
  /// In en, this message translates to:
  /// **'Enter task UUID.'**
  String get taskCenterErrFillTaskUuid;

  /// No description provided for @taskCenterOriginRetrySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Retry submitted'**
  String get taskCenterOriginRetrySubmitted;

  /// No description provided for @taskCenterOriginTaskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Task cancelled'**
  String get taskCenterOriginTaskCancelled;

  /// No description provided for @taskCenterStatusEnteredWritebackCompensation.
  ///
  /// In en, this message translates to:
  /// **'Entered writeback compensation: load UUID details first and verify writeback status.'**
  String get taskCenterStatusEnteredWritebackCompensation;

  /// No description provided for @taskCenterOriginRealtimeUpdate.
  ///
  /// In en, this message translates to:
  /// **'Realtime update received'**
  String get taskCenterOriginRealtimeUpdate;

  /// No description provided for @taskCenterStatusMergedUpdate.
  ///
  /// In en, this message translates to:
  /// **'{origin}: #{taskId} {kind} -> {status}'**
  String taskCenterStatusMergedUpdate(
    String origin,
    int taskId,
    String kind,
    String status,
  );

  /// No description provided for @taskCenterProjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No task projects currently.'**
  String get taskCenterProjectsEmpty;

  /// No description provided for @taskCenterProjectsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} projects · {preview}{ellipsis}'**
  String taskCenterProjectsSummary(int count, String preview, String ellipsis);

  /// No description provided for @taskCenterCategoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No task categories currently.'**
  String get taskCenterCategoriesEmpty;

  /// No description provided for @taskCenterCategoriesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} categories · {preview}{ellipsis}'**
  String taskCenterCategoriesSummary(
    int count,
    String preview,
    String ellipsis,
  );

  /// No description provided for @taskCenterJobsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No task records currently.'**
  String get taskCenterJobsEmpty;

  /// No description provided for @taskCenterJobsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks · {preview}{ellipsis}'**
  String taskCenterJobsSummary(int count, String preview, String ellipsis);

  /// No description provided for @taskCenterFailurePayloadMissingSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Missing source_url'**
  String get taskCenterFailurePayloadMissingSourceUrl;

  /// No description provided for @taskCenterFailurePayloadSourceUrlEmpty.
  ///
  /// In en, this message translates to:
  /// **'Output URL is empty'**
  String get taskCenterFailurePayloadSourceUrlEmpty;

  /// No description provided for @taskCenterFailurePayloadFormatInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid export format'**
  String get taskCenterFailurePayloadFormatInvalid;

  /// No description provided for @taskCenterFailureLocalExportDirUnset.
  ///
  /// In en, this message translates to:
  /// **'Export directory is not configured on server'**
  String get taskCenterFailureLocalExportDirUnset;

  /// No description provided for @taskCenterFailureExportProviderFailed.
  ///
  /// In en, this message translates to:
  /// **'Export provider failed'**
  String get taskCenterFailureExportProviderFailed;

  /// No description provided for @taskCenterFailureExportDirectoryCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create export directory'**
  String get taskCenterFailureExportDirectoryCreateFailed;

  /// No description provided for @taskCenterFailureExportFilePersistFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to persist export file'**
  String get taskCenterFailureExportFilePersistFailed;

  /// No description provided for @taskCenterFailureVideoDownloadHttp.
  ///
  /// In en, this message translates to:
  /// **'Source video HTTP failed'**
  String get taskCenterFailureVideoDownloadHttp;

  /// No description provided for @taskCenterFailureVideoDownloadStream.
  ///
  /// In en, this message translates to:
  /// **'Source video stream interrupted'**
  String get taskCenterFailureVideoDownloadStream;

  /// No description provided for @taskCenterFailureVideoFormatMismatchNoTranscode.
  ///
  /// In en, this message translates to:
  /// **'Format mismatch (no transcoding)'**
  String get taskCenterFailureVideoFormatMismatchNoTranscode;

  /// No description provided for @taskCenterFailureVideoContentLengthExceedsLimit.
  ///
  /// In en, this message translates to:
  /// **'Source video too large (content-length)'**
  String get taskCenterFailureVideoContentLengthExceedsLimit;

  /// No description provided for @taskCenterFailureVideoBodyExceedsLimit.
  ///
  /// In en, this message translates to:
  /// **'Source video too large (body)'**
  String get taskCenterFailureVideoBodyExceedsLimit;

  /// No description provided for @taskCenterFailureUnknownCode.
  ///
  /// In en, this message translates to:
  /// **'Unknown failure code'**
  String get taskCenterFailureUnknownCode;

  /// No description provided for @projectsCreativeManualVerbCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get projectsCreativeManualVerbCreate;

  /// No description provided for @projectsCreativeManualVerbSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get projectsCreativeManualVerbSave;

  /// No description provided for @projectsCreativeManualVerbDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get projectsCreativeManualVerbDelete;

  /// No description provided for @projectsArtWorkbenchStatusRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing art styles…'**
  String get projectsArtWorkbenchStatusRefreshing;

  /// No description provided for @projectsArtWorkbenchStatusRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Refreshed {count} art styles.'**
  String projectsArtWorkbenchStatusRefreshed(int count);

  /// No description provided for @projectsArtWorkbenchStatusRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String projectsArtWorkbenchStatusRefreshFailed(String error);

  /// No description provided for @projectsArtWorkbenchStatusReadingCover.
  ///
  /// In en, this message translates to:
  /// **'Reading cover…'**
  String get projectsArtWorkbenchStatusReadingCover;

  /// No description provided for @projectsArtWorkbenchStatusReadCover.
  ///
  /// In en, this message translates to:
  /// **'Read cover for style #{id}.'**
  String projectsArtWorkbenchStatusReadCover(int id);

  /// No description provided for @projectsArtWorkbenchStatusReadCoverFailed.
  ///
  /// In en, this message translates to:
  /// **'Read cover failed: {error}'**
  String projectsArtWorkbenchStatusReadCoverFailed(String error);

  /// No description provided for @projectsArtWorkbenchStatusCreateNeedName.
  ///
  /// In en, this message translates to:
  /// **'Create failed: name is required.'**
  String get projectsArtWorkbenchStatusCreateNeedName;

  /// No description provided for @projectsArtWorkbenchStatusCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating art style…'**
  String get projectsArtWorkbenchStatusCreating;

  /// No description provided for @projectsArtWorkbenchStatusCreated.
  ///
  /// In en, this message translates to:
  /// **'Created style #{id}.'**
  String projectsArtWorkbenchStatusCreated(int id);

  /// No description provided for @projectsArtWorkbenchStatusCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Create failed: {error}'**
  String projectsArtWorkbenchStatusCreateFailed(String error);

  /// No description provided for @projectsArtWorkbenchStatusSaveNeedSelect.
  ///
  /// In en, this message translates to:
  /// **'Save failed: select a style first.'**
  String get projectsArtWorkbenchStatusSaveNeedSelect;

  /// No description provided for @projectsArtWorkbenchStatusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving art style…'**
  String get projectsArtWorkbenchStatusSaving;

  /// No description provided for @projectsArtWorkbenchStatusSaved.
  ///
  /// In en, this message translates to:
  /// **'Updated style #{id}.'**
  String projectsArtWorkbenchStatusSaved(int id);

  /// No description provided for @projectsArtWorkbenchStatusSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String projectsArtWorkbenchStatusSaveFailed(String error);

  /// No description provided for @projectsArtWorkbenchStatusDeleteNeedSelect.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: select a style first.'**
  String get projectsArtWorkbenchStatusDeleteNeedSelect;

  /// No description provided for @projectsArtWorkbenchStatusDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting art style…'**
  String get projectsArtWorkbenchStatusDeleting;

  /// No description provided for @projectsArtWorkbenchStatusDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted style #{id}.'**
  String projectsArtWorkbenchStatusDeleted(int id);

  /// No description provided for @projectsArtWorkbenchStatusDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String projectsArtWorkbenchStatusDeleteFailed(String error);

  /// No description provided for @projectsArtWorkbenchStatusExtractNeedInput.
  ///
  /// In en, this message translates to:
  /// **'Extraction failed: provide at least one image URL or data URI.'**
  String get projectsArtWorkbenchStatusExtractNeedInput;

  /// No description provided for @projectsArtWorkbenchStatusExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting art-style prompt…'**
  String get projectsArtWorkbenchStatusExtracting;

  /// No description provided for @projectsArtWorkbenchStatusExtracted.
  ///
  /// In en, this message translates to:
  /// **'Prompt generated. You can save it to the current style.'**
  String get projectsArtWorkbenchStatusExtracted;

  /// No description provided for @projectsArtWorkbenchStatusExtractFailed.
  ///
  /// In en, this message translates to:
  /// **'Extraction failed: {error}'**
  String projectsArtWorkbenchStatusExtractFailed(String error);

  /// No description provided for @globalSearchErrSignInFirst.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first.'**
  String get globalSearchErrSignInFirst;

  /// No description provided for @globalSearchErrSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String globalSearchErrSearchFailed(String error);

  /// No description provided for @globalSearchCopiedDeepLink.
  ///
  /// In en, this message translates to:
  /// **'Copied current search deep link.'**
  String get globalSearchCopiedDeepLink;

  /// No description provided for @globalSearchAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get globalSearchAllTypes;

  /// No description provided for @globalSearchTimeStart.
  ///
  /// In en, this message translates to:
  /// **'start'**
  String get globalSearchTimeStart;

  /// No description provided for @globalSearchTimeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get globalSearchTimeNow;

  /// No description provided for @globalSearchAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get globalSearchAllTime;

  /// No description provided for @globalSearchNeverUsed.
  ///
  /// In en, this message translates to:
  /// **'never used'**
  String get globalSearchNeverUsed;

  /// No description provided for @globalSearchSaveViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Save search view'**
  String get globalSearchSaveViewTitle;

  /// No description provided for @globalSearchViewNameField.
  ///
  /// In en, this message translates to:
  /// **'View name'**
  String get globalSearchViewNameField;

  /// No description provided for @globalSearchViewNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. scripts in last 30 days'**
  String get globalSearchViewNameHint;

  /// No description provided for @globalSearchCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get globalSearchCancel;

  /// No description provided for @globalSearchSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get globalSearchSave;

  /// No description provided for @globalSearchViewNameRequired.
  ///
  /// In en, this message translates to:
  /// **'View name is required.'**
  String get globalSearchViewNameRequired;

  /// No description provided for @globalSearchViewSaved.
  ///
  /// In en, this message translates to:
  /// **'Search view saved.'**
  String get globalSearchViewSaved;

  /// No description provided for @globalSearchNoSavedViews.
  ///
  /// In en, this message translates to:
  /// **'No saved search views yet.'**
  String get globalSearchNoSavedViews;

  /// No description provided for @globalSearchPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get globalSearchPinned;

  /// No description provided for @globalSearchUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get globalSearchUnpin;

  /// No description provided for @globalSearchPinToSearchBar.
  ///
  /// In en, this message translates to:
  /// **'Pin to search bar'**
  String get globalSearchPinToSearchBar;

  /// No description provided for @globalSearchUnpinnedView.
  ///
  /// In en, this message translates to:
  /// **'Unpinned search view.'**
  String get globalSearchUnpinnedView;

  /// No description provided for @globalSearchPinnedToSearchBar.
  ///
  /// In en, this message translates to:
  /// **'Pinned to search bar.'**
  String get globalSearchPinnedToSearchBar;

  /// No description provided for @globalSearchDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get globalSearchDelete;

  /// No description provided for @globalSearchViewDeleted.
  ///
  /// In en, this message translates to:
  /// **'Search view deleted.'**
  String get globalSearchViewDeleted;

  /// No description provided for @globalSearchTypeProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get globalSearchTypeProject;

  /// No description provided for @globalSearchTypeScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get globalSearchTypeScript;

  /// No description provided for @globalSearchTypeAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get globalSearchTypeAsset;

  /// No description provided for @globalSearchTypeNovel.
  ///
  /// In en, this message translates to:
  /// **'Novel chapters'**
  String get globalSearchTypeNovel;

  /// No description provided for @globalSearchTypeNovelEvent.
  ///
  /// In en, this message translates to:
  /// **'Novel events'**
  String get globalSearchTypeNovelEvent;

  /// No description provided for @globalSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search: {query}'**
  String globalSearchTitle(String query);

  /// No description provided for @globalSearchTooltipSaveCurrentView.
  ///
  /// In en, this message translates to:
  /// **'Save current view'**
  String get globalSearchTooltipSaveCurrentView;

  /// No description provided for @globalSearchTooltipSavedViews.
  ///
  /// In en, this message translates to:
  /// **'Saved views'**
  String get globalSearchTooltipSavedViews;

  /// No description provided for @globalSearchTooltipCopyDeepLink.
  ///
  /// In en, this message translates to:
  /// **'Copy search deep link'**
  String get globalSearchTooltipCopyDeepLink;

  /// No description provided for @globalSearchTooltipFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get globalSearchTooltipFilter;

  /// No description provided for @globalSearchFoundResults.
  ///
  /// In en, this message translates to:
  /// **'Found {count} results'**
  String globalSearchFoundResults(int count);

  /// No description provided for @globalSearchClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get globalSearchClearFilters;

  /// No description provided for @globalSearchTimeChip.
  ///
  /// In en, this message translates to:
  /// **'Time {from} ~ {to}'**
  String globalSearchTimeChip(String from, String to);

  /// No description provided for @globalSearchErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Search error'**
  String get globalSearchErrorTitle;

  /// No description provided for @globalSearchUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get globalSearchUnknownError;

  /// No description provided for @globalSearchRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get globalSearchRetry;

  /// No description provided for @globalSearchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get globalSearchNoResultsTitle;

  /// No description provided for @globalSearchNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try different keywords'**
  String get globalSearchNoResultsHint;

  /// No description provided for @globalSearchPrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get globalSearchPrevPage;

  /// No description provided for @globalSearchCurrentPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String globalSearchCurrentPage(int page);

  /// No description provided for @globalSearchNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get globalSearchNextPage;

  /// No description provided for @globalSearchTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get globalSearchTimeJustNow;

  /// No description provided for @globalSearchTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String globalSearchTimeMinutesAgo(int minutes);

  /// No description provided for @globalSearchTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String globalSearchTimeHoursAgo(int hours);

  /// No description provided for @globalSearchTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String globalSearchTimeDaysAgo(int days);

  /// No description provided for @globalSearchChooseStartDate.
  ///
  /// In en, this message translates to:
  /// **'Choose start date'**
  String get globalSearchChooseStartDate;

  /// No description provided for @globalSearchChooseEndDate.
  ///
  /// In en, this message translates to:
  /// **'Choose end date'**
  String get globalSearchChooseEndDate;

  /// No description provided for @globalSearchConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get globalSearchConfirm;

  /// No description provided for @globalSearchAppliedFilters.
  ///
  /// In en, this message translates to:
  /// **'Applied {count} filters'**
  String globalSearchAppliedFilters(int count);

  /// No description provided for @globalSearchClearedAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Cleared all filters.'**
  String get globalSearchClearedAllFilters;

  /// No description provided for @globalSearchAdvancedFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced filters'**
  String get globalSearchAdvancedFilterTitle;

  /// No description provided for @globalSearchResultTypeSection.
  ///
  /// In en, this message translates to:
  /// **'Result type'**
  String get globalSearchResultTypeSection;

  /// No description provided for @globalSearchCreatedTimeSection.
  ///
  /// In en, this message translates to:
  /// **'Created time'**
  String get globalSearchCreatedTimeSection;

  /// No description provided for @globalSearchTypeNovelEventOutline.
  ///
  /// In en, this message translates to:
  /// **'Novel outline events'**
  String get globalSearchTypeNovelEventOutline;

  /// No description provided for @globalSearchStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start: {date}'**
  String globalSearchStartDateLabel(String date);

  /// No description provided for @globalSearchEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End: {date}'**
  String globalSearchEndDateLabel(String date);

  /// No description provided for @globalSearchClearTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Clear time range'**
  String get globalSearchClearTimeRange;

  /// No description provided for @globalSearchApplyFilter.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get globalSearchApplyFilter;

  /// No description provided for @globalSearchWorkspaceUnlabeled.
  ///
  /// In en, this message translates to:
  /// **'Unlabeled workspace'**
  String get globalSearchWorkspaceUnlabeled;

  /// No description provided for @globalSearchWorkspaceCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current workspace'**
  String get globalSearchWorkspaceCurrent;

  /// No description provided for @globalSearchViewActions.
  ///
  /// In en, this message translates to:
  /// **'View actions'**
  String get globalSearchViewActions;

  /// No description provided for @globalSearchRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get globalSearchRename;

  /// No description provided for @globalSearchDeleteView.
  ///
  /// In en, this message translates to:
  /// **'Delete view'**
  String get globalSearchDeleteView;

  /// No description provided for @globalSearchRenameViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename search view'**
  String get globalSearchRenameViewTitle;

  /// No description provided for @globalSearchRenameViewHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new view name'**
  String get globalSearchRenameViewHint;

  /// No description provided for @globalSearchRenamedView.
  ///
  /// In en, this message translates to:
  /// **'Renamed search view.'**
  String get globalSearchRenamedView;

  /// No description provided for @globalSearchDeleteViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete search view'**
  String get globalSearchDeleteViewTitle;

  /// No description provided for @globalSearchDeleteViewConfirmRemote.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? Signed-in mode will sync removal to all clients with this saved view data.'**
  String globalSearchDeleteViewConfirmRemote(String title);

  /// No description provided for @globalSearchDeleteViewConfirmLocal.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This only removes the locally saved view.'**
  String globalSearchDeleteViewConfirmLocal(String title);

  /// No description provided for @globalSearchPinnedViewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned views'**
  String get globalSearchPinnedViewsTitle;

  /// No description provided for @globalSearchRecentViewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent views'**
  String get globalSearchRecentViewsTitle;

  /// No description provided for @globalSearchQuickTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick templates'**
  String get globalSearchQuickTemplatesTitle;

  /// No description provided for @globalSearchLiveSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Live suggestions'**
  String get globalSearchLiveSuggestionsTitle;

  /// No description provided for @globalSearchRecentSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get globalSearchRecentSearchTitle;

  /// No description provided for @globalSearchClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get globalSearchClearHistory;

  /// No description provided for @globalSearchNoPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'No preview matches yet. Press Enter for full results.'**
  String get globalSearchNoPreviewHint;

  /// No description provided for @globalSearchMinCharsHint.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 2 characters to search.'**
  String get globalSearchMinCharsHint;

  /// No description provided for @globalSearchHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Search history cleared.'**
  String get globalSearchHistoryCleared;

  /// No description provided for @globalSearchClearHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear history: {error}'**
  String globalSearchClearHistoryFailed(String error);

  /// No description provided for @globalSearchEnterAtLeastChars.
  ///
  /// In en, this message translates to:
  /// **'Enter at least {count} characters.'**
  String globalSearchEnterAtLeastChars(int count);

  /// No description provided for @globalSearchMaxCharsHint.
  ///
  /// In en, this message translates to:
  /// **'Search query is too long. Limit to {count} characters.'**
  String globalSearchMaxCharsHint(int count);

  /// No description provided for @globalSearchInputHint.
  ///
  /// In en, this message translates to:
  /// **'Search projects, scripts, assets...'**
  String get globalSearchInputHint;

  /// No description provided for @globalSearchActionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get globalSearchActionSearch;

  /// No description provided for @globalSearchLocalClientPrefsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Local client preferences (view silenced / restore confirmations)'**
  String get globalSearchLocalClientPrefsTooltip;

  /// No description provided for @globalSearchSavedUsed.
  ///
  /// In en, this message translates to:
  /// **'used={count}'**
  String globalSearchSavedUsed(int count);

  /// No description provided for @globalSearchTemplateRecent7d.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get globalSearchTemplateRecent7d;

  /// No description provided for @globalSearchTemplateProjects30d.
  ///
  /// In en, this message translates to:
  /// **'Projects in last 30 days'**
  String get globalSearchTemplateProjects30d;

  /// No description provided for @globalSearchTemplateScripts30d.
  ///
  /// In en, this message translates to:
  /// **'Scripts in last 30 days'**
  String get globalSearchTemplateScripts30d;

  /// No description provided for @globalSearchClearSearchHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get globalSearchClearSearchHistoryTitle;

  /// No description provided for @globalSearchClearSearchHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all search history? This action cannot be undone.'**
  String get globalSearchClearSearchHistoryConfirm;

  /// No description provided for @globalSearchLoadHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history'**
  String get globalSearchLoadHistoryFailed;

  /// No description provided for @globalSearchNoSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'No search history yet'**
  String get globalSearchNoSearchHistory;

  /// No description provided for @globalSearchResultRows.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String globalSearchResultRows(int count);

  /// No description provided for @qualityReviewsErrNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in. Unable to load quality reviews.'**
  String get qualityReviewsErrNotLoggedIn;

  /// No description provided for @qualityReviewsSummaryNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Review list not loaded yet.'**
  String get qualityReviewsSummaryNotLoaded;

  /// No description provided for @qualityReviewsSectionIntro.
  ///
  /// In en, this message translates to:
  /// **'View review list, bad cases, and stage pass rates. Low-score bad cases write back negative memory, while high-score passes promote positive memory.'**
  String get qualityReviewsSectionIntro;

  /// No description provided for @qualityReviewsOpsDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Quality operations dashboard'**
  String get qualityReviewsOpsDashboardTitle;

  /// No description provided for @qualityReviewsCopiedDashboardSummary.
  ///
  /// In en, this message translates to:
  /// **'Copied dashboard summary.'**
  String get qualityReviewsCopiedDashboardSummary;

  /// No description provided for @qualityReviewsCopyDashboardSummary.
  ///
  /// In en, this message translates to:
  /// **'Copy dashboard summary'**
  String get qualityReviewsCopyDashboardSummary;

  /// No description provided for @qualityReviewsFieldReviewId.
  ///
  /// In en, this message translates to:
  /// **'Review ID (tap from list below to autofill)'**
  String get qualityReviewsFieldReviewId;

  /// No description provided for @qualityReviewsViewReviewDetails.
  ///
  /// In en, this message translates to:
  /// **'View review details'**
  String get qualityReviewsViewReviewDetails;

  /// No description provided for @qualityReviewsSummaryReviewDetails.
  ///
  /// In en, this message translates to:
  /// **'Review details: {value}'**
  String qualityReviewsSummaryReviewDetails(String value);

  /// No description provided for @qualityReviewsSummaryStats.
  ///
  /// In en, this message translates to:
  /// **'Quality stats: {value}'**
  String qualityReviewsSummaryStats(String value);

  /// No description provided for @qualityReviewsSummaryStagePassRate.
  ///
  /// In en, this message translates to:
  /// **'Stage pass rate: {value}'**
  String qualityReviewsSummaryStagePassRate(String value);

  /// No description provided for @qualityReviewsSummaryStageGrade.
  ///
  /// In en, this message translates to:
  /// **'Stage grade distribution: {value}'**
  String qualityReviewsSummaryStageGrade(String value);

  /// No description provided for @qualityReviewsSummaryScopeInsights.
  ///
  /// In en, this message translates to:
  /// **'Scope leaderboard: {value}'**
  String qualityReviewsSummaryScopeInsights(String value);

  /// No description provided for @qualityReviewsSummaryTokenEfficiency.
  ///
  /// In en, this message translates to:
  /// **'Token efficiency: {value}'**
  String qualityReviewsSummaryTokenEfficiency(String value);

  /// No description provided for @qualityReviewsSummaryBadCaseHotspots.
  ///
  /// In en, this message translates to:
  /// **'Bad-case hotspots: {value}'**
  String qualityReviewsSummaryBadCaseHotspots(String value);

  /// No description provided for @qualityReviewsOpenWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Open quality workbench'**
  String get qualityReviewsOpenWorkbench;

  /// No description provided for @qualityReviewsLoadCurrentDashboard.
  ///
  /// In en, this message translates to:
  /// **'Load current dashboard'**
  String get qualityReviewsLoadCurrentDashboard;

  /// No description provided for @qualityReviewsRefreshReadModel.
  ///
  /// In en, this message translates to:
  /// **'Refresh underlying read model'**
  String get qualityReviewsRefreshReadModel;

  /// No description provided for @qualityReviewsLoadReviewList.
  ///
  /// In en, this message translates to:
  /// **'Load review list'**
  String get qualityReviewsLoadReviewList;

  /// No description provided for @qualityReviewsViewBadCases.
  ///
  /// In en, this message translates to:
  /// **'View bad cases'**
  String get qualityReviewsViewBadCases;

  /// No description provided for @qualityReviewsViewStats.
  ///
  /// In en, this message translates to:
  /// **'View quality stats'**
  String get qualityReviewsViewStats;

  /// No description provided for @qualityReviewsViewStagePassRate.
  ///
  /// In en, this message translates to:
  /// **'View stage pass rates'**
  String get qualityReviewsViewStagePassRate;

  /// No description provided for @qualityReviewsDashboardNotLoadedRefreshEnabled.
  ///
  /// In en, this message translates to:
  /// **'Quality dashboard not loaded. You can refresh aggregated stats, bad-case hotspots, stage distributions, and token efficiency directly.'**
  String get qualityReviewsDashboardNotLoadedRefreshEnabled;

  /// No description provided for @qualityReviewsDashboardNotLoadedRefreshDisabled.
  ///
  /// In en, this message translates to:
  /// **'Quality dashboard not loaded. Refresh controls are disabled by platform config; load current dashboard to view existing aggregates and bad-case hotspots.'**
  String get qualityReviewsDashboardNotLoadedRefreshDisabled;

  /// No description provided for @qualityReviewsTargetType.
  ///
  /// In en, this message translates to:
  /// **'Target type'**
  String get qualityReviewsTargetType;

  /// No description provided for @qualityReviewsTargetTypeChip.
  ///
  /// In en, this message translates to:
  /// **'{target} {pass}% · {count} items'**
  String qualityReviewsTargetTypeChip(String target, String pass, int count);

  /// No description provided for @qualityReviewsStageGrade.
  ///
  /// In en, this message translates to:
  /// **'Stage grade'**
  String get qualityReviewsStageGrade;

  /// No description provided for @qualityReviewsBadCaseHotspots.
  ///
  /// In en, this message translates to:
  /// **'Bad-case hotspots'**
  String get qualityReviewsBadCaseHotspots;

  /// No description provided for @qualityReviewsBadCaseChip.
  ///
  /// In en, this message translates to:
  /// **'{category} {count}'**
  String qualityReviewsBadCaseChip(String category, int count);

  /// No description provided for @qualityReviewsUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get qualityReviewsUncategorized;

  /// No description provided for @qualityReviewsScopeLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Scope leaderboard'**
  String get qualityReviewsScopeLeaderboard;

  /// No description provided for @qualityReviewsTokenEfficiency.
  ///
  /// In en, this message translates to:
  /// **'Token efficiency'**
  String get qualityReviewsTokenEfficiency;

  /// No description provided for @qualityReviewsCompatibilityCheck.
  ///
  /// In en, this message translates to:
  /// **'Compatibility check'**
  String get qualityReviewsCompatibilityCheck;

  /// No description provided for @qualityReviewsCompatibilityCheckIntro.
  ///
  /// In en, this message translates to:
  /// **'Keep a read-only regression entry to ensure review list and detail queries still work.'**
  String get qualityReviewsCompatibilityCheckIntro;

  /// No description provided for @qualityReviewsReadProbeLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality review read probe'**
  String get qualityReviewsReadProbeLabel;

  /// No description provided for @qualityReviewsRunReadOnlyRegressionCheck.
  ///
  /// In en, this message translates to:
  /// **'Run read-only regression check'**
  String get qualityReviewsRunReadOnlyRegressionCheck;

  /// No description provided for @qualityReviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String qualityReviewsCount(int count);

  /// No description provided for @qualityReviewsFilterBadCase.
  ///
  /// In en, this message translates to:
  /// **'bad case'**
  String get qualityReviewsFilterBadCase;

  /// No description provided for @qualityReviewsFilterDeliveryPriorityHit.
  ///
  /// In en, this message translates to:
  /// **'delivery/tone priority hit'**
  String get qualityReviewsFilterDeliveryPriorityHit;

  /// No description provided for @qualityReviewsFilterStage.
  ///
  /// In en, this message translates to:
  /// **'Stage {value}'**
  String qualityReviewsFilterStage(String value);

  /// No description provided for @qualityReviewsFilterGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade {value}'**
  String qualityReviewsFilterGrade(String value);

  /// No description provided for @qualityReviewsStatusLoadedReviews.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} reviews'**
  String qualityReviewsStatusLoadedReviews(int count);

  /// No description provided for @qualityReviewsStatusLoadedReviewsWithLabels.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} reviews with {labels}'**
  String qualityReviewsStatusLoadedReviewsWithLabels(int count, String labels);

  /// No description provided for @qualityReviewsStatusRefreshedStats.
  ///
  /// In en, this message translates to:
  /// **'Refreshed quality stats'**
  String get qualityReviewsStatusRefreshedStats;

  /// No description provided for @qualityReviewsStatusRefreshedScopeLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Refreshed scope leaderboard'**
  String get qualityReviewsStatusRefreshedScopeLeaderboard;

  /// No description provided for @qualityReviewsStatusRefreshedStageAndGrade.
  ///
  /// In en, this message translates to:
  /// **'Refreshed stage pass rates and grade distribution'**
  String get qualityReviewsStatusRefreshedStageAndGrade;

  /// No description provided for @qualityReviewsNoBadCaseData.
  ///
  /// In en, this message translates to:
  /// **'No bad-case data'**
  String get qualityReviewsNoBadCaseData;

  /// No description provided for @qualityReviewsBadCaseStatsLine.
  ///
  /// In en, this message translates to:
  /// **'{category} {count} items pass={pass}'**
  String qualityReviewsBadCaseStatsLine(
    String category,
    int count,
    String pass,
  );

  /// No description provided for @qualityReviewsStatusRefreshedBadCaseDistribution.
  ///
  /// In en, this message translates to:
  /// **'Refreshed bad-case distribution'**
  String get qualityReviewsStatusRefreshedBadCaseDistribution;

  /// No description provided for @qualityReviewsStatusRefreshedTokenAggregate.
  ///
  /// In en, this message translates to:
  /// **'Refreshed token aggregate'**
  String get qualityReviewsStatusRefreshedTokenAggregate;

  /// No description provided for @qualityReviewsStatusRefreshedTokenSavingSamples.
  ///
  /// In en, this message translates to:
  /// **'Refreshed token-saving samples'**
  String get qualityReviewsStatusRefreshedTokenSavingSamples;

  /// No description provided for @qualityReviewsErrInputReviewIdFirst.
  ///
  /// In en, this message translates to:
  /// **'Please input review ID first'**
  String get qualityReviewsErrInputReviewIdFirst;

  /// No description provided for @qualityReviewsStatusLoadedReviewDetails.
  ///
  /// In en, this message translates to:
  /// **'Loaded review details'**
  String get qualityReviewsStatusLoadedReviewDetails;

  /// No description provided for @qualityReviewsErrTargetTypeSourceRequired.
  ///
  /// In en, this message translates to:
  /// **'targetType and source are required'**
  String get qualityReviewsErrTargetTypeSourceRequired;

  /// No description provided for @qualityReviewsErrScriptNeedsProject.
  ///
  /// In en, this message translates to:
  /// **'scriptId requires projectId'**
  String get qualityReviewsErrScriptNeedsProject;

  /// No description provided for @qualityReviewsErrStoryboardTargetIdPositive.
  ///
  /// In en, this message translates to:
  /// **'When creating storyboard review, targetId must be a positive integer shot ID'**
  String get qualityReviewsErrStoryboardTargetIdPositive;

  /// No description provided for @qualityReviewsStatusCreated.
  ///
  /// In en, this message translates to:
  /// **'Created review {id}'**
  String qualityReviewsStatusCreated(String id);

  /// No description provided for @qualityReviewsStatusCreatedWithScopedWriteback.
  ///
  /// In en, this message translates to:
  /// **'Created review {id}; this row will write back to project/script scoped memory'**
  String qualityReviewsStatusCreatedWithScopedWriteback(String id);

  /// No description provided for @qualityReviewsWorkbenchTitle.
  ///
  /// In en, this message translates to:
  /// **'Quality workbench'**
  String get qualityReviewsWorkbenchTitle;

  /// No description provided for @qualityReviewsWorkbenchIntro.
  ///
  /// In en, this message translates to:
  /// **'Use one entry for review filtering, bad-case lookup, stats loading, detail queries, and manual creation.'**
  String get qualityReviewsWorkbenchIntro;

  /// No description provided for @qualityReviewsOnlyBadCases.
  ///
  /// In en, this message translates to:
  /// **'Only bad cases'**
  String get qualityReviewsOnlyBadCases;

  /// No description provided for @qualityReviewsOnlyDeliveryPriorityHit.
  ///
  /// In en, this message translates to:
  /// **'Only delivery/tone priority hits'**
  String get qualityReviewsOnlyDeliveryPriorityHit;

  /// No description provided for @qualityReviewsOnlyAutoSamples.
  ///
  /// In en, this message translates to:
  /// **'Only auto samples'**
  String get qualityReviewsOnlyAutoSamples;

  /// No description provided for @qualityReviewsFilterAutoSamples.
  ///
  /// In en, this message translates to:
  /// **'auto samples'**
  String get qualityReviewsFilterAutoSamples;

  /// No description provided for @qualityReviewsFilterQueryLine.
  ///
  /// In en, this message translates to:
  /// **'Filter query: {value}'**
  String qualityReviewsFilterQueryLine(String value);

  /// No description provided for @qualityReviewsCopyFilterQuery.
  ///
  /// In en, this message translates to:
  /// **'Copy filter query'**
  String get qualityReviewsCopyFilterQuery;

  /// No description provided for @qualityReviewsCopiedFilterQuery.
  ///
  /// In en, this message translates to:
  /// **'Copied filter query.'**
  String get qualityReviewsCopiedFilterQuery;

  /// No description provided for @qualityReviewsCopyApiUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy full API URL'**
  String get qualityReviewsCopyApiUrl;

  /// No description provided for @qualityReviewsCopiedApiUrl.
  ///
  /// In en, this message translates to:
  /// **'Copied API URL.'**
  String get qualityReviewsCopiedApiUrl;

  /// No description provided for @qualityReviewsFilterAndReadSection.
  ///
  /// In en, this message translates to:
  /// **'Filter and load'**
  String get qualityReviewsFilterAndReadSection;

  /// No description provided for @qualityReviewsFilterProjectId.
  ///
  /// In en, this message translates to:
  /// **'Filter projectId'**
  String get qualityReviewsFilterProjectId;

  /// No description provided for @qualityReviewsFilterScriptId.
  ///
  /// In en, this message translates to:
  /// **'Filter scriptId'**
  String get qualityReviewsFilterScriptId;

  /// No description provided for @qualityReviewsFilterTargetType.
  ///
  /// In en, this message translates to:
  /// **'Filter targetType'**
  String get qualityReviewsFilterTargetType;

  /// No description provided for @qualityReviewsFilterTargetId.
  ///
  /// In en, this message translates to:
  /// **'Filter targetId'**
  String get qualityReviewsFilterTargetId;

  /// No description provided for @qualityReviewsFilterJobId.
  ///
  /// In en, this message translates to:
  /// **'Filter jobId'**
  String get qualityReviewsFilterJobId;

  /// No description provided for @qualityReviewsFilterStageLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage filter'**
  String get qualityReviewsFilterStageLabel;

  /// No description provided for @qualityReviewsFilterGradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grade filter'**
  String get qualityReviewsFilterGradeLabel;

  /// No description provided for @qualityReviewsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get qualityReviewsAll;

  /// No description provided for @qualityReviewsSummarizing.
  ///
  /// In en, this message translates to:
  /// **'Summarizing...'**
  String get qualityReviewsSummarizing;

  /// No description provided for @qualityReviewsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get qualityReviewsLoading;

  /// No description provided for @qualityReviewsLoadStats.
  ///
  /// In en, this message translates to:
  /// **'Load quality stats'**
  String get qualityReviewsLoadStats;

  /// No description provided for @qualityReviewsLoadScopeLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Load scope leaderboard'**
  String get qualityReviewsLoadScopeLeaderboard;

  /// No description provided for @qualityReviewsLoadTokenEfficiency.
  ///
  /// In en, this message translates to:
  /// **'Load token efficiency'**
  String get qualityReviewsLoadTokenEfficiency;

  /// No description provided for @qualityReviewsLoadTokenSavingSamples.
  ///
  /// In en, this message translates to:
  /// **'Load token-saving samples'**
  String get qualityReviewsLoadTokenSavingSamples;

  /// No description provided for @qualityReviewsLoadStagePassRate.
  ///
  /// In en, this message translates to:
  /// **'Load stage pass rate'**
  String get qualityReviewsLoadStagePassRate;

  /// No description provided for @qualityReviewsLoadBadCaseDistribution.
  ///
  /// In en, this message translates to:
  /// **'Load bad-case distribution'**
  String get qualityReviewsLoadBadCaseDistribution;

  /// No description provided for @qualityReviewsDetailsQuerySection.
  ///
  /// In en, this message translates to:
  /// **'Details query'**
  String get qualityReviewsDetailsQuerySection;

  /// No description provided for @qualityReviewsReviewId.
  ///
  /// In en, this message translates to:
  /// **'Review ID'**
  String get qualityReviewsReviewId;

  /// No description provided for @qualityReviewsCreateReviewSection.
  ///
  /// In en, this message translates to:
  /// **'Create review'**
  String get qualityReviewsCreateReviewSection;

  /// No description provided for @qualityReviewsCreateProjectIdOptional.
  ///
  /// In en, this message translates to:
  /// **'projectId (optional)'**
  String get qualityReviewsCreateProjectIdOptional;

  /// No description provided for @qualityReviewsCreateProjectIdHelper.
  ///
  /// In en, this message translates to:
  /// **'When provided, low-score/bad-case rows can auto-write project-scoped memory.'**
  String get qualityReviewsCreateProjectIdHelper;

  /// No description provided for @qualityReviewsCreateScriptIdOptional.
  ///
  /// In en, this message translates to:
  /// **'scriptId (optional)'**
  String get qualityReviewsCreateScriptIdOptional;

  /// No description provided for @qualityReviewsCreateScriptIdHelper.
  ///
  /// In en, this message translates to:
  /// **'Fill with projectId together to write into script-scoped memory.'**
  String get qualityReviewsCreateScriptIdHelper;

  /// No description provided for @qualityReviewsCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get qualityReviewsCreating;

  /// No description provided for @qualityReviewsCreateReview.
  ///
  /// In en, this message translates to:
  /// **'Create review'**
  String get qualityReviewsCreateReview;

  /// No description provided for @qualityReviewsStatusLine.
  ///
  /// In en, this message translates to:
  /// **'Status: {value}'**
  String qualityReviewsStatusLine(String value);

  /// No description provided for @qualityReviewsSummaryTokenAggregate.
  ///
  /// In en, this message translates to:
  /// **'Token aggregate: {value}'**
  String qualityReviewsSummaryTokenAggregate(String value);

  /// No description provided for @qualityReviewsSummaryMemoryAction.
  ///
  /// In en, this message translates to:
  /// **'Memory action: {value}'**
  String qualityReviewsSummaryMemoryAction(String value);

  /// No description provided for @qualityReviewsCopyExecutionChecklist.
  ///
  /// In en, this message translates to:
  /// **'Copy execution checklist'**
  String get qualityReviewsCopyExecutionChecklist;

  /// No description provided for @qualityReviewsCopiedExecutionChecklist.
  ///
  /// In en, this message translates to:
  /// **'Copied execution checklist.'**
  String get qualityReviewsCopiedExecutionChecklist;

  /// No description provided for @qualityReviewsSummaryTokenSavingSamples.
  ///
  /// In en, this message translates to:
  /// **'Token-saving samples: {value}'**
  String qualityReviewsSummaryTokenSavingSamples(String value);

  /// No description provided for @qualityReviewsSummaryBadCaseDistribution.
  ///
  /// In en, this message translates to:
  /// **'Bad-case distribution: {value}'**
  String qualityReviewsSummaryBadCaseDistribution(String value);

  /// No description provided for @qualityReviewsGradeDistribution.
  ///
  /// In en, this message translates to:
  /// **'Grade distribution'**
  String get qualityReviewsGradeDistribution;

  /// No description provided for @qualityReviewsTotalAndPassRate.
  ///
  /// In en, this message translates to:
  /// **'Total {total} · A+B pass rate {rate}%'**
  String qualityReviewsTotalAndPassRate(int total, String rate);

  /// No description provided for @qualityReviewsPromptDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Prompt diagnostics: {value}'**
  String qualityReviewsPromptDiagnostics(String value);

  /// No description provided for @qualityReviewsScopePressure.
  ///
  /// In en, this message translates to:
  /// **'Scope pressure: {value}'**
  String qualityReviewsScopePressure(String value);

  /// No description provided for @qualityReviewsMemorySlimming.
  ///
  /// In en, this message translates to:
  /// **'Memory slimming: {value}'**
  String qualityReviewsMemorySlimming(String value);

  /// No description provided for @qualityReviewsPriorityFix.
  ///
  /// In en, this message translates to:
  /// **'Priority fixes: {value}'**
  String qualityReviewsPriorityFix(String value);

  /// No description provided for @qualityReviewsRepairSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Repair suggestions: {value}'**
  String qualityReviewsRepairSuggestions(String value);

  /// No description provided for @qualityReviewsFilterCountLine.
  ///
  /// In en, this message translates to:
  /// **'{filters} {count} reviews'**
  String qualityReviewsFilterCountLine(String filters, int count);

  /// No description provided for @qualityReviewsSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions: {value}'**
  String qualityReviewsSuggestions(String value);

  /// No description provided for @qualityReviewsEmptyForCurrentFilters.
  ///
  /// In en, this message translates to:
  /// **'No reviews under current filters'**
  String get qualityReviewsEmptyForCurrentFilters;

  /// No description provided for @qualityReviewsNoTokenEfficiencyStats.
  ///
  /// In en, this message translates to:
  /// **'No token efficiency stats yet'**
  String get qualityReviewsNoTokenEfficiencyStats;

  /// No description provided for @qualityReviewsActionKeepDeliveryMemory.
  ///
  /// In en, this message translates to:
  /// **'action=keep delivery memory'**
  String get qualityReviewsActionKeepDeliveryMemory;

  /// No description provided for @qualityReviewsActionReuseNegativeMemory.
  ///
  /// In en, this message translates to:
  /// **'action=reuse negative constraints'**
  String get qualityReviewsActionReuseNegativeMemory;

  /// No description provided for @qualityReviewsActionTrimGenericStyle.
  ///
  /// In en, this message translates to:
  /// **'action=trim generic style memory'**
  String get qualityReviewsActionTrimGenericStyle;

  /// No description provided for @qualityReviewsActionPromoteSelectedMemory.
  ///
  /// In en, this message translates to:
  /// **'action=promote selected memory'**
  String get qualityReviewsActionPromoteSelectedMemory;

  /// No description provided for @qualityReviewsFocusLabel.
  ///
  /// In en, this message translates to:
  /// **'focus'**
  String get qualityReviewsFocusLabel;

  /// No description provided for @qualityReviewsNoTokenEfficiencySamples.
  ///
  /// In en, this message translates to:
  /// **'No token efficiency samples yet'**
  String get qualityReviewsNoTokenEfficiencySamples;

  /// No description provided for @qualityReviewsDeliveryPriority.
  ///
  /// In en, this message translates to:
  /// **'delivery-priority'**
  String get qualityReviewsDeliveryPriority;

  /// No description provided for @qualityReviewsRegular.
  ///
  /// In en, this message translates to:
  /// **'regular'**
  String get qualityReviewsRegular;

  /// No description provided for @qualityReviewsNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No quality reviews yet'**
  String get qualityReviewsNoReviews;

  /// No description provided for @qualityReviewsSummaryLine.
  ///
  /// In en, this message translates to:
  /// **'Reviews {total} · auto {autoCount} · {details}'**
  String qualityReviewsSummaryLine(int total, int autoCount, String details);

  /// No description provided for @qualityReviewsNoQualityStats.
  ///
  /// In en, this message translates to:
  /// **'No quality stats yet'**
  String get qualityReviewsNoQualityStats;

  /// No description provided for @qualityReviewsNoScopeLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'No scope leaderboard yet'**
  String get qualityReviewsNoScopeLeaderboard;

  /// No description provided for @qualityReviewsItemUnit.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get qualityReviewsItemUnit;

  /// No description provided for @qualityReviewsEmotionRisk.
  ///
  /// In en, this message translates to:
  /// **'emotion'**
  String get qualityReviewsEmotionRisk;

  /// No description provided for @qualityReviewsRealismRisk.
  ///
  /// In en, this message translates to:
  /// **'realism'**
  String get qualityReviewsRealismRisk;

  /// No description provided for @qualityReviewsPromotionsLabel.
  ///
  /// In en, this message translates to:
  /// **'promotions'**
  String get qualityReviewsPromotionsLabel;

  /// No description provided for @qualityReviewsBadCaseWriteback.
  ///
  /// In en, this message translates to:
  /// **'bad-case writeback'**
  String get qualityReviewsBadCaseWriteback;

  /// No description provided for @qualityReviewsSummaryWriteback.
  ///
  /// In en, this message translates to:
  /// **'summary writeback'**
  String get qualityReviewsSummaryWriteback;

  /// No description provided for @qualityReviewsWritebackSlim.
  ///
  /// In en, this message translates to:
  /// **'writeback slim'**
  String get qualityReviewsWritebackSlim;

  /// No description provided for @qualityReviewsFocusWatch.
  ///
  /// In en, this message translates to:
  /// **'watch'**
  String get qualityReviewsFocusWatch;

  /// No description provided for @qualityReviewsNoStagePassRate.
  ///
  /// In en, this message translates to:
  /// **'No stage pass rates yet'**
  String get qualityReviewsNoStagePassRate;

  /// No description provided for @qualityReviewsNoStageGradeDistribution.
  ///
  /// In en, this message translates to:
  /// **'No stage grade distribution yet'**
  String get qualityReviewsNoStageGradeDistribution;

  /// No description provided for @qualityReviewsNoBadCaseHotspots.
  ///
  /// In en, this message translates to:
  /// **'No bad-case hotspots yet'**
  String get qualityReviewsNoBadCaseHotspots;

  /// No description provided for @qualityReviewsSummaryStatsPrefix.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get qualityReviewsSummaryStatsPrefix;

  /// No description provided for @qualityReviewsSummaryStagePrefix.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get qualityReviewsSummaryStagePrefix;

  /// No description provided for @qualityReviewsSummaryGradePrefix.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get qualityReviewsSummaryGradePrefix;

  /// No description provided for @qualityReviewsSummaryBadCasePrefix.
  ///
  /// In en, this message translates to:
  /// **'Bad case'**
  String get qualityReviewsSummaryBadCasePrefix;

  /// No description provided for @qualityReviewsDiagnosticLabel.
  ///
  /// In en, this message translates to:
  /// **'diagnostic'**
  String get qualityReviewsDiagnosticLabel;

  /// No description provided for @qualityReviewsWritebackLabel.
  ///
  /// In en, this message translates to:
  /// **'writeback'**
  String get qualityReviewsWritebackLabel;

  /// No description provided for @qualityReviewsSuggestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'suggestions'**
  String get qualityReviewsSuggestionsLabel;

  /// No description provided for @qualityReviewsNegativeConstraintReviewAndBadCase.
  ///
  /// In en, this message translates to:
  /// **'negative constraint=reviews+bad-case memory'**
  String get qualityReviewsNegativeConstraintReviewAndBadCase;

  /// No description provided for @qualityReviewsNegativeConstraintRecentReviews.
  ///
  /// In en, this message translates to:
  /// **'negative constraint=recent reviews'**
  String get qualityReviewsNegativeConstraintRecentReviews;

  /// No description provided for @qualityReviewsNegativeConstraintBadCaseMemory.
  ///
  /// In en, this message translates to:
  /// **'negative constraint=bad-case memory'**
  String get qualityReviewsNegativeConstraintBadCaseMemory;

  /// No description provided for @qualityReviewsNegativeConstraintPendingBadCase.
  ///
  /// In en, this message translates to:
  /// **'negative constraint=pending bad cases'**
  String get qualityReviewsNegativeConstraintPendingBadCase;

  /// No description provided for @qualityReviewsNegativeConstraintPendingRejected.
  ///
  /// In en, this message translates to:
  /// **'negative constraint=pending rejected items'**
  String get qualityReviewsNegativeConstraintPendingRejected;

  /// No description provided for @qualityReviewsNegativeConstraintGeneric.
  ///
  /// In en, this message translates to:
  /// **'negative constraint={source}'**
  String qualityReviewsNegativeConstraintGeneric(String source);

  /// No description provided for @qualityReviewsBucketCount.
  ///
  /// In en, this message translates to:
  /// **'{bucket}{count} times'**
  String qualityReviewsBucketCount(String bucket, int count);

  /// No description provided for @qualityReviewsFeedbackTagDeliveryRealism.
  ///
  /// In en, this message translates to:
  /// **'dialogue realism'**
  String get qualityReviewsFeedbackTagDeliveryRealism;

  /// No description provided for @qualityReviewsFeedbackTagEmotionArc.
  ///
  /// In en, this message translates to:
  /// **'emotion arc'**
  String get qualityReviewsFeedbackTagEmotionArc;

  /// No description provided for @qualityReviewsFeedbackTagIdentityContinuity.
  ///
  /// In en, this message translates to:
  /// **'identity continuity'**
  String get qualityReviewsFeedbackTagIdentityContinuity;

  /// No description provided for @qualityReviewsFeedbackTagLightingRealism.
  ///
  /// In en, this message translates to:
  /// **'lighting realism'**
  String get qualityReviewsFeedbackTagLightingRealism;

  /// No description provided for @qualityReviewsScopeProject.
  ///
  /// In en, this message translates to:
  /// **'project {count}'**
  String qualityReviewsScopeProject(int count);

  /// No description provided for @qualityReviewsScopeScript.
  ///
  /// In en, this message translates to:
  /// **'script {count}'**
  String qualityReviewsScopeScript(int count);

  /// No description provided for @qualityReviewsScopeRole.
  ///
  /// In en, this message translates to:
  /// **'role {count}'**
  String qualityReviewsScopeRole(int count);

  /// No description provided for @qualityReviewsFocusSelectedVideoMemory.
  ///
  /// In en, this message translates to:
  /// **'selected shot memory'**
  String get qualityReviewsFocusSelectedVideoMemory;

  /// No description provided for @qualityReviewsFocusRejectedVideoNegativeMemory.
  ///
  /// In en, this message translates to:
  /// **'bad-case memory'**
  String get qualityReviewsFocusRejectedVideoNegativeMemory;

  /// No description provided for @qualityReviewsFocusProjectVideoStyleMemory.
  ///
  /// In en, this message translates to:
  /// **'project style memory'**
  String get qualityReviewsFocusProjectVideoStyleMemory;

  /// No description provided for @qualityReviewsFocusCurrentMemory.
  ///
  /// In en, this message translates to:
  /// **'current memory'**
  String get qualityReviewsFocusCurrentMemory;

  /// No description provided for @qualityReviewsSuggestionReferenceFrame.
  ///
  /// In en, this message translates to:
  /// **'Add reference frame and previous-shot continuity first; lock face, costume/props, and blocking continuity.'**
  String get qualityReviewsSuggestionReferenceFrame;

  /// No description provided for @qualityReviewsSuggestionContinuity.
  ///
  /// In en, this message translates to:
  /// **'Compress continuity constraints to 1-2 hard rules: camera setup, costume/props, and character positions only.'**
  String get qualityReviewsSuggestionContinuity;

  /// No description provided for @qualityReviewsSuggestionDelivery.
  ///
  /// In en, this message translates to:
  /// **'Keep delivery/tone memory, add performable emotional actions, and do not trim delivery memory first.'**
  String get qualityReviewsSuggestionDelivery;

  /// No description provided for @qualityReviewsSuggestionTrimGeneric.
  ///
  /// In en, this message translates to:
  /// **'Continue trimming generic action/lighting lines and reserve budget for expressions, lip sync, and identity continuity.'**
  String get qualityReviewsSuggestionTrimGeneric;

  /// No description provided for @qualityReviewsSuggestionNegativeReuse.
  ///
  /// In en, this message translates to:
  /// **'Reuse existing bad-case negative constraints; dedupe manually added phrases first to avoid repeated token burn.'**
  String get qualityReviewsSuggestionNegativeReuse;

  /// No description provided for @qualityReviewsSuggestionDirectorTrim.
  ///
  /// In en, this message translates to:
  /// **'Director descriptions already yielded to memory; reclaim repeated director lines first and keep key performance anchors.'**
  String get qualityReviewsSuggestionDirectorTrim;

  /// No description provided for @qualityReviewsSuggestionProjectScopeTrim.
  ///
  /// In en, this message translates to:
  /// **'Current hits are mostly project-scoped memory; trim generic style lines first and keep character performance details.'**
  String get qualityReviewsSuggestionProjectScopeTrim;

  /// No description provided for @qualityReviewsSuggestionRoleScopeKeep.
  ///
  /// In en, this message translates to:
  /// **'Role-scoped memory already hit; strengthen role performance actions first and avoid regressing to generic project copy.'**
  String get qualityReviewsSuggestionRoleScopeKeep;

  /// No description provided for @qualityReviewsSuggestionEmotion.
  ///
  /// In en, this message translates to:
  /// **'In next round, turn emotional arc into observable actions; avoid explanatory dialogue only.'**
  String get qualityReviewsSuggestionEmotion;

  /// No description provided for @qualityReviewsSuggestionVisual.
  ///
  /// In en, this message translates to:
  /// **'Prioritize character appearance and shot realism constraints, then decide whether to add more style descriptions.'**
  String get qualityReviewsSuggestionVisual;

  /// No description provided for @qualityReviewsSuggestionGeneral.
  ///
  /// In en, this message translates to:
  /// **'Lock emotion, continuity, and bad-case constraints first, then run the next generation round.'**
  String get qualityReviewsSuggestionGeneral;

  /// No description provided for @qualityReviewsRepairPlanCount.
  ///
  /// In en, this message translates to:
  /// **'{suggestion} {count} times'**
  String qualityReviewsRepairPlanCount(String suggestion, int count);

  /// No description provided for @qualityReviewsCurrentFilterScope.
  ///
  /// In en, this message translates to:
  /// **'current filter scope'**
  String get qualityReviewsCurrentFilterScope;

  /// No description provided for @qualityReviewsActionPlanKeepDelivery.
  ///
  /// In en, this message translates to:
  /// **'{targetType}: keep delivery/emotion memory from {focus}; continue trimming generic style lines before delivery fragments.'**
  String qualityReviewsActionPlanKeepDelivery(String targetType, String focus);

  /// No description provided for @qualityReviewsActionPlanReuseNegative.
  ///
  /// In en, this message translates to:
  /// **'{targetType}: reuse {focus} for bad-case isolation constraints; lock glitches/fakeness before deciding prompt additions.'**
  String qualityReviewsActionPlanReuseNegative(String targetType, String focus);

  /// No description provided for @qualityReviewsActionPlanTrimGeneric.
  ///
  /// In en, this message translates to:
  /// **'{targetType}: prioritize trimming action/lighting/mood filler in {focus}; reserve tokens for performance, lip sync, and continuity.'**
  String qualityReviewsActionPlanTrimGeneric(String targetType, String focus);

  /// No description provided for @qualityReviewsActionPlanPromoteSelected.
  ///
  /// In en, this message translates to:
  /// **'{targetType}: promote one high-score sample to {focus}; reuse emotion and shot execution while reducing repetitive descriptions.'**
  String qualityReviewsActionPlanPromoteSelected(
    String targetType,
    String focus,
  );

  /// No description provided for @qualityReviewsScopedMemorySuggestion.
  ///
  /// In en, this message translates to:
  /// **'{scope} scoped-memory suggestion: {value}'**
  String qualityReviewsScopedMemorySuggestion(String scope, String value);

  /// No description provided for @qualityReviewsChecklistKeepDelivery.
  ///
  /// In en, this message translates to:
  /// **'Keep performance/tone/lip-sync/emotion memory in {focus}, only trim generic style filler.'**
  String qualityReviewsChecklistKeepDelivery(String focus);

  /// No description provided for @qualityReviewsChecklistReuseNegative.
  ///
  /// In en, this message translates to:
  /// **'Reuse bad-case constraints in {focus} first; lock glitches/fakeness/coldness before deciding prompt additions.'**
  String qualityReviewsChecklistReuseNegative(String focus);

  /// No description provided for @qualityReviewsChecklistTrimGeneric.
  ///
  /// In en, this message translates to:
  /// **'Remove action/lighting/mood filler in {focus}; keep tokens for performance and continuity.'**
  String qualityReviewsChecklistTrimGeneric(String focus);

  /// No description provided for @qualityReviewsChecklistPromoteSelected.
  ///
  /// In en, this message translates to:
  /// **'Promote high-score samples to {focus}; reuse emotion and shot execution while reducing repetitive director copy.'**
  String qualityReviewsChecklistPromoteSelected(String focus);

  /// No description provided for @qualityReviewsChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'{scope} checklist:'**
  String qualityReviewsChecklistTitle(String scope);

  /// No description provided for @qualityReviewsChecklistScope.
  ///
  /// In en, this message translates to:
  /// **'Scope: memory takes effect only in {scope}; no reuse across users, projects, or shows.'**
  String qualityReviewsChecklistScope(String scope);

  /// No description provided for @qualityReviewsAutoSampleSummary.
  ///
  /// In en, this message translates to:
  /// **'auto samples {count} · avg prompt={prompt} chars · memory={memory} (visual={visual}, delivery={delivery}) · delivery-priority hit {hitRate}%'**
  String qualityReviewsAutoSampleSummary(
    int count,
    String prompt,
    String memory,
    String visual,
    String delivery,
    String hitRate,
  );

  /// No description provided for @qualityReviewsAutoDiagnosticsCount.
  ///
  /// In en, this message translates to:
  /// **'auto diagnostics {count}'**
  String qualityReviewsAutoDiagnosticsCount(int count);

  /// No description provided for @qualityReviewsAveragePrompt.
  ///
  /// In en, this message translates to:
  /// **'avg prompt={prompt} chars'**
  String qualityReviewsAveragePrompt(String prompt);

  /// No description provided for @qualityReviewsDeliveryPriorityRate.
  ///
  /// In en, this message translates to:
  /// **'delivery-priority {rate}%'**
  String qualityReviewsDeliveryPriorityRate(String rate);

  /// No description provided for @qualityReviewsTimesUnit.
  ///
  /// In en, this message translates to:
  /// **' times'**
  String get qualityReviewsTimesUnit;

  /// No description provided for @qualityReviewsHitMemoryBuckets.
  ///
  /// In en, this message translates to:
  /// **'hit memory {value}'**
  String qualityReviewsHitMemoryBuckets(String value);

  /// No description provided for @qualityReviewsSuppressedBuckets.
  ///
  /// In en, this message translates to:
  /// **'suppressed buckets {value}'**
  String qualityReviewsSuppressedBuckets(String value);

  /// No description provided for @qualityReviewsDirectorYieldCount.
  ///
  /// In en, this message translates to:
  /// **'director yield {hit}/{total}'**
  String qualityReviewsDirectorYieldCount(int hit, int total);

  /// No description provided for @qualityReviewsContinuityConstraintCount.
  ///
  /// In en, this message translates to:
  /// **'continuity constraints {hit}/{total}'**
  String qualityReviewsContinuityConstraintCount(int hit, int total);

  /// No description provided for @qualityReviewsReferenceFrameCount.
  ///
  /// In en, this message translates to:
  /// **'reference frame {hit}/{total}'**
  String qualityReviewsReferenceFrameCount(int hit, int total);

  /// No description provided for @qualityReviewsHitBucketsInline.
  ///
  /// In en, this message translates to:
  /// **'hit={value}'**
  String qualityReviewsHitBucketsInline(String value);

  /// No description provided for @qualityReviewsSuppressedBucketsInline.
  ///
  /// In en, this message translates to:
  /// **'suppressed={value}'**
  String qualityReviewsSuppressedBucketsInline(String value);

  /// No description provided for @qualityReviewsDirectorYield.
  ///
  /// In en, this message translates to:
  /// **'director yield'**
  String get qualityReviewsDirectorYield;

  /// No description provided for @qualityReviewsSavedChars.
  ///
  /// In en, this message translates to:
  /// **'saved {chars} chars'**
  String qualityReviewsSavedChars(int chars);

  /// No description provided for @qualityReviewsNegativeSlim.
  ///
  /// In en, this message translates to:
  /// **'negative slim={fragments} items/{chars} chars'**
  String qualityReviewsNegativeSlim(int fragments, int chars);

  /// No description provided for @qualityReviewsMemoryScopeLevel.
  ///
  /// In en, this message translates to:
  /// **'memory scope={value}'**
  String qualityReviewsMemoryScopeLevel(String value);

  /// No description provided for @qualityReviewsContinuityCount.
  ///
  /// In en, this message translates to:
  /// **'continuity {count}'**
  String qualityReviewsContinuityCount(int count);

  /// No description provided for @qualityReviewsReferenceFrame.
  ///
  /// In en, this message translates to:
  /// **'reference frame'**
  String get qualityReviewsReferenceFrame;

  /// No description provided for @qualityReviewsWritebackPromotedSelected.
  ///
  /// In en, this message translates to:
  /// **'promoted selected memory'**
  String get qualityReviewsWritebackPromotedSelected;

  /// No description provided for @qualityReviewsWritebackRejectedMemory.
  ///
  /// In en, this message translates to:
  /// **'bad-case memory writeback'**
  String get qualityReviewsWritebackRejectedMemory;

  /// No description provided for @qualityReviewsWritebackSummaryMemory.
  ///
  /// In en, this message translates to:
  /// **'review summary writeback'**
  String get qualityReviewsWritebackSummaryMemory;

  /// No description provided for @qualityReviewsWritebackMissingPromptSeed.
  ///
  /// In en, this message translates to:
  /// **'selected memory missing prompt seed'**
  String get qualityReviewsWritebackMissingPromptSeed;

  /// No description provided for @qualityReviewsWritebackEmptySelectedMemory.
  ///
  /// In en, this message translates to:
  /// **'selected memory yielded no effective fragment'**
  String get qualityReviewsWritebackEmptySelectedMemory;

  /// No description provided for @qualityReviewsShotId.
  ///
  /// In en, this message translates to:
  /// **'shot {id}'**
  String qualityReviewsShotId(int id);

  /// No description provided for @qualityReviewsWriteMemory.
  ///
  /// In en, this message translates to:
  /// **'write={name}'**
  String qualityReviewsWriteMemory(String name);

  /// No description provided for @qualityReviewsClearMemory.
  ///
  /// In en, this message translates to:
  /// **'clear={name}'**
  String qualityReviewsClearMemory(String name);

  /// No description provided for @qualityReviewsSlimSummary.
  ///
  /// In en, this message translates to:
  /// **'slim {chars} chars / {rows} items (dup {dup} / visual-only {visual})'**
  String qualityReviewsSlimSummary(int chars, int rows, int dup, int visual);

  /// No description provided for @qualityReviewsFocusWatchTag.
  ///
  /// In en, this message translates to:
  /// **'watch={value}'**
  String qualityReviewsFocusWatchTag(String value);

  /// No description provided for @qualityReviewsHitSummary.
  ///
  /// In en, this message translates to:
  /// **'hit {value}'**
  String qualityReviewsHitSummary(String value);

  /// No description provided for @qualityReviewsSuppressedSummary.
  ///
  /// In en, this message translates to:
  /// **'suppressed {value}'**
  String qualityReviewsSuppressedSummary(String value);

  /// No description provided for @qualityReviewsMemoryOptimizationScopeLine.
  ///
  /// In en, this message translates to:
  /// **'{scope} {reviews} items · slim {chars} chars / {rows} items (dup {dup} / visual-only {visual})'**
  String qualityReviewsMemoryOptimizationScopeLine(
    String scope,
    int reviews,
    int chars,
    int rows,
    int dup,
    int visual,
  );

  /// No description provided for @qualityReviewsBadCaseCount.
  ///
  /// In en, this message translates to:
  /// **'bad cases {count}'**
  String qualityReviewsBadCaseCount(int count);

  /// No description provided for @qualityReviewsDialogueRiskCount.
  ///
  /// In en, this message translates to:
  /// **'emotion/dialogue {count}'**
  String qualityReviewsDialogueRiskCount(int count);

  /// No description provided for @qualityReviewsVisualRiskCount.
  ///
  /// In en, this message translates to:
  /// **'realism {count}'**
  String qualityReviewsVisualRiskCount(int count);

  /// No description provided for @qualityReviewsNextStep.
  ///
  /// In en, this message translates to:
  /// **'next step {value}'**
  String qualityReviewsNextStep(String value);

  /// No description provided for @qualityReviewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get qualityReviewsEmpty;

  /// No description provided for @qualityReviewsDashboardRefreshPerformed.
  ///
  /// In en, this message translates to:
  /// **'Snapshot refreshed: {rows} review facts · reviews={reviews} · usage={usage} · {time}'**
  String qualityReviewsDashboardRefreshPerformed(
    int rows,
    int reviews,
    int usage,
    String time,
  );

  /// No description provided for @qualityReviewsDashboardRefreshSkipped.
  ///
  /// In en, this message translates to:
  /// **'Snapshot unchanged · fresh snapshot skipped refresh · {time}'**
  String qualityReviewsDashboardRefreshSkipped(String time);

  /// No description provided for @qualityReviewsFreshnessUnknownAge.
  ///
  /// In en, this message translates to:
  /// **'unknown_age'**
  String get qualityReviewsFreshnessUnknownAge;

  /// No description provided for @qualityReviewsFreshnessNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get qualityReviewsFreshnessNever;

  /// No description provided for @qualityReviewsFreshnessNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get qualityReviewsFreshnessNone;

  /// No description provided for @qualityReviewsFreshnessStale.
  ///
  /// In en, this message translates to:
  /// **'STALE'**
  String get qualityReviewsFreshnessStale;

  /// No description provided for @qualityReviewsFreshnessFresh.
  ///
  /// In en, this message translates to:
  /// **'fresh'**
  String get qualityReviewsFreshnessFresh;

  /// No description provided for @qualityReviewsStageStorySkeleton.
  ///
  /// In en, this message translates to:
  /// **'Story skeleton'**
  String get qualityReviewsStageStorySkeleton;

  /// No description provided for @qualityReviewsStageAdaptationStrategy.
  ///
  /// In en, this message translates to:
  /// **'Adaptation strategy'**
  String get qualityReviewsStageAdaptationStrategy;

  /// No description provided for @qualityReviewsStageDirectorPlanning.
  ///
  /// In en, this message translates to:
  /// **'Director planning'**
  String get qualityReviewsStageDirectorPlanning;

  /// No description provided for @qualityReviewsStageStoryboardTable.
  ///
  /// In en, this message translates to:
  /// **'Storyboard table'**
  String get qualityReviewsStageStoryboardTable;

  /// No description provided for @qualityReviewsStageStoryboardPanel.
  ///
  /// In en, this message translates to:
  /// **'Storyboard panel'**
  String get qualityReviewsStageStoryboardPanel;

  /// No description provided for @qualityReviewsStageVideoPrompt.
  ///
  /// In en, this message translates to:
  /// **'Video prompt'**
  String get qualityReviewsStageVideoPrompt;

  /// No description provided for @qualityReviewsSourceAuto.
  ///
  /// In en, this message translates to:
  /// **'source=auto'**
  String get qualityReviewsSourceAuto;

  /// No description provided for @qualityReviewsFieldTargetType.
  ///
  /// In en, this message translates to:
  /// **'targetType'**
  String get qualityReviewsFieldTargetType;

  /// No description provided for @qualityReviewsFieldTargetId.
  ///
  /// In en, this message translates to:
  /// **'targetId'**
  String get qualityReviewsFieldTargetId;

  /// No description provided for @qualityReviewsFieldSource.
  ///
  /// In en, this message translates to:
  /// **'source'**
  String get qualityReviewsFieldSource;

  /// No description provided for @qualityReviewsFieldOverallScore.
  ///
  /// In en, this message translates to:
  /// **'overallScore'**
  String get qualityReviewsFieldOverallScore;

  /// No description provided for @qualityReviewsFieldStage.
  ///
  /// In en, this message translates to:
  /// **'stage'**
  String get qualityReviewsFieldStage;

  /// No description provided for @qualityReviewsFieldGrade.
  ///
  /// In en, this message translates to:
  /// **'grade'**
  String get qualityReviewsFieldGrade;

  /// No description provided for @qualityReviewsFieldComments.
  ///
  /// In en, this message translates to:
  /// **'comments'**
  String get qualityReviewsFieldComments;

  /// No description provided for @qualityReviewsFieldPassed.
  ///
  /// In en, this message translates to:
  /// **'passed'**
  String get qualityReviewsFieldPassed;

  /// No description provided for @qualityReviewsFieldIsBadCase.
  ///
  /// In en, this message translates to:
  /// **'isBadCase'**
  String get qualityReviewsFieldIsBadCase;

  /// No description provided for @qualityReviewsFieldBadCaseCategory.
  ///
  /// In en, this message translates to:
  /// **'badCaseCategory'**
  String get qualityReviewsFieldBadCaseCategory;

  /// No description provided for @qualityReviewsDeliveryTag.
  ///
  /// In en, this message translates to:
  /// **'delivery'**
  String get qualityReviewsDeliveryTag;

  /// No description provided for @qualityReviewsAutoTag.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get qualityReviewsAutoTag;

  /// No description provided for @qualityReviewsMemoryTag.
  ///
  /// In en, this message translates to:
  /// **'memory'**
  String get qualityReviewsMemoryTag;

  /// No description provided for @qualityReviewsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'n/a'**
  String get qualityReviewsNotAvailable;

  /// No description provided for @qualityReviewsReviewRowTitle.
  ///
  /// In en, this message translates to:
  /// **'{targetType} · {source} · score={score}'**
  String qualityReviewsReviewRowTitle(
    String targetType,
    String source,
    String score,
  );

  /// No description provided for @qualityReviewsStageGradeRow.
  ///
  /// In en, this message translates to:
  /// **'{stage} · A {a} / B {b} / C {c} / D {d}'**
  String qualityReviewsStageGradeRow(String stage, int a, int b, int c, int d);

  /// No description provided for @teamWorkspaceInviteTokenAutofillHint.
  ///
  /// In en, this message translates to:
  /// **'Invite token was auto-filled from the link. You can accept directly.'**
  String get teamWorkspaceInviteTokenAutofillHint;

  /// No description provided for @teamWorkspaceOnlyPersonalTitle.
  ///
  /// In en, this message translates to:
  /// **'Only Personal workspace is active'**
  String get teamWorkspaceOnlyPersonalTitle;

  /// No description provided for @teamWorkspaceOnlyPersonalBody.
  ///
  /// In en, this message translates to:
  /// **'To start team collaboration, create an enterprise workspace first, then invite members from member management. Projects, jobs, and Agent context can then share the same team scope.'**
  String get teamWorkspaceOnlyPersonalBody;

  /// No description provided for @teamWorkspaceArchivedFlag.
  ///
  /// In en, this message translates to:
  /// **', archived'**
  String get teamWorkspaceArchivedFlag;

  /// No description provided for @teamWorkspaceCurrentFlag.
  ///
  /// In en, this message translates to:
  /// **', current workspace'**
  String get teamWorkspaceCurrentFlag;

  /// No description provided for @teamWorkspaceRowSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {type} workspace, your role is {role}{archived}{current}'**
  String teamWorkspaceRowSemantics(
    String name,
    String type,
    String role,
    String archived,
    String current,
  );

  /// No description provided for @teamWorkspaceActionTooltip.
  ///
  /// In en, this message translates to:
  /// **'{action} {workspace}'**
  String teamWorkspaceActionTooltip(String action, String workspace);

  /// No description provided for @teamWorkspaceEnterEnterpriseName.
  ///
  /// In en, this message translates to:
  /// **'Please enter enterprise workspace name'**
  String get teamWorkspaceEnterEnterpriseName;

  /// No description provided for @teamWorkspaceCreated.
  ///
  /// In en, this message translates to:
  /// **'Enterprise workspace created'**
  String get teamWorkspaceCreated;

  /// No description provided for @teamWorkspaceCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Create failed: {error}'**
  String teamWorkspaceCreateFailed(String error);

  /// No description provided for @teamWorkspaceEnterInviteToken.
  ///
  /// In en, this message translates to:
  /// **'Please enter invite token'**
  String get teamWorkspaceEnterInviteToken;

  /// No description provided for @teamWorkspaceInviteAcceptedAndJoined.
  ///
  /// In en, this message translates to:
  /// **'Invite accepted and joined workspace'**
  String get teamWorkspaceInviteAcceptedAndJoined;

  /// No description provided for @teamWorkspaceAcceptInviteFailed.
  ///
  /// In en, this message translates to:
  /// **'Accept invite failed: {error}'**
  String teamWorkspaceAcceptInviteFailed(String error);

  /// No description provided for @teamWorkspaceArchiveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive enterprise workspace?'**
  String get teamWorkspaceArchiveDialogTitle;

  /// No description provided for @teamWorkspaceArchiveDialogBody.
  ///
  /// In en, this message translates to:
  /// **'After archiving, this workspace is hidden from default list; if it is current workspace, context switches back to Personal.'**
  String get teamWorkspaceArchiveDialogBody;

  /// No description provided for @teamWorkspaceArchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get teamWorkspaceArchiveAction;

  /// No description provided for @teamWorkspaceArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get teamWorkspaceArchived;

  /// No description provided for @teamWorkspaceRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get teamWorkspaceRestored;

  /// No description provided for @teamWorkspaceOpFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String teamWorkspaceOpFailed(String error);

  /// No description provided for @teamWorkspaceSwitchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String teamWorkspaceSwitchedTo(String name);

  /// No description provided for @teamWorkspaceSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Switch failed: {error}'**
  String teamWorkspaceSwitchFailed(String error);

  /// No description provided for @teamWorkspaceLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage enterprise workspaces.'**
  String get teamWorkspaceLoginRequired;

  /// No description provided for @teamWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Team workspaces'**
  String get teamWorkspaceTitle;

  /// No description provided for @teamWorkspaceIntro.
  ///
  /// In en, this message translates to:
  /// **'List your accessible workspaces (including Personal), create enterprise workspaces, and allow owner/admin to archive or restore them.'**
  String get teamWorkspaceIntro;

  /// No description provided for @teamWorkspaceCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get teamWorkspaceCreating;

  /// No description provided for @teamWorkspaceCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get teamWorkspaceCreateAction;

  /// No description provided for @teamWorkspaceJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get teamWorkspaceJoining;

  /// No description provided for @teamWorkspaceAcceptInviteAction.
  ///
  /// In en, this message translates to:
  /// **'Accept invite'**
  String get teamWorkspaceAcceptInviteAction;

  /// No description provided for @teamWorkspaceShowArchivedToggle.
  ///
  /// In en, this message translates to:
  /// **'Show archived enterprise workspaces'**
  String get teamWorkspaceShowArchivedToggle;

  /// No description provided for @teamWorkspaceLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get teamWorkspaceLoading;

  /// No description provided for @teamWorkspaceRefreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get teamWorkspaceRefreshList;

  /// No description provided for @teamWorkspaceNoListDataHint.
  ///
  /// In en, this message translates to:
  /// **'No list data yet; tap \"Refresh list\".'**
  String get teamWorkspaceNoListDataHint;

  /// No description provided for @teamWorkspaceNoWorkspacesHint.
  ///
  /// In en, this message translates to:
  /// **'No workspace found (unexpected); normally Personal is always available.'**
  String get teamWorkspaceNoWorkspacesHint;

  /// No description provided for @teamWorkspaceArchivedBadge.
  ///
  /// In en, this message translates to:
  /// **'archived'**
  String get teamWorkspaceArchivedBadge;

  /// No description provided for @teamWorkspaceCurrentBadge.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get teamWorkspaceCurrentBadge;

  /// No description provided for @teamWorkspaceManageMembersAction.
  ///
  /// In en, this message translates to:
  /// **'Manage members'**
  String get teamWorkspaceManageMembersAction;

  /// No description provided for @teamWorkspaceMembersShortAction.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get teamWorkspaceMembersShortAction;

  /// No description provided for @teamWorkspaceManageInvitesAction.
  ///
  /// In en, this message translates to:
  /// **'Manage invites'**
  String get teamWorkspaceManageInvitesAction;

  /// No description provided for @teamWorkspaceInvitesShortAction.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get teamWorkspaceInvitesShortAction;

  /// No description provided for @teamWorkspaceSwitchActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Switch to workspace'**
  String get teamWorkspaceSwitchActionLabel;

  /// No description provided for @teamWorkspaceSwitchHereAction.
  ///
  /// In en, this message translates to:
  /// **'Switch here'**
  String get teamWorkspaceSwitchHereAction;

  /// No description provided for @teamWorkspaceArchiveActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Archive workspace'**
  String get teamWorkspaceArchiveActionLabel;

  /// No description provided for @teamWorkspaceRestoreActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore workspace'**
  String get teamWorkspaceRestoreActionLabel;

  /// No description provided for @teamWorkspaceRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get teamWorkspaceRestoreAction;

  /// No description provided for @teamWorkspaceInviteMetaLine.
  ///
  /// In en, this message translates to:
  /// **'Status: {status} · expires: {expiry}'**
  String teamWorkspaceInviteMetaLine(String status, String expiry);

  /// No description provided for @teamWorkspaceInviteStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get teamWorkspaceInviteStatusRevoked;

  /// No description provided for @teamWorkspaceInviteStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get teamWorkspaceInviteStatusExpired;

  /// No description provided for @teamWorkspaceInviteStatusValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get teamWorkspaceInviteStatusValid;

  /// No description provided for @teamWorkspaceInviteStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get teamWorkspaceInviteStatusAccepted;

  /// No description provided for @teamWorkspaceAuditMemberUpserted.
  ///
  /// In en, this message translates to:
  /// **'Member added or updated'**
  String get teamWorkspaceAuditMemberUpserted;

  /// No description provided for @teamWorkspaceAuditMemberRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'Member role changed'**
  String get teamWorkspaceAuditMemberRoleChanged;

  /// No description provided for @teamWorkspaceAuditMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get teamWorkspaceAuditMemberRemoved;

  /// No description provided for @teamWorkspaceAuditMemberLeft.
  ///
  /// In en, this message translates to:
  /// **'Member left workspace'**
  String get teamWorkspaceAuditMemberLeft;

  /// No description provided for @teamWorkspaceAuditOwnerTransferred.
  ///
  /// In en, this message translates to:
  /// **'Owner transferred'**
  String get teamWorkspaceAuditOwnerTransferred;

  /// No description provided for @teamWorkspaceAuditInviteCreated.
  ///
  /// In en, this message translates to:
  /// **'Invite created'**
  String get teamWorkspaceAuditInviteCreated;

  /// No description provided for @teamWorkspaceAuditInviteResent.
  ///
  /// In en, this message translates to:
  /// **'Invite resent'**
  String get teamWorkspaceAuditInviteResent;

  /// No description provided for @teamWorkspaceAuditInviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invite revoked'**
  String get teamWorkspaceAuditInviteRevoked;

  /// No description provided for @teamWorkspaceAuditInviteAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invite accepted'**
  String get teamWorkspaceAuditInviteAccepted;

  /// No description provided for @teamWorkspaceTransferOwnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer owner'**
  String get teamWorkspaceTransferOwnerTitle;

  /// No description provided for @teamWorkspaceTransferOwnerBody.
  ///
  /// In en, this message translates to:
  /// **'Transfer owner of {workspace} from {fromUser} to {toUser}.\n\nAfter confirmation, current owner is downgraded to admin and target member is promoted to owner.'**
  String teamWorkspaceTransferOwnerBody(
    String workspace,
    String fromUser,
    String toUser,
  );

  /// No description provided for @teamWorkspaceConfirmTransferOwner.
  ///
  /// In en, this message translates to:
  /// **'Confirm transfer'**
  String get teamWorkspaceConfirmTransferOwner;

  /// No description provided for @teamWorkspaceMembersDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Members · {workspace}'**
  String teamWorkspaceMembersDialogTitle(String workspace);

  /// No description provided for @teamWorkspaceUserUuidLabel.
  ///
  /// In en, this message translates to:
  /// **'User UUID'**
  String get teamWorkspaceUserUuidLabel;

  /// No description provided for @teamWorkspaceRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get teamWorkspaceRoleLabel;

  /// No description provided for @teamWorkspaceEnterUserUuid.
  ///
  /// In en, this message translates to:
  /// **'Please enter user UUID'**
  String get teamWorkspaceEnterUserUuid;

  /// No description provided for @teamWorkspaceAddingMember.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get teamWorkspaceAddingMember;

  /// No description provided for @teamWorkspaceAddMemberAction.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get teamWorkspaceAddMemberAction;

  /// No description provided for @teamWorkspaceRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get teamWorkspaceRefreshAction;

  /// No description provided for @teamWorkspaceInviteEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite email'**
  String get teamWorkspaceInviteEmailLabel;

  /// No description provided for @teamWorkspaceEnterInviteEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter invite email'**
  String get teamWorkspaceEnterInviteEmail;

  /// No description provided for @teamWorkspaceGeneratingInvite.
  ///
  /// In en, this message translates to:
  /// **'Generating invite…'**
  String get teamWorkspaceGeneratingInvite;

  /// No description provided for @teamWorkspaceGenerateInviteLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Generate invite link'**
  String get teamWorkspaceGenerateInviteLinkAction;

  /// No description provided for @teamWorkspaceOpsStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Internal ops stats'**
  String get teamWorkspaceOpsStatsTitle;

  /// No description provided for @teamWorkspaceReading.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get teamWorkspaceReading;

  /// No description provided for @teamWorkspaceRefreshStats.
  ///
  /// In en, this message translates to:
  /// **'Refresh stats'**
  String get teamWorkspaceRefreshStats;

  /// No description provided for @teamWorkspaceStatsMembers.
  ///
  /// In en, this message translates to:
  /// **'Members {count}'**
  String teamWorkspaceStatsMembers(int count);

  /// No description provided for @teamWorkspaceStatsProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects {count}'**
  String teamWorkspaceStatsProjects(int count);

  /// No description provided for @teamWorkspaceStatsActiveJobs.
  ///
  /// In en, this message translates to:
  /// **'Active jobs {count}'**
  String teamWorkspaceStatsActiveJobs(int count);

  /// No description provided for @teamWorkspacePlatformInvitesTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform invites (server)'**
  String get teamWorkspacePlatformInvitesTitle;

  /// No description provided for @teamWorkspaceIncludeRevokedInvites.
  ///
  /// In en, this message translates to:
  /// **'Include revoked invites'**
  String get teamWorkspaceIncludeRevokedInvites;

  /// No description provided for @teamWorkspaceShowExpiredInvites.
  ///
  /// In en, this message translates to:
  /// **'Show expired invites'**
  String get teamWorkspaceShowExpiredInvites;

  /// No description provided for @teamWorkspaceSearchInvitesHint.
  ///
  /// In en, this message translates to:
  /// **'Search invites (email / role / status)'**
  String get teamWorkspaceSearchInvitesHint;

  /// No description provided for @teamWorkspaceNoInviteRecords.
  ///
  /// In en, this message translates to:
  /// **'No invite records yet. Generate one or load more from server.'**
  String get teamWorkspaceNoInviteRecords;

  /// No description provided for @teamWorkspaceInviteTokenLine.
  ///
  /// In en, this message translates to:
  /// **'invite token: {token}'**
  String teamWorkspaceInviteTokenLine(String token);

  /// No description provided for @teamWorkspaceRefreshInviteLinkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh link (extend expiry and rotate token)'**
  String get teamWorkspaceRefreshInviteLinkTooltip;

  /// No description provided for @teamWorkspaceRevokeInviteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Revoke invite'**
  String get teamWorkspaceRevokeInviteTooltip;

  /// No description provided for @teamWorkspaceCopyInviteInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy invite info'**
  String get teamWorkspaceCopyInviteInfoTooltip;

  /// No description provided for @teamWorkspaceCopiedInvite.
  ///
  /// In en, this message translates to:
  /// **'Copied invite: {email}'**
  String teamWorkspaceCopiedInvite(String email);

  /// No description provided for @teamWorkspaceLoadMoreInvites.
  ///
  /// In en, this message translates to:
  /// **'Load more invites'**
  String get teamWorkspaceLoadMoreInvites;

  /// No description provided for @teamWorkspaceActivityRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity records'**
  String get teamWorkspaceActivityRecordsTitle;

  /// No description provided for @teamWorkspaceSearchActivityHint.
  ///
  /// In en, this message translates to:
  /// **'Search activity (action / actor / target / role / email)'**
  String get teamWorkspaceSearchActivityHint;

  /// No description provided for @teamWorkspaceNoActivityRecords.
  ///
  /// In en, this message translates to:
  /// **'No activity records.'**
  String get teamWorkspaceNoActivityRecords;

  /// No description provided for @teamWorkspaceLoadMoreActivity.
  ///
  /// In en, this message translates to:
  /// **'Load more activity'**
  String get teamWorkspaceLoadMoreActivity;

  /// No description provided for @teamWorkspaceCurrentOwnerLine.
  ///
  /// In en, this message translates to:
  /// **'Current owner: {userId}'**
  String teamWorkspaceCurrentOwnerLine(String userId);

  /// No description provided for @teamWorkspaceSearchMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Search members (UUID / role)'**
  String get teamWorkspaceSearchMembersHint;

  /// No description provided for @teamWorkspaceNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members (unexpected).'**
  String get teamWorkspaceNoMembers;

  /// No description provided for @teamWorkspaceTransferOwnerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Transfer owner'**
  String get teamWorkspaceTransferOwnerTooltip;

  /// No description provided for @teamWorkspaceRemoveMemberTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get teamWorkspaceRemoveMemberTooltip;

  /// No description provided for @teamWorkspaceLeftWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Left this workspace'**
  String get teamWorkspaceLeftWorkspace;

  /// No description provided for @teamWorkspaceLeaving.
  ///
  /// In en, this message translates to:
  /// **'Leaving…'**
  String get teamWorkspaceLeaving;

  /// No description provided for @teamWorkspaceLeaveWorkspaceAction.
  ///
  /// In en, this message translates to:
  /// **'Leave workspace'**
  String get teamWorkspaceLeaveWorkspaceAction;

  /// No description provided for @teamWorkspaceRoleOptionMember.
  ///
  /// In en, this message translates to:
  /// **'member'**
  String get teamWorkspaceRoleOptionMember;

  /// No description provided for @teamWorkspaceRoleOptionAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get teamWorkspaceRoleOptionAdmin;

  /// No description provided for @teamWorkspaceStatusOptionPending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get teamWorkspaceStatusOptionPending;

  /// No description provided for @teamWorkspaceStatusOptionAccepted.
  ///
  /// In en, this message translates to:
  /// **'accepted'**
  String get teamWorkspaceStatusOptionAccepted;

  /// No description provided for @teamWorkspaceStatusOptionRevoked.
  ///
  /// In en, this message translates to:
  /// **'revoked'**
  String get teamWorkspaceStatusOptionRevoked;

  /// No description provided for @teamWorkspaceStatusOptionAll.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get teamWorkspaceStatusOptionAll;

  /// No description provided for @teamWorkspaceInvitesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Invites · {workspace}'**
  String teamWorkspaceInvitesDialogTitle(String workspace);

  /// No description provided for @teamWorkspaceGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get teamWorkspaceGenerating;

  /// No description provided for @teamWorkspaceGenerateInviteAction.
  ///
  /// In en, this message translates to:
  /// **'Generate invite'**
  String get teamWorkspaceGenerateInviteAction;

  /// No description provided for @teamWorkspaceRefreshInvitesAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh invites'**
  String get teamWorkspaceRefreshInvitesAction;

  /// No description provided for @teamWorkspaceCopiedInviteCount.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} invites'**
  String teamWorkspaceCopiedInviteCount(int count);

  /// No description provided for @teamWorkspaceBulkCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Bulk copy'**
  String get teamWorkspaceBulkCopyAction;

  /// No description provided for @teamWorkspaceClearSelectionAction.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get teamWorkspaceClearSelectionAction;

  /// No description provided for @teamWorkspaceStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get teamWorkspaceStatusLabel;

  /// No description provided for @teamWorkspacePageSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get teamWorkspacePageSizeLabel;

  /// No description provided for @teamWorkspaceNoInvitesForCurrentFilters.
  ///
  /// In en, this message translates to:
  /// **'No invites for current filters.'**
  String get teamWorkspaceNoInvitesForCurrentFilters;

  /// No description provided for @teamWorkspacePagingLine.
  ///
  /// In en, this message translates to:
  /// **'Page {page} / {pages} · total {total}'**
  String teamWorkspacePagingLine(int page, int pages, int total);

  /// No description provided for @teamWorkspacePrevPageAction.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get teamWorkspacePrevPageAction;

  /// No description provided for @teamWorkspaceNextPageAction.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get teamWorkspaceNextPageAction;

  /// No description provided for @teamWorkspaceResendInviteLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Resend link'**
  String get teamWorkspaceResendInviteLinkAction;

  /// No description provided for @teamWorkspaceRevokeAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get teamWorkspaceRevokeAction;

  /// No description provided for @teamWorkspaceRoleOptionOwner.
  ///
  /// In en, this message translates to:
  /// **'owner'**
  String get teamWorkspaceRoleOptionOwner;

  /// No description provided for @teamWorkspaceMemberPrimaryOwnerLine.
  ///
  /// In en, this message translates to:
  /// **'{role} · primary owner'**
  String teamWorkspaceMemberPrimaryOwnerLine(String role);

  /// No description provided for @teamWorkspaceEnterpriseNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Enterprise workspace name'**
  String get teamWorkspaceEnterpriseNameLabel;

  /// No description provided for @teamWorkspaceInviteTokenInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite token (accept and join)'**
  String get teamWorkspaceInviteTokenInputLabel;

  /// No description provided for @platformStatusRecoveredHealthy.
  ///
  /// In en, this message translates to:
  /// **'Platform status is healthy again'**
  String get platformStatusRecoveredHealthy;

  /// No description provided for @platformStatusDegradedWarning.
  ///
  /// In en, this message translates to:
  /// **'Platform degraded; check SLI and hot endpoints'**
  String get platformStatusDegradedWarning;

  /// No description provided for @platformStatusNotRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Not refreshed'**
  String get platformStatusNotRefreshed;

  /// No description provided for @platformStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform status'**
  String get platformStatusTitle;

  /// No description provided for @platformStatusWindowMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minute window'**
  String platformStatusWindowMinutes(int minutes);

  /// No description provided for @platformStatusWindowHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hour window'**
  String platformStatusWindowHours(int hours);

  /// No description provided for @platformStatusRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get platformStatusRefreshAction;

  /// No description provided for @platformStatusIntro.
  ///
  /// In en, this message translates to:
  /// **'Inspect health, readiness, version, SLI health, and endpoint request overview.'**
  String get platformStatusIntro;

  /// No description provided for @platformStatusLastRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Last refreshed: {time}'**
  String platformStatusLastRefreshed(String time);

  /// No description provided for @platformStatusAutoRefresh.
  ///
  /// In en, this message translates to:
  /// **'Auto polling'**
  String get platformStatusAutoRefresh;

  /// No description provided for @platformStatusHealthy.
  ///
  /// In en, this message translates to:
  /// **'healthy'**
  String get platformStatusHealthy;

  /// No description provided for @platformStatusDegraded.
  ///
  /// In en, this message translates to:
  /// **'degraded'**
  String get platformStatusDegraded;

  /// No description provided for @platformStatusVersionLine.
  ///
  /// In en, this message translates to:
  /// **'Version: {service} {version}{gitSha}'**
  String platformStatusVersionLine(
    String service,
    String version,
    String gitSha,
  );

  /// No description provided for @platformStatusSliSnapshot.
  ///
  /// In en, this message translates to:
  /// **'SLI snapshot'**
  String get platformStatusSliSnapshot;

  /// No description provided for @platformStatusHotEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Hot endpoints'**
  String get platformStatusHotEndpoints;

  /// No description provided for @platformStatusChipHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get platformStatusChipHealth;

  /// No description provided for @platformStatusChipReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get platformStatusChipReady;

  /// No description provided for @platformStatusChipSli.
  ///
  /// In en, this message translates to:
  /// **'SLI'**
  String get platformStatusChipSli;

  /// No description provided for @platformStatusChipEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Endpoints'**
  String get platformStatusChipEndpoints;

  /// No description provided for @platformStatusChipDegraded.
  ///
  /// In en, this message translates to:
  /// **'Degraded'**
  String get platformStatusChipDegraded;

  /// No description provided for @platformStatusSliTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{path} · P95 {p95Ms}ms · success {successRate}%'**
  String platformStatusSliTileSubtitle(
    String path,
    String p95Ms,
    String successRate,
  );

  /// No description provided for @platformStatusRequests.
  ///
  /// In en, this message translates to:
  /// **'requests {count}'**
  String platformStatusRequests(int count);

  /// No description provided for @platformStatusEndpointTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'total {total} · success {successRate}% · P95 {p95Ms}ms'**
  String platformStatusEndpointTileSubtitle(
    int total,
    String successRate,
    String p95Ms,
  );

  /// No description provided for @platformStatusServerErrors.
  ///
  /// In en, this message translates to:
  /// **'5xx {count}'**
  String platformStatusServerErrors(int count);

  /// No description provided for @adminConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin console'**
  String get adminConsoleTitle;

  /// No description provided for @adminConsoleIntro.
  ///
  /// In en, this message translates to:
  /// **'Internal governance surface. Unified search over users, workspace, project, and job; supports user governance, workspace context repair, member remediation, and workspace/project ownership, archive, and internal-note governance.'**
  String get adminConsoleIntro;

  /// No description provided for @adminConsoleSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search email / workspace / project / job'**
  String get adminConsoleSearchLabel;

  /// No description provided for @adminConsoleSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Supports UUID prefix, project numeric_id, and status/kind keywords'**
  String get adminConsoleSearchHint;

  /// No description provided for @adminConsoleSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get adminConsoleSearchAction;

  /// No description provided for @adminConsoleClearDetailAction.
  ///
  /// In en, this message translates to:
  /// **'Clear detail'**
  String get adminConsoleClearDetailAction;

  /// No description provided for @adminConsoleGroupUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminConsoleGroupUsers;

  /// No description provided for @adminConsoleEmptyUsers.
  ///
  /// In en, this message translates to:
  /// **'No matching users'**
  String get adminConsoleEmptyUsers;

  /// No description provided for @adminConsoleGroupWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get adminConsoleGroupWorkspaces;

  /// No description provided for @adminConsoleEmptyWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'No matching workspace'**
  String get adminConsoleEmptyWorkspaces;

  /// No description provided for @adminConsoleGroupProjects.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get adminConsoleGroupProjects;

  /// No description provided for @adminConsoleEmptyProjects.
  ///
  /// In en, this message translates to:
  /// **'No matching project'**
  String get adminConsoleEmptyProjects;

  /// No description provided for @adminConsoleGroupJobs.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get adminConsoleGroupJobs;

  /// No description provided for @adminConsoleEmptyJobs.
  ///
  /// In en, this message translates to:
  /// **'No matching job'**
  String get adminConsoleEmptyJobs;

  /// No description provided for @adminConsoleUserHitSummary.
  ///
  /// In en, this message translates to:
  /// **'plan {plan} · {status} · ws {workspaces} · project {projects} · active job {activeJobs}'**
  String adminConsoleUserHitSummary(
    String plan,
    String status,
    int workspaces,
    int projects,
    int activeJobs,
  );

  /// No description provided for @adminConsoleWorkspaceHitSummary.
  ///
  /// In en, this message translates to:
  /// **'{workspaceType} · member {members} · project {projects} · active job {activeJobs}{archivedSuffix}'**
  String adminConsoleWorkspaceHitSummary(
    String workspaceType,
    int members,
    int projects,
    int activeJobs,
    String archivedSuffix,
  );

  /// No description provided for @adminConsoleArchivedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · archived'**
  String get adminConsoleArchivedSuffix;

  /// No description provided for @adminConsoleNoWorkspace.
  ///
  /// In en, this message translates to:
  /// **'no workspace'**
  String get adminConsoleNoWorkspace;

  /// No description provided for @adminConsoleProjectHitSummary.
  ///
  /// In en, this message translates to:
  /// **'#{numericId} · {workspaceName} · {owner}{archivedSuffix}'**
  String adminConsoleProjectHitSummary(
    int numericId,
    String workspaceName,
    String owner,
    String archivedSuffix,
  );

  /// No description provided for @adminConsoleJobHitTitle.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {status}'**
  String adminConsoleJobHitTitle(String kind, String status);

  /// No description provided for @adminConsoleJobHitSummary.
  ///
  /// In en, this message translates to:
  /// **'{owner} · project {projectNumericId} · {createdAt}'**
  String adminConsoleJobHitSummary(
    String owner,
    String projectNumericId,
    String createdAt,
  );

  /// No description provided for @adminConsoleChipPlan.
  ///
  /// In en, this message translates to:
  /// **'plan {value}'**
  String adminConsoleChipPlan(String value);

  /// No description provided for @adminConsoleChipWorkspace.
  ///
  /// In en, this message translates to:
  /// **'workspace {value}'**
  String adminConsoleChipWorkspace(int value);

  /// No description provided for @adminConsoleChipProject.
  ///
  /// In en, this message translates to:
  /// **'project {value}'**
  String adminConsoleChipProject(int value);

  /// No description provided for @adminConsoleChipActiveJob.
  ///
  /// In en, this message translates to:
  /// **'active job {value}'**
  String adminConsoleChipActiveJob(int value);

  /// No description provided for @adminConsoleChipApiKey.
  ///
  /// In en, this message translates to:
  /// **'api key {value}'**
  String adminConsoleChipApiKey(int value);

  /// No description provided for @adminConsoleChipUnreadNotif.
  ///
  /// In en, this message translates to:
  /// **'unread notif {value}'**
  String adminConsoleChipUnreadNotif(int value);

  /// No description provided for @adminConsoleSectionMemberships.
  ///
  /// In en, this message translates to:
  /// **'Memberships'**
  String get adminConsoleSectionMemberships;

  /// No description provided for @adminConsoleSectionRecentJobs.
  ///
  /// In en, this message translates to:
  /// **'Recent jobs'**
  String get adminConsoleSectionRecentJobs;

  /// No description provided for @adminConsoleSectionGovernanceAudit.
  ///
  /// In en, this message translates to:
  /// **'Governance audit'**
  String get adminConsoleSectionGovernanceAudit;

  /// No description provided for @adminConsoleGovernanceActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Governance actions'**
  String get adminConsoleGovernanceActionsTitle;

  /// No description provided for @adminConsoleStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminConsoleStatusActive;

  /// No description provided for @adminConsoleStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get adminConsoleStatusSuspended;

  /// No description provided for @adminConsoleSuspendReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Suspension reason'**
  String get adminConsoleSuspendReasonLabel;

  /// No description provided for @adminConsoleSuspendReasonHint.
  ///
  /// In en, this message translates to:
  /// **'For example: abuse, refund dispute, or manual risk-control hit'**
  String get adminConsoleSuspendReasonHint;

  /// No description provided for @adminConsoleSuspendReasonDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Suspension reason is not saved when user is active'**
  String get adminConsoleSuspendReasonDisabledHint;

  /// No description provided for @adminConsoleInternalNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Internal note'**
  String get adminConsoleInternalNoteLabel;

  /// No description provided for @adminConsoleInternalNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Context for operations / support / risk-control teammates'**
  String get adminConsoleInternalNoteHint;

  /// No description provided for @adminConsoleDailyQuotaOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily quota override'**
  String get adminConsoleDailyQuotaOverrideTitle;

  /// No description provided for @adminConsoleDailyQuotaNotOverridden.
  ///
  /// In en, this message translates to:
  /// **'No override currently; package default quota is used.'**
  String get adminConsoleDailyQuotaNotOverridden;

  /// No description provided for @adminConsoleDailyQuotaCurrentOverride.
  ///
  /// In en, this message translates to:
  /// **'Current override: {value}'**
  String adminConsoleDailyQuotaCurrentOverride(int value);

  /// No description provided for @adminConsoleQuotaActionPreserve.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get adminConsoleQuotaActionPreserve;

  /// No description provided for @adminConsoleQuotaActionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear override'**
  String get adminConsoleQuotaActionClear;

  /// No description provided for @adminConsoleQuotaActionSet.
  ///
  /// In en, this message translates to:
  /// **'Set quota'**
  String get adminConsoleQuotaActionSet;

  /// No description provided for @adminConsoleDailyQuotaInputExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 500'**
  String get adminConsoleDailyQuotaInputExample;

  /// No description provided for @adminConsoleDailyQuotaInputDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Only effective when \"Set quota\" is selected'**
  String get adminConsoleDailyQuotaInputDisabledHint;

  /// No description provided for @adminConsoleSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get adminConsoleSaving;

  /// No description provided for @adminConsoleSaveGovernanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Save governance settings'**
  String get adminConsoleSaveGovernanceSettings;

  /// No description provided for @adminConsoleWorkspaceContextRepairTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace context repair'**
  String get adminConsoleWorkspaceContextRepairTitle;

  /// No description provided for @adminConsoleWorkspaceContextRepairIntro.
  ///
  /// In en, this message translates to:
  /// **'Used for scenarios where current_workspace points to an invalid workspace, or membership has changed but user is still stuck on old workspace.'**
  String get adminConsoleWorkspaceContextRepairIntro;

  /// No description provided for @adminConsoleWorkspaceContextRebuildAndSwitchPersonal.
  ///
  /// In en, this message translates to:
  /// **'Rebuild and switch to Personal'**
  String get adminConsoleWorkspaceContextRebuildAndSwitchPersonal;

  /// No description provided for @adminConsoleWorkspaceContextSwitchPersonal.
  ///
  /// In en, this message translates to:
  /// **'Switch to Personal'**
  String get adminConsoleWorkspaceContextSwitchPersonal;

  /// No description provided for @adminConsoleWorkspaceContextSwitchTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to {workspaceName}'**
  String adminConsoleWorkspaceContextSwitchTo(String workspaceName);

  /// No description provided for @adminConsoleWorkspaceContextRepairing.
  ///
  /// In en, this message translates to:
  /// **'Repairing workspace context...'**
  String get adminConsoleWorkspaceContextRepairing;

  /// No description provided for @adminConsoleWorkspaceGovernanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace governance'**
  String get adminConsoleWorkspaceGovernanceTitle;

  /// No description provided for @adminConsoleWorkspaceGovernancePersonalHint.
  ///
  /// In en, this message translates to:
  /// **'Personal workspace cannot be archived; internal notes (metadata.internalOps) can be maintained.'**
  String get adminConsoleWorkspaceGovernancePersonalHint;

  /// No description provided for @adminConsoleWorkspaceGovernanceEnterpriseHint.
  ///
  /// In en, this message translates to:
  /// **'Enterprise workspace can be archived (soft-frozen) or restored; internal notes are written to metadata.internalOps.'**
  String get adminConsoleWorkspaceGovernanceEnterpriseHint;

  /// No description provided for @adminConsoleLifecyclePreserve.
  ///
  /// In en, this message translates to:
  /// **'Keep lifecycle unchanged'**
  String get adminConsoleLifecyclePreserve;

  /// No description provided for @adminConsoleLifecycleArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get adminConsoleLifecycleArchive;

  /// No description provided for @adminConsoleLifecycleRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get adminConsoleLifecycleRestore;

  /// No description provided for @adminConsoleNoteActionPreserve.
  ///
  /// In en, this message translates to:
  /// **'Keep note unchanged'**
  String get adminConsoleNoteActionPreserve;

  /// No description provided for @adminConsoleNoteActionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear note'**
  String get adminConsoleNoteActionClear;

  /// No description provided for @adminConsoleNoteActionSet.
  ///
  /// In en, this message translates to:
  /// **'Write/Update note'**
  String get adminConsoleNoteActionSet;

  /// No description provided for @adminConsoleInternalNoteBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Internal note body'**
  String get adminConsoleInternalNoteBodyLabel;

  /// No description provided for @adminConsoleInternalNoteBodySubmitHint.
  ///
  /// In en, this message translates to:
  /// **'Submitted only when \"Write/Update note\" is selected'**
  String get adminConsoleInternalNoteBodySubmitHint;

  /// No description provided for @adminConsoleInternalNoteBodyEditableHint.
  ///
  /// In en, this message translates to:
  /// **'Editable after selecting \"Write/Update note\"'**
  String get adminConsoleInternalNoteBodyEditableHint;

  /// No description provided for @adminConsoleSaveGovernance.
  ///
  /// In en, this message translates to:
  /// **'Save governance'**
  String get adminConsoleSaveGovernance;

  /// No description provided for @adminConsoleWorkspaceMemberRemediationTitle.
  ///
  /// In en, this message translates to:
  /// **'Member remediation'**
  String get adminConsoleWorkspaceMemberRemediationTitle;

  /// No description provided for @adminConsoleWorkspaceMemberRemediationHint.
  ///
  /// In en, this message translates to:
  /// **'Internal ops can directly add member, change role, or remove member. Removal also falls back current workspace and clears stale project ACL entries under this workspace.'**
  String get adminConsoleWorkspaceMemberRemediationHint;

  /// No description provided for @adminConsoleMemberUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Member userId'**
  String get adminConsoleMemberUserIdLabel;

  /// No description provided for @adminConsoleMemberUserIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter user UUID to add member or change role'**
  String get adminConsoleMemberUserIdHint;

  /// No description provided for @adminConsoleRoleMember.
  ///
  /// In en, this message translates to:
  /// **'member'**
  String get adminConsoleRoleMember;

  /// No description provided for @adminConsoleRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get adminConsoleRoleAdmin;

  /// No description provided for @adminConsoleProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get adminConsoleProcessing;

  /// No description provided for @adminConsoleUpsertMemberAction.
  ///
  /// In en, this message translates to:
  /// **'Add member / change role'**
  String get adminConsoleUpsertMemberAction;

  /// No description provided for @adminConsoleSetAsMember.
  ///
  /// In en, this message translates to:
  /// **'Set as member'**
  String get adminConsoleSetAsMember;

  /// No description provided for @adminConsoleSetAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Set as admin'**
  String get adminConsoleSetAsAdmin;

  /// No description provided for @adminConsoleRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adminConsoleRemoveAction;

  /// No description provided for @adminConsoleOwnerTransferHint.
  ///
  /// In en, this message translates to:
  /// **'Use owner transfer for owner'**
  String get adminConsoleOwnerTransferHint;

  /// No description provided for @adminConsoleWorkspaceOwnerRemediationTitle.
  ///
  /// In en, this message translates to:
  /// **'Owner remediation'**
  String get adminConsoleWorkspaceOwnerRemediationTitle;

  /// No description provided for @adminConsoleWorkspaceOwnerRemediationPersonalHint.
  ///
  /// In en, this message translates to:
  /// **'Owner transfer is not allowed for personal workspace.'**
  String get adminConsoleWorkspaceOwnerRemediationPersonalHint;

  /// No description provided for @adminConsoleWorkspaceOwnerRemediationHint.
  ///
  /// In en, this message translates to:
  /// **'Internal ops can directly remediate workspace owner. Target user must already be a workspace member, and previous owner is automatically downgraded to admin.'**
  String get adminConsoleWorkspaceOwnerRemediationHint;

  /// No description provided for @adminConsoleTargetOwnerUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Target owner userId'**
  String get adminConsoleTargetOwnerUserIdLabel;

  /// No description provided for @adminConsoleTargetOwnerUserIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter target member UUID'**
  String get adminConsoleTargetOwnerUserIdHint;

  /// No description provided for @adminConsoleTransferOwnerAction.
  ///
  /// In en, this message translates to:
  /// **'Transfer owner'**
  String get adminConsoleTransferOwnerAction;

  /// No description provided for @adminConsoleSetAsOwner.
  ///
  /// In en, this message translates to:
  /// **'Set as owner'**
  String get adminConsoleSetAsOwner;

  /// No description provided for @adminConsoleAclSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'ACL summary'**
  String get adminConsoleAclSummaryTitle;

  /// No description provided for @adminConsoleRoleCountOwner.
  ///
  /// In en, this message translates to:
  /// **'owner {count}'**
  String adminConsoleRoleCountOwner(int count);

  /// No description provided for @adminConsoleRoleCountAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin {count}'**
  String adminConsoleRoleCountAdmin(int count);

  /// No description provided for @adminConsoleRoleCountMember.
  ///
  /// In en, this message translates to:
  /// **'member {count}'**
  String adminConsoleRoleCountMember(int count);

  /// No description provided for @adminConsoleNoProjectAclSummary.
  ///
  /// In en, this message translates to:
  /// **'No project ACL summary in current workspace'**
  String get adminConsoleNoProjectAclSummary;

  /// No description provided for @adminConsoleExplicitAclCount.
  ///
  /// In en, this message translates to:
  /// **'explicit {count}'**
  String adminConsoleExplicitAclCount(int count);

  /// No description provided for @adminConsoleEditorCount.
  ///
  /// In en, this message translates to:
  /// **'editor {count}'**
  String adminConsoleEditorCount(int count);

  /// No description provided for @adminConsoleViewerCount.
  ///
  /// In en, this message translates to:
  /// **'viewer {count}'**
  String adminConsoleViewerCount(int count);

  /// No description provided for @adminConsoleViewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get adminConsoleViewAction;

  /// No description provided for @adminConsoleBatchProjectGovernanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch project governance'**
  String get adminConsoleBatchProjectGovernanceTitle;

  /// No description provided for @adminConsoleBatchProjectGovernanceHint.
  ///
  /// In en, this message translates to:
  /// **'Batch apply archive / restore / internal note writes to selected projects under current workspace for clustered ACL and governance remediation.'**
  String get adminConsoleBatchProjectGovernanceHint;

  /// No description provided for @adminConsoleBatchLifecyclePreserve.
  ///
  /// In en, this message translates to:
  /// **'Keep archive state unchanged'**
  String get adminConsoleBatchLifecyclePreserve;

  /// No description provided for @adminConsoleBatchLifecycleArchive.
  ///
  /// In en, this message translates to:
  /// **'Batch archive'**
  String get adminConsoleBatchLifecycleArchive;

  /// No description provided for @adminConsoleBatchLifecycleRestore.
  ///
  /// In en, this message translates to:
  /// **'Batch restore'**
  String get adminConsoleBatchLifecycleRestore;

  /// No description provided for @adminConsoleBatchNotePreserve.
  ///
  /// In en, this message translates to:
  /// **'Keep note unchanged'**
  String get adminConsoleBatchNotePreserve;

  /// No description provided for @adminConsoleBatchNoteClear.
  ///
  /// In en, this message translates to:
  /// **'Clear note'**
  String get adminConsoleBatchNoteClear;

  /// No description provided for @adminConsoleBatchNoteSet.
  ///
  /// In en, this message translates to:
  /// **'Write note'**
  String get adminConsoleBatchNoteSet;

  /// No description provided for @adminConsoleBatchNoteBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch internal note'**
  String get adminConsoleBatchNoteBodyLabel;

  /// No description provided for @adminConsoleBatchNoteBodySubmitHint.
  ///
  /// In en, this message translates to:
  /// **'Submitted only when \"Write note\" is selected'**
  String get adminConsoleBatchNoteBodySubmitHint;

  /// No description provided for @adminConsoleBatchNoteBodyEditableHint.
  ///
  /// In en, this message translates to:
  /// **'Editable after selecting \"Write note\"'**
  String get adminConsoleBatchNoteBodyEditableHint;

  /// No description provided for @adminConsoleBatchApplyAction.
  ///
  /// In en, this message translates to:
  /// **'Batch apply to {count} projects'**
  String adminConsoleBatchApplyAction(int count);

  /// No description provided for @adminConsoleSectionMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get adminConsoleSectionMembers;

  /// No description provided for @adminConsoleSectionRecentProjects.
  ///
  /// In en, this message translates to:
  /// **'Recent projects'**
  String get adminConsoleSectionRecentProjects;

  /// No description provided for @adminConsoleProjectOwnerRemediationTitle.
  ///
  /// In en, this message translates to:
  /// **'Project owner remediation'**
  String get adminConsoleProjectOwnerRemediationTitle;

  /// No description provided for @adminConsoleProjectOwnerRemediationHint.
  ///
  /// In en, this message translates to:
  /// **'Internal ops can directly remediate project owner. Target user must already be a member in the project workspace. If ACL is enabled, old owner with member role keeps editor access automatically.'**
  String get adminConsoleProjectOwnerRemediationHint;

  /// No description provided for @adminConsoleTargetProjectOwnerUserIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter target workspace member UUID'**
  String get adminConsoleTargetProjectOwnerUserIdHint;

  /// No description provided for @adminConsoleRepairProjectOwnerAction.
  ///
  /// In en, this message translates to:
  /// **'Repair project owner'**
  String get adminConsoleRepairProjectOwnerAction;

  /// No description provided for @adminConsoleProjectGovernanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Project governance'**
  String get adminConsoleProjectGovernanceTitle;

  /// No description provided for @adminConsoleProjectGovernanceHint.
  ///
  /// In en, this message translates to:
  /// **'After archive, the project is hidden from member lists and aggregate statistics, and all project-scope APIs return 403; restore reverses this. Internal note is written to metadata.internalOps.'**
  String get adminConsoleProjectGovernanceHint;

  /// No description provided for @adminConsoleProjectTitleWithName.
  ///
  /// In en, this message translates to:
  /// **'{name} (#{numericId})'**
  String adminConsoleProjectTitleWithName(String name, int numericId);

  /// No description provided for @adminConsoleProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Project #{numericId}'**
  String adminConsoleProjectTitle(int numericId);

  /// No description provided for @adminConsoleSectionExplicitAclMembers.
  ///
  /// In en, this message translates to:
  /// **'Explicit ACL members'**
  String get adminConsoleSectionExplicitAclMembers;

  /// No description provided for @adminConsoleSectionWorkspaceCandidates.
  ///
  /// In en, this message translates to:
  /// **'Workspace candidate members'**
  String get adminConsoleSectionWorkspaceCandidates;

  /// No description provided for @adminConsoleNoData.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get adminConsoleNoData;

  /// No description provided for @adminConsoleErrSearchAtLeast2Chars.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least 2 characters'**
  String get adminConsoleErrSearchAtLeast2Chars;

  /// No description provided for @adminConsoleErrSuspendReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Suspension reason is required when suspending a user'**
  String get adminConsoleErrSuspendReasonRequired;

  /// No description provided for @adminConsoleErrDailyQuotaPositiveRequired.
  ///
  /// In en, this message translates to:
  /// **'A positive integer is required when setting daily quota'**
  String get adminConsoleErrDailyQuotaPositiveRequired;

  /// No description provided for @adminConsoleErrInternalNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Internal note content is required when setting note'**
  String get adminConsoleErrInternalNoteRequired;

  /// No description provided for @adminConsoleErrMemberUserIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Member userId cannot be empty'**
  String get adminConsoleErrMemberUserIdRequired;

  /// No description provided for @adminConsoleErrMemberRoleRequired.
  ///
  /// In en, this message translates to:
  /// **'Role is required when adding or updating a member'**
  String get adminConsoleErrMemberRoleRequired;

  /// No description provided for @adminConsoleErrTargetOwnerUserIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Target owner userId cannot be empty'**
  String get adminConsoleErrTargetOwnerUserIdRequired;

  /// No description provided for @adminConsoleErrAtLeastOneProjectRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one project'**
  String get adminConsoleErrAtLeastOneProjectRequired;

  /// No description provided for @adminConsoleErrBatchNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Batch note content is required when writing notes'**
  String get adminConsoleErrBatchNoteRequired;

  /// No description provided for @contentComplianceWorkspacePersonalScope.
  ///
  /// In en, this message translates to:
  /// **'Personal / direct user scope'**
  String get contentComplianceWorkspacePersonalScope;

  /// No description provided for @contentComplianceOpenProject.
  ///
  /// In en, this message translates to:
  /// **'Open project'**
  String get contentComplianceOpenProject;

  /// No description provided for @contentComplianceOpenScriptProject.
  ///
  /// In en, this message translates to:
  /// **'Open script project'**
  String get contentComplianceOpenScriptProject;

  /// No description provided for @contentComplianceOpenStoryboardProject.
  ///
  /// In en, this message translates to:
  /// **'Open storyboard project'**
  String get contentComplianceOpenStoryboardProject;

  /// No description provided for @contentComplianceOpenAssetProject.
  ///
  /// In en, this message translates to:
  /// **'Open asset project'**
  String get contentComplianceOpenAssetProject;

  /// No description provided for @contentComplianceOpenNovelProject.
  ///
  /// In en, this message translates to:
  /// **'Open novel project'**
  String get contentComplianceOpenNovelProject;

  /// No description provided for @contentComplianceOpenUserContext.
  ///
  /// In en, this message translates to:
  /// **'View user context'**
  String get contentComplianceOpenUserContext;

  /// No description provided for @contentComplianceOpenContext.
  ///
  /// In en, this message translates to:
  /// **'Open context'**
  String get contentComplianceOpenContext;

  /// No description provided for @contentComplianceOwnerUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'Unclaimed'**
  String get contentComplianceOwnerUnclaimed;

  /// No description provided for @contentComplianceEscalationCriticalUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'critical unclaimed'**
  String get contentComplianceEscalationCriticalUnclaimed;

  /// No description provided for @contentComplianceEscalationStalledClaimed.
  ///
  /// In en, this message translates to:
  /// **'claimed stalled'**
  String get contentComplianceEscalationStalledClaimed;

  /// No description provided for @contentComplianceEscalationOverCapacity.
  ///
  /// In en, this message translates to:
  /// **'reviewer overloaded'**
  String get contentComplianceEscalationOverCapacity;

  /// No description provided for @contentComplianceEscalationEscalated72h.
  ///
  /// In en, this message translates to:
  /// **'72h escalated'**
  String get contentComplianceEscalationEscalated72h;

  /// No description provided for @contentComplianceEscalationUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get contentComplianceEscalationUrgent;

  /// No description provided for @contentComplianceEscalationClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get contentComplianceEscalationClosed;

  /// No description provided for @contentComplianceEscalationWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get contentComplianceEscalationWatch;

  /// No description provided for @contentComplianceAlertHintCriticalUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'Start by bulk-claiming critical unclaimed items.'**
  String get contentComplianceAlertHintCriticalUnclaimed;

  /// No description provided for @contentComplianceAlertHintOverCapacity.
  ///
  /// In en, this message translates to:
  /// **'Preview or run auto-rebalance first.'**
  String get contentComplianceAlertHintOverCapacity;

  /// No description provided for @contentComplianceAlertHintStalledClaimed.
  ///
  /// In en, this message translates to:
  /// **'Handle stalled claimed items first (reassign or converge).'**
  String get contentComplianceAlertHintStalledClaimed;

  /// No description provided for @contentComplianceAlertHintEscalated72h.
  ///
  /// In en, this message translates to:
  /// **'Prioritize clearing 72h non-converged items.'**
  String get contentComplianceAlertHintEscalated72h;

  /// No description provided for @contentComplianceAlertHintDefault.
  ///
  /// In en, this message translates to:
  /// **'Review this layer and address high-risk items first.'**
  String get contentComplianceAlertHintDefault;

  /// No description provided for @contentComplianceSnackNoCriticalUnclaimedBulkClaim.
  ///
  /// In en, this message translates to:
  /// **'No critical unclaimed items available for bulk claim.'**
  String get contentComplianceSnackNoCriticalUnclaimedBulkClaim;

  /// No description provided for @contentComplianceSnackSelectedStalledClaimed.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} stalled claimed items; you can reassign or process them.'**
  String contentComplianceSnackSelectedStalledClaimed(int count);

  /// No description provided for @contentComplianceSnackSelected72hUnconverged.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} 72h non-converged items; you can reassign or process them.'**
  String contentComplianceSnackSelected72hUnconverged(int count);

  /// No description provided for @contentComplianceSnackSelectedCriticalUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} critical unclaimed items.'**
  String contentComplianceSnackSelectedCriticalUnclaimed(int count);

  /// No description provided for @contentComplianceSnackSelected72hItems.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} 72h non-converged items.'**
  String contentComplianceSnackSelected72hItems(int count);

  /// No description provided for @contentComplianceSnackRestoredDefaultActionOrder.
  ///
  /// In en, this message translates to:
  /// **'Restored default action order.'**
  String get contentComplianceSnackRestoredDefaultActionOrder;

  /// No description provided for @contentComplianceBulkClaim.
  ///
  /// In en, this message translates to:
  /// **'Bulk claim'**
  String get contentComplianceBulkClaim;

  /// No description provided for @contentComplianceBulkResolve.
  ///
  /// In en, this message translates to:
  /// **'Bulk resolve'**
  String get contentComplianceBulkResolve;

  /// No description provided for @contentComplianceBulkDismiss.
  ///
  /// In en, this message translates to:
  /// **'Bulk dismiss'**
  String get contentComplianceBulkDismiss;

  /// No description provided for @contentComplianceBulkGeneric.
  ///
  /// In en, this message translates to:
  /// **'Bulk action'**
  String get contentComplianceBulkGeneric;

  /// No description provided for @contentComplianceBulkConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Run {verb} on {count} reports?'**
  String contentComplianceBulkConfirmBody(String verb, int count);

  /// No description provided for @contentComplianceBulkConfirmNoteReuse.
  ///
  /// In en, this message translates to:
  /// **'\n\nWill reuse the current resolution note.'**
  String get contentComplianceBulkConfirmNoteReuse;

  /// No description provided for @contentComplianceBulkResult.
  ///
  /// In en, this message translates to:
  /// **'{verb} finished: succeeded {succeeded}, failed {failed}; {remainingAlerts} alerts remaining ({criticalAlerts} high priority).'**
  String contentComplianceBulkResult(
    String verb,
    int succeeded,
    int failed,
    int remainingAlerts,
    int criticalAlerts,
  );

  /// No description provided for @contentComplianceCsvCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied filtered queue CSV ({count} rows).'**
  String contentComplianceCsvCopied(int count);

  /// No description provided for @contentComplianceFillReviewerFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter a target reviewer first.'**
  String get contentComplianceFillReviewerFirst;

  /// No description provided for @contentComplianceReassignTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk reassign'**
  String get contentComplianceReassignTitle;

  /// No description provided for @contentComplianceReassignBody.
  ///
  /// In en, this message translates to:
  /// **'Reassign {count} reports to {assignee}?'**
  String contentComplianceReassignBody(int count, String assignee);

  /// No description provided for @contentComplianceReassignResult.
  ///
  /// In en, this message translates to:
  /// **'Reassigned to {assignee}: succeeded {succeeded}, failed {failed}.'**
  String contentComplianceReassignResult(
    String assignee,
    int succeeded,
    int failed,
  );

  /// No description provided for @contentComplianceAutoRebalanceNoOverload.
  ///
  /// In en, this message translates to:
  /// **'No overloaded reviewers; auto-rebalance is not needed.'**
  String get contentComplianceAutoRebalanceNoOverload;

  /// No description provided for @contentComplianceAutoRebalanceTitlePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview auto-rebalance'**
  String get contentComplianceAutoRebalanceTitlePreview;

  /// No description provided for @contentComplianceAutoRebalanceTitleExecute.
  ///
  /// In en, this message translates to:
  /// **'Run auto-rebalance'**
  String get contentComplianceAutoRebalanceTitleExecute;

  /// No description provided for @contentComplianceAutoRebalanceBodyPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview reassignment plan at capacity threshold ({limit}); nothing will be written.'**
  String contentComplianceAutoRebalanceBodyPreview(int limit);

  /// No description provided for @contentComplianceAutoRebalanceBodyExecute.
  ///
  /// In en, this message translates to:
  /// **'Run automatic reassignment at capacity threshold ({limit}) and write audit records.'**
  String contentComplianceAutoRebalanceBodyExecute(int limit);

  /// No description provided for @contentComplianceStartPreview.
  ///
  /// In en, this message translates to:
  /// **'Start preview'**
  String get contentComplianceStartPreview;

  /// No description provided for @contentComplianceExecuteNow.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get contentComplianceExecuteNow;

  /// No description provided for @contentComplianceAutoRebalanceResultPreview.
  ///
  /// In en, this message translates to:
  /// **'Auto-rebalance preview: {planned} moves suggested (capacity {capacity}).'**
  String contentComplianceAutoRebalanceResultPreview(int planned, int capacity);

  /// No description provided for @contentComplianceAutoRebalanceResultExecute.
  ///
  /// In en, this message translates to:
  /// **'Auto-rebalance done: planned {planned}, executed {executed}; over_capacity remaining {overCapacityRemaining}, {remainingAlerts} alerts total.'**
  String contentComplianceAutoRebalanceResultExecute(
    int planned,
    int executed,
    int overCapacityRemaining,
    int remainingAlerts,
  );

  /// No description provided for @contentComplianceAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Report audit · {reportId}'**
  String contentComplianceAuditTitle(String reportId);

  /// No description provided for @contentComplianceAuditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No audit records to display.'**
  String get contentComplianceAuditEmpty;

  /// No description provided for @contentComplianceTitle.
  ///
  /// In en, this message translates to:
  /// **'Content & compliance'**
  String get contentComplianceTitle;

  /// No description provided for @contentComplianceIntro.
  ///
  /// In en, this message translates to:
  /// **'One place for user-submitted content reports and internal-ops claim/resolve review queues.'**
  String get contentComplianceIntro;

  /// No description provided for @contentComplianceSubmitReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get contentComplianceSubmitReportTitle;

  /// No description provided for @contentComplianceTargetUuidHint.
  ///
  /// In en, this message translates to:
  /// **'Enter reported object UUID'**
  String get contentComplianceTargetUuidHint;

  /// No description provided for @contentComplianceDetailLabel.
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get contentComplianceDetailLabel;

  /// No description provided for @contentComplianceDetailHint.
  ///
  /// In en, this message translates to:
  /// **'Add context, timeline, or risk description'**
  String get contentComplianceDetailHint;

  /// No description provided for @contentComplianceSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get contentComplianceSubmitting;

  /// No description provided for @contentComplianceSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get contentComplianceSubmitReport;

  /// No description provided for @contentComplianceQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Review queue'**
  String get contentComplianceQueueTitle;

  /// No description provided for @contentComplianceClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get contentComplianceClearFilters;

  /// No description provided for @contentComplianceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get contentComplianceRefresh;

  /// No description provided for @contentComplianceCopyCsv.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV'**
  String get contentComplianceCopyCsv;

  /// No description provided for @contentComplianceTopActionSummary.
  ///
  /// In en, this message translates to:
  /// **'Primary action: {title} ({count})\n{hint}'**
  String contentComplianceTopActionSummary(
    String title,
    int count,
    String hint,
  );

  /// No description provided for @contentComplianceViewLayer.
  ///
  /// In en, this message translates to:
  /// **'View this layer'**
  String get contentComplianceViewLayer;

  /// No description provided for @contentComplianceRestoreDefaultActionOrder.
  ///
  /// In en, this message translates to:
  /// **'Restore default action order'**
  String get contentComplianceRestoreDefaultActionOrder;

  /// No description provided for @contentCompliancePreviewRebalanceShort.
  ///
  /// In en, this message translates to:
  /// **'Preview rebalance'**
  String get contentCompliancePreviewRebalanceShort;

  /// No description provided for @contentComplianceExecuteRebalanceShort.
  ///
  /// In en, this message translates to:
  /// **'Run rebalance'**
  String get contentComplianceExecuteRebalanceShort;

  /// No description provided for @contentComplianceSnackSelectedCriticalReadyClaim.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} critical unclaimed items; you can bulk claim.'**
  String contentComplianceSnackSelectedCriticalReadyClaim(int count);

  /// No description provided for @contentComplianceSelectCriticalUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'Select critical unclaimed'**
  String get contentComplianceSelectCriticalUnclaimed;

  /// No description provided for @contentComplianceSnackNoCriticalUnclaimedInList.
  ///
  /// In en, this message translates to:
  /// **'No critical unclaimed items in the current list for bulk claim.'**
  String get contentComplianceSnackNoCriticalUnclaimedInList;

  /// No description provided for @contentComplianceBulkClaimOneClick.
  ///
  /// In en, this message translates to:
  /// **'Bulk claim (one click)'**
  String get contentComplianceBulkClaimOneClick;

  /// No description provided for @contentComplianceSelectStalled.
  ///
  /// In en, this message translates to:
  /// **'Select stalled'**
  String get contentComplianceSelectStalled;

  /// No description provided for @contentCompliancePreviewStalledRebalance.
  ///
  /// In en, this message translates to:
  /// **'Preview stalled rebalance'**
  String get contentCompliancePreviewStalledRebalance;

  /// No description provided for @contentComplianceSelect72hUnconverged.
  ///
  /// In en, this message translates to:
  /// **'Select 72h non-converged'**
  String get contentComplianceSelect72hUnconverged;

  /// No description provided for @contentComplianceClaimedOnly.
  ///
  /// In en, this message translates to:
  /// **'Claimed only'**
  String get contentComplianceClaimedOnly;

  /// No description provided for @contentComplianceOwnerChipUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'owner: unclaimed'**
  String get contentComplianceOwnerChipUnclaimed;

  /// No description provided for @contentComplianceOwnerChip.
  ///
  /// In en, this message translates to:
  /// **'owner: {owner}'**
  String contentComplianceOwnerChip(String owner);

  /// No description provided for @contentComplianceEscalationChipPrefix.
  ///
  /// In en, this message translates to:
  /// **'Escalation: {stage}'**
  String contentComplianceEscalationChipPrefix(String stage);

  /// No description provided for @contentComplianceSlaUnclaimedCritical.
  ///
  /// In en, this message translates to:
  /// **'critical unclaimed {count}'**
  String contentComplianceSlaUnclaimedCritical(int count);

  /// No description provided for @contentComplianceOverloadedReviewers.
  ///
  /// In en, this message translates to:
  /// **'overloaded reviewers {count}'**
  String contentComplianceOverloadedReviewers(int count);

  /// No description provided for @contentComplianceRebalanceNeeded.
  ///
  /// In en, this message translates to:
  /// **'rebalance needed {count}'**
  String contentComplianceRebalanceNeeded(int count);

  /// No description provided for @contentComplianceReviewerOwnerLoad.
  ///
  /// In en, this message translates to:
  /// **'Reviewer / owner load'**
  String get contentComplianceReviewerOwnerLoad;

  /// No description provided for @contentComplianceOverCapacitySuffix.
  ///
  /// In en, this message translates to:
  /// **' · overloaded +{by}'**
  String contentComplianceOverCapacitySuffix(int by);

  /// No description provided for @contentComplianceEscalationRhythm.
  ///
  /// In en, this message translates to:
  /// **'Escalation rhythm'**
  String get contentComplianceEscalationRhythm;

  /// No description provided for @contentComplianceWorkspaceHotspots.
  ///
  /// In en, this message translates to:
  /// **'Workspace hotspots'**
  String get contentComplianceWorkspaceHotspots;

  /// No description provided for @contentComplianceQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending reports right now.'**
  String get contentComplianceQueueEmpty;

  /// No description provided for @contentComplianceCopyTarget.
  ///
  /// In en, this message translates to:
  /// **'Copy target'**
  String get contentComplianceCopyTarget;

  /// No description provided for @contentComplianceCopiedTargetUuid.
  ///
  /// In en, this message translates to:
  /// **'Copied target UUID'**
  String get contentComplianceCopiedTargetUuid;

  /// No description provided for @contentComplianceCopyReport.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get contentComplianceCopyReport;

  /// No description provided for @contentComplianceCopiedReportUuid.
  ///
  /// In en, this message translates to:
  /// **'Copied report UUID'**
  String get contentComplianceCopiedReportUuid;

  /// No description provided for @contentComplianceAdminConsoleContext.
  ///
  /// In en, this message translates to:
  /// **'Admin console context'**
  String get contentComplianceAdminConsoleContext;

  /// No description provided for @contentComplianceLoadingAudit.
  ///
  /// In en, this message translates to:
  /// **'Loading audit…'**
  String get contentComplianceLoadingAudit;

  /// No description provided for @contentComplianceViewAudit.
  ///
  /// In en, this message translates to:
  /// **'View audit'**
  String get contentComplianceViewAudit;

  /// No description provided for @contentComplianceBulkReassignReviewerLabel.
  ///
  /// In en, this message translates to:
  /// **'Bulk reassign reviewer'**
  String get contentComplianceBulkReassignReviewerLabel;

  /// No description provided for @contentComplianceBulkReassignReviewerHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. internal_ops_cn_shift_b'**
  String get contentComplianceBulkReassignReviewerHint;

  /// No description provided for @contentComplianceSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected {count}'**
  String contentComplianceSelectedCount(int count);

  /// No description provided for @contentComplianceSelectAllOpen.
  ///
  /// In en, this message translates to:
  /// **'Select all open'**
  String get contentComplianceSelectAllOpen;

  /// No description provided for @contentComplianceClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get contentComplianceClearSelection;

  /// No description provided for @contentComplianceBulkReassign.
  ///
  /// In en, this message translates to:
  /// **'Bulk reassign'**
  String get contentComplianceBulkReassign;

  /// No description provided for @contentComplianceResolutionNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Reused for claim / resolve when provided'**
  String get contentComplianceResolutionNoteHint;

  /// No description provided for @contentComplianceTopSecondaryPendingOnly.
  ///
  /// In en, this message translates to:
  /// **'Select pending only'**
  String get contentComplianceTopSecondaryPendingOnly;

  /// No description provided for @contentComplianceTopSecondaryRunRebalance.
  ///
  /// In en, this message translates to:
  /// **'Run auto-rebalance'**
  String get contentComplianceTopSecondaryRunRebalance;

  /// No description provided for @contentComplianceTopSecondaryPreviewStalledRebalance.
  ///
  /// In en, this message translates to:
  /// **'Preview stalled rebalance'**
  String get contentComplianceTopSecondaryPreviewStalledRebalance;

  /// No description provided for @contentComplianceTopSecondarySelect72hOnly.
  ///
  /// In en, this message translates to:
  /// **'Select 72h non-converged only'**
  String get contentComplianceTopSecondarySelect72hOnly;

  /// No description provided for @contentComplianceDialogContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get contentComplianceDialogContinue;

  /// No description provided for @contentComplianceLabelSelect72hUnconverged.
  ///
  /// In en, this message translates to:
  /// **'Select 72h non-converged'**
  String get contentComplianceLabelSelect72hUnconverged;

  /// No description provided for @contentComplianceErrAssigneeRequired.
  ///
  /// In en, this message translates to:
  /// **'Assignee reviewer cannot be empty.'**
  String get contentComplianceErrAssigneeRequired;

  /// No description provided for @taskCenterFieldProjectUuidOptional.
  ///
  /// In en, this message translates to:
  /// **'Project UUID (optional)'**
  String get taskCenterFieldProjectUuidOptional;

  /// No description provided for @qualityReviewsScopeSeedLine.
  ///
  /// In en, this message translates to:
  /// **'Scope seed: {line}'**
  String qualityReviewsScopeSeedLine(String line);

  /// No description provided for @projectEditorAssetHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset History Workbench'**
  String get projectEditorAssetHistoryTitle;

  /// No description provided for @projectEditorAssetHistoryTypeFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Type filter (optional)'**
  String get projectEditorAssetHistoryTypeFilterLabel;

  /// No description provided for @projectEditorAssetHistoryTypeFilterHelper.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated, e.g. role,clip,props; leave empty for all'**
  String get projectEditorAssetHistoryTypeFilterHelper;

  /// No description provided for @projectEditorAssetHistoryLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get projectEditorAssetHistoryLoading;

  /// No description provided for @projectEditorAssetHistoryQueryButton.
  ///
  /// In en, this message translates to:
  /// **'Query history assets'**
  String get projectEditorAssetHistoryQueryButton;

  /// No description provided for @projectEditorAssetHistoryClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear type filter'**
  String get projectEditorAssetHistoryClearFilter;

  /// No description provided for @projectEditorAssetHistoryLoadingAssets.
  ///
  /// In en, this message translates to:
  /// **'Loading history assets…'**
  String get projectEditorAssetHistoryLoadingAssets;

  /// No description provided for @projectEditorAssetHistoryEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No data, click \"Query history assets\" to start.'**
  String get projectEditorAssetHistoryEmptyState;

  /// No description provided for @projectEditorAssetHistoryImageDropdownLabel.
  ///
  /// In en, this message translates to:
  /// **'History image'**
  String get projectEditorAssetHistoryImageDropdownLabel;

  /// No description provided for @projectEditorAssetHistoryNoImages.
  ///
  /// In en, this message translates to:
  /// **'This asset has no history images'**
  String get projectEditorAssetHistoryNoImages;

  /// No description provided for @projectEditorAssetHistoryCurrentImage.
  ///
  /// In en, this message translates to:
  /// **'Current image: sort={sortIndex} · state={state}'**
  String projectEditorAssetHistoryCurrentImage(int sortIndex, String state);

  /// No description provided for @projectEditorAssetHistoryNoPreview.
  ///
  /// In en, this message translates to:
  /// **'Current image has no available preview (may be path placeholder or remote resource temporarily unavailable)'**
  String get projectEditorAssetHistoryNoPreview;

  /// No description provided for @projectEditorAssetHistoryClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get projectEditorAssetHistoryClose;

  /// No description provided for @projectEditorAssetGenerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset Generation Workbench'**
  String get projectEditorAssetGenerationTitle;

  /// No description provided for @projectEditorAssetGenerationDescription.
  ///
  /// In en, this message translates to:
  /// **'Consolidates production asset summary, batch generation, status polling, derivative cleanup, and cover URL updates into the main project asset workflow, no longer relying solely on system probes.'**
  String get projectEditorAssetGenerationDescription;

  /// No description provided for @projectEditorAssetGenerationClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get projectEditorAssetGenerationClose;

  /// No description provided for @projectEditorScriptsBatchAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch Add Scripts'**
  String get projectEditorScriptsBatchAddTitle;

  /// No description provided for @projectEditorScriptsBatchAddCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Count (1-20)'**
  String get projectEditorScriptsBatchAddCountLabel;

  /// No description provided for @projectEditorScriptsBatchAddCountHelper.
  ///
  /// In en, this message translates to:
  /// **'Maximum 20 per batch to avoid accidental operations.'**
  String get projectEditorScriptsBatchAddCountHelper;

  /// No description provided for @projectEditorScriptsBatchAddNamePrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'Name prefix'**
  String get projectEditorScriptsBatchAddNamePrefixLabel;

  /// No description provided for @projectEditorScriptsBatchAddContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Default script content'**
  String get projectEditorScriptsBatchAddContentLabel;

  /// No description provided for @projectEditorScriptsBatchAddCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get projectEditorScriptsBatchAddCancel;

  /// No description provided for @projectEditorScriptsBatchAddCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get projectEditorScriptsBatchAddCreate;

  /// No description provided for @projectEditorScriptsBatchAddCountError.
  ///
  /// In en, this message translates to:
  /// **'Count must be an integer between 1-20'**
  String get projectEditorScriptsBatchAddCountError;

  /// No description provided for @projectEditorScriptsBatchAddDefaultPrefix.
  ///
  /// In en, this message translates to:
  /// **'New Script'**
  String get projectEditorScriptsBatchAddDefaultPrefix;

  /// No description provided for @projectEditorScriptsBatchAddDefaultContent.
  ///
  /// In en, this message translates to:
  /// **'Plot synopsis to be added.'**
  String get projectEditorScriptsBatchAddDefaultContent;

  /// No description provided for @projectEditorScriptsBatchAddSuccess.
  ///
  /// In en, this message translates to:
  /// **'Created {count} scripts in batch'**
  String projectEditorScriptsBatchAddSuccess(int count);

  /// No description provided for @projectEditorProbeTasksZeroItems.
  ///
  /// In en, this message translates to:
  /// **'0 items'**
  String get projectEditorProbeTasksZeroItems;

  /// No description provided for @projectEditorProbeTasksZeroClasses.
  ///
  /// In en, this message translates to:
  /// **'0 classes'**
  String get projectEditorProbeTasksZeroClasses;

  /// No description provided for @projectEditorProbeTasksCompatGetTaskApi.
  ///
  /// In en, this message translates to:
  /// **'compat get-task-api (GET jobs/page): total={total} · {count} items on this page'**
  String projectEditorProbeTasksCompatGetTaskApi(int total, int count);

  /// No description provided for @projectEditorProbeProjectsZeroItems.
  ///
  /// In en, this message translates to:
  /// **'0 items'**
  String get projectEditorProbeProjectsZeroItems;

  /// No description provided for @projectEditorProbeProjectsCompatList.
  ///
  /// In en, this message translates to:
  /// **'GET …/projects (compat list): {line}'**
  String projectEditorProbeProjectsCompatList(String line);

  /// No description provided for @projectEditorProbeScriptsZeroItems.
  ///
  /// In en, this message translates to:
  /// **'0 items'**
  String get projectEditorProbeScriptsZeroItems;

  /// No description provided for @projectEditorProbeScriptsEmpty.
  ///
  /// In en, this message translates to:
  /// **'(empty: all extracting or idle)'**
  String get projectEditorProbeScriptsEmpty;

  /// No description provided for @projectEditorProbeScriptsGetFirstScript.
  ///
  /// In en, this message translates to:
  /// **'GET projects/…/scripts (first)'**
  String get projectEditorProbeScriptsGetFirstScript;

  /// No description provided for @projectEditorProbeScriptsLoading.
  ///
  /// In en, this message translates to:
  /// **'script…'**
  String get projectEditorProbeScriptsLoading;

  /// No description provided for @projectEditorProbeScriptsPostGetScriptApi.
  ///
  /// In en, this message translates to:
  /// **'POST …/projects/{id}/scripts/get-script-api: {count} items · {sample}'**
  String projectEditorProbeScriptsPostGetScriptApi(
    int count,
    String sample,
    Object id,
  );

  /// No description provided for @projectEditorProbeTasksBusyLabel.
  ///
  /// In en, this message translates to:
  /// **'tasks…'**
  String get projectEditorProbeTasksBusyLabel;

  /// No description provided for @projectEditorProbeTasksButtonCompatGetProject.
  ///
  /// In en, this message translates to:
  /// **'compat tasks get-project'**
  String get projectEditorProbeTasksButtonCompatGetProject;

  /// No description provided for @projectEditorProbeTasksCompatGetProjectResult.
  ///
  /// In en, this message translates to:
  /// **'compat getProject (GET projects): {line}'**
  String projectEditorProbeTasksCompatGetProjectResult(String line);

  /// No description provided for @projectEditorProbeTasksButtonCompatCategories.
  ///
  /// In en, this message translates to:
  /// **'compat tasks categories'**
  String get projectEditorProbeTasksButtonCompatCategories;

  /// No description provided for @projectEditorProbeTasksCompatCategoriesResult.
  ///
  /// In en, this message translates to:
  /// **'compat categories (GET jobs/kinds): {line}'**
  String projectEditorProbeTasksCompatCategoriesResult(String line);

  /// No description provided for @projectEditorProbeTasksButtonCompatList.
  ///
  /// In en, this message translates to:
  /// **'compat tasks list'**
  String get projectEditorProbeTasksButtonCompatList;

  /// No description provided for @projectEditorProbeTasksButtonCompatTaskDetails.
  ///
  /// In en, this message translates to:
  /// **'compat task-details int'**
  String get projectEditorProbeTasksButtonCompatTaskDetails;

  /// No description provided for @projectEditorProbeTasksCompatTaskDetailsResult.
  ///
  /// In en, this message translates to:
  /// **'compat task-details (GET jobs/task-detail): #{taskId} -> {kind}/{status}'**
  String projectEditorProbeTasksCompatTaskDetailsResult(
    int taskId,
    String kind,
    String status,
  );

  /// No description provided for @projectEditorProbeProjectBusyLabel.
  ///
  /// In en, this message translates to:
  /// **'project…'**
  String get projectEditorProbeProjectBusyLabel;

  /// No description provided for @projectEditorProbeProjectButtonGetProject.
  ///
  /// In en, this message translates to:
  /// **'POST project get-project'**
  String get projectEditorProbeProjectButtonGetProject;

  /// No description provided for @projectEditorProbeProjectEditNoopResult.
  ///
  /// In en, this message translates to:
  /// **'POST …/project/edit-project noop #{numericId}: {message}'**
  String projectEditorProbeProjectEditNoopResult(int numericId, String message);

  /// No description provided for @projectEditorProbeProjectButtonEditNoop.
  ///
  /// In en, this message translates to:
  /// **'POST project edit (noop)'**
  String get projectEditorProbeProjectButtonEditNoop;

  /// No description provided for @projectEditorProbeProjectButtonDeleteZero.
  ///
  /// In en, this message translates to:
  /// **'POST project delete id=0'**
  String get projectEditorProbeProjectButtonDeleteZero;

  /// No description provided for @projectEditorProbeProjectDeleteUnexpected200.
  ///
  /// In en, this message translates to:
  /// **'POST …/project/delete-project: unexpected 200'**
  String get projectEditorProbeProjectDeleteUnexpected200;

  /// No description provided for @projectEditorProbeProjectDeleteExpected400.
  ///
  /// In en, this message translates to:
  /// **'POST …/project/delete-project id=0 -> 400 (expected)'**
  String get projectEditorProbeProjectDeleteExpected400;

  /// No description provided for @projectEditorProbeProjectButtonEditZero.
  ///
  /// In en, this message translates to:
  /// **'POST project edit id=0'**
  String get projectEditorProbeProjectButtonEditZero;

  /// No description provided for @projectEditorProbeProjectEditUnexpected200.
  ///
  /// In en, this message translates to:
  /// **'POST …/project/edit-project: unexpected 200'**
  String get projectEditorProbeProjectEditUnexpected200;

  /// No description provided for @projectEditorProbeProjectEditExpected400.
  ///
  /// In en, this message translates to:
  /// **'POST …/project/edit-project id=0 -> 400 (expected)'**
  String get projectEditorProbeProjectEditExpected400;

  /// No description provided for @projectEditorProbeProjectButtonAddDelete.
  ///
  /// In en, this message translates to:
  /// **'POST project add→del'**
  String get projectEditorProbeProjectButtonAddDelete;

  /// No description provided for @projectEditorProbeProjectAddMissingAfterList.
  ///
  /// In en, this message translates to:
  /// **'add-project ok but get-project missing name=\"{name}\"'**
  String projectEditorProbeProjectAddMissingAfterList(String name);

  /// No description provided for @projectEditorProbeProjectAddDeleteOk.
  ///
  /// In en, this message translates to:
  /// **'POST add-project → delete project#{numericId} ok'**
  String projectEditorProbeProjectAddDeleteOk(int numericId);

  /// No description provided for @projectEditorProbeScriptsBatchAddProbeResult.
  ///
  /// In en, this message translates to:
  /// **'POST …/projects/:id/scripts/batch-add: inserted={inserted}'**
  String projectEditorProbeScriptsBatchAddProbeResult(int inserted);

  /// No description provided for @projectEditorProbeScriptsButtonBatchAdd.
  ///
  /// In en, this message translates to:
  /// **'POST projects/…/scripts/batch-add'**
  String get projectEditorProbeScriptsButtonBatchAdd;

  /// No description provided for @projectEditorProbeScriptsButtonPostGetScriptApi.
  ///
  /// In en, this message translates to:
  /// **'POST get-script-api'**
  String get projectEditorProbeScriptsButtonPostGetScriptApi;

  /// No description provided for @projectEditorProbeScriptsGetByNumericResult.
  ///
  /// In en, this message translates to:
  /// **'GET …/projects/:id/scripts/{sid}: {name}'**
  String projectEditorProbeScriptsGetByNumericResult(int sid, String name);

  /// No description provided for @projectEditorProbeScriptsPatchNameNoopBusy.
  ///
  /// In en, this message translates to:
  /// **'script…'**
  String get projectEditorProbeScriptsPatchNameNoopBusy;

  /// No description provided for @projectEditorProbeScriptsButtonPatchNameNoop.
  ///
  /// In en, this message translates to:
  /// **'PATCH projects/…/scripts (name noop)'**
  String get projectEditorProbeScriptsButtonPatchNameNoop;

  /// No description provided for @projectEditorProbeScriptsPatchNameNoopResult.
  ///
  /// In en, this message translates to:
  /// **'PATCH …/projects/:id/scripts/{sid} name noop → {name}'**
  String projectEditorProbeScriptsPatchNameNoopResult(int sid, String name);

  /// No description provided for @projectEditorProbeScriptsExportZipBusy.
  ///
  /// In en, this message translates to:
  /// **'export…'**
  String get projectEditorProbeScriptsExportZipBusy;

  /// No description provided for @projectEditorProbeScriptsButtonExportZip.
  ///
  /// In en, this message translates to:
  /// **'POST scripts/export (ZIP)'**
  String get projectEditorProbeScriptsButtonExportZip;

  /// No description provided for @projectEditorProbeScriptsExportZipResult.
  ///
  /// In en, this message translates to:
  /// **'POST …/scripts/export: {bytes} bytes · {count} numeric id(s)'**
  String projectEditorProbeScriptsExportZipResult(int bytes, int count);

  /// No description provided for @projectEditorProbeScriptsPollExtractBusy.
  ///
  /// In en, this message translates to:
  /// **'poll…'**
  String get projectEditorProbeScriptsPollExtractBusy;

  /// No description provided for @projectEditorProbeScriptsButtonPollExtract.
  ///
  /// In en, this message translates to:
  /// **'POST extract-state/poll'**
  String get projectEditorProbeScriptsButtonPollExtract;

  /// No description provided for @projectEditorProbeScriptsPollExtractResult.
  ///
  /// In en, this message translates to:
  /// **'POST …/extract-state/poll: {rowCount} row(s) {sample}'**
  String projectEditorProbeScriptsPollExtractResult(
    int rowCount,
    String sample,
  );

  /// No description provided for @projectEditorProbeScriptsExtractAssetsBusy.
  ///
  /// In en, this message translates to:
  /// **'extract…'**
  String get projectEditorProbeScriptsExtractAssetsBusy;

  /// No description provided for @projectEditorProbeScriptsButtonExtractAssets.
  ///
  /// In en, this message translates to:
  /// **'POST extract-assets'**
  String get projectEditorProbeScriptsButtonExtractAssets;

  /// No description provided for @projectEditorProbeScriptsExtractAssetsResult.
  ///
  /// In en, this message translates to:
  /// **'POST …/extract-assets: {status} — {message}'**
  String projectEditorProbeScriptsExtractAssetsResult(
    String status,
    String message,
  );

  /// No description provided for @projectEditorNovelsEventsDefaultCreateName.
  ///
  /// In en, this message translates to:
  /// **'Event_{stamp}'**
  String projectEditorNovelsEventsDefaultCreateName(int stamp);

  /// No description provided for @projectEditorNovelsEventsDefaultCreateDetail.
  ///
  /// In en, this message translates to:
  /// **'Describe the event here.'**
  String get projectEditorNovelsEventsDefaultCreateDetail;

  /// No description provided for @projectEditorNovelsEventsInfoNoEvents.
  ///
  /// In en, this message translates to:
  /// **'This project has no events yet.'**
  String get projectEditorNovelsEventsInfoNoEvents;

  /// No description provided for @projectEditorNovelsEventsInfoLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} events.'**
  String projectEditorNovelsEventsInfoLoaded(int count);

  /// No description provided for @projectEditorNovelsEventsInfoListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Event list is empty.'**
  String get projectEditorNovelsEventsInfoListEmpty;

  /// No description provided for @projectEditorNovelsEventsInfoRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Refreshed: {count} events in total.'**
  String projectEditorNovelsEventsInfoRefreshed(int count);

  /// No description provided for @projectEditorNovelsEventsInfoSearchDual.
  ///
  /// In en, this message translates to:
  /// **'REST matched {restTotal}; workbench matched {wbTotal}.'**
  String projectEditorNovelsEventsInfoSearchDual(int restTotal, int wbTotal);

  /// No description provided for @projectEditorNovelsEventsInfoCreated.
  ///
  /// In en, this message translates to:
  /// **'Event created.'**
  String get projectEditorNovelsEventsInfoCreated;

  /// No description provided for @projectEditorNovelsEventsInfoCreatedWithId.
  ///
  /// In en, this message translates to:
  /// **'Event created; numeric id = {id}.'**
  String projectEditorNovelsEventsInfoCreatedWithId(int id);

  /// No description provided for @projectEditorNovelsEventsInfoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated event {eventId}: {message}'**
  String projectEditorNovelsEventsInfoUpdated(int eventId, String message);

  /// No description provided for @projectEditorNovelsEventsInfoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted event {eventId}: {message}'**
  String projectEditorNovelsEventsInfoDeleted(int eventId, String message);

  /// No description provided for @projectEditorNovelsEventsInfoBatchDeleted.
  ///
  /// In en, this message translates to:
  /// **'Batch deleted {count} events: {message}'**
  String projectEditorNovelsEventsInfoBatchDeleted(int count, String message);

  /// No description provided for @projectEditorNovelsEventsWorkbenchTitle.
  ///
  /// In en, this message translates to:
  /// **'Events workbench'**
  String get projectEditorNovelsEventsWorkbenchTitle;

  /// No description provided for @projectEditorNovelsEventsPreviewSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Current event preview'**
  String get projectEditorNovelsEventsPreviewSectionTitle;

  /// No description provided for @projectEditorNovelsEventsPreviewRow.
  ///
  /// In en, this message translates to:
  /// **'{numericId} · {name} · chapter indexes {indexesLine}'**
  String projectEditorNovelsEventsPreviewRow(
    int numericId,
    String name,
    String indexesLine,
  );

  /// No description provided for @projectEditorNovelsEventsSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search event keyword'**
  String get projectEditorNovelsEventsSearchLabel;

  /// No description provided for @projectEditorNovelsEventsSearchHelper.
  ///
  /// In en, this message translates to:
  /// **'Calls both REST and workbench get-events search'**
  String get projectEditorNovelsEventsSearchHelper;

  /// No description provided for @projectEditorNovelsEventsSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search events'**
  String get projectEditorNovelsEventsSearchButton;

  /// No description provided for @projectEditorNovelsEventsRefreshListButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get projectEditorNovelsEventsRefreshListButton;

  /// No description provided for @projectEditorNovelsEventsNewEventHeading.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get projectEditorNovelsEventsNewEventHeading;

  /// No description provided for @projectEditorNovelsEventsFieldEventName.
  ///
  /// In en, this message translates to:
  /// **'Event name'**
  String get projectEditorNovelsEventsFieldEventName;

  /// No description provided for @projectEditorNovelsEventsFieldEventDescription.
  ///
  /// In en, this message translates to:
  /// **'Event description'**
  String get projectEditorNovelsEventsFieldEventDescription;

  /// No description provided for @projectEditorNovelsEventsFieldChapterIdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Linked chapter IDs'**
  String get projectEditorNovelsEventsFieldChapterIdsLabel;

  /// No description provided for @projectEditorNovelsEventsFieldChapterIdsHelper.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated chapter numeric IDs'**
  String get projectEditorNovelsEventsFieldChapterIdsHelper;

  /// No description provided for @projectEditorNovelsEventsCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create event'**
  String get projectEditorNovelsEventsCreateButton;

  /// No description provided for @projectEditorNovelsEventsUpdateHeading.
  ///
  /// In en, this message translates to:
  /// **'Update event'**
  String get projectEditorNovelsEventsUpdateHeading;

  /// No description provided for @projectEditorNovelsEventsFieldNumericId.
  ///
  /// In en, this message translates to:
  /// **'Event numeric ID'**
  String get projectEditorNovelsEventsFieldNumericId;

  /// No description provided for @projectEditorNovelsEventsFieldUpdatedName.
  ///
  /// In en, this message translates to:
  /// **'Updated event name'**
  String get projectEditorNovelsEventsFieldUpdatedName;

  /// No description provided for @projectEditorNovelsEventsFieldUpdatedDescription.
  ///
  /// In en, this message translates to:
  /// **'Updated event description'**
  String get projectEditorNovelsEventsFieldUpdatedDescription;

  /// No description provided for @projectEditorNovelsEventsFieldUpdatedChapterIds.
  ///
  /// In en, this message translates to:
  /// **'Updated chapter IDs'**
  String get projectEditorNovelsEventsFieldUpdatedChapterIds;

  /// No description provided for @projectEditorNovelsEventsFieldUpdatedChapterIdsHelper.
  ///
  /// In en, this message translates to:
  /// **'Chapter numeric IDs; mapped to chapterIds internally'**
  String get projectEditorNovelsEventsFieldUpdatedChapterIdsHelper;

  /// No description provided for @projectEditorNovelsEventsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save event'**
  String get projectEditorNovelsEventsSaveButton;

  /// No description provided for @projectEditorNovelsEventsDeleteHeading.
  ///
  /// In en, this message translates to:
  /// **'Delete / batch delete'**
  String get projectEditorNovelsEventsDeleteHeading;

  /// No description provided for @projectEditorNovelsEventsDeleteCurrentButton.
  ///
  /// In en, this message translates to:
  /// **'Delete current event'**
  String get projectEditorNovelsEventsDeleteCurrentButton;

  /// No description provided for @projectEditorNovelsEventsBatchDeleteIdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch delete event IDs'**
  String get projectEditorNovelsEventsBatchDeleteIdsLabel;

  /// No description provided for @projectEditorNovelsEventsBatchDeleteIdsHelper.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated IDs (POST …/novel-events/batch-delete).'**
  String get projectEditorNovelsEventsBatchDeleteIdsHelper;

  /// No description provided for @projectEditorNovelsEventsBatchDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Batch delete events'**
  String get projectEditorNovelsEventsBatchDeleteButton;

  /// No description provided for @projectEditorNovelsEventsCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get projectEditorNovelsEventsCloseButton;

  /// No description provided for @projectEditorNovelsAndEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Novels & events'**
  String get projectEditorNovelsAndEventsTitle;

  /// No description provided for @projectEditorNovelsEventsGenerateEmptyAdmitted.
  ///
  /// In en, this message translates to:
  /// **'No admitted chapters eligible for event generation; admit chapters first.'**
  String get projectEditorNovelsEventsGenerateEmptyAdmitted;

  /// No description provided for @projectEditorNovelsEventsGenerateTriggered.
  ///
  /// In en, this message translates to:
  /// **'Triggered event generation for chapters {ids}: {message}'**
  String projectEditorNovelsEventsGenerateTriggered(String ids, String message);

  /// No description provided for @projectEditorNovelsChapterWorkbenchTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapters workbench'**
  String get projectEditorNovelsChapterWorkbenchTitle;

  /// No description provided for @projectEditorNovelsChapterWorkbenchPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Current chapter preview'**
  String get projectEditorNovelsChapterWorkbenchPreviewTitle;

  /// No description provided for @projectEditorNovelsChapterWorkbenchPreviewRow.
  ///
  /// In en, this message translates to:
  /// **'{numericId} · {chapter} · {intakeSource} / {intakeStatus} · event state {eventState}'**
  String projectEditorNovelsChapterWorkbenchPreviewRow(
    int numericId,
    String chapter,
    String intakeSource,
    String intakeStatus,
    String eventState,
  );

  /// No description provided for @projectEditorNovelsChapterWorkbenchCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get projectEditorNovelsChapterWorkbenchCloseButton;

  /// No description provided for @projectEditorNovelsChapterWorkbenchInfoNoChapters.
  ///
  /// In en, this message translates to:
  /// **'This project has no chapters yet.'**
  String get projectEditorNovelsChapterWorkbenchInfoNoChapters;

  /// No description provided for @projectEditorNovelsChapterWorkbenchInfoLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} chapters.'**
  String projectEditorNovelsChapterWorkbenchInfoLoaded(int count);

  /// No description provided for @projectEditorNovelsChapterWorkbenchInfoListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Chapter list is empty.'**
  String get projectEditorNovelsChapterWorkbenchInfoListEmpty;

  /// No description provided for @projectEditorNovelsChapterWorkbenchInfoRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Refreshed: {count} chapters in total.'**
  String projectEditorNovelsChapterWorkbenchInfoRefreshed(int count);

  /// No description provided for @projectEditorNovelsActionErrorUrlEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a crawl URL first.'**
  String get projectEditorNovelsActionErrorUrlEmpty;

  /// No description provided for @projectEditorNovelsActionErrorUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Crawl URL must be a valid http/https address.'**
  String get projectEditorNovelsActionErrorUrlInvalid;

  /// No description provided for @projectEditorNovelsActionErrorCrawlHttp.
  ///
  /// In en, this message translates to:
  /// **'Crawl failed, HTTP {code}'**
  String projectEditorNovelsActionErrorCrawlHttp(int code);

  /// No description provided for @projectEditorNovelsActionCrawlImportPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Captured {title}, but no importable body was extracted.'**
  String projectEditorNovelsActionCrawlImportPreviewEmpty(String title);

  /// No description provided for @projectEditorNovelsActionCrawlImportPreviewOk.
  ///
  /// In en, this message translates to:
  /// **'Captured {title}; extracted {count} importable chapters.'**
  String projectEditorNovelsActionCrawlImportPreviewOk(String title, int count);

  /// No description provided for @projectEditorNovelsActionCrawlSideServer.
  ///
  /// In en, this message translates to:
  /// **'server-side crawl'**
  String get projectEditorNovelsActionCrawlSideServer;

  /// No description provided for @projectEditorNovelsActionCrawlSideClient.
  ///
  /// In en, this message translates to:
  /// **'client-side crawl'**
  String get projectEditorNovelsActionCrawlSideClient;

  /// No description provided for @projectEditorNovelsActionCrawlDoneInfo.
  ///
  /// In en, this message translates to:
  /// **'{side} completed: {title} (mode {mode}, pages {pageCount}, chapter link candidates {chapterUrlCount}, body {bodyCharCount} chars)'**
  String projectEditorNovelsActionCrawlDoneInfo(
    String side,
    String title,
    String mode,
    int pageCount,
    int chapterUrlCount,
    int bodyCharCount,
  );

  /// No description provided for @projectEditorNovelsActionSearchHit.
  ///
  /// In en, this message translates to:
  /// **'Search matched {total} rows; showing {shown}.'**
  String projectEditorNovelsActionSearchHit(int total, int shown);

  /// No description provided for @projectEditorNovelsActionSearchFiltered.
  ///
  /// In en, this message translates to:
  /// **'Filter matched {total} rows ({filters}); showing {shown}.'**
  String projectEditorNovelsActionSearchFiltered(
    int total,
    String filters,
    int shown,
  );

  /// No description provided for @projectEditorNovelsActionErrorPreparseRequired.
  ///
  /// In en, this message translates to:
  /// **'Pre-parse the whole book first.'**
  String get projectEditorNovelsActionErrorPreparseRequired;

  /// No description provided for @projectEditorNovelsActionErrorImportQuality.
  ///
  /// In en, this message translates to:
  /// **'Import quality gate failed: {blockers}'**
  String projectEditorNovelsActionErrorImportQuality(String blockers);

  /// No description provided for @projectEditorNovelsActionImportQualityHint.
  ///
  /// In en, this message translates to:
  /// **'Import quality hint: {warnings}'**
  String projectEditorNovelsActionImportQualityHint(String warnings);

  /// No description provided for @projectEditorNovelsActionErrorBatchSizePositive.
  ///
  /// In en, this message translates to:
  /// **'Batch size must be greater than 0.'**
  String get projectEditorNovelsActionErrorBatchSizePositive;

  /// No description provided for @projectEditorNovelsActionErrorChapterBodyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Chapter #{index} has empty body; fix it in the pre-parse preview before importing.'**
  String projectEditorNovelsActionErrorChapterBodyEmpty(int index);

  /// No description provided for @projectEditorNovelsActionImportProgress.
  ///
  /// In en, this message translates to:
  /// **'Imported {end}/{total} chapters…'**
  String projectEditorNovelsActionImportProgress(int end, int total);

  /// No description provided for @projectEditorNovelsActionImportComplete.
  ///
  /// In en, this message translates to:
  /// **'Whole-book import finished; added {count} chapters.'**
  String projectEditorNovelsActionImportComplete(int count);

  /// No description provided for @projectEditorNovelsActionServerImportDone.
  ///
  /// In en, this message translates to:
  /// **'Server-hosted import finished: {title} (added {chaptersCreated} chapters, mode {mode}, crawled {pageCount} pages, chapter link candidates {chapterUrlCount}, body {bodyCharCount} chars)'**
  String projectEditorNovelsActionServerImportDone(
    String title,
    int chaptersCreated,
    String mode,
    int pageCount,
    int chapterUrlCount,
    int bodyCharCount,
  );

  /// No description provided for @projectEditorNovelsActionErrorBatchUrlsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one URL line in the batch hosted URL field.'**
  String get projectEditorNovelsActionErrorBatchUrlsEmpty;

  /// No description provided for @projectEditorNovelsActionBatchImportDone.
  ///
  /// In en, this message translates to:
  /// **'Batch server import: succeeded {succeeded}/{total}, failed {failed}.{detail}'**
  String projectEditorNovelsActionBatchImportDone(
    int succeeded,
    int total,
    int failed,
    String detail,
  );

  /// No description provided for @projectEditorNovelsActionBatchImportFailuresPrefix.
  ///
  /// In en, this message translates to:
  /// **' Failure samples: '**
  String get projectEditorNovelsActionBatchImportFailuresPrefix;

  /// No description provided for @projectEditorNovelsActionCrawlScheduleCreated.
  ///
  /// In en, this message translates to:
  /// **'Created crawl schedule: task id {taskId} ({status}; delay {delayMinutes}m; repeat {repeatMinutes}m)'**
  String projectEditorNovelsActionCrawlScheduleCreated(
    int taskId,
    String status,
    int delayMinutes,
    int repeatMinutes,
  );

  /// No description provided for @projectEditorNovelsActionCrawlSchedulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No hosted crawl schedules (showing up to 100 recent for this project).'**
  String get projectEditorNovelsActionCrawlSchedulesEmpty;

  /// No description provided for @projectEditorNovelsActionCrawlSchedulesSummary.
  ///
  /// In en, this message translates to:
  /// **'This project has {count} hosted crawl schedules; recent: {head}'**
  String projectEditorNovelsActionCrawlSchedulesSummary(int count, String head);

  /// No description provided for @projectEditorNovelsActionCrawlObservability.
  ///
  /// In en, this message translates to:
  /// **'Hosted stats: chapters {totalChapters}; source[{topSources}]; status[{topStatuses}]; crawlJobs[{jobs}].{recent}'**
  String projectEditorNovelsActionCrawlObservability(
    int totalChapters,
    String topSources,
    String topStatuses,
    String jobs,
    String recent,
  );

  /// No description provided for @projectEditorNovelsActionCrawlObservabilityRecentImports.
  ///
  /// In en, this message translates to:
  /// **' Recent server imports: {ids}'**
  String projectEditorNovelsActionCrawlObservabilityRecentImports(String ids);

  /// No description provided for @projectEditorNovelsActionChapterReadOk.
  ///
  /// In en, this message translates to:
  /// **'Loaded chapter #{id}.'**
  String projectEditorNovelsActionChapterReadOk(int id);

  /// No description provided for @projectEditorNovelsActionChapterSaveOk.
  ///
  /// In en, this message translates to:
  /// **'Updated chapter #{id}.'**
  String projectEditorNovelsActionChapterSaveOk(int id);

  /// No description provided for @projectEditorNovelsActionChapterDeleteOk.
  ///
  /// In en, this message translates to:
  /// **'Deleted chapter #{id}.'**
  String projectEditorNovelsActionChapterDeleteOk(int id);

  /// No description provided for @projectEditorNovelsActionErrorIdsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Provide at least one chapter id.'**
  String get projectEditorNovelsActionErrorIdsEmpty;

  /// No description provided for @projectEditorNovelsActionEventsGenerateOk.
  ///
  /// In en, this message translates to:
  /// **'Triggered event generation: {message}'**
  String projectEditorNovelsActionEventsGenerateOk(String message);

  /// No description provided for @projectEditorNovelsActionListLabelEmpty.
  ///
  /// In en, this message translates to:
  /// **'(empty list)'**
  String get projectEditorNovelsActionListLabelEmpty;

  /// No description provided for @projectEditorNovelsActionListLabelAllZero.
  ///
  /// In en, this message translates to:
  /// **'(all zero)'**
  String get projectEditorNovelsActionListLabelAllZero;

  /// No description provided for @projectEditorNovelsActionWorkbenchDataResult.
  ///
  /// In en, this message translates to:
  /// **'workbench get-novel-data returned {count} rows: {sample}'**
  String projectEditorNovelsActionWorkbenchDataResult(int count, String sample);

  /// No description provided for @projectEditorNovelsActionWorkbenchIndexResult.
  ///
  /// In en, this message translates to:
  /// **'workbench get-novel-index returned {count} rows: {sample}'**
  String projectEditorNovelsActionWorkbenchIndexResult(
    int count,
    String sample,
  );

  /// No description provided for @projectEditorNovelsActionWorkbenchEventStateResult.
  ///
  /// In en, this message translates to:
  /// **'workbench get-novel-event-state returned {count} rows: {sample}'**
  String projectEditorNovelsActionWorkbenchEventStateResult(
    int count,
    String sample,
  );

  /// No description provided for @projectEditorNovelsActionBatchDeleteOk.
  ///
  /// In en, this message translates to:
  /// **'Batch deleted {count} chapters: {message}'**
  String projectEditorNovelsActionBatchDeleteOk(int count, String message);

  /// No description provided for @projectEditorNovelsActionErrorAdmissionStatusEmpty.
  ///
  /// In en, this message translates to:
  /// **'Select a target admission status first.'**
  String get projectEditorNovelsActionErrorAdmissionStatusEmpty;

  /// No description provided for @projectEditorNovelsActionBatchAdmissionOk.
  ///
  /// In en, this message translates to:
  /// **'Batch updated {count} chapters to {status}.'**
  String projectEditorNovelsActionBatchAdmissionOk(int count, String status);

  /// No description provided for @projectEditorNovelsChapterWorkbenchValueUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get projectEditorNovelsChapterWorkbenchValueUnknown;

  /// No description provided for @projectEditorNovelsChapterWorkbenchValueUnset.
  ///
  /// In en, this message translates to:
  /// **'unset'**
  String get projectEditorNovelsChapterWorkbenchValueUnset;

  /// No description provided for @projectEditorNovelsActionSearchFiltersCleared.
  ///
  /// In en, this message translates to:
  /// **'Chapter search filters cleared.'**
  String get projectEditorNovelsActionSearchFiltersCleared;

  /// No description provided for @projectEditorNovelsActionChapterCreateOk.
  ///
  /// In en, this message translates to:
  /// **'Chapter created.'**
  String get projectEditorNovelsActionChapterCreateOk;

  /// No description provided for @projectEditorNovelsActionPreparseResultEmpty.
  ///
  /// In en, this message translates to:
  /// **'No importable content was detected.'**
  String get projectEditorNovelsActionPreparseResultEmpty;

  /// No description provided for @projectEditorNovelsActionPreparseResultOk.
  ///
  /// In en, this message translates to:
  /// **'Pre-parsed {count} chapters; confirm titles and order before importing.'**
  String projectEditorNovelsActionPreparseResultOk(int count);

  /// No description provided for @projectEditorNovelsActionImportPreviewAppendChapter.
  ///
  /// In en, this message translates to:
  /// **'Appended 1 supplement chapter; fill in title and body before importing.'**
  String get projectEditorNovelsActionImportPreviewAppendChapter;

  /// No description provided for @projectEditorNovelsActionImportPreviewDeletedRow.
  ///
  /// In en, this message translates to:
  /// **'Removed pre-parsed row #{chapterIndex}.'**
  String projectEditorNovelsActionImportPreviewDeletedRow(int chapterIndex);

  /// No description provided for @projectEditorNovelsActionImportPreviewRowTitleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated title for pre-parsed row #{chapterIndex}.'**
  String projectEditorNovelsActionImportPreviewRowTitleUpdated(
    int chapterIndex,
  );

  /// No description provided for @projectEditorNovelsActionImportPreviewRowBodyUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated body for row #{chapterIndex}.'**
  String projectEditorNovelsActionImportPreviewRowBodyUpdated(int chapterIndex);

  /// No description provided for @projectEditorNovelsActionImportPreviewAreaTitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-parse edit area ({count} rows)'**
  String projectEditorNovelsActionImportPreviewAreaTitle(int count);

  /// No description provided for @projectEditorNovelsActionImportPreviewFooterNote.
  ///
  /// In en, this message translates to:
  /// **'Import will renumber automatically; empty-body chapters are blocked—fix them here first.'**
  String get projectEditorNovelsActionImportPreviewFooterNote;

  /// No description provided for @projectEditorNovelsActionImportPreviewLongListHint.
  ///
  /// In en, this message translates to:
  /// **'Preview is long; scroll to edit every chapter.'**
  String get projectEditorNovelsActionImportPreviewLongListHint;

  /// No description provided for @projectEditorNovelsActionImportPreviewSupplementChapterTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplement chapter {n}'**
  String projectEditorNovelsActionImportPreviewSupplementChapterTitle(int n);

  /// No description provided for @projectEditorNovelsWorkbenchCardSummaryEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'Use explicit forms to add, search, view, update, delete chapters, and generate events—without legacy first/last probe shortcuts.'**
  String get projectEditorNovelsWorkbenchCardSummaryEmptyHelp;

  /// No description provided for @projectEditorNovelsWorkbenchCardSummaryDualBounds.
  ///
  /// In en, this message translates to:
  /// **'{summaryLine} · first #{firstId} {firstChapter} · last #{lastId} {lastChapter}.'**
  String projectEditorNovelsWorkbenchCardSummaryDualBounds(
    String summaryLine,
    int firstId,
    String firstChapter,
    int lastId,
    String lastChapter,
  );

  /// No description provided for @projectEditorNovelsWorkbenchCardOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Open chapters workbench'**
  String get projectEditorNovelsWorkbenchCardOpenButton;

  /// No description provided for @projectEditorNovelsWorkbenchCardRefreshChapters.
  ///
  /// In en, this message translates to:
  /// **'Refresh chapters'**
  String get projectEditorNovelsWorkbenchCardRefreshChapters;

  /// No description provided for @projectEditorNovelsWorkbenchCardRefreshChaptersBusy.
  ///
  /// In en, this message translates to:
  /// **'Refreshing chapters…'**
  String get projectEditorNovelsWorkbenchCardRefreshChaptersBusy;

  /// No description provided for @projectEditorNovelsWorkbenchCardGenerateEventsForTopThree.
  ///
  /// In en, this message translates to:
  /// **'Generate events for top 3'**
  String get projectEditorNovelsWorkbenchCardGenerateEventsForTopThree;

  /// No description provided for @projectEditorNovelsWorkbenchSearchKeywordLabel.
  ///
  /// In en, this message translates to:
  /// **'Search chapter keyword'**
  String get projectEditorNovelsWorkbenchSearchKeywordLabel;

  /// No description provided for @projectEditorNovelsWorkbenchSearchKeywordHelper.
  ///
  /// In en, this message translates to:
  /// **'Calls GET /projects/:project_uuid/novels?search='**
  String get projectEditorNovelsWorkbenchSearchKeywordHelper;

  /// No description provided for @projectEditorNovelsWorkbenchSearchIntakeStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Admission status'**
  String get projectEditorNovelsWorkbenchSearchIntakeStatusLabel;

  /// No description provided for @projectEditorNovelsWorkbenchSearchIntakeStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get projectEditorNovelsWorkbenchSearchIntakeStatusAll;

  /// No description provided for @projectEditorNovelsWorkbenchSearchIntakeSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Intake source'**
  String get projectEditorNovelsWorkbenchSearchIntakeSourceLabel;

  /// No description provided for @projectEditorNovelsWorkbenchSearchIntakeSourceAll.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get projectEditorNovelsWorkbenchSearchIntakeSourceAll;

  /// No description provided for @projectEditorNovelsWorkbenchSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get projectEditorNovelsWorkbenchSearchButton;

  /// No description provided for @projectEditorNovelsWorkbenchSearchClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get projectEditorNovelsWorkbenchSearchClearFilters;

  /// No description provided for @projectEditorNovelsWorkbenchSearchRefreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get projectEditorNovelsWorkbenchSearchRefreshList;

  /// No description provided for @projectEditorNovelsWorkbenchCreateSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add chapter'**
  String get projectEditorNovelsWorkbenchCreateSectionTitle;

  /// No description provided for @projectEditorNovelsWorkbenchCreateChapterTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter title'**
  String get projectEditorNovelsWorkbenchCreateChapterTitleLabel;

  /// No description provided for @projectEditorNovelsWorkbenchCreateChapterBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter body'**
  String get projectEditorNovelsWorkbenchCreateChapterBodyLabel;

  /// No description provided for @projectEditorNovelsWorkbenchCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Add chapter'**
  String get projectEditorNovelsWorkbenchCreateSubmit;

  /// No description provided for @projectEditorNovelsWorkbenchEditSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Read / update chapter'**
  String get projectEditorNovelsWorkbenchEditSectionTitle;

  /// No description provided for @projectEditorNovelsWorkbenchEditNumericIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter numeric ID'**
  String get projectEditorNovelsWorkbenchEditNumericIdLabel;

  /// No description provided for @projectEditorNovelsWorkbenchEditReadButton.
  ///
  /// In en, this message translates to:
  /// **'Load chapter'**
  String get projectEditorNovelsWorkbenchEditReadButton;

  /// No description provided for @projectEditorNovelsWorkbenchEditPatchChapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated chapter title'**
  String get projectEditorNovelsWorkbenchEditPatchChapterLabel;

  /// No description provided for @projectEditorNovelsWorkbenchEditPatchBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated chapter body'**
  String get projectEditorNovelsWorkbenchEditPatchBodyLabel;

  /// No description provided for @projectEditorNovelsWorkbenchEditIntakeStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Admission status'**
  String get projectEditorNovelsWorkbenchEditIntakeStatusLabel;

  /// No description provided for @projectEditorNovelsWorkbenchEditIntakeStatusHelper.
  ///
  /// In en, this message translates to:
  /// **'draft / pending_review / admitted / rejected'**
  String get projectEditorNovelsWorkbenchEditIntakeStatusHelper;

  /// No description provided for @projectEditorNovelsWorkbenchEditSourceUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Source URL'**
  String get projectEditorNovelsWorkbenchEditSourceUrlLabel;

  /// No description provided for @projectEditorNovelsWorkbenchEditIntakeNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Admission note'**
  String get projectEditorNovelsWorkbenchEditIntakeNoteLabel;

  /// No description provided for @projectEditorNovelsWorkbenchEditSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save chapter'**
  String get projectEditorNovelsWorkbenchEditSaveButton;

  /// No description provided for @projectEditorNovelsWorkbenchDeleteSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete / generate events'**
  String get projectEditorNovelsWorkbenchDeleteSectionTitle;

  /// No description provided for @projectEditorNovelsWorkbenchDeleteNumericIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter numeric ID to delete'**
  String get projectEditorNovelsWorkbenchDeleteNumericIdLabel;

  /// No description provided for @projectEditorNovelsWorkbenchDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete chapter'**
  String get projectEditorNovelsWorkbenchDeleteButton;

  /// No description provided for @projectEditorNovelsWorkbenchDeleteGenerateIdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter IDs for event generation'**
  String get projectEditorNovelsWorkbenchDeleteGenerateIdsLabel;

  /// No description provided for @projectEditorNovelsWorkbenchDeleteGenerateIdsHelper.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated, e.g. 1,2,3'**
  String get projectEditorNovelsWorkbenchDeleteGenerateIdsHelper;

  /// No description provided for @projectEditorNovelsWorkbenchDeleteGenerateEventsButton.
  ///
  /// In en, this message translates to:
  /// **'Generate chapter events'**
  String get projectEditorNovelsWorkbenchDeleteGenerateEventsButton;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Snapshots / batch actions'**
  String get projectEditorNovelsWorkbenchSnapshotSectionTitle;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotEventStateIdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter IDs (numeric)'**
  String get projectEditorNovelsWorkbenchSnapshotEventStateIdsLabel;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotEventStateIdsHelper.
  ///
  /// In en, this message translates to:
  /// **'For get-novel-event-state; comma-separated, e.g. 1,2,3'**
  String get projectEditorNovelsWorkbenchSnapshotEventStateIdsHelper;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotReadNovelDataButton.
  ///
  /// In en, this message translates to:
  /// **'Read get-novel-data'**
  String get projectEditorNovelsWorkbenchSnapshotReadNovelDataButton;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotReadNovelIndexButton.
  ///
  /// In en, this message translates to:
  /// **'Read get-novel-index'**
  String get projectEditorNovelsWorkbenchSnapshotReadNovelIndexButton;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotReadEventStateButton.
  ///
  /// In en, this message translates to:
  /// **'Read event-state'**
  String get projectEditorNovelsWorkbenchSnapshotReadEventStateButton;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch delete chapter IDs'**
  String get projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsLabel;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsHelper.
  ///
  /// In en, this message translates to:
  /// **'Calls workbench batch-delete; comma-separated; refreshes the workbench after delete.'**
  String get projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsHelper;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotBatchDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Batch delete chapters'**
  String get projectEditorNovelsWorkbenchSnapshotBatchDeleteButton;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch admission chapter IDs'**
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsLabel;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsHelper.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated, e.g. 1,2,3'**
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsHelper;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotBatchAdmissionStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Target admission status'**
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionStatusLabel;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch admission note'**
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteLabel;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to clear; overwrites intake_note for selected chapters.'**
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteHelper;

  /// No description provided for @projectEditorNovelsWorkbenchSnapshotBatchAdmissionButton.
  ///
  /// In en, this message translates to:
  /// **'Batch update admission status'**
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Whole-book import'**
  String get projectEditorNovelsWorkbenchImportSectionTitle;

  /// No description provided for @projectEditorNovelsWorkbenchImportCrawlUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Crawl URL'**
  String get projectEditorNovelsWorkbenchImportCrawlUrlLabel;

  /// No description provided for @projectEditorNovelsWorkbenchImportCrawlUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Prefer client crawl + fix + import; server is for hosted preview.'**
  String get projectEditorNovelsWorkbenchImportCrawlUrlHelper;

  /// No description provided for @projectEditorNovelsWorkbenchImportBatchUrlsLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch hosted URLs (one per line)'**
  String get projectEditorNovelsWorkbenchImportBatchUrlsLabel;

  /// No description provided for @projectEditorNovelsWorkbenchImportBatchUrlsHelper.
  ///
  /// In en, this message translates to:
  /// **'Hosted import (paid) batch trigger only; default import still uses the pre-parse editor.'**
  String get projectEditorNovelsWorkbenchImportBatchUrlsHelper;

  /// No description provided for @projectEditorNovelsWorkbenchImportScheduleDelayLabel.
  ///
  /// In en, this message translates to:
  /// **'Hosted schedule delay (minutes)'**
  String get projectEditorNovelsWorkbenchImportScheduleDelayLabel;

  /// No description provided for @projectEditorNovelsWorkbenchImportScheduleDelayHelper.
  ///
  /// In en, this message translates to:
  /// **'0 means run immediately'**
  String get projectEditorNovelsWorkbenchImportScheduleDelayHelper;

  /// No description provided for @projectEditorNovelsWorkbenchImportScheduleRepeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat interval (minutes)'**
  String get projectEditorNovelsWorkbenchImportScheduleRepeatLabel;

  /// No description provided for @projectEditorNovelsWorkbenchImportScheduleRepeatHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for no repeat'**
  String get projectEditorNovelsWorkbenchImportScheduleRepeatHelper;

  /// No description provided for @projectEditorNovelsWorkbenchImportCreateScheduleButton.
  ///
  /// In en, this message translates to:
  /// **'Create hosted crawl schedule'**
  String get projectEditorNovelsWorkbenchImportCreateScheduleButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportListSchedulesButton.
  ///
  /// In en, this message translates to:
  /// **'View hosted schedules'**
  String get projectEditorNovelsWorkbenchImportListSchedulesButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportRefreshObservabilityButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh hosted stats'**
  String get projectEditorNovelsWorkbenchImportRefreshObservabilityButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportCrawlPreparseButton.
  ///
  /// In en, this message translates to:
  /// **'Crawl and pre-parse'**
  String get projectEditorNovelsWorkbenchImportCrawlPreparseButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportRawPasteLabel.
  ///
  /// In en, this message translates to:
  /// **'Paste whole book or multi-chapter text'**
  String get projectEditorNovelsWorkbenchImportRawPasteLabel;

  /// No description provided for @projectEditorNovelsWorkbenchImportRawPasteHelper.
  ///
  /// In en, this message translates to:
  /// **'Auto-split by headings like “Chapter 12”, “第3回”, “第五集”.'**
  String get projectEditorNovelsWorkbenchImportRawPasteHelper;

  /// No description provided for @projectEditorNovelsWorkbenchImportBatchSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapters per import batch'**
  String get projectEditorNovelsWorkbenchImportBatchSizeLabel;

  /// No description provided for @projectEditorNovelsWorkbenchImportPreparseButton.
  ///
  /// In en, this message translates to:
  /// **'Pre-parse whole book'**
  String get projectEditorNovelsWorkbenchImportPreparseButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportParsedChaptersButton.
  ///
  /// In en, this message translates to:
  /// **'Import pre-parsed chapters'**
  String get projectEditorNovelsWorkbenchImportParsedChaptersButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportServerImportButton.
  ///
  /// In en, this message translates to:
  /// **'Hosted import (paid)'**
  String get projectEditorNovelsWorkbenchImportServerImportButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportServerBatchButton.
  ///
  /// In en, this message translates to:
  /// **'Batch hosted import (paid)'**
  String get projectEditorNovelsWorkbenchImportServerBatchButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportExecutionSideLabel.
  ///
  /// In en, this message translates to:
  /// **'Crawl execution side'**
  String get projectEditorNovelsWorkbenchImportExecutionSideLabel;

  /// No description provided for @projectEditorNovelsWorkbenchImportExecutionSideClient.
  ///
  /// In en, this message translates to:
  /// **'client (available)'**
  String get projectEditorNovelsWorkbenchImportExecutionSideClient;

  /// No description provided for @projectEditorNovelsWorkbenchImportExecutionSideServer.
  ///
  /// In en, this message translates to:
  /// **'server (hosted preview)'**
  String get projectEditorNovelsWorkbenchImportExecutionSideServer;

  /// No description provided for @projectEditorNovelsWorkbenchImportIntakeStatusAfterImportLabel.
  ///
  /// In en, this message translates to:
  /// **'Admission status after import'**
  String get projectEditorNovelsWorkbenchImportIntakeStatusAfterImportLabel;

  /// No description provided for @projectEditorNovelsWorkbenchImportIntakeNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Import note'**
  String get projectEditorNovelsWorkbenchImportIntakeNoteLabel;

  /// No description provided for @projectEditorNovelsWorkbenchImportIntakeNoteHelper.
  ///
  /// In en, this message translates to:
  /// **'Crawl source, cleanup notes, review reasons, etc.'**
  String get projectEditorNovelsWorkbenchImportIntakeNoteHelper;

  /// No description provided for @projectEditorNovelsWorkbenchImportPreviewAddChapterButton.
  ///
  /// In en, this message translates to:
  /// **'Add chapter'**
  String get projectEditorNovelsWorkbenchImportPreviewAddChapterButton;

  /// No description provided for @projectEditorNovelsWorkbenchImportPreviewDeleteChapterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove this chapter'**
  String get projectEditorNovelsWorkbenchImportPreviewDeleteChapterTooltip;

  /// No description provided for @projectEditorNovelsWorkbenchImportPreviewChapterTitleField.
  ///
  /// In en, this message translates to:
  /// **'Chapter title'**
  String get projectEditorNovelsWorkbenchImportPreviewChapterTitleField;

  /// No description provided for @projectEditorNovelsWorkbenchImportPreviewChapterBodyField.
  ///
  /// In en, this message translates to:
  /// **'Chapter body'**
  String get projectEditorNovelsWorkbenchImportPreviewChapterBodyField;

  /// No description provided for @projectEditorScriptsWorkbenchBatchFollowUpLine.
  ///
  /// In en, this message translates to:
  /// **'{actionSummary} Suggested next step: {nextAction}. {detail}'**
  String projectEditorScriptsWorkbenchBatchFollowUpLine(
    String actionSummary,
    String nextAction,
    String detail,
  );

  /// No description provided for @projectEditorScriptsWorkbenchRecommendSyncContext.
  ///
  /// In en, this message translates to:
  /// **'Read script context'**
  String get projectEditorScriptsWorkbenchRecommendSyncContext;

  /// No description provided for @projectEditorScriptsWorkbenchRecommendPollSelected.
  ///
  /// In en, this message translates to:
  /// **'Poll selected extract states'**
  String get projectEditorScriptsWorkbenchRecommendPollSelected;

  /// No description provided for @projectEditorScriptsWorkbenchRecommendExtractSelected.
  ///
  /// In en, this message translates to:
  /// **'Extract assets for selected scripts'**
  String get projectEditorScriptsWorkbenchRecommendExtractSelected;

  /// No description provided for @projectEditorScriptsWorkbenchRecommendExportSelected.
  ///
  /// In en, this message translates to:
  /// **'Export selected scripts'**
  String get projectEditorScriptsWorkbenchRecommendExportSelected;

  /// No description provided for @projectEditorScriptsWorkbenchReloadEmpty.
  ///
  /// In en, this message translates to:
  /// **'Refresh finished; no scripts in this project.'**
  String get projectEditorScriptsWorkbenchReloadEmpty;

  /// No description provided for @projectEditorScriptsWorkbenchReloadCount.
  ///
  /// In en, this message translates to:
  /// **'Refresh finished; loaded {count} scripts.'**
  String projectEditorScriptsWorkbenchReloadCount(int count);

  /// No description provided for @projectEditorScriptsWorkbenchReadContextEmpty.
  ///
  /// In en, this message translates to:
  /// **'Context read finished; no matching scripts.'**
  String get projectEditorScriptsWorkbenchReadContextEmpty;

  /// No description provided for @projectEditorScriptsWorkbenchReadContextCount.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} script context rows.'**
  String projectEditorScriptsWorkbenchReadContextCount(int count);

  /// No description provided for @projectEditorScriptsWorkbenchErrorNeedScriptIds.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one script id.'**
  String get projectEditorScriptsWorkbenchErrorNeedScriptIds;

  /// No description provided for @projectEditorScriptsWorkbenchExportSelectedSummary.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} scripts, ZIP {zipSize}.'**
  String projectEditorScriptsWorkbenchExportSelectedSummary(
    int count,
    String zipSize,
  );

  /// No description provided for @projectEditorScriptsWorkbenchPollExtractIdleOrComplete.
  ///
  /// In en, this message translates to:
  /// **'All idle or completed'**
  String get projectEditorScriptsWorkbenchPollExtractIdleOrComplete;

  /// No description provided for @projectEditorScriptsWorkbenchPollSelectedSummary.
  ///
  /// In en, this message translates to:
  /// **'Polled {count} scripts for extract state: {sample}'**
  String projectEditorScriptsWorkbenchPollSelectedSummary(
    int count,
    String sample,
  );

  /// No description provided for @projectEditorScriptsWorkbenchExtractSubmittedSelected.
  ///
  /// In en, this message translates to:
  /// **'Submitted asset extract for {count} scripts: {status} · {message}'**
  String projectEditorScriptsWorkbenchExtractSubmittedSelected(
    int count,
    String status,
    String message,
  );

  /// No description provided for @projectEditorScriptsWorkbenchBatchCreateCountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Count must be an integer between 1 and 20.'**
  String get projectEditorScriptsWorkbenchBatchCreateCountInvalid;

  /// No description provided for @projectEditorScriptsWorkbenchDefaultNewScriptName.
  ///
  /// In en, this message translates to:
  /// **'New script'**
  String get projectEditorScriptsWorkbenchDefaultNewScriptName;

  /// No description provided for @projectEditorScriptsWorkbenchBatchCreated.
  ///
  /// In en, this message translates to:
  /// **'Batch created {inserted} scripts.'**
  String projectEditorScriptsWorkbenchBatchCreated(int inserted);

  /// No description provided for @projectEditorScriptsWorkbenchCreatedScriptFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Created script #{id}.'**
  String projectEditorScriptsWorkbenchCreatedScriptFollowUp(int id);

  /// No description provided for @projectEditorScriptsWorkbenchCreatedScriptSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Created script #{id}'**
  String projectEditorScriptsWorkbenchCreatedScriptSnackBar(int id);

  /// No description provided for @projectEditorScriptsWorkbenchExportAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String projectEditorScriptsWorkbenchExportAllFailed(String error);

  /// No description provided for @projectEditorScriptsWorkbenchPollAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Polling extract state failed: {error}'**
  String projectEditorScriptsWorkbenchPollAllFailed(String error);

  /// No description provided for @projectEditorScriptsWorkbenchExtractAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Submitting asset extract failed: {error}'**
  String projectEditorScriptsWorkbenchExtractAllFailed(String error);

  /// No description provided for @projectEditorScriptsWorkbenchExportAllSummary.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} scripts, ZIP {zipSize}.'**
  String projectEditorScriptsWorkbenchExportAllSummary(
    int count,
    String zipSize,
  );

  /// No description provided for @projectEditorScriptsWorkbenchPollAllSummary.
  ///
  /// In en, this message translates to:
  /// **'Polled {count} scripts for extract state: {sample}'**
  String projectEditorScriptsWorkbenchPollAllSummary(int count, String sample);

  /// No description provided for @projectEditorScriptsWorkbenchExtractAllSummary.
  ///
  /// In en, this message translates to:
  /// **'Submitted asset extract for {count} scripts: {status} · {message}'**
  String projectEditorScriptsWorkbenchExtractAllSummary(
    int count,
    String status,
    String message,
  );

  /// No description provided for @projectEditorScriptsWorkbenchOverviewOpenWorkbenchReadContext.
  ///
  /// In en, this message translates to:
  /// **'Open workbench to read context'**
  String get projectEditorScriptsWorkbenchOverviewOpenWorkbenchReadContext;

  /// No description provided for @projectEditorScriptsWorkbenchOverviewPollAllExtract.
  ///
  /// In en, this message translates to:
  /// **'Poll extract state for all'**
  String get projectEditorScriptsWorkbenchOverviewPollAllExtract;

  /// No description provided for @projectEditorScriptsWorkbenchOverviewExtractAllAssets.
  ///
  /// In en, this message translates to:
  /// **'Extract assets for all scripts'**
  String get projectEditorScriptsWorkbenchOverviewExtractAllAssets;

  /// No description provided for @projectEditorScriptsWorkbenchOverviewExportAllScripts.
  ///
  /// In en, this message translates to:
  /// **'Export all scripts'**
  String get projectEditorScriptsWorkbenchOverviewExportAllScripts;

  /// No description provided for @projectEditorScriptsSessionInfoNoScripts.
  ///
  /// In en, this message translates to:
  /// **'This project has no scripts yet.'**
  String get projectEditorScriptsSessionInfoNoScripts;

  /// No description provided for @projectEditorScriptsSessionInfoLoadedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} scripts loaded; you can filter and run batch actions.'**
  String projectEditorScriptsSessionInfoLoadedCount(int count);

  /// No description provided for @projectEditorScriptsSessionDefaultAddBody.
  ///
  /// In en, this message translates to:
  /// **'Plot outline to be filled.'**
  String get projectEditorScriptsSessionDefaultAddBody;

  /// No description provided for @projectEditorScriptsDiagnosisBatchEmptySummary.
  ///
  /// In en, this message translates to:
  /// **'No scripts selected for processing.'**
  String get projectEditorScriptsDiagnosisBatchEmptySummary;

  /// No description provided for @projectEditorScriptsDiagnosisBatchEmptyDetail.
  ///
  /// In en, this message translates to:
  /// **'Read script context or enter target script ids, then run batch export, polling, or asset extract.'**
  String get projectEditorScriptsDiagnosisBatchEmptyDetail;

  /// No description provided for @projectEditorScriptsDiagnosisBatchRunningSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} selected script(s) are still extracting.'**
  String projectEditorScriptsDiagnosisBatchRunningSummary(int count);

  /// No description provided for @projectEditorScriptsDiagnosisBatchRunningDetail.
  ///
  /// In en, this message translates to:
  /// **'Poll selected extract states first to confirm batch work finished before retrying extract.'**
  String get projectEditorScriptsDiagnosisBatchRunningDetail;

  /// No description provided for @projectEditorScriptsDiagnosisBatchFailedSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} selected script(s) recently failed extract.'**
  String projectEditorScriptsDiagnosisBatchFailedSummary(int count);

  /// No description provided for @projectEditorScriptsDiagnosisBatchFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Start asset extract again for the selection; prioritize fixing failed items.'**
  String get projectEditorScriptsDiagnosisBatchFailedDetail;

  /// No description provided for @projectEditorScriptsDiagnosisBatchMissingContextSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} selected script(s) are missing a context snapshot.'**
  String projectEditorScriptsDiagnosisBatchMissingContextSummary(int count);

  /// No description provided for @projectEditorScriptsDiagnosisBatchMissingContextDetail.
  ///
  /// In en, this message translates to:
  /// **'Read script context first to see which scripts already have assets, then decide whether to export ZIP or run asset extract.'**
  String get projectEditorScriptsDiagnosisBatchMissingContextDetail;

  /// No description provided for @projectEditorScriptsDiagnosisBatchAllAssetsSummary.
  ///
  /// In en, this message translates to:
  /// **'All {count} selected script(s) already have related assets.'**
  String projectEditorScriptsDiagnosisBatchAllAssetsSummary(int count);

  /// No description provided for @projectEditorScriptsDiagnosisBatchAllAssetsDetail.
  ///
  /// In en, this message translates to:
  /// **'You can export a ZIP of the selection for review, or continue in the single-script workbench for images.'**
  String get projectEditorScriptsDiagnosisBatchAllAssetsDetail;

  /// No description provided for @projectEditorScriptsDiagnosisBatchPendingExtractSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} selected script(s) still have items pending extract.'**
  String projectEditorScriptsDiagnosisBatchPendingExtractSummary(int count);

  /// No description provided for @projectEditorScriptsDiagnosisBatchPendingExtractDetail.
  ///
  /// In en, this message translates to:
  /// **'Start batch asset extract to turn the current selection into assets usable for images and storyboards.'**
  String get projectEditorScriptsDiagnosisBatchPendingExtractDetail;

  /// No description provided for @projectEditorScriptsDiagnosisSingleNoSnapshotSummary.
  ///
  /// In en, this message translates to:
  /// **'No workbench snapshot for the current script yet.'**
  String get projectEditorScriptsDiagnosisSingleNoSnapshotSummary;

  /// No description provided for @projectEditorScriptsDiagnosisSingleNoSnapshotDetail.
  ///
  /// In en, this message translates to:
  /// **'Sync the workbench first to load get-script-api context and the latest extract state.'**
  String get projectEditorScriptsDiagnosisSingleNoSnapshotDetail;

  /// No description provided for @projectEditorScriptsDiagnosisSingleExtractFailedSummary.
  ///
  /// In en, this message translates to:
  /// **'The latest asset extract run failed.'**
  String get projectEditorScriptsDiagnosisSingleExtractFailedSummary;

  /// No description provided for @projectEditorScriptsDiagnosisSingleExtractFailedDetailNoReason.
  ///
  /// In en, this message translates to:
  /// **'Fix inputs and start asset extract again for this script.'**
  String get projectEditorScriptsDiagnosisSingleExtractFailedDetailNoReason;

  /// No description provided for @projectEditorScriptsDiagnosisSingleExtractFailedDetailWithReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}. Fix inputs and start asset extract again.'**
  String projectEditorScriptsDiagnosisSingleExtractFailedDetailWithReason(
    String reason,
  );

  /// No description provided for @projectEditorScriptsDiagnosisSingleExtractRunningSummary.
  ///
  /// In en, this message translates to:
  /// **'Asset extract is in progress.'**
  String get projectEditorScriptsDiagnosisSingleExtractRunningSummary;

  /// No description provided for @projectEditorScriptsDiagnosisSingleExtractRunningDetail.
  ///
  /// In en, this message translates to:
  /// **'Poll extract state first to confirm the task finished before continuing to image editing.'**
  String get projectEditorScriptsDiagnosisSingleExtractRunningDetail;

  /// No description provided for @projectEditorScriptsDiagnosisSingleNoAssetsSummary.
  ///
  /// In en, this message translates to:
  /// **'This script has no related assets yet.'**
  String get projectEditorScriptsDiagnosisSingleNoAssetsSummary;

  /// No description provided for @projectEditorScriptsDiagnosisSingleNoAssetsDetail.
  ///
  /// In en, this message translates to:
  /// **'You can start asset extract to turn script context into assets for images and storyboards.'**
  String get projectEditorScriptsDiagnosisSingleNoAssetsDetail;

  /// No description provided for @projectEditorScriptsDiagnosisSingleHasAssetsSummary.
  ///
  /// In en, this message translates to:
  /// **'This script already has related assets.'**
  String get projectEditorScriptsDiagnosisSingleHasAssetsSummary;

  /// No description provided for @projectEditorScriptsDiagnosisSingleHasAssetsDetail.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} related assets; continue to the edit-image workbench or export a ZIP for local review.'**
  String projectEditorScriptsDiagnosisSingleHasAssetsDetail(int count);

  /// No description provided for @projectEditorScriptsSingleWorkbenchRecommendSyncWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Sync workbench'**
  String get projectEditorScriptsSingleWorkbenchRecommendSyncWorkbench;

  /// No description provided for @projectEditorScriptsSingleWorkbenchRecommendPollExtractState.
  ///
  /// In en, this message translates to:
  /// **'Poll extract state'**
  String get projectEditorScriptsSingleWorkbenchRecommendPollExtractState;

  /// No description provided for @projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets.
  ///
  /// In en, this message translates to:
  /// **'Extract assets for this script'**
  String get projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets;

  /// No description provided for @projectEditorScriptsSingleWorkbenchRecommendOpenEditImageWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Open edit-image workbench'**
  String get projectEditorScriptsSingleWorkbenchRecommendOpenEditImageWorkbench;

  /// No description provided for @projectEditorScriptsSingleWorkbenchRecommendExportScriptZip.
  ///
  /// In en, this message translates to:
  /// **'Export this script ZIP'**
  String get projectEditorScriptsSingleWorkbenchRecommendExportScriptZip;

  /// No description provided for @projectEditorScriptsSingleWorkbenchContextNotInApi.
  ///
  /// In en, this message translates to:
  /// **'This script is not present in get-script-api results yet.'**
  String get projectEditorScriptsSingleWorkbenchContextNotInApi;

  /// No description provided for @projectEditorScriptsSingleWorkbenchContextLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded script context: {assetCount} related assets'**
  String projectEditorScriptsSingleWorkbenchContextLoaded(int assetCount);

  /// No description provided for @projectEditorScriptsSingleWorkbenchContextReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read script context: {error}'**
  String projectEditorScriptsSingleWorkbenchContextReadFailed(String error);

  /// No description provided for @projectEditorScriptsSingleWorkbenchFollowUpExportDone.
  ///
  /// In en, this message translates to:
  /// **'Export finished: 1 script, ZIP {zipSize}.'**
  String projectEditorScriptsSingleWorkbenchFollowUpExportDone(String zipSize);

  /// No description provided for @projectEditorScriptsSingleWorkbenchFollowUpPollState.
  ///
  /// In en, this message translates to:
  /// **'Polled extract state for this script: {stateLine}'**
  String projectEditorScriptsSingleWorkbenchFollowUpPollState(String stateLine);

  /// No description provided for @projectEditorScriptsSingleWorkbenchFollowUpExtractSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Asset extract submitted: {status} · {message}'**
  String projectEditorScriptsSingleWorkbenchFollowUpExtractSubmitted(
    String status,
    String message,
  );

  /// No description provided for @projectEditorScriptsSingleWorkbenchEditClosedStillMissing.
  ///
  /// In en, this message translates to:
  /// **'Edit-image workbench closed; this script is still not present in get-script-api results.'**
  String get projectEditorScriptsSingleWorkbenchEditClosedStillMissing;

  /// No description provided for @projectEditorScriptsSingleWorkbenchFollowUpEditClosedSynced.
  ///
  /// In en, this message translates to:
  /// **'Edit-image workbench closed; synced script context and extract state.'**
  String get projectEditorScriptsSingleWorkbenchFollowUpEditClosedSynced;

  /// No description provided for @projectEditorScriptsSingleWorkbenchSyncBusy.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get projectEditorScriptsSingleWorkbenchSyncBusy;

  /// No description provided for @projectEditorScriptsExtractStateEmpty.
  ///
  /// In en, this message translates to:
  /// **'Extract state is empty: usually idle or completed.'**
  String get projectEditorScriptsExtractStateEmpty;

  /// No description provided for @projectEditorScriptsExtractStateLine.
  ///
  /// In en, this message translates to:
  /// **'Extract state: {state}{errorSuffix}'**
  String projectEditorScriptsExtractStateLine(int state, String errorSuffix);

  /// No description provided for @scriptEditorRelatedAssetsNone.
  ///
  /// In en, this message translates to:
  /// **'No related assets'**
  String get scriptEditorRelatedAssetsNone;

  /// No description provided for @scriptEditorRelatedAssetsNameSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get scriptEditorRelatedAssetsNameSeparator;

  /// No description provided for @scriptEditorRelatedAssetsOverflow.
  ///
  /// In en, this message translates to:
  /// **'{visibleNames} · {totalCount} items'**
  String scriptEditorRelatedAssetsOverflow(String visibleNames, int totalCount);

  /// No description provided for @scriptEditorWorkbenchPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Script workbench'**
  String get scriptEditorWorkbenchPanelTitle;

  /// No description provided for @scriptEditorWorkbenchPanelIntro.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync get-script-api context and extract state; supports ZIP export, asset extract, and edit-image flows.'**
  String get scriptEditorWorkbenchPanelIntro;

  /// No description provided for @scriptEditorWorkbenchRelatedAssetsLine.
  ///
  /// In en, this message translates to:
  /// **'Related assets: {assets}'**
  String scriptEditorWorkbenchRelatedAssetsLine(String assets);

  /// No description provided for @scriptEditorDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Script #{numericId}'**
  String scriptEditorDialogTitle(int numericId);

  /// No description provided for @scriptEditorFieldNameLabelClearIfEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name (leave empty to clear)'**
  String get scriptEditorFieldNameLabelClearIfEmpty;

  /// No description provided for @scriptEditorFieldContentLabelClearIfEmpty.
  ///
  /// In en, this message translates to:
  /// **'Content (leave empty to clear)'**
  String get scriptEditorFieldContentLabelClearIfEmpty;

  /// No description provided for @scriptEditorFieldExtractStateLabelClearIfEmpty.
  ///
  /// In en, this message translates to:
  /// **'Extract state (leave empty to clear)'**
  String get scriptEditorFieldExtractStateLabelClearIfEmpty;

  /// No description provided for @scriptEditorOpenStoryboards.
  ///
  /// In en, this message translates to:
  /// **'Storyboards…'**
  String get scriptEditorOpenStoryboards;

  /// No description provided for @scriptEditorDeleteScriptButton.
  ///
  /// In en, this message translates to:
  /// **'Delete script'**
  String get scriptEditorDeleteScriptButton;

  /// No description provided for @scriptEditorDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this script?'**
  String get scriptEditorDeleteConfirmTitle;

  /// No description provided for @scriptEditorDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete script #{numericId} and its storyboards (database cascade).'**
  String scriptEditorDeleteConfirmBody(int numericId);

  /// No description provided for @scriptEditorDeleteConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get scriptEditorDeleteConfirmDelete;

  /// No description provided for @scriptEditorExtractStateMustBeInteger.
  ///
  /// In en, this message translates to:
  /// **'extract_state must be an integer'**
  String get scriptEditorExtractStateMustBeInteger;

  /// No description provided for @scriptEditorSaveSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get scriptEditorSaveSaving;

  /// No description provided for @scriptEditorSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get scriptEditorSaveChanges;

  /// No description provided for @scriptEditorDeletedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Script deleted'**
  String get scriptEditorDeletedSnackBar;

  /// No description provided for @scriptEditorStoryboardAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add storyboard'**
  String get scriptEditorStoryboardAddDialogTitle;

  /// No description provided for @scriptEditorStoryboardAddPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Shot prompt'**
  String get scriptEditorStoryboardAddPromptLabel;

  /// No description provided for @scriptEditorStoryboardAddPromptHelper.
  ///
  /// In en, this message translates to:
  /// **'Describe this shot\'s visuals or motion.'**
  String get scriptEditorStoryboardAddPromptHelper;

  /// No description provided for @scriptEditorStoryboardAddDurationOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (optional)'**
  String get scriptEditorStoryboardAddDurationOptionalLabel;

  /// No description provided for @scriptEditorStoryboardAddDurationOptionalHelper.
  ///
  /// In en, this message translates to:
  /// **'Whole seconds; leave empty for backend default.'**
  String get scriptEditorStoryboardAddDurationOptionalHelper;

  /// No description provided for @scriptEditorStoryboardAddConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get scriptEditorStoryboardAddConfirmButton;

  /// No description provided for @scriptEditorStoryboardAddPromptRequiredSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Storyboard prompt cannot be empty.'**
  String get scriptEditorStoryboardAddPromptRequiredSnackBar;

  /// No description provided for @scriptEditorStoryboardDurationMustBeIntegerSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Duration must be an integer.'**
  String get scriptEditorStoryboardDurationMustBeIntegerSnackBar;

  /// No description provided for @scriptEditorStoryboardDurationMustBePositiveSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Duration must be a positive integer.'**
  String get scriptEditorStoryboardDurationMustBePositiveSnackBar;

  /// No description provided for @scriptEditorStoryboardAddFollowUpSummary.
  ///
  /// In en, this message translates to:
  /// **'Added storyboard #{storyboardId}.'**
  String scriptEditorStoryboardAddFollowUpSummary(int storyboardId);

  /// No description provided for @scriptEditorStoryboardBatchAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch add storyboards'**
  String get scriptEditorStoryboardBatchAddDialogTitle;

  /// No description provided for @scriptEditorStoryboardBatchAddPromptsLabel.
  ///
  /// In en, this message translates to:
  /// **'One prompt per line'**
  String get scriptEditorStoryboardBatchAddPromptsLabel;

  /// No description provided for @scriptEditorStoryboardBatchAddPromptsHelper.
  ///
  /// In en, this message translates to:
  /// **'Empty lines are skipped; shots are created in input order.'**
  String get scriptEditorStoryboardBatchAddPromptsHelper;

  /// No description provided for @scriptEditorStoryboardBatchAddUnifiedDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared duration (optional)'**
  String get scriptEditorStoryboardBatchAddUnifiedDurationLabel;

  /// No description provided for @scriptEditorStoryboardBatchAddUnifiedDurationHelper.
  ///
  /// In en, this message translates to:
  /// **'If set, applies to every shot added in this batch.'**
  String get scriptEditorStoryboardBatchAddUnifiedDurationHelper;

  /// No description provided for @scriptEditorStoryboardBatchAddConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Batch add'**
  String get scriptEditorStoryboardBatchAddConfirmButton;

  /// No description provided for @scriptEditorStoryboardBatchAddNeedOnePromptSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one storyboard prompt.'**
  String get scriptEditorStoryboardBatchAddNeedOnePromptSnackBar;

  /// No description provided for @scriptEditorStoryboardBatchAddUnifiedDurationMustBeIntegerSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Shared duration must be an integer.'**
  String get scriptEditorStoryboardBatchAddUnifiedDurationMustBeIntegerSnackBar;

  /// No description provided for @scriptEditorStoryboardBatchAddUnifiedDurationMustBePositiveSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Shared duration must be a positive integer.'**
  String
  get scriptEditorStoryboardBatchAddUnifiedDurationMustBePositiveSnackBar;

  /// No description provided for @scriptEditorStoryboardBatchAddFollowUpSummary.
  ///
  /// In en, this message translates to:
  /// **'Batch-added {count} storyboards.'**
  String scriptEditorStoryboardBatchAddFollowUpSummary(int count);

  /// No description provided for @scriptEditorStoryboardsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Storyboards ({count})'**
  String scriptEditorStoryboardsDialogTitle(int count);

  /// No description provided for @scriptEditorStoryboardsIntroEmpty.
  ///
  /// In en, this message translates to:
  /// **'This script has no storyboards yet. Add one or paste one prompt per line to import a batch.'**
  String get scriptEditorStoryboardsIntroEmpty;

  /// No description provided for @scriptEditorStoryboardsIntroHasBoards.
  ///
  /// In en, this message translates to:
  /// **'Manage shot order, prompts, and status for this script; tap a row to edit a single storyboard.'**
  String get scriptEditorStoryboardsIntroHasBoards;

  /// No description provided for @scriptEditorStoryboardsProductionSummaryPending.
  ///
  /// In en, this message translates to:
  /// **'Production view summary not loaded yet.'**
  String get scriptEditorStoryboardsProductionSummaryPending;

  /// No description provided for @scriptEditorStoryboardsRecommendedActionLine.
  ///
  /// In en, this message translates to:
  /// **'Recommended action: {action}'**
  String scriptEditorStoryboardsRecommendedActionLine(String action);

  /// No description provided for @scriptEditorStoryboardsBusy.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get scriptEditorStoryboardsBusy;

  /// No description provided for @scriptEditorStoryboardsRefreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get scriptEditorStoryboardsRefreshList;

  /// No description provided for @scriptEditorStoryboardsRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get scriptEditorStoryboardsRefreshing;

  /// No description provided for @scriptEditorStoryboardsOpenImageWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Storyboard image workbench'**
  String get scriptEditorStoryboardsOpenImageWorkbench;

  /// No description provided for @scriptEditorStoryboardsRefreshProductionView.
  ///
  /// In en, this message translates to:
  /// **'Refresh production view'**
  String get scriptEditorStoryboardsRefreshProductionView;

  /// No description provided for @scriptEditorStoryboardsLoadingProductionView.
  ///
  /// In en, this message translates to:
  /// **'Loading production view…'**
  String get scriptEditorStoryboardsLoadingProductionView;

  /// No description provided for @scriptEditorStoryboardsEmptyList.
  ///
  /// In en, this message translates to:
  /// **'No storyboards'**
  String get scriptEditorStoryboardsEmptyList;

  /// No description provided for @scriptEditorStoryboardsRowOrder.
  ///
  /// In en, this message translates to:
  /// **'Order {index}'**
  String scriptEditorStoryboardsRowOrder(int index);

  /// No description provided for @scriptEditorStoryboardsRowState.
  ///
  /// In en, this message translates to:
  /// **'State {state}'**
  String scriptEditorStoryboardsRowState(String state);

  /// No description provided for @scriptEditorStoryboardsRowDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration {duration}'**
  String scriptEditorStoryboardsRowDuration(String duration);

  /// No description provided for @scriptEditorStoryboardsStateFallback.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get scriptEditorStoryboardsStateFallback;

  /// No description provided for @scriptEditorStoryboardsProductionEmptyData.
  ///
  /// In en, this message translates to:
  /// **'Production view has no storyboard rows yet.'**
  String get scriptEditorStoryboardsProductionEmptyData;

  /// No description provided for @scriptEditorStoryboardsProductionSummaryLine.
  ///
  /// In en, this message translates to:
  /// **'Production view · {count} rows · {preview}{ellipsis}'**
  String scriptEditorStoryboardsProductionSummaryLine(
    int count,
    String preview,
    String ellipsis,
  );

  /// No description provided for @scriptEditorStoryboardsProductionReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read production view: {error}'**
  String scriptEditorStoryboardsProductionReadFailed(String error);

  /// No description provided for @scriptEditorStoryboardsDiagnosisEmptySummary.
  ///
  /// In en, this message translates to:
  /// **'This script has no storyboards yet.'**
  String get scriptEditorStoryboardsDiagnosisEmptySummary;

  /// No description provided for @scriptEditorStoryboardsDiagnosisEmptyDetail.
  ///
  /// In en, this message translates to:
  /// **'Add a single shot or batch-import prompts, then sync the production view or start image generation.'**
  String get scriptEditorStoryboardsDiagnosisEmptyDetail;

  /// No description provided for @scriptEditorStoryboardsDiagnosisProductionNotSyncedSummary.
  ///
  /// In en, this message translates to:
  /// **'Maintaining {count} storyboards, but the production view is not synced.'**
  String scriptEditorStoryboardsDiagnosisProductionNotSyncedSummary(int count);

  /// No description provided for @scriptEditorStoryboardsDiagnosisProductionNotSyncedDetail.
  ///
  /// In en, this message translates to:
  /// **'Refresh the production view first to confirm production-side rows exist, then decide whether to continue batch generation.'**
  String get scriptEditorStoryboardsDiagnosisProductionNotSyncedDetail;

  /// No description provided for @scriptEditorStoryboardsDiagnosisNoPromptsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} storyboards exist, but none have a usable prompt.'**
  String scriptEditorStoryboardsDiagnosisNoPromptsSummary(int count);

  /// No description provided for @scriptEditorStoryboardsDiagnosisNoPromptsDetail.
  ///
  /// In en, this message translates to:
  /// **'Open individual storyboards to fill prompts before the image workbench is reliable.'**
  String get scriptEditorStoryboardsDiagnosisNoPromptsDetail;

  /// No description provided for @scriptEditorStoryboardsDiagnosisReadyBatchSummary.
  ///
  /// In en, this message translates to:
  /// **'{ready}/{total} storyboards can enter the image-generation flow.'**
  String scriptEditorStoryboardsDiagnosisReadyBatchSummary(
    int ready,
    int total,
  );

  /// No description provided for @scriptEditorStoryboardsDiagnosisReadyBatchDetail.
  ///
  /// In en, this message translates to:
  /// **'Open the storyboard image workbench to read the production view, generate previews, and export selected images in batch.'**
  String get scriptEditorStoryboardsDiagnosisReadyBatchDetail;

  /// No description provided for @scriptEditorStoryboardsRecommendAddStoryboard.
  ///
  /// In en, this message translates to:
  /// **'Keep adding storyboards'**
  String get scriptEditorStoryboardsRecommendAddStoryboard;

  /// No description provided for @scriptEditorStoryboardsRecommendRefreshProduction.
  ///
  /// In en, this message translates to:
  /// **'Refresh production view'**
  String get scriptEditorStoryboardsRecommendRefreshProduction;

  /// No description provided for @scriptEditorStoryboardsRecommendOpenBatchWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Open storyboard image workbench'**
  String get scriptEditorStoryboardsRecommendOpenBatchWorkbench;

  /// No description provided for @scriptEditorStoryboardsRecommendEditPrompts.
  ///
  /// In en, this message translates to:
  /// **'Fill in storyboard prompts'**
  String get scriptEditorStoryboardsRecommendEditPrompts;

  /// No description provided for @scriptEditorStoryboardsFollowUpLine.
  ///
  /// In en, this message translates to:
  /// **'{actionSummary} Suggested next step: {nextAction}. {detail}'**
  String scriptEditorStoryboardsFollowUpLine(
    String actionSummary,
    String nextAction,
    String detail,
  );

  /// No description provided for @projectEditorScriptsSingleWorkbenchRecentExtractError.
  ///
  /// In en, this message translates to:
  /// **'Recent extract error: {reason}'**
  String projectEditorScriptsSingleWorkbenchRecentExtractError(String reason);

  /// No description provided for @projectEditorScriptsWorkbenchDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Script batch workbench'**
  String get projectEditorScriptsWorkbenchDialogTitle;

  /// No description provided for @projectEditorScriptsWorkbenchDialogNameFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter scripts by name'**
  String get projectEditorScriptsWorkbenchDialogNameFilterLabel;

  /// No description provided for @projectEditorScriptsWorkbenchDialogNameFilterHelper.
  ///
  /// In en, this message translates to:
  /// **'When calling POST …/projects/<project id>/scripts/get-script-api, filter by name; leave empty to load full context.'**
  String get projectEditorScriptsWorkbenchDialogNameFilterHelper;

  /// No description provided for @projectEditorScriptsWorkbenchDialogReadScriptContext.
  ///
  /// In en, this message translates to:
  /// **'Read script context'**
  String get projectEditorScriptsWorkbenchDialogReadScriptContext;

  /// No description provided for @projectEditorScriptsWorkbenchDialogUseCurrentPreview.
  ///
  /// In en, this message translates to:
  /// **'Use current preview'**
  String get projectEditorScriptsWorkbenchDialogUseCurrentPreview;

  /// No description provided for @projectEditorScriptsWorkbenchDialogUseAllScripts.
  ///
  /// In en, this message translates to:
  /// **'Use all project scripts'**
  String get projectEditorScriptsWorkbenchDialogUseAllScripts;

  /// No description provided for @projectEditorScriptsWorkbenchDialogReloadProjectScripts.
  ///
  /// In en, this message translates to:
  /// **'Reload project scripts'**
  String get projectEditorScriptsWorkbenchDialogReloadProjectScripts;

  /// No description provided for @projectEditorScriptsWorkbenchDialogTargetScriptIdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Target script numeric ids'**
  String get projectEditorScriptsWorkbenchDialogTargetScriptIdsLabel;

  /// No description provided for @projectEditorScriptsWorkbenchDialogTargetScriptIdsHelper.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas, spaces, or newlines; batch export, polling, and asset extract use this list.'**
  String get projectEditorScriptsWorkbenchDialogTargetScriptIdsHelper;

  /// No description provided for @projectEditorScriptsWorkbenchDialogExtractGroupSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Asset extract group size'**
  String get projectEditorScriptsWorkbenchDialogExtractGroupSizeLabel;

  /// No description provided for @projectEditorScriptsWorkbenchDialogExtractGroupSizeHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for backend default; used for extract-assets when set.'**
  String get projectEditorScriptsWorkbenchDialogExtractGroupSizeHelper;

  /// No description provided for @projectEditorScriptsWorkbenchDialogContextPreviewHeading.
  ///
  /// In en, this message translates to:
  /// **'Context preview'**
  String get projectEditorScriptsWorkbenchDialogContextPreviewHeading;

  /// No description provided for @projectEditorScriptsWorkbenchDialogContextPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview yet.'**
  String get projectEditorScriptsWorkbenchDialogContextPreviewEmpty;

  /// No description provided for @projectEditorScriptsWorkbenchDialogPreviewRowBrief.
  ///
  /// In en, this message translates to:
  /// **'#{numericId} {name} · extract state {extractState}'**
  String projectEditorScriptsWorkbenchDialogPreviewRowBrief(
    int numericId,
    String name,
    int extractState,
  );

  /// No description provided for @projectEditorScriptsWorkbenchDialogPreviewRowWithAssets.
  ///
  /// In en, this message translates to:
  /// **'#{numericId} {name} · extract state {extractState} · assets {assets}'**
  String projectEditorScriptsWorkbenchDialogPreviewRowWithAssets(
    int numericId,
    String name,
    int extractState,
    String assets,
  );

  /// No description provided for @projectEditorScriptsWorkbenchDialogBatchCreate.
  ///
  /// In en, this message translates to:
  /// **'Batch create'**
  String get projectEditorScriptsWorkbenchDialogBatchCreate;

  /// No description provided for @projectEditorScriptsWorkbenchDialogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get projectEditorScriptsWorkbenchDialogClose;

  /// No description provided for @projectEditorAssetSummaryProductionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Production asset data is empty'**
  String get projectEditorAssetSummaryProductionEmpty;

  /// No description provided for @projectEditorAssetSummaryProductionLine.
  ///
  /// In en, this message translates to:
  /// **'Production assets {total} items · {typesLine} · Sample: {sampleLine}'**
  String projectEditorAssetSummaryProductionLine(
    int total,
    String typesLine,
    String sampleLine,
  );

  /// No description provided for @projectEditorAssetSummaryTypeCount.
  ///
  /// In en, this message translates to:
  /// **'{type} {count} items'**
  String projectEditorAssetSummaryTypeCount(String type, int count);

  /// No description provided for @projectEditorAssetSummaryPollingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No image status returned for selected assets'**
  String get projectEditorAssetSummaryPollingEmpty;

  /// No description provided for @projectEditorAssetSummaryPollingLine.
  ///
  /// In en, this message translates to:
  /// **'Polled {count} assets · {stateLine} · Sample: {sampleLine}'**
  String projectEditorAssetSummaryPollingLine(
    int count,
    String stateLine,
    String sampleLine,
  );

  /// No description provided for @projectEditorAssetSummaryStateCount.
  ///
  /// In en, this message translates to:
  /// **'{state} {count} items'**
  String projectEditorAssetSummaryStateCount(String state, int count);

  /// No description provided for @projectEditorAssetSummaryImageCount.
  ///
  /// In en, this message translates to:
  /// **'#{assetId}: {count} images'**
  String projectEditorAssetSummaryImageCount(int assetId, int count);

  /// No description provided for @projectEditorAssetSummaryMaterialContext.
  ///
  /// In en, this message translates to:
  /// **'Material context {imageCount} image materials · {videoCount} video materials'**
  String projectEditorAssetSummaryMaterialContext(
    int imageCount,
    int videoCount,
  );

  /// No description provided for @projectEditorAssetSummaryBatchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Batch candidates are empty'**
  String get projectEditorAssetSummaryBatchEmpty;

  /// No description provided for @projectEditorAssetSummaryBatchLine.
  ///
  /// In en, this message translates to:
  /// **'Batch candidates {count}/{total} items · Sample: {sampleLine}'**
  String projectEditorAssetSummaryBatchLine(
    int count,
    int total,
    String sampleLine,
  );

  /// No description provided for @projectEditorAssetSummaryPromptEmpty.
  ///
  /// In en, this message translates to:
  /// **'No prompt status returned'**
  String get projectEditorAssetSummaryPromptEmpty;

  /// No description provided for @projectEditorAssetSummaryPromptLine.
  ///
  /// In en, this message translates to:
  /// **'Prompt polling {count} items · {stateLine}'**
  String projectEditorAssetSummaryPromptLine(int count, String stateLine);

  /// No description provided for @projectEditorAssetSummarySelectionNone.
  ///
  /// In en, this message translates to:
  /// **'No assets currently selected'**
  String get projectEditorAssetSummarySelectionNone;

  /// No description provided for @projectEditorAssetSummarySelectionSingle.
  ///
  /// In en, this message translates to:
  /// **'Currently selected #{id} {name}'**
  String projectEditorAssetSummarySelectionSingle(int id, String name);

  /// No description provided for @projectEditorAssetSummarySelectionMultiple.
  ///
  /// In en, this message translates to:
  /// **'Currently selected {count} assets: {sample}'**
  String projectEditorAssetSummarySelectionMultiple(int count, String sample);

  /// No description provided for @authSupabaseNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured: run example\nflutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...'**
  String get authSupabaseNotConfigured;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get authSignOut;

  /// No description provided for @authSignedInUser.
  ///
  /// In en, this message translates to:
  /// **'Signed in user: {userId}'**
  String authSignedInUser(String userId);

  /// No description provided for @authRequestInProgress.
  ///
  /// In en, this message translates to:
  /// **'Requesting…'**
  String get authRequestInProgress;

  /// No description provided for @authGetMeBearer.
  ///
  /// In en, this message translates to:
  /// **'GET /api/v1/me (Bearer)'**
  String get authGetMeBearer;

  /// No description provided for @authMeResponse.
  ///
  /// In en, this message translates to:
  /// **'/me: {response}'**
  String authMeResponse(String response);

  /// No description provided for @authDevSwitchProbe.
  ///
  /// In en, this message translates to:
  /// **'GET+PUT /api/v1/settings/dev/switch-ai-tool'**
  String get authDevSwitchProbe;

  /// No description provided for @authDevSwitchResponse.
  ///
  /// In en, this message translates to:
  /// **'dev switch: {response}'**
  String authDevSwitchResponse(String response);

  /// No description provided for @authMemoryConfigProbe.
  ///
  /// In en, this message translates to:
  /// **'memory-config GET+POST + clear-agent-memories'**
  String get authMemoryConfigProbe;

  /// No description provided for @authMemoryConfigResponse.
  ///
  /// In en, this message translates to:
  /// **'memory-config: {response}'**
  String authMemoryConfigResponse(String response);

  /// No description provided for @authAboutProbe.
  ///
  /// In en, this message translates to:
  /// **'POST …/settings/about/check-update + download-app'**
  String get authAboutProbe;

  /// No description provided for @authAboutResponse.
  ///
  /// In en, this message translates to:
  /// **'about: {response}'**
  String authAboutResponse(String response);

  /// No description provided for @authUsageSummary.
  ///
  /// In en, this message translates to:
  /// **'GET /api/v1/usage/summary'**
  String get authUsageSummary;

  /// No description provided for @authUsageResponse.
  ///
  /// In en, this message translates to:
  /// **'usage: {response}'**
  String authUsageResponse(String response);

  /// No description provided for @authPromptsProbe.
  ///
  /// In en, this message translates to:
  /// **'GET /api/v1/prompts + GET/1 + PATCH/1'**
  String get authPromptsProbe;

  /// No description provided for @authPromptsResponse.
  ///
  /// In en, this message translates to:
  /// **'prompts: {response}'**
  String authPromptsResponse(String response);

  /// No description provided for @authVisualManualProbe.
  ///
  /// In en, this message translates to:
  /// **'GET+POST /api/v1/visual-manual'**
  String get authVisualManualProbe;

  /// No description provided for @authVisualManualResponse.
  ///
  /// In en, this message translates to:
  /// **'visual-manual: {response}'**
  String authVisualManualResponse(String response);

  /// No description provided for @authDirectorManualProbe.
  ///
  /// In en, this message translates to:
  /// **'POST …/project/query-director-manual'**
  String get authDirectorManualProbe;

  /// No description provided for @authDirectorManualResponse.
  ///
  /// In en, this message translates to:
  /// **'director-manual: {response}'**
  String authDirectorManualResponse(String response);

  /// No description provided for @authSkillsBinaryProbe.
  ///
  /// In en, this message translates to:
  /// **'GET /api/v1/skills/binary (_smoke PNG)'**
  String get authSkillsBinaryProbe;

  /// No description provided for @authSkillsBinaryResponse.
  ///
  /// In en, this message translates to:
  /// **'skills/binary: {response}'**
  String authSkillsBinaryResponse(String response);

  /// No description provided for @authModelsCatalogProbe.
  ///
  /// In en, this message translates to:
  /// **'models + vendors + vendor-add + danger + production + agent-deploy + model-test + script-agent + assets-gen'**
  String get authModelsCatalogProbe;

  /// No description provided for @authTextModelDefaultProbe.
  ///
  /// In en, this message translates to:
  /// **'GET+PATCH /api/v1/models/text-default'**
  String get authTextModelDefaultProbe;

  /// No description provided for @authModelDetailProbe.
  ///
  /// In en, this message translates to:
  /// **'GET /api/v1/models/detail (1:gpt-4o-mini)'**
  String get authModelDetailProbe;

  /// No description provided for @authModelsResponse.
  ///
  /// In en, this message translates to:
  /// **'models: {response}'**
  String authModelsResponse(String response);

  /// No description provided for @authTextDefaultResponse.
  ///
  /// In en, this message translates to:
  /// **'text-default: {response}'**
  String authTextDefaultResponse(String response);

  /// No description provided for @authModelDetailResponse.
  ///
  /// In en, this message translates to:
  /// **'model detail: {response}'**
  String authModelDetailResponse(String response);

  /// No description provided for @shortVideoSpaceDialogExportProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Progress'**
  String get shortVideoSpaceDialogExportProgressTitle;

  /// No description provided for @shortVideoSpaceDialogExportProgressStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get shortVideoSpaceDialogExportProgressStatusQueued;

  /// No description provided for @shortVideoSpaceDialogExportProgressStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get shortVideoSpaceDialogExportProgressStatusProcessing;

  /// No description provided for @shortVideoSpaceDialogExportProgressStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get shortVideoSpaceDialogExportProgressStatusCompleted;

  /// No description provided for @shortVideoSpaceDialogExportProgressStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get shortVideoSpaceDialogExportProgressStatusFailed;

  /// No description provided for @shortVideoSpaceDialogExportProgressStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get shortVideoSpaceDialogExportProgressStatusCancelled;

  /// No description provided for @shortVideoSpaceDialogExportProgressStageInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing'**
  String get shortVideoSpaceDialogExportProgressStageInitializing;

  /// No description provided for @shortVideoSpaceDialogExportProgressStageLoadingAssets.
  ///
  /// In en, this message translates to:
  /// **'Loading Assets'**
  String get shortVideoSpaceDialogExportProgressStageLoadingAssets;

  /// No description provided for @shortVideoSpaceDialogExportProgressStageEncoding.
  ///
  /// In en, this message translates to:
  /// **'Encoding Video'**
  String get shortVideoSpaceDialogExportProgressStageEncoding;

  /// No description provided for @shortVideoSpaceDialogExportProgressStageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading File'**
  String get shortVideoSpaceDialogExportProgressStageUploading;

  /// No description provided for @shortVideoSpaceDialogExportProgressStageFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing'**
  String get shortVideoSpaceDialogExportProgressStageFinalizing;

  /// No description provided for @shortVideoSpaceDialogExportProgressLoadingStatus.
  ///
  /// In en, this message translates to:
  /// **'Fetching export status...'**
  String get shortVideoSpaceDialogExportProgressLoadingStatus;

  /// No description provided for @shortVideoSpaceDialogExportProgressFetchError.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch progress: {error}'**
  String shortVideoSpaceDialogExportProgressFetchError(String error);

  /// No description provided for @shortVideoSpaceDialogExportProgressSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please login again'**
  String get shortVideoSpaceDialogExportProgressSessionExpired;

  /// No description provided for @shortVideoSpaceDialogExportProgressCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancel failed: {error}'**
  String shortVideoSpaceDialogExportProgressCancelFailed(String error);

  /// No description provided for @shortVideoSpaceDialogExportProgressTaskId.
  ///
  /// In en, this message translates to:
  /// **'Task ID: {taskId}'**
  String shortVideoSpaceDialogExportProgressTaskId(String taskId);

  /// No description provided for @shortVideoSpaceDialogExportProgressCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel Export'**
  String get shortVideoSpaceDialogExportProgressCancelButton;

  /// No description provided for @shortVideoSpaceDialogExportProgressCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get shortVideoSpaceDialogExportProgressCloseButton;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageQueued.
  ///
  /// In en, this message translates to:
  /// **'Export task queued, waiting for processing...'**
  String get shortVideoSpaceDialogExportProgressMessageQueued;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing export task...'**
  String get shortVideoSpaceDialogExportProgressMessageInitializing;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageLoadingAssets.
  ///
  /// In en, this message translates to:
  /// **'Loading video assets and audio files...'**
  String get shortVideoSpaceDialogExportProgressMessageLoadingAssets;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageEncoding.
  ///
  /// In en, this message translates to:
  /// **'Encoding video, this may take a few minutes...'**
  String get shortVideoSpaceDialogExportProgressMessageEncoding;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading exported video file...'**
  String get shortVideoSpaceDialogExportProgressMessageUploading;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Completing final processing steps...'**
  String get shortVideoSpaceDialogExportProgressMessageFinalizing;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing export task...'**
  String get shortVideoSpaceDialogExportProgressMessageProcessing;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageCompleted.
  ///
  /// In en, this message translates to:
  /// **'Export completed successfully! Video is ready for download.'**
  String get shortVideoSpaceDialogExportProgressMessageCompleted;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed, please retry or contact support.'**
  String get shortVideoSpaceDialogExportProgressMessageFailed;

  /// No description provided for @shortVideoSpaceDialogExportProgressMessageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export has been cancelled.'**
  String get shortVideoSpaceDialogExportProgressMessageCancelled;

  /// No description provided for @shortVideoSpaceDialogConfirmDeleteVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get shortVideoSpaceDialogConfirmDeleteVersionTitle;

  /// No description provided for @shortVideoSpaceDialogConfirmDeleteVersionMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete version \"{versionName}\"?\n\nThis action cannot be undone.'**
  String shortVideoSpaceDialogConfirmDeleteVersionMessage(String versionName);

  /// No description provided for @shortVideoSpaceDialogConfirmDeleteVersionDontShow.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get shortVideoSpaceDialogConfirmDeleteVersionDontShow;

  /// No description provided for @shortVideoSpaceDialogConfirmDeleteVersionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shortVideoSpaceDialogConfirmDeleteVersionCancel;

  /// No description provided for @shortVideoSpaceDialogConfirmDeleteVersionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get shortVideoSpaceDialogConfirmDeleteVersionConfirm;

  /// No description provided for @shortVideoSpaceDialogConfirmBatchDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Batch Disable'**
  String get shortVideoSpaceDialogConfirmBatchDisableTitle;

  /// No description provided for @shortVideoSpaceDialogConfirmBatchDisableMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disable {shotCount} selected shots?\n\nDisabled shots will not appear in the final video.'**
  String shortVideoSpaceDialogConfirmBatchDisableMessage(int shotCount);

  /// No description provided for @shortVideoSpaceDialogConfirmBatchDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Disable'**
  String get shortVideoSpaceDialogConfirmBatchDisableConfirm;

  /// No description provided for @shortVideoSpaceDialogConfirmRestoreDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Restore Draft'**
  String get shortVideoSpaceDialogConfirmRestoreDraftTitle;

  /// No description provided for @shortVideoSpaceDialogConfirmRestoreDraftMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to restore draft \"{draftName}\"?\n\nCurrent unsaved edits will be lost.'**
  String shortVideoSpaceDialogConfirmRestoreDraftMessage(String draftName);

  /// No description provided for @shortVideoSpaceDialogConfirmRestoreDraftConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get shortVideoSpaceDialogConfirmRestoreDraftConfirm;

  /// No description provided for @shortVideoSpaceDialogConfirmCancelExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Export'**
  String get shortVideoSpaceDialogConfirmCancelExportTitle;

  /// No description provided for @shortVideoSpaceDialogConfirmCancelExportMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel the export? Processed content will be lost.'**
  String get shortVideoSpaceDialogConfirmCancelExportMessage;

  /// No description provided for @shortVideoSpaceDialogConfirmCancelExportContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue Export'**
  String get shortVideoSpaceDialogConfirmCancelExportContinue;

  /// No description provided for @shortVideoSpaceDialogConfirmCancelExportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Cancel'**
  String get shortVideoSpaceDialogConfirmCancelExportConfirm;

  /// No description provided for @shortVideoSpaceDialogConfirmBatchArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Batch Archive'**
  String get shortVideoSpaceDialogConfirmBatchArchiveTitle;

  /// No description provided for @shortVideoSpaceDialogConfirmBatchArchiveMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to archive {draftCount} publish drafts? They will be removed from the publish queue (may be recoverable depending on backend policy).'**
  String shortVideoSpaceDialogConfirmBatchArchiveMessage(int draftCount);

  /// No description provided for @shortVideoSpaceDialogConfirmBatchArchiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Archive'**
  String get shortVideoSpaceDialogConfirmBatchArchiveConfirm;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Voiceover Settings'**
  String get shortVideoSpaceDialogVoiceoverSettingsTitle;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'TTS Provider'**
  String get shortVideoSpaceDialogVoiceoverSettingsProviderLabel;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsProviderOpenAI.
  ///
  /// In en, this message translates to:
  /// **'OpenAI TTS'**
  String get shortVideoSpaceDialogVoiceoverSettingsProviderOpenAI;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsProviderAzure.
  ///
  /// In en, this message translates to:
  /// **'Azure TTS'**
  String get shortVideoSpaceDialogVoiceoverSettingsProviderAzure;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsProviderGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google TTS'**
  String get shortVideoSpaceDialogVoiceoverSettingsProviderGoogle;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceLabel;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsVoiceAlloy.
  ///
  /// In en, this message translates to:
  /// **'Alloy (Neutral)'**
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceAlloy;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsVoiceEcho.
  ///
  /// In en, this message translates to:
  /// **'Echo (Male)'**
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceEcho;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsVoiceFable.
  ///
  /// In en, this message translates to:
  /// **'Fable (British)'**
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceFable;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsVoiceOnyx.
  ///
  /// In en, this message translates to:
  /// **'Onyx (Deep)'**
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceOnyx;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsVoiceNova.
  ///
  /// In en, this message translates to:
  /// **'Nova (Female)'**
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceNova;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsVoiceShimmer.
  ///
  /// In en, this message translates to:
  /// **'Shimmer (Soft)'**
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceShimmer;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsEmotionLabel.
  ///
  /// In en, this message translates to:
  /// **'Emotion'**
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionLabel;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsEmotionNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionNeutral;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsEmotionHappy.
  ///
  /// In en, this message translates to:
  /// **'Happy'**
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionHappy;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsEmotionSad.
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionSad;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsEmotionAngry.
  ///
  /// In en, this message translates to:
  /// **'Angry'**
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionAngry;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get shortVideoSpaceDialogVoiceoverSettingsSpeedLabel;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsSpeedRange.
  ///
  /// In en, this message translates to:
  /// **'Range: 0.5x (slow) - 2.0x (fast)'**
  String get shortVideoSpaceDialogVoiceoverSettingsSpeedRange;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'Settings will apply to newly generated voiceovers. Existing voiceovers need to be regenerated to apply new parameters.'**
  String get shortVideoSpaceDialogVoiceoverSettingsInfoMessage;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shortVideoSpaceDialogVoiceoverSettingsCancel;

  /// No description provided for @shortVideoSpaceDialogVoiceoverSettingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shortVideoSpaceDialogVoiceoverSettingsSave;

  /// No description provided for @shortVideoSpacePublishQualityStageUnlabeled.
  ///
  /// In en, this message translates to:
  /// **'Unlabeled stage'**
  String get shortVideoSpacePublishQualityStageUnlabeled;

  /// No description provided for @shortVideoSpacePublishQualityStageStorySkeleton.
  ///
  /// In en, this message translates to:
  /// **'Story skeleton'**
  String get shortVideoSpacePublishQualityStageStorySkeleton;

  /// No description provided for @shortVideoSpacePublishQualityStageAdaptationStrategy.
  ///
  /// In en, this message translates to:
  /// **'Adaptation strategy'**
  String get shortVideoSpacePublishQualityStageAdaptationStrategy;

  /// No description provided for @shortVideoSpacePublishQualityStageDirectorPlanning.
  ///
  /// In en, this message translates to:
  /// **'Director planning'**
  String get shortVideoSpacePublishQualityStageDirectorPlanning;

  /// No description provided for @shortVideoSpacePublishQualityStageStoryboardTable.
  ///
  /// In en, this message translates to:
  /// **'Storyboard table'**
  String get shortVideoSpacePublishQualityStageStoryboardTable;

  /// No description provided for @shortVideoSpacePublishQualityStageStoryboardPanel.
  ///
  /// In en, this message translates to:
  /// **'Storyboard panel'**
  String get shortVideoSpacePublishQualityStageStoryboardPanel;

  /// No description provided for @shortVideoSpacePublishQualityStageVideoPrompt.
  ///
  /// In en, this message translates to:
  /// **'Video prompt / Final'**
  String get shortVideoSpacePublishQualityStageVideoPrompt;

  /// No description provided for @shortVideoSpacePublishExportIssueCandidatePending.
  ///
  /// In en, this message translates to:
  /// **'Candidate pending confirmation'**
  String get shortVideoSpacePublishExportIssueCandidatePending;

  /// No description provided for @shortVideoSpacePublishExportIssueMissingSelectedMedia.
  ///
  /// In en, this message translates to:
  /// **'Missing final media'**
  String get shortVideoSpacePublishExportIssueMissingSelectedMedia;

  /// No description provided for @shortVideoSpacePublishExportIssueSelectedMediaNotVideo.
  ///
  /// In en, this message translates to:
  /// **'Selected media is not video'**
  String get shortVideoSpacePublishExportIssueSelectedMediaNotVideo;

  /// No description provided for @shortVideoSpacePublishExportIssueSubtitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Subtitle / voiceover text missing'**
  String get shortVideoSpacePublishExportIssueSubtitlePlaceholder;

  /// No description provided for @shortVideoSpacePublishExportIssueSubtitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Subtitle is empty'**
  String get shortVideoSpacePublishExportIssueSubtitleEmpty;

  /// No description provided for @shortVideoSpacePublishExportIssueVoiceoverFailed.
  ///
  /// In en, this message translates to:
  /// **'Voiceover generation failed'**
  String get shortVideoSpacePublishExportIssueVoiceoverFailed;

  /// No description provided for @shortVideoSpacePublishExportIssueVoiceoverAudioMissing.
  ///
  /// In en, this message translates to:
  /// **'Voiceover audio not ready'**
  String get shortVideoSpacePublishExportIssueVoiceoverAudioMissing;

  /// No description provided for @shortVideoSpacePublishExportIssueVoiceoverNotReady.
  ///
  /// In en, this message translates to:
  /// **'Voiceover not ready'**
  String get shortVideoSpacePublishExportIssueVoiceoverNotReady;

  /// No description provided for @shortVideoSpacePublishExportIssueDurationNotExplicit.
  ///
  /// In en, this message translates to:
  /// **'Duration not specified (export default)'**
  String get shortVideoSpacePublishExportIssueDurationNotExplicit;

  /// No description provided for @shortVideoSpacePublishExportIssueDurationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Duration not set'**
  String get shortVideoSpacePublishExportIssueDurationNotSet;

  /// No description provided for @shortVideoSpacePublishExportIssueDurationUnparsable.
  ///
  /// In en, this message translates to:
  /// **'Duration format error'**
  String get shortVideoSpacePublishExportIssueDurationUnparsable;

  /// No description provided for @shortVideoSpacePublishExportIssueCompletionUncertain.
  ///
  /// In en, this message translates to:
  /// **'Final status not marked as completed'**
  String get shortVideoSpacePublishExportIssueCompletionUncertain;

  /// No description provided for @shortVideoSpacePublishAssemblyLoadingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Loading final assembly snapshot…'**
  String get shortVideoSpacePublishAssemblyLoadingHeadline;

  /// No description provided for @shortVideoSpacePublishAssemblyLoadingDetail.
  ///
  /// In en, this message translates to:
  /// **'Data from GET …/short-video-assembly (aggregates storyboards and final elements by script order).'**
  String get shortVideoSpacePublishAssemblyLoadingDetail;

  /// No description provided for @shortVideoSpacePublishAssemblyUnavailableHeadline.
  ///
  /// In en, this message translates to:
  /// **'Final assembly snapshot unavailable.'**
  String get shortVideoSpacePublishAssemblyUnavailableHeadline;

  /// No description provided for @shortVideoSpacePublishAssemblyUnavailableDetail.
  ///
  /// In en, this message translates to:
  /// **'Please refresh later, or confirm storyboards and timeline in production workspace.'**
  String get shortVideoSpacePublishAssemblyUnavailableDetail;

  /// No description provided for @shortVideoSpacePublishAssemblyNoScriptsHeadline.
  ///
  /// In en, this message translates to:
  /// **'No script / storyboard assembly data yet.'**
  String get shortVideoSpacePublishAssemblyNoScriptsHeadline;

  /// No description provided for @shortVideoSpacePublishAssemblyHeadlineScripts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 script} other{{count} scripts}} · {shots} shots (export path snapshot)\nTotal duration: {seconds}s ({formatted})'**
  String shortVideoSpacePublishAssemblyHeadlineScripts(
    int count,
    int shots,
    int seconds,
    String formatted,
  );

  /// No description provided for @shortVideoSpacePublishAssemblyVoiceProfileNotSet.
  ///
  /// In en, this message translates to:
  /// **'Voice profile: Not set'**
  String get shortVideoSpacePublishAssemblyVoiceProfileNotSet;

  /// No description provided for @shortVideoSpacePublishAssemblyVoiceProfile.
  ///
  /// In en, this message translates to:
  /// **'Voice profile: {profile}'**
  String shortVideoSpacePublishAssemblyVoiceProfile(String profile);

  /// No description provided for @shortVideoSpacePublishAssemblySubtitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Subtitle: Default'**
  String get shortVideoSpacePublishAssemblySubtitleDefault;

  /// No description provided for @shortVideoSpacePublishAssemblySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle: {style}'**
  String shortVideoSpacePublishAssemblySubtitle(String style);

  /// No description provided for @shortVideoSpacePublishAssemblyBgmNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'BGM: Not specified'**
  String get shortVideoSpacePublishAssemblyBgmNotSpecified;

  /// No description provided for @shortVideoSpacePublishAssemblyBgm.
  ///
  /// In en, this message translates to:
  /// **'BGM: {strategy}'**
  String shortVideoSpacePublishAssemblyBgm(String strategy);

  /// No description provided for @shortVideoSpacePublishAssemblyEffectiveTts.
  ///
  /// In en, this message translates to:
  /// **'Effective TTS (queue/worker): {voice}'**
  String shortVideoSpacePublishAssemblyEffectiveTts(String voice);

  /// No description provided for @shortVideoSpacePublishAssemblyScriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Script #{id}'**
  String shortVideoSpacePublishAssemblyScriptTitle(int id);

  /// No description provided for @shortVideoSpacePublishAssemblyScriptTitleNamed.
  ///
  /// In en, this message translates to:
  /// **'Script #{id} · {name}'**
  String shortVideoSpacePublishAssemblyScriptTitleNamed(int id, String name);

  /// No description provided for @shortVideoSpacePublishAssemblyScriptSummary.
  ///
  /// In en, this message translates to:
  /// **'{title} · {shots} shots · Final selected {withMedia} · Voiceover ready {voReady}'**
  String shortVideoSpacePublishAssemblyScriptSummary(
    String title,
    int shots,
    int withMedia,
    int voReady,
  );

  /// No description provided for @shortVideoSpacePublishAssemblyShotPreviewYes.
  ///
  /// In en, this message translates to:
  /// **'Preview✓'**
  String get shortVideoSpacePublishAssemblyShotPreviewYes;

  /// No description provided for @shortVideoSpacePublishAssemblyShotPreviewNo.
  ///
  /// In en, this message translates to:
  /// **'Preview×'**
  String get shortVideoSpacePublishAssemblyShotPreviewNo;

  /// No description provided for @shortVideoSpacePublishAssemblyShotDurationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Duration?'**
  String get shortVideoSpacePublishAssemblyShotDurationUnknown;

  /// No description provided for @shortVideoSpacePublishAssemblyShotSubtitleYes.
  ///
  /// In en, this message translates to:
  /// **'Subtitle✓'**
  String get shortVideoSpacePublishAssemblyShotSubtitleYes;

  /// No description provided for @shortVideoSpacePublishAssemblyShotSubtitleNo.
  ///
  /// In en, this message translates to:
  /// **'Subtitle×'**
  String get shortVideoSpacePublishAssemblyShotSubtitleNo;

  /// No description provided for @shortVideoSpacePublishAssemblyShotVoiceoverYes.
  ///
  /// In en, this message translates to:
  /// **'Voiceover✓'**
  String get shortVideoSpacePublishAssemblyShotVoiceoverYes;

  /// No description provided for @shortVideoSpacePublishAssemblyShotVoiceoverNo.
  ///
  /// In en, this message translates to:
  /// **'Voiceover×'**
  String get shortVideoSpacePublishAssemblyShotVoiceoverNo;

  /// No description provided for @shortVideoSpacePublishAssemblyShotBgmDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get shortVideoSpacePublishAssemblyShotBgmDefault;

  /// No description provided for @shortVideoSpacePublishAssemblyShotDetail.
  ///
  /// In en, this message translates to:
  /// **'Shot[{order}] · {preview} · {duration} · {subtitle} · {voiceover} · BGM {bgm}'**
  String shortVideoSpacePublishAssemblyShotDetail(
    String order,
    String preview,
    String duration,
    String subtitle,
    String voiceover,
    String bgm,
  );

  /// No description provided for @shortVideoSpacePublishAssemblyMoreShots.
  ///
  /// In en, this message translates to:
  /// **'…{count} more shots, view in production workspace timeline'**
  String shortVideoSpacePublishAssemblyMoreShots(int count);

  /// No description provided for @shortVideoSpacePublishAssemblyQualityProjectBadCase.
  ///
  /// In en, this message translates to:
  /// **'Project-level bad cases pending review: {count} (same source as production overview)'**
  String shortVideoSpacePublishAssemblyQualityProjectBadCase(int count);

  /// No description provided for @shortVideoSpacePublishAssemblyQualityAssemblyReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews on current assembly storyboards: {total} · Bad cases {badCase} · Affected storyboards {shots}'**
  String shortVideoSpacePublishAssemblyQualityAssemblyReviews(
    int total,
    int badCase,
    int shots,
  );

  /// No description provided for @shortVideoSpacePublishAssemblyQualityLateStageBadCase.
  ///
  /// In en, this message translates to:
  /// **'Late-stage bad cases (storyboard panel/video prompt): {count}'**
  String shortVideoSpacePublishAssemblyQualityLateStageBadCase(int count);

  /// No description provided for @shortVideoSpacePublishAssemblyQualityByStage.
  ///
  /// In en, this message translates to:
  /// **'By stage: {stages}'**
  String shortVideoSpacePublishAssemblyQualityByStage(String stages);

  /// No description provided for @shortVideoSpacePublishAssemblyQualityStageBadCase.
  ///
  /// In en, this message translates to:
  /// **'{stage} · Bad cases {count}'**
  String shortVideoSpacePublishAssemblyQualityStageBadCase(
    String stage,
    int count,
  );

  /// No description provided for @shortVideoSpacePublishAssemblyQualityTaskCenterHint.
  ///
  /// In en, this message translates to:
  /// **'In task center, you can filter quality review list by project; storyboard-level targets match assembly.'**
  String get shortVideoSpacePublishAssemblyQualityTaskCenterHint;

  /// No description provided for @shortVideoSpacePublishAssemblyMultiTrackEstimate.
  ///
  /// In en, this message translates to:
  /// **'Track usage estimate: Video 1 + Subtitle {subtitle} + Voiceover {voiceover} + BGM {bgm} = {total} tracks.'**
  String shortVideoSpacePublishAssemblyMultiTrackEstimate(
    int subtitle,
    int voiceover,
    int bgm,
    int total,
  );

  /// No description provided for @shortVideoSpacePublishAssemblyMaterialReady.
  ///
  /// In en, this message translates to:
  /// **'Materials ready: Video shots {video}/{totalShots}, Subtitle shots {subtitle}/{totalShots}, Voiceover shots {voiceover}/{totalShots}.'**
  String shortVideoSpacePublishAssemblyMaterialReady(
    int video,
    int subtitle,
    int voiceover,
    int totalShots,
  );

  /// No description provided for @shortVideoSpacePublishAssemblyDurationEstimate.
  ///
  /// In en, this message translates to:
  /// **'Duration estimate: Identified {known}/{total} shots, total duration ~{minutes} minutes.'**
  String shortVideoSpacePublishAssemblyDurationEstimate(
    int known,
    int total,
    String minutes,
  );

  /// No description provided for @shortVideoSpacePublishAssemblyExportDecisionProfessional.
  ///
  /// In en, this message translates to:
  /// **'Export decision: Exceeds limited multi-track boundary (>4 tracks or complex duration), recommend professional platform (Requirement 8.2).'**
  String get shortVideoSpacePublishAssemblyExportDecisionProfessional;

  /// No description provided for @shortVideoSpacePublishAssemblyExportDecisionLimited.
  ///
  /// In en, this message translates to:
  /// **'Export decision: Maintain limited multi-track (<=4 tracks) path, can continue export in current pipeline.'**
  String get shortVideoSpacePublishAssemblyExportDecisionLimited;

  /// No description provided for @shortVideoSpacePublishAssemblyBoundaryNote.
  ///
  /// In en, this message translates to:
  /// **'Boundary note: Space only covers \"video + single subtitle track + voiceover + BGM\" limited mixing, not a replacement for professional NLE.'**
  String get shortVideoSpacePublishAssemblyBoundaryNote;

  /// No description provided for @shortVideoSpacePublishAssemblyDetail.
  ///
  /// In en, this message translates to:
  /// **'Read-only editing desk: Shows shot order, duration, subtitle, voiceover, BGM and preview readiness summary; export blocking conclusions see \"Export Pre-check\" below.'**
  String get shortVideoSpacePublishAssemblyDetail;

  /// No description provided for @shortVideoSpacePublishExportCheckLoadingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Loading export pre-check…'**
  String get shortVideoSpacePublishExportCheckLoadingHeadline;

  /// No description provided for @shortVideoSpacePublishExportCheckLoadingDetail.
  ///
  /// In en, this message translates to:
  /// **'Aggregates storyboard blocking and warnings; quality gate observation fields are placeholder display only.'**
  String get shortVideoSpacePublishExportCheckLoadingDetail;

  /// No description provided for @shortVideoSpacePublishExportCheckUnavailableHeadline.
  ///
  /// In en, this message translates to:
  /// **'Export pre-check unavailable.'**
  String get shortVideoSpacePublishExportCheckUnavailableHeadline;

  /// No description provided for @shortVideoSpacePublishExportCheckUnavailableDetail.
  ///
  /// In en, this message translates to:
  /// **'Please refresh page later, or confirm storyboards in production workspace.'**
  String get shortVideoSpacePublishExportCheckUnavailableDetail;

  /// No description provided for @shortVideoSpacePublishExportCheckReadyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Server found no blocking issues (still need to confirm final in production).'**
  String get shortVideoSpacePublishExportCheckReadyHeadline;

  /// No description provided for @shortVideoSpacePublishExportCheckBlockingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Blocking items exist: Recommend completing fields in production workspace before export / final.'**
  String get shortVideoSpacePublishExportCheckBlockingHeadline;

  /// No description provided for @shortVideoSpacePublishExportCheckMetricStoryboards.
  ///
  /// In en, this message translates to:
  /// **'Storyboards'**
  String get shortVideoSpacePublishExportCheckMetricStoryboards;

  /// No description provided for @shortVideoSpacePublishExportCheckMetricBlocking.
  ///
  /// In en, this message translates to:
  /// **'Blocking'**
  String get shortVideoSpacePublishExportCheckMetricBlocking;

  /// No description provided for @shortVideoSpacePublishExportCheckMetricWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get shortVideoSpacePublishExportCheckMetricWarning;

  /// No description provided for @shortVideoSpacePublishExportCheckMetricExportable.
  ///
  /// In en, this message translates to:
  /// **'Exportable'**
  String get shortVideoSpacePublishExportCheckMetricExportable;

  /// No description provided for @shortVideoSpacePublishExportCheckMetricYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get shortVideoSpacePublishExportCheckMetricYes;

  /// No description provided for @shortVideoSpacePublishExportCheckMetricNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get shortVideoSpacePublishExportCheckMetricNo;

  /// No description provided for @shortVideoSpacePublishExportCheckQualityGateOff.
  ///
  /// In en, this message translates to:
  /// **'Quality gate: Off (no quality check).'**
  String get shortVideoSpacePublishExportCheckQualityGateOff;

  /// No description provided for @shortVideoSpacePublishExportCheckQualityGateWarnNoBadCase.
  ///
  /// In en, this message translates to:
  /// **'Quality gate: Warn mode - No pending review bad cases (export allowed).'**
  String get shortVideoSpacePublishExportCheckQualityGateWarnNoBadCase;

  /// No description provided for @shortVideoSpacePublishExportCheckQualityGateWarnWithBadCase.
  ///
  /// In en, this message translates to:
  /// **'Quality gate: Warn mode - {count} pending review bad cases (export allowed but recommend fixing).'**
  String shortVideoSpacePublishExportCheckQualityGateWarnWithBadCase(int count);

  /// No description provided for @shortVideoSpacePublishExportCheckQualityGateBlockEnforcedWithBadCase.
  ///
  /// In en, this message translates to:
  /// **'Quality gate: Block mode - {count} pending review bad cases (blocks export, must fix first).'**
  String shortVideoSpacePublishExportCheckQualityGateBlockEnforcedWithBadCase(
    int count,
  );

  /// No description provided for @shortVideoSpacePublishExportCheckQualityGateBlockNotEnforcedWithBadCase.
  ///
  /// In en, this message translates to:
  /// **'Quality gate: Block mode - {count} pending review bad cases (not enforced yet).'**
  String
  shortVideoSpacePublishExportCheckQualityGateBlockNotEnforcedWithBadCase(
    int count,
  );

  /// No description provided for @shortVideoSpacePublishExportCheckQualityGateBlockNoBadCase.
  ///
  /// In en, this message translates to:
  /// **'Quality gate: Block mode - No pending review bad cases (export allowed).'**
  String get shortVideoSpacePublishExportCheckQualityGateBlockNoBadCase;

  /// No description provided for @shortVideoSpacePublishExportCheckQualityGateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Quality gate: Unknown strategy \"{strategy}\".'**
  String shortVideoSpacePublishExportCheckQualityGateUnknown(String strategy);

  /// No description provided for @shortVideoSpacePublishExportCheckBlockingIssue.
  ///
  /// In en, this message translates to:
  /// **'Script #{scriptId} · Storyboard #{sbId}{sbIndex} · {label} · {detail}'**
  String shortVideoSpacePublishExportCheckBlockingIssue(
    int scriptId,
    int sbId,
    String sbIndex,
    String label,
    String detail,
  );

  /// No description provided for @shortVideoSpacePublishExportCheckDetailReady.
  ///
  /// In en, this message translates to:
  /// **'Blocking count is 0, indicating no hard blocking on server aggregation path (still subject to actual export pipeline).'**
  String get shortVideoSpacePublishExportCheckDetailReady;

  /// No description provided for @shortVideoSpacePublishExportCheckDetailBlocking.
  ///
  /// In en, this message translates to:
  /// **'Below lists some blocking items; for complete list, check each shot in production workspace.'**
  String get shortVideoSpacePublishExportCheckDetailBlocking;

  /// No description provided for @shortVideoSpacePublishCandidateLoadingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Loading project assets…'**
  String get shortVideoSpacePublishCandidateLoadingHeadline;

  /// No description provided for @shortVideoSpacePublishCandidateLoadingDetail.
  ///
  /// In en, this message translates to:
  /// **'Used to count candidate workflow: pending / linked / ignored (consistent with PATCH asset).'**
  String get shortVideoSpacePublishCandidateLoadingDetail;

  /// No description provided for @shortVideoSpacePublishCandidateUnavailableHeadline.
  ///
  /// In en, this message translates to:
  /// **'Candidate asset summary unavailable.'**
  String get shortVideoSpacePublishCandidateUnavailableHeadline;

  /// No description provided for @shortVideoSpacePublishCandidateUnavailableDetail.
  ///
  /// In en, this message translates to:
  /// **'Please refresh page later, or go to project area to view and edit assets.'**
  String get shortVideoSpacePublishCandidateUnavailableDetail;

  /// No description provided for @shortVideoSpacePublishCandidateNoTrackedHeadline.
  ///
  /// In en, this message translates to:
  /// **'No pending / linked / ignored marked yet; can PATCH candidate_status on shot candidates and other assets in project area.'**
  String get shortVideoSpacePublishCandidateNoTrackedHeadline;

  /// No description provided for @shortVideoSpacePublishCandidateTrackedHeadline.
  ///
  /// In en, this message translates to:
  /// **'Candidate status aggregated by project (counts below include unmarked):'**
  String get shortVideoSpacePublishCandidateTrackedHeadline;

  /// No description provided for @shortVideoSpacePublishCandidateDetail.
  ///
  /// In en, this message translates to:
  /// **'Project has {total} assets; counts aggregated by server in one go (no pagination). Can update via PATCH candidate_status in project area.'**
  String shortVideoSpacePublishCandidateDetail(int total);

  /// No description provided for @shortVideoSpacePublishPanelLoadingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Loading export check and publish domain…'**
  String get shortVideoSpacePublishPanelLoadingHeadline;

  /// No description provided for @shortVideoSpacePublishPanelLoadingDetail.
  ///
  /// In en, this message translates to:
  /// **'Backend path: `/api/v1/projects/:id/publish/*` (profiles / drafts / jobs).'**
  String get shortVideoSpacePublishPanelLoadingDetail;

  /// No description provided for @shortVideoSpacePublishPanelUnavailableHeadline.
  ///
  /// In en, this message translates to:
  /// **'Publish domain interface unavailable (database migration may not be executed yet).'**
  String get shortVideoSpacePublishPanelUnavailableHeadline;

  /// No description provided for @shortVideoSpacePublishPanelUnavailableExportGateMissing.
  ///
  /// In en, this message translates to:
  /// **'Export check data missing, publish panel shows placeholder only.'**
  String get shortVideoSpacePublishPanelUnavailableExportGateMissing;

  /// No description provided for @shortVideoSpacePublishPanelUnavailableExportGateNoBlocking.
  ///
  /// In en, this message translates to:
  /// **'Export check: Currently no blocking items.'**
  String get shortVideoSpacePublishPanelUnavailableExportGateNoBlocking;

  /// No description provided for @shortVideoSpacePublishPanelUnavailableExportGateBlocking.
  ///
  /// In en, this message translates to:
  /// **'Export check: Still {count} blocking items.'**
  String shortVideoSpacePublishPanelUnavailableExportGateBlocking(int count);

  /// No description provided for @shortVideoSpacePublishPanelUnavailableDetail.
  ///
  /// In en, this message translates to:
  /// **'Confirm Supabase has applied `app_publish_*` migrations then retry; Rust worker will digest publish job queue in background.'**
  String get shortVideoSpacePublishPanelUnavailableDetail;

  /// No description provided for @shortVideoSpacePublishPanelExportGateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Export check data unavailable; can still try creating publish draft and validate.'**
  String get shortVideoSpacePublishPanelExportGateUnavailable;

  /// No description provided for @shortVideoSpacePublishPanelExportGateReady.
  ///
  /// In en, this message translates to:
  /// **'Export check: No blocking items (**E13**: Can enter publish preparation from final pipeline).'**
  String get shortVideoSpacePublishPanelExportGateReady;

  /// No description provided for @shortVideoSpacePublishPanelExportGateBlocking.
  ///
  /// In en, this message translates to:
  /// **'Export check: Still {count} blocking items; can complete fields first then submit job.'**
  String shortVideoSpacePublishPanelExportGateBlocking(int count);

  /// No description provided for @shortVideoSpacePublishPanelHeadline.
  ///
  /// In en, this message translates to:
  /// **'Connected to publish API: {drafts} drafts · {jobs} jobs.'**
  String shortVideoSpacePublishPanelHeadline(int drafts, int jobs);

  /// No description provided for @shortVideoSpacePublishPanelCurrentDraft.
  ///
  /// In en, this message translates to:
  /// **'Current draft: {title}'**
  String shortVideoSpacePublishPanelCurrentDraft(String title);

  /// No description provided for @shortVideoSpacePublishPanelCurrentDraftUntitled.
  ///
  /// In en, this message translates to:
  /// **'Current draft: (Untitled)'**
  String get shortVideoSpacePublishPanelCurrentDraftUntitled;

  /// No description provided for @shortVideoSpacePublishPanelSelectDraftWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Please explicitly select draft (no longer auto-use first one)'**
  String get shortVideoSpacePublishPanelSelectDraftWarning;

  /// No description provided for @shortVideoSpacePublishPanelPrepareCheckOk.
  ///
  /// In en, this message translates to:
  /// **'Validation: ✓ Current draft meets placeholder rules (still needs real final reference to actually go live).'**
  String get shortVideoSpacePublishPanelPrepareCheckOk;

  /// No description provided for @shortVideoSpacePublishPanelPrepareCheckMultipleDrafts.
  ///
  /// In en, this message translates to:
  /// **'When multiple drafts exist, please select one in \"Current Operation Draft\" first, then show prepare-check.'**
  String get shortVideoSpacePublishPanelPrepareCheckMultipleDrafts;

  /// No description provided for @shortVideoSpacePublishPanelPrepareCheckSelectFirst.
  ///
  /// In en, this message translates to:
  /// **'After selecting draft, will show prepare-check validation result.'**
  String get shortVideoSpacePublishPanelPrepareCheckSelectFirst;

  /// No description provided for @shortVideoSpacePublishPanelPrepareCheckNoDraft.
  ///
  /// In en, this message translates to:
  /// **'No draft yet or prepare-check not completed.'**
  String get shortVideoSpacePublishPanelPrepareCheckNoDraft;

  /// No description provided for @shortVideoSpacePublishPanelDraftNoTitle.
  ///
  /// In en, this message translates to:
  /// **'(Untitled)'**
  String get shortVideoSpacePublishPanelDraftNoTitle;

  /// No description provided for @shortVideoSpacePublishPanelDraftMissingVideo.
  ///
  /// In en, this message translates to:
  /// **' · Missing video reference'**
  String get shortVideoSpacePublishPanelDraftMissingVideo;

  /// No description provided for @shortVideoSpacePublishPanelDraftScheduled.
  ///
  /// In en, this message translates to:
  /// **' · Scheduled {time}'**
  String shortVideoSpacePublishPanelDraftScheduled(String time);

  /// No description provided for @shortVideoSpacePublishPanelJobShortId.
  ///
  /// In en, this message translates to:
  /// **'{id}…'**
  String shortVideoSpacePublishPanelJobShortId(String id);

  /// No description provided for @shortVideoSpacePublishPanelJobError.
  ///
  /// In en, this message translates to:
  /// **' · {error}'**
  String shortVideoSpacePublishPanelJobError(String error);

  /// No description provided for @shortVideoSpacePublishPanelOverviewSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded jobs: {count}'**
  String shortVideoSpacePublishPanelOverviewSucceeded(int count);

  /// No description provided for @shortVideoSpacePublishPanelOverviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed/Partial failed: {count}'**
  String shortVideoSpacePublishPanelOverviewFailed(int count);

  /// No description provided for @shortVideoSpacePublishPanelOverviewAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation: {count}'**
  String shortVideoSpacePublishPanelOverviewAwaiting(int count);

  /// No description provided for @shortVideoSpacePublishPanelOverviewScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled drafts: {scheduled}/{total}'**
  String shortVideoSpacePublishPanelOverviewScheduled(int scheduled, int total);

  /// No description provided for @shortVideoSpacePublishPanelOverviewDeliveryModes.
  ///
  /// In en, this message translates to:
  /// **'Delivery modes: {modes}'**
  String shortVideoSpacePublishPanelOverviewDeliveryModes(String modes);

  /// No description provided for @shortVideoSpacePublishPanelOverviewPerformanceAlerts.
  ///
  /// In en, this message translates to:
  /// **'Low performance alerts: {count} (recommend troubleshooting in task center and rewriting copy)'**
  String shortVideoSpacePublishPanelOverviewPerformanceAlerts(int count);

  /// No description provided for @shortVideoSpacePublishPanelOverviewPerformanceAlert.
  ///
  /// In en, this message translates to:
  /// **'{platform} · Views {views} · Completion {rate}%'**
  String shortVideoSpacePublishPanelOverviewPerformanceAlert(
    String platform,
    int views,
    String rate,
  );

  /// No description provided for @shortVideoSpacePublishPanelOverviewAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit: {platform} · {status} · mode={mode}'**
  String shortVideoSpacePublishPanelOverviewAudit(
    String platform,
    String status,
    String mode,
  );

  /// No description provided for @shortVideoSpacePublishPanelOverviewTargetAutomation.
  ///
  /// In en, this message translates to:
  /// **'Target automation: {modes}'**
  String shortVideoSpacePublishPanelOverviewTargetAutomation(String modes);

  /// No description provided for @shortVideoSpacePublishPanelDetail.
  ///
  /// In en, this message translates to:
  /// **'Semi-auto jobs need \"Confirm\" when in `awaiting_confirmation`; worker skeleton will write `publish_attempts` placeholder success records.'**
  String get shortVideoSpacePublishPanelDetail;

  /// No description provided for @shortVideoSpaceProductionAssemblyExportCompleted.
  ///
  /// In en, this message translates to:
  /// **'Export completed.'**
  String get shortVideoSpaceProductionAssemblyExportCompleted;

  /// No description provided for @shortVideoSpaceProductionAssemblyExportNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Export not completed or cancelled.'**
  String get shortVideoSpaceProductionAssemblyExportNotCompleted;

  /// No description provided for @shortVideoSpaceProductionAssemblyExportStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Export start failed: {error}'**
  String shortVideoSpaceProductionAssemblyExportStartFailed(String error);

  /// No description provided for @shortVideoSpaceProductionAssemblyReplaceVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace current video version'**
  String get shortVideoSpaceProductionAssemblyReplaceVideoTitle;

  /// No description provided for @shortVideoSpaceProductionAssemblyVideoUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Video URL'**
  String get shortVideoSpaceProductionAssemblyVideoUrlLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblyVideoUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://...'**
  String get shortVideoSpaceProductionAssemblyVideoUrlHint;

  /// No description provided for @shortVideoSpaceProductionAssemblyCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shortVideoSpaceProductionAssemblyCancel;

  /// No description provided for @shortVideoSpaceProductionAssemblyWriteBackVersion.
  ///
  /// In en, this message translates to:
  /// **'Write back current version'**
  String get shortVideoSpaceProductionAssemblyWriteBackVersion;

  /// No description provided for @shortVideoSpaceProductionAssemblyShotDisabled.
  ///
  /// In en, this message translates to:
  /// **'Shot #{storyboardId} paused (cleared current video).'**
  String shortVideoSpaceProductionAssemblyShotDisabled(int storyboardId);

  /// No description provided for @shortVideoSpaceProductionAssemblyDisableFailed.
  ///
  /// In en, this message translates to:
  /// **'Pause failed: {error}'**
  String shortVideoSpaceProductionAssemblyDisableFailed(String error);

  /// No description provided for @shortVideoSpaceProductionAssemblyNoVideoUrl.
  ///
  /// In en, this message translates to:
  /// **'No available video URL, please enter replacement address first.'**
  String get shortVideoSpaceProductionAssemblyNoVideoUrl;

  /// No description provided for @shortVideoSpaceProductionAssemblyShotWriteBack.
  ///
  /// In en, this message translates to:
  /// **'Shot #{storyboardId} wrote back current video version.'**
  String shortVideoSpaceProductionAssemblyShotWriteBack(int storyboardId);

  /// No description provided for @shortVideoSpaceProductionAssemblyWriteBackFailed.
  ///
  /// In en, this message translates to:
  /// **'Write back failed: {error}'**
  String shortVideoSpaceProductionAssemblyWriteBackFailed(String error);

  /// No description provided for @shortVideoSpaceProductionAssemblyReorderPersisted.
  ///
  /// In en, this message translates to:
  /// **'Persisted shot reorder (wrote back timeline and shot numbers by script).'**
  String get shortVideoSpaceProductionAssemblyReorderPersisted;

  /// No description provided for @shortVideoSpaceProductionAssemblyReorderFailed.
  ///
  /// In en, this message translates to:
  /// **'Reorder persistence failed: {error}'**
  String shortVideoSpaceProductionAssemblyReorderFailed(String error);

  /// No description provided for @shortVideoSpaceProductionAssemblyShotAligned.
  ///
  /// In en, this message translates to:
  /// **'Shot #{storyboardId} aligned to {duration}s.'**
  String shortVideoSpaceProductionAssemblyShotAligned(
    int storyboardId,
    int duration,
  );

  /// No description provided for @shortVideoSpaceProductionAssemblyAlignFailed.
  ///
  /// In en, this message translates to:
  /// **'Duration alignment failed: {error}'**
  String shortVideoSpaceProductionAssemblyAlignFailed(String error);

  /// No description provided for @shortVideoSpaceProductionAssemblySubtitleExistsDurationMissing.
  ///
  /// In en, this message translates to:
  /// **'Subtitle exists, but duration not explicit (suggest aligning duration first).'**
  String get shortVideoSpaceProductionAssemblySubtitleExistsDurationMissing;

  /// No description provided for @shortVideoSpaceProductionAssemblyDurationSetSubtitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Duration is set, but subtitle is empty (possible subtitle track gap).'**
  String get shortVideoSpaceProductionAssemblyDurationSetSubtitleEmpty;

  /// No description provided for @shortVideoSpaceProductionAssemblySubtitleExistsDurationAbnormal.
  ///
  /// In en, this message translates to:
  /// **'Subtitle exists, but duration is abnormal (<=0).'**
  String get shortVideoSpaceProductionAssemblySubtitleExistsDurationAbnormal;

  /// No description provided for @shortVideoSpaceProductionAssemblySubtitleDurationNoMismatch.
  ///
  /// In en, this message translates to:
  /// **'No obvious subtitle-duration mismatch.'**
  String get shortVideoSpaceProductionAssemblySubtitleDurationNoMismatch;

  /// No description provided for @shortVideoSpaceProductionAssemblyBasicOpsTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic shot operations'**
  String get shortVideoSpaceProductionAssemblyBasicOpsTitle;

  /// No description provided for @shortVideoSpaceProductionAssemblyBasicOpsDescription.
  ///
  /// In en, this message translates to:
  /// **'Supports basic reordering (this panel view), enable/disable, and replace current video version.'**
  String get shortVideoSpaceProductionAssemblyBasicOpsDescription;

  /// No description provided for @shortVideoSpaceProductionAssemblyBasicOpsNote.
  ///
  /// In en, this message translates to:
  /// **'Enable/disable/replace writes back directly to J media slot; reorder is for this troubleshooting view only.'**
  String get shortVideoSpaceProductionAssemblyBasicOpsNote;

  /// No description provided for @shortVideoSpaceProductionAssemblyTotalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total finished duration: {seconds}s ({formatted})'**
  String shortVideoSpaceProductionAssemblyTotalDuration(
    int seconds,
    String formatted,
  );

  /// No description provided for @shortVideoSpaceProductionAssemblySaveReorder.
  ///
  /// In en, this message translates to:
  /// **'Save reorder'**
  String get shortVideoSpaceProductionAssemblySaveReorder;

  /// No description provided for @shortVideoSpaceProductionAssemblyUndoToOpen.
  ///
  /// In en, this message translates to:
  /// **'Undo to open time'**
  String get shortVideoSpaceProductionAssemblyUndoToOpen;

  /// No description provided for @shortVideoSpaceProductionAssemblyVoiceoverTasks.
  ///
  /// In en, this message translates to:
  /// **'Voiceover tasks'**
  String get shortVideoSpaceProductionAssemblyVoiceoverTasks;

  /// No description provided for @shortVideoSpaceProductionAssemblyClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get shortVideoSpaceProductionAssemblyClose;

  /// No description provided for @shortVideoSpaceProductionAssemblyNoShotsFiltered.
  ///
  /// In en, this message translates to:
  /// **'No shots under current filter conditions, try clearing search or relaxing criteria.'**
  String get shortVideoSpaceProductionAssemblyNoShotsFiltered;

  /// No description provided for @shortVideoSpaceProductionAssemblyScriptShotOrder.
  ///
  /// In en, this message translates to:
  /// **'Script #{scriptId} · Shot #{storyboardId} · Order {order}'**
  String shortVideoSpaceProductionAssemblyScriptShotOrder(
    int scriptId,
    int storyboardId,
    int order,
  );

  /// No description provided for @shortVideoSpaceProductionAssemblyStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Status: Paused'**
  String get shortVideoSpaceProductionAssemblyStatusPaused;

  /// No description provided for @shortVideoSpaceProductionAssemblyStatusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Status: Enabled ({kind})'**
  String shortVideoSpaceProductionAssemblyStatusEnabled(String kind);

  /// No description provided for @shortVideoSpaceProductionAssemblyDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration:'**
  String get shortVideoSpaceProductionAssemblyDurationLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblyDurationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get shortVideoSpaceProductionAssemblyDurationNotSet;

  /// No description provided for @shortVideoSpaceProductionAssemblySubtitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtitle:'**
  String get shortVideoSpaceProductionAssemblySubtitleLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblySubtitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get shortVideoSpaceProductionAssemblySubtitleEmpty;

  /// No description provided for @shortVideoSpaceProductionAssemblyVoiceoverScriptReady.
  ///
  /// In en, this message translates to:
  /// **'Voiceover script: ✓ Ready'**
  String get shortVideoSpaceProductionAssemblyVoiceoverScriptReady;

  /// No description provided for @shortVideoSpaceProductionAssemblyVoiceoverScriptNotReady.
  ///
  /// In en, this message translates to:
  /// **'Voiceover script: ✗ Not ready'**
  String get shortVideoSpaceProductionAssemblyVoiceoverScriptNotReady;

  /// No description provided for @shortVideoSpaceProductionAssemblyVoiceoverAssetReady.
  ///
  /// In en, this message translates to:
  /// **'Voiceover asset: ✓ Ready'**
  String get shortVideoSpaceProductionAssemblyVoiceoverAssetReady;

  /// No description provided for @shortVideoSpaceProductionAssemblyVoiceoverAssetNotReady.
  ///
  /// In en, this message translates to:
  /// **'Voiceover asset: ✗ Not ready'**
  String get shortVideoSpaceProductionAssemblyVoiceoverAssetNotReady;

  /// No description provided for @shortVideoSpaceProductionAssemblyVoiceoverStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Voiceover status:'**
  String get shortVideoSpaceProductionAssemblyVoiceoverStatusLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblyVoiceoverAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'Voiceover audio:'**
  String get shortVideoSpaceProductionAssemblyVoiceoverAudioLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblyVoiceoverErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Voiceover error:'**
  String get shortVideoSpaceProductionAssemblyVoiceoverErrorLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblyMismatchCheckLabel.
  ///
  /// In en, this message translates to:
  /// **'Mismatch check:'**
  String get shortVideoSpaceProductionAssemblyMismatchCheckLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblyMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get shortVideoSpaceProductionAssemblyMoveUp;

  /// No description provided for @shortVideoSpaceProductionAssemblyMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get shortVideoSpaceProductionAssemblyMoveDown;

  /// No description provided for @shortVideoSpaceProductionAssemblyEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get shortVideoSpaceProductionAssemblyEnable;

  /// No description provided for @shortVideoSpaceProductionAssemblyPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get shortVideoSpaceProductionAssemblyPause;

  /// No description provided for @shortVideoSpaceProductionAssemblyAlignDuration.
  ///
  /// In en, this message translates to:
  /// **'Align duration'**
  String get shortVideoSpaceProductionAssemblyAlignDuration;

  /// No description provided for @shortVideoSpaceProductionAssemblyReplaceVersion.
  ///
  /// In en, this message translates to:
  /// **'Replace current version'**
  String get shortVideoSpaceProductionAssemblyReplaceVersion;

  /// No description provided for @shortVideoSpaceProductionAssemblyGenerateVoiceover.
  ///
  /// In en, this message translates to:
  /// **'Generate voiceover'**
  String get shortVideoSpaceProductionAssemblyGenerateVoiceover;

  /// No description provided for @shortVideoSpaceProductionAssemblyPreviewVoiceover.
  ///
  /// In en, this message translates to:
  /// **'Preview voiceover'**
  String get shortVideoSpaceProductionAssemblyPreviewVoiceover;

  /// No description provided for @shortVideoSpaceProductionAssemblySingleShotDurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Single shot duration alignment'**
  String get shortVideoSpaceProductionAssemblySingleShotDurationTitle;

  /// No description provided for @shortVideoSpaceProductionAssemblySingleShotDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (seconds)'**
  String get shortVideoSpaceProductionAssemblySingleShotDurationLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblySingleShotDurationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 1~300'**
  String get shortVideoSpaceProductionAssemblySingleShotDurationHint;

  /// No description provided for @shortVideoSpaceProductionAssemblyAlignAndWriteBack.
  ///
  /// In en, this message translates to:
  /// **'Align and write back'**
  String get shortVideoSpaceProductionAssemblyAlignAndWriteBack;

  /// No description provided for @shortVideoSpaceProductionAssemblyAssemblyStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Assembly-level style adjustment'**
  String get shortVideoSpaceProductionAssemblyAssemblyStyleTitle;

  /// No description provided for @shortVideoSpaceProductionAssemblySubtitleStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtitle style subtitle_style'**
  String get shortVideoSpaceProductionAssemblySubtitleStyleLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblySubtitleStyleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. cinematic_cn_v2 (leave empty to fall back to default)'**
  String get shortVideoSpaceProductionAssemblySubtitleStyleHint;

  /// No description provided for @shortVideoSpaceProductionAssemblyBgmStrategyLabel.
  ///
  /// In en, this message translates to:
  /// **'BGM strategy bgm_strategy'**
  String get shortVideoSpaceProductionAssemblyBgmStrategyLabel;

  /// No description provided for @shortVideoSpaceProductionAssemblyBgmStrategyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. pulse_light (leave empty to fall back to default)'**
  String get shortVideoSpaceProductionAssemblyBgmStrategyHint;

  /// No description provided for @shortVideoSpaceProductionAssemblyStyleNote.
  ///
  /// In en, this message translates to:
  /// **'After saving, will write back D7 default configuration and refresh effective values in assembly snapshot.'**
  String get shortVideoSpaceProductionAssemblyStyleNote;

  /// No description provided for @shortVideoSpaceProductionAssemblySaveAndRefresh.
  ///
  /// In en, this message translates to:
  /// **'Save and refresh'**
  String get shortVideoSpaceProductionAssemblySaveAndRefresh;

  /// No description provided for @shortVideoSpaceProductionAssemblyStyleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated assembly-level defaults: subtitle {subtitle} · BGM {bgm}'**
  String shortVideoSpaceProductionAssemblyStyleUpdated(
    String subtitle,
    String bgm,
  );

  /// No description provided for @shortVideoSpaceProductionAssemblyStyleDefault.
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get shortVideoSpaceProductionAssemblyStyleDefault;

  /// No description provided for @shortVideoSpaceProductionAssemblyStyleWriteBackFailed.
  ///
  /// In en, this message translates to:
  /// **'Assembly style write back failed: {error}'**
  String shortVideoSpaceProductionAssemblyStyleWriteBackFailed(String error);

  /// No description provided for @shortVideoSpaceProductionAssemblyVoiceoverTaskCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Voiceover task center'**
  String get shortVideoSpaceProductionAssemblyVoiceoverTaskCenterTitle;

  /// No description provided for @shortVideoSpaceProductionAssemblyAllStatus.
  ///
  /// In en, this message translates to:
  /// **'All status'**
  String get shortVideoSpaceProductionAssemblyAllStatus;

  /// No description provided for @shortVideoSpaceProductionAssemblyRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get shortVideoSpaceProductionAssemblyRefresh;

  /// No description provided for @shortVideoSpaceProductionAssemblyGroupByShot.
  ///
  /// In en, this message translates to:
  /// **'Group by shot'**
  String get shortVideoSpaceProductionAssemblyGroupByShot;

  /// No description provided for @shortVideoSpaceProductionAssemblyBatchRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Batch retry failed ({count})'**
  String shortVideoSpaceProductionAssemblyBatchRetryFailed(int count);

  /// No description provided for @shortVideoSpaceProductionAssemblyFilterTaskIdScriptShot.
  ///
  /// In en, this message translates to:
  /// **'Filter: Task ID / Script # / Shot #'**
  String get shortVideoSpaceProductionAssemblyFilterTaskIdScriptShot;

  /// No description provided for @shortVideoSpaceProductionAssemblyTaskSummary.
  ///
  /// In en, this message translates to:
  /// **'Total {total} · queued {queued} · running {running} · succeeded {succeeded} · failed {failed} · cancelled {cancelled} · Showing {filtered}/{visible}'**
  String shortVideoSpaceProductionAssemblyTaskSummary(
    int total,
    int queued,
    int running,
    int succeeded,
    int failed,
    int cancelled,
    int filtered,
    int visible,
  );

  /// No description provided for @shortVideoSpaceProductionAssemblyNoVoiceoverTasks.
  ///
  /// In en, this message translates to:
  /// **'No voiceover tasks yet'**
  String get shortVideoSpaceProductionAssemblyNoVoiceoverTasks;

  /// No description provided for @shortVideoSpaceProductionAssemblyTaskEntry.
  ///
  /// In en, this message translates to:
  /// **'{prefix} {taskId} · Status {status}'**
  String shortVideoSpaceProductionAssemblyTaskEntry(
    String prefix,
    String taskId,
    String status,
  );

  /// No description provided for @shortVideoSpaceProductionAssemblyLatestTask.
  ///
  /// In en, this message translates to:
  /// **'Latest task'**
  String get shortVideoSpaceProductionAssemblyLatestTask;

  /// No description provided for @shortVideoSpaceProductionAssemblyTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get shortVideoSpaceProductionAssemblyTask;

  /// No description provided for @shortVideoSpaceProductionAssemblyTaskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Script #{scriptId} · Shot #{shotId}{audio}{error}'**
  String shortVideoSpaceProductionAssemblyTaskSubtitle(
    String scriptId,
    String shotId,
    String audio,
    String error,
  );

  /// No description provided for @shortVideoSpaceProductionAssemblyTaskSubtitleAudioReady.
  ///
  /// In en, this message translates to:
  /// **' · Audio ready'**
  String get shortVideoSpaceProductionAssemblyTaskSubtitleAudioReady;

  /// No description provided for @shortVideoSpaceProductionAssemblyTaskSubtitleError.
  ///
  /// In en, this message translates to:
  /// **' · Error: {error}'**
  String shortVideoSpaceProductionAssemblyTaskSubtitleError(String error);

  /// No description provided for @shortVideoSpaceProductionAssemblyPreviewAudio.
  ///
  /// In en, this message translates to:
  /// **'Preview audio'**
  String get shortVideoSpaceProductionAssemblyPreviewAudio;

  /// No description provided for @shortVideoSpaceProductionAssemblyCopyAudioLink.
  ///
  /// In en, this message translates to:
  /// **'Copy audio link'**
  String get shortVideoSpaceProductionAssemblyCopyAudioLink;

  /// No description provided for @shortVideoSpaceProductionAssemblyAudioLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Audio link copied'**
  String get shortVideoSpaceProductionAssemblyAudioLinkCopied;

  /// No description provided for @shortVideoSpaceProductionAssemblyCancelTask.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shortVideoSpaceProductionAssemblyCancelTask;

  /// No description provided for @shortVideoSpaceProductionAssemblyTaskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled voiceover task {taskId}'**
  String shortVideoSpaceProductionAssemblyTaskCancelled(String taskId);

  /// No description provided for @shortVideoSpaceProductionAssemblyCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancel failed: {error}'**
  String shortVideoSpaceProductionAssemblyCancelFailed(String error);

  /// No description provided for @shortVideoSpaceProductionAssemblyRetryTask.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get shortVideoSpaceProductionAssemblyRetryTask;

  /// No description provided for @shortVideoSpaceProductionAssemblyTaskRetried.
  ///
  /// In en, this message translates to:
  /// **'Retried, task {taskId} queued'**
  String shortVideoSpaceProductionAssemblyTaskRetried(String taskId);

  /// No description provided for @shortVideoSpaceProductionAssemblyRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed: {error}'**
  String shortVideoSpaceProductionAssemblyRetryFailed(String error);

  /// No description provided for @shortVideoSpaceProductionAssemblyBatchRetryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Batch retry completed: succeeded {succeeded}, failed {failed}'**
  String shortVideoSpaceProductionAssemblyBatchRetryCompleted(
    int succeeded,
    int failed,
  );

  /// No description provided for @shortVideoSpaceProductionAssemblyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String shortVideoSpaceProductionAssemblyLoadFailed(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
