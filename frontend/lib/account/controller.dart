import 'package:flutter/material.dart';

import '../rust_api.dart';
import 'download_stub.dart'
    if (dart.library.html) 'download_web.dart'
    if (dart.library.io) 'download_io.dart';

typedef AccountAccessTokenProvider = String? Function();
typedef AccountErrorSink = void Function(String? error);

class AccountController extends ChangeNotifier {
  AccountController({
    required AccountAccessTokenProvider accessTokenProvider,
    required AccountErrorSink onErrorChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged;

  final AccountAccessTokenProvider _accessTokenProvider;
  final AccountErrorSink _onErrorChanged;

  bool loading = false;
  bool creatingExport = false;
  bool deletingAccount = false;
  bool includeAuditLogs = false;
  bool includeNotifications = true;
  int activeCount = 0;
  String? lastSavedPath;
  AccountDeleteResponseV1? lastDeleteResponse;
  List<AccountExportJobRecordV1> items = const <AccountExportJobRecordV1>[];
  final Set<String> _downloadingJobIds = <String>{};
  bool _primed = false;

  String? get _accessToken => _accessTokenProvider();

  bool isDownloading(String jobId) => _downloadingJobIds.contains(jobId);

  void _setError(String? error) {
    _onErrorChanged(error);
  }

  Future<void> prime() async {
    if (_primed && items.isNotEmpty) {
      return;
    }
    _primed = true;
    await refresh();
  }

  Future<void> refresh() async {
    final token = _accessToken;
    if (token == null) {
      reset();
      return;
    }
    loading = true;
    _setError(null);
    notifyListeners();
    try {
      final response = await fetchAccountExportsV1(token);
      items = response.items;
      activeCount = response.activeCount;
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError(describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error));
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> requestExport() async {
    final token = _accessToken;
    if (token == null || creatingExport) {
      return;
    }
    creatingExport = true;
    _setError(null);
    notifyListeners();
    try {
      final created = await createAccountExportV1(
        token,
        includeAuditLogs: includeAuditLogs,
        includeNotifications: includeNotifications,
      );
      items = <AccountExportJobRecordV1>[
        created,
        ...items.where((item) => item.id != created.id),
      ];
      activeCount += created.status == 'queued' || created.status == 'running'
          ? 1
          : 0;
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError(describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error));
    } finally {
      creatingExport = false;
      notifyListeners();
    }
  }

  Future<String?> downloadExport(AccountExportJobRecordV1 item) async {
    final token = _accessToken;
    if (token == null || _downloadingJobIds.contains(item.id)) {
      return null;
    }
    _downloadingJobIds.add(item.id);
    _setError(null);
    notifyListeners();
    try {
      final payload = await downloadAccountExportV1(
        token,
        jobId: item.id,
        fallbackFileName: item.fileName,
      );
      final savedPath = await saveAccountExportToDevice(
        payload.bytes,
        payload.fileName,
      );
      lastSavedPath = savedPath;
      return savedPath;
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError(describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error));
    } finally {
      _downloadingJobIds.remove(item.id);
      notifyListeners();
    }
    return null;
  }

  Future<AccountDeleteResponseV1?> deleteAccount({
    required String confirmPhrase,
    required bool acknowledgeIrreversible,
  }) async {
    final token = _accessToken;
    if (token == null || deletingAccount) {
      return null;
    }
    deletingAccount = true;
    _setError(null);
    notifyListeners();
    try {
      final response = await deleteAccountV1(
        token,
        confirmPhrase: confirmPhrase,
        acknowledgeIrreversible: acknowledgeIrreversible,
      );
      lastDeleteResponse = response;
      return response;
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError(describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error));
    } finally {
      deletingAccount = false;
      notifyListeners();
    }
    return null;
  }

  void setIncludeAuditLogs(bool value) {
    if (includeAuditLogs == value) {
      return;
    }
    includeAuditLogs = value;
    notifyListeners();
  }

  void setIncludeNotifications(bool value) {
    if (includeNotifications == value) {
      return;
    }
    includeNotifications = value;
    notifyListeners();
  }

  void reset() {
    loading = false;
    creatingExport = false;
    deletingAccount = false;
    activeCount = 0;
    lastSavedPath = null;
    lastDeleteResponse = null;
    items = const <AccountExportJobRecordV1>[];
    _downloadingJobIds.clear();
    _primed = false;
    notifyListeners();
  }
}
