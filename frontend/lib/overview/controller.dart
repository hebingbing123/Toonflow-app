import 'package:flutter/material.dart';

import '../rust_api.dart';

typedef OverviewErrorSink = void Function(String? error);

class OverviewController extends ChangeNotifier {
  OverviewController({required OverviewErrorSink onErrorChanged})
    : _onErrorChanged = onErrorChanged;

  final OverviewErrorSink _onErrorChanged;

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

  void _setErrorFromObject(Object error) {
    _setError(describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error));
  }

  Future<void> pingHealth() async {
    loadingHealth = true;
    _setError(null);
    healthBody = null;
    notifyListeners();
    try {
      final response = await fetchHealthV1();
      healthBody = 'status=${response.status} service=${response.service}';
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setErrorFromObject(e);
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
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setErrorFromObject(e);
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
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setErrorFromObject(e);
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
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setErrorFromObject(e);
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
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setErrorFromObject(e);
    } finally {
      loadingReady = false;
      notifyListeners();
    }
  }
}
