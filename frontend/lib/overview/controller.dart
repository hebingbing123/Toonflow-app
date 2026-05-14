import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../rust_api.dart';

typedef OverviewErrorSink = void Function(String? error);
typedef OverviewL10nProvider = AppLocalizations? Function();

class OverviewController extends ChangeNotifier {
  OverviewController({
    required OverviewErrorSink onErrorChanged,
    required OverviewL10nProvider l10nProvider,
  }) : _onErrorChanged = onErrorChanged,
       _l10nProvider = l10nProvider;

  final OverviewErrorSink _onErrorChanged;
  final OverviewL10nProvider _l10nProvider;

  AppLocalizations? get _l10n => _l10nProvider();

  AppLocalizations get _l10nResolved =>
      _l10n ?? lookupAppLocalizations(const Locale('en'));

  bool loadingHealth = false;
  bool loadingHealthRoot = false;
  bool loadingPing = false;
  bool loadingVersion = false;
  bool loadingReady = false;
  String? healthBody;
  String? healthRootBody;
  String? pingBody;
  String? versionBody;
  String? readyBody;

  void reset() {
    loadingHealth = false;
    loadingHealthRoot = false;
    loadingPing = false;
    loadingVersion = false;
    loadingReady = false;
    healthBody = null;
    healthRootBody = null;
    pingBody = null;
    versionBody = null;
    readyBody = null;
    notifyListeners();
  }

  void _setError(String? error) {
    _onErrorChanged(error);
  }

  Future<void> pingHealth() async {
    loadingHealth = true;
    _setError(null);
    healthBody = null;
    notifyListeners();
    try {
      final response = await fetchHealthV1();
      healthBody = 'status=${response.status} service=${response.service}';
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      loadingHealth = false;
      notifyListeners();
    }
  }

  Future<void> pingHealthRoot() async {
    loadingHealthRoot = true;
    _setError(null);
    healthRootBody = null;
    notifyListeners();
    try {
      final response = await fetchHealthRoot();
      healthRootBody = 'status=${response.status} service=${response.service}';
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      loadingHealthRoot = false;
      notifyListeners();
    }
  }

  Future<void> pingPing() async {
    loadingPing = true;
    _setError(null);
    pingBody = null;
    notifyListeners();
    try {
      final response = await fetchPingV1();
      pingBody = 'ok=${response.ok}';
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      loadingPing = false;
      notifyListeners();
    }
  }

  Future<void> pingVersion() async {
    loadingVersion = true;
    _setError(null);
    versionBody = null;
    notifyListeners();
    try {
      final response = await fetchVersionV1();
      final parts = <String>[
        'service=${response.service}',
        'version=${response.version}',
      ];
      if (response.gitSha != null && response.gitSha!.isNotEmpty) {
        parts.add('git_sha=${response.gitSha}');
      }
      versionBody = parts.join(' · ');
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      loadingVersion = false;
      notifyListeners();
    }
  }

  Future<void> pingReady() async {
    loadingReady = true;
    _setError(null);
    readyBody = null;
    notifyListeners();
    try {
      final response = await fetchReadyV1();
      readyBody = 'status=${response.status}, database=${response.database}';
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      loadingReady = false;
      notifyListeners();
    }
  }
}
