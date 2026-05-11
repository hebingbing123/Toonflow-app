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
