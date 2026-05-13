import 'package:flutter/material.dart';

import '../rust_api.dart';

typedef ApiKeysAccessTokenProvider = String? Function();
typedef ApiKeysErrorSink = void Function(String? error);

class ApiKeysController extends ChangeNotifier {
  ApiKeysController({
    required ApiKeysAccessTokenProvider accessTokenProvider,
    required ApiKeysErrorSink onErrorChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged;

  final ApiKeysAccessTokenProvider _accessTokenProvider;
  final ApiKeysErrorSink _onErrorChanged;

  bool loading = false;
  bool creating = false;
  String? busyKeyId;
  String? latestPlaintextToken;
  List<ApiKeyRecordV1> items = const <ApiKeyRecordV1>[];
  List<ApiKeyAuditRecordV1> auditItems = const <ApiKeyAuditRecordV1>[];
  int activeCount = 0;
  int revokedCount = 0;
  bool _primed = false;

  String? get _accessToken => _accessTokenProvider();

  void _setError(String? value) => _onErrorChanged(value);

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
      final results = await Future.wait<dynamic>([
        fetchApiKeysV1(token),
        fetchApiKeyAuditV1(token),
      ]);
      final list = results[0] as ApiKeyListResponseV1;
      final audit = results[1] as ApiKeyAuditListResponseV1;
      items = list.items;
      activeCount = list.activeCount;
      revokedCount = list.revokedCount;
      auditItems = audit.items;
    } catch (error) {
      reportRustOrDescribeApiError(error, onErrorChanged: _setError);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> createKey({
    required String displayName,
    required ApiKeyScopeV1 scope,
    String? expiresAt,
  }) async {
    final token = _accessToken;
    if (token == null || creating) {
      return;
    }
    creating = true;
    _setError(null);
    notifyListeners();
    try {
      final created = await createApiKeyV1(
        token,
        displayName: displayName,
        scope: scope,
        expiresAt: expiresAt,
      );
      latestPlaintextToken = created.plaintextToken;
      await refresh();
    } catch (error) {
      reportRustOrDescribeApiError(error, onErrorChanged: _setError);
    } finally {
      creating = false;
      notifyListeners();
    }
  }

  Future<void> rotateKey(String apiKeyId, {String? expiresAt}) async {
    await _runKeyMutation(apiKeyId, () async {
      final token = _accessToken;
      if (token == null) return;
      final rotated = await rotateApiKeyV1(
        token,
        apiKeyId: apiKeyId,
        expiresAtAction: expiresAt == null
            ? ApiKeyExpiresAtActionV1.preserve
            : expiresAt.isEmpty
            ? ApiKeyExpiresAtActionV1.clear
            : ApiKeyExpiresAtActionV1.set,
        expiresAt: expiresAt,
      );
      latestPlaintextToken = rotated.plaintextToken;
      await refresh();
    });
  }

  Future<void> revokeKey(String apiKeyId, {String? reason}) async {
    await _runKeyMutation(apiKeyId, () async {
      final token = _accessToken;
      if (token == null) return;
      await revokeApiKeyV1(token, apiKeyId: apiKeyId, reason: reason);
      await refresh();
    });
  }

  Future<void> activateKey(String apiKeyId) async {
    await _runKeyMutation(apiKeyId, () async {
      final token = _accessToken;
      if (token == null) return;
      await activateApiKeyV1(token, apiKeyId: apiKeyId);
      await refresh();
    });
  }

  Future<void> deleteKey(String apiKeyId) async {
    await _runKeyMutation(apiKeyId, () async {
      final token = _accessToken;
      if (token == null) return;
      await deleteApiKeyV1(token, apiKeyId: apiKeyId);
      await refresh();
    });
  }

  Future<void> _runKeyMutation(
    String apiKeyId,
    Future<void> Function() action,
  ) async {
    if (busyKeyId != null) {
      return;
    }
    busyKeyId = apiKeyId;
    _setError(null);
    notifyListeners();
    try {
      await action();
    } catch (error) {
      reportRustOrDescribeApiError(error, onErrorChanged: _setError);
    } finally {
      busyKeyId = null;
      notifyListeners();
    }
  }

  void clearLatestPlaintextToken() {
    latestPlaintextToken = null;
    notifyListeners();
  }

  void reset() {
    loading = false;
    creating = false;
    busyKeyId = null;
    latestPlaintextToken = null;
    items = const <ApiKeyRecordV1>[];
    auditItems = const <ApiKeyAuditRecordV1>[];
    activeCount = 0;
    revokedCount = 0;
    _primed = false;
    notifyListeners();
  }
}
