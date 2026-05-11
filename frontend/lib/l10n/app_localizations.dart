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
