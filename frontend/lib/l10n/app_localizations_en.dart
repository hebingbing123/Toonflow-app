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
}
