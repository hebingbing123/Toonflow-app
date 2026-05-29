import 'package:flutter/material.dart';

import '../demo/product_demo_mode.dart';
import '../l10n/app_localizations.dart';
import '../platform/studio_optimistic_api_key.dart';
import '../platform/studio_optimistic_mutation.dart';
import '../rust_api.dart';

typedef ApiKeysAccessTokenProvider = String? Function();
typedef ApiKeysErrorSink = void Function(String? error);
typedef ApiKeysL10nProvider = AppLocalizations? Function();

class ApiKeysController extends ChangeNotifier {
  ApiKeysController({
    required ApiKeysAccessTokenProvider accessTokenProvider,
    required ApiKeysErrorSink onErrorChanged,
    required ApiKeysL10nProvider l10nProvider,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _l10nProvider = l10nProvider;

  final ApiKeysAccessTokenProvider _accessTokenProvider;
  final ApiKeysErrorSink _onErrorChanged;
  final ApiKeysL10nProvider _l10nProvider;

  bool loading = false;
  bool creating = false;
  String? busyKeyId;
  String? latestPlaintextToken;
  List<ApiKeyRecordV1> items = const <ApiKeyRecordV1>[];
  List<ApiKeyAuditRecordV1> auditItems = const <ApiKeyAuditRecordV1>[];
  int activeCount = 0;
  int revokedCount = 0;
  bool _primed = false;
  bool skipDemoApi = false;

  String? get _accessToken => _accessTokenProvider();
  AppLocalizations? get _l10n => _l10nProvider();

  AppLocalizations get _l10nResolved =>
      _l10n ?? lookupAppLocalizations(const Locale('en'));

  void _setError(String? value) => _onErrorChanged(value);

  Future<void> prime() async {
    if (_primed && items.isNotEmpty) {
      return;
    }
    _primed = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (skipDemoApi || ProductDemoMode.instance.shouldSkipLiveApi) {
      return;
    }
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
      reportRustOrDescribeApiError(
        error,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
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
      reportRustOrDescribeApiError(
        error,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
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
      if (token == null) {
        return;
      }
      final index = items.indexWhere((item) => item.id == apiKeyId);
      if (index < 0) {
        await revokeApiKeyV1(token, apiKeyId: apiKeyId, reason: reason);
        await refresh();
        return;
      }
      final row = items[index];
      final previousItems = items;
      final previousActive = activeCount;
      final previousRevoked = revokedCount;
      await studioRunOptimisticMutation(
        apply: () {
          items = studioReplaceApiKeyInList(
            items,
            studioApiKeyWithStatus(row, ApiKeyStatusV1.revoked),
          );
          final counts = studioApiKeyCountsAfterStatusChange(
            row: row,
            nextStatus: ApiKeyStatusV1.revoked,
            activeCount: activeCount,
            revokedCount: revokedCount,
          );
          activeCount = counts.$1;
          revokedCount = counts.$2;
          notifyListeners();
        },
        rollback: () {
          items = previousItems;
          activeCount = previousActive;
          revokedCount = previousRevoked;
          notifyListeners();
        },
        commit: () async {
          await revokeApiKeyV1(token, apiKeyId: apiKeyId, reason: reason);
          await refresh();
        },
      );
    });
  }

  Future<void> activateKey(String apiKeyId) async {
    await _runKeyMutation(apiKeyId, () async {
      final token = _accessToken;
      if (token == null) {
        return;
      }
      final index = items.indexWhere((item) => item.id == apiKeyId);
      if (index < 0) {
        await activateApiKeyV1(token, apiKeyId: apiKeyId);
        await refresh();
        return;
      }
      final row = items[index];
      final previousItems = items;
      final previousActive = activeCount;
      final previousRevoked = revokedCount;
      await studioRunOptimisticMutation(
        apply: () {
          items = studioReplaceApiKeyInList(
            items,
            studioApiKeyWithStatus(row, ApiKeyStatusV1.active),
          );
          final counts = studioApiKeyCountsAfterStatusChange(
            row: row,
            nextStatus: ApiKeyStatusV1.active,
            activeCount: activeCount,
            revokedCount: revokedCount,
          );
          activeCount = counts.$1;
          revokedCount = counts.$2;
          notifyListeners();
        },
        rollback: () {
          items = previousItems;
          activeCount = previousActive;
          revokedCount = previousRevoked;
          notifyListeners();
        },
        commit: () async {
          await activateApiKeyV1(token, apiKeyId: apiKeyId);
          await refresh();
        },
      );
    });
  }

  Future<void> deleteKey(String apiKeyId) async {
    await _runKeyMutation(apiKeyId, () async {
      final token = _accessToken;
      if (token == null) {
        return;
      }
      final index = items.indexWhere((item) => item.id == apiKeyId);
      if (index < 0) {
        await deleteApiKeyV1(token, apiKeyId: apiKeyId);
        await refresh();
        return;
      }
      final row = items[index];
      final previousItems = items;
      final previousActive = activeCount;
      final previousRevoked = revokedCount;
      await studioRunOptimisticMutation(
        apply: () {
          items = studioRemoveApiKeyById(items, apiKeyId);
          final counts = studioApiKeyCountsAfterDelete(
            row: row,
            activeCount: activeCount,
            revokedCount: revokedCount,
          );
          activeCount = counts.$1;
          revokedCount = counts.$2;
          notifyListeners();
        },
        rollback: () {
          items = previousItems;
          activeCount = previousActive;
          revokedCount = previousRevoked;
          notifyListeners();
        },
        commit: () async {
          await deleteApiKeyV1(token, apiKeyId: apiKeyId);
          await refresh();
        },
      );
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
      reportRustOrDescribeApiError(
        error,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      busyKeyId = null;
      notifyListeners();
    }
  }

  void clearLatestPlaintextToken() {
    latestPlaintextToken = null;
    notifyListeners();
  }

  void applyDemoPreview({
    required List<ApiKeyRecordV1> items,
    required List<ApiKeyAuditRecordV1> auditItems,
    required int activeCount,
    required int revokedCount,
  }) {
    skipDemoApi = true;
    loading = false;
    creating = false;
    busyKeyId = null;
    this.items = items;
    this.auditItems = auditItems;
    this.activeCount = activeCount;
    this.revokedCount = revokedCount;
    _primed = true;
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
