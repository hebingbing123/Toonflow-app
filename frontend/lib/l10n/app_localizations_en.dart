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
}
