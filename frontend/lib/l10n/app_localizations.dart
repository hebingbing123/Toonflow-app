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
