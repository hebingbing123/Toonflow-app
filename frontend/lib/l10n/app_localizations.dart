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
