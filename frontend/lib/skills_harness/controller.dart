import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/layout_breakpoints.dart';
import '../design_system/studio_responsive_layout.dart';
import '../design_system/tokens.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../rust_api.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

part 'files.dart';
part 'websocket.dart';

typedef SkillsHarnessAccessTokenProvider = String? Function();
typedef SkillsHarnessErrorSink = void Function(String? error);
typedef SkillsHarnessWsMessageHandler = void Function(String raw);
typedef SkillsHarnessWsLifecycleHandler = void Function();
typedef SkillsHarnessWsConnectionHandler = void Function(bool connected);
typedef SkillsHarnessL10nProvider = AppLocalizations? Function();

class SkillsHarnessController extends ChangeNotifier {
  SkillsHarnessController({
    required SkillsHarnessAccessTokenProvider accessTokenProvider,
    required SkillsHarnessErrorSink onErrorChanged,
    required SkillsHarnessL10nProvider l10nProvider,
    required SkillsHarnessWsMessageHandler onWsMessage,
    required SkillsHarnessWsLifecycleHandler onWsLifecycleSettled,
    required SkillsHarnessWsConnectionHandler onWsConnectionChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _l10nProvider = l10nProvider,
       _onWsMessage = onWsMessage,
       _onWsLifecycleSettled = onWsLifecycleSettled,
       _onWsConnectionChanged = onWsConnectionChanged;

  final SkillsHarnessAccessTokenProvider _accessTokenProvider;
  final SkillsHarnessErrorSink _onErrorChanged;
  final SkillsHarnessL10nProvider _l10nProvider;
  final SkillsHarnessWsMessageHandler _onWsMessage;
  final SkillsHarnessWsLifecycleHandler _onWsLifecycleSettled;
  final SkillsHarnessWsConnectionHandler _onWsConnectionChanged;

  final TextEditingController skillPathController = TextEditingController(
    text: 'script_execution_script.md',
  );
  final TextEditingController skillContentController = TextEditingController(
    text: '# flutter probe\n',
  );

  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _wsReconnectTimer;
  bool _maintainSessionWs = false;

  bool loadingHarnessTools = false;
  bool loadingUserWasmValidate = false;
  bool loadingUserWasmPersist = false;
  bool loadingUserWasmList = false;
  bool loadingUserWasmRevoke = false;
  bool loadingSkillsSummary = false;
  bool loadingSkillList = false;
  bool loadingSkillPreview = false;
  bool loadingSkillVersions = false;
  bool loadingSkillPut = false;
  bool loadingSkillPost = false;
  bool loadingSkillDelete = false;
  bool rollingBackSkillVersion = false;
  bool loadingWs = false;
  bool loadingWsHarness = false;
  bool loadingWsIsolatedEcho = false;
  bool loadingWsWasmProbe = false;
  bool loadingWsHarnessAgent = false;
  bool loadingWsSkillsRead = false;
  final List<String> wsLog = [];
  String? harnessToolsLine;

  void applyDemoPreview({required List<String> lines}) {
    wsLog
      ..clear()
      ..addAll(lines);
    notifyListeners();
  }
  String? userWasmValidateLine;
  String? userWasmPersistLine;
  String? userWasmListLine;
  String? userWasmRevokeTargetId;
  String? userWasmRevokeLine;
  String? skillsAggregateLine;
  String? skillsListSummary;
  String? skillMutationLine;

  String? get _accessToken => _accessTokenProvider();
  AppLocalizations? get _l10n => _l10nProvider();

  AppLocalizations get _l10nResolved =>
      _l10n ?? lookupAppLocalizations(const Locale('en'));

  bool get wsConnected => _ws != null;

  Future<void> startAutoSessionWs() async {
    _maintainSessionWs = true;
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    await ensureHarnessChannel(token);
  }

  void stopAutoSessionWs() {
    _maintainSessionWs = false;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
  }

  void scheduleSessionWsReconnect() {
    if (!_maintainSessionWs || _wsReconnectTimer != null || wsConnected) {
      return;
    }
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    _wsReconnectTimer = Timer(const Duration(seconds: 2), () async {
      _wsReconnectTimer = null;
      if (!_maintainSessionWs || wsConnected) {
        return;
      }
      final latestToken = _accessToken;
      if (latestToken == null || latestToken.isEmpty) {
        return;
      }
      await ensureHarnessChannel(latestToken);
    });
  }

  bool get wsProbesBusy =>
      loadingWs ||
      loadingWsHarness ||
      loadingWsIsolatedEcho ||
      loadingWsWasmProbe ||
      loadingWsHarnessAgent ||
      loadingWsSkillsRead;

  void reset() {
    resetWsBusyFlags();
    wsLog.clear();
    harnessToolsLine = null;
    userWasmValidateLine = null;
    userWasmPersistLine = null;
    userWasmListLine = null;
    userWasmRevokeTargetId = null;
    userWasmRevokeLine = null;
    skillsAggregateLine = null;
    skillsListSummary = null;
    skillMutationLine = null;
    notifyListeners();
  }

  void resetWsBusyFlags() {
    loadingWs = false;
    loadingWsHarness = false;
    loadingWsIsolatedEcho = false;
    loadingWsWasmProbe = false;
    loadingWsHarnessAgent = false;
    loadingWsSkillsRead = false;
  }

  void clearToolProbeFlags() {
    loadingWsHarness = false;
    loadingWsIsolatedEcho = false;
    loadingWsWasmProbe = false;
    loadingWsSkillsRead = false;
    notifyListeners();
  }

  void clearAgentProbeFlags() {
    loadingWs = false;
    loadingWsHarnessAgent = false;
    notifyListeners();
  }

  void appendWsLog(String raw) {
    const maxChars = 12000;
    final line = raw.length > maxChars
        ? '${raw.substring(0, maxChars)}… (+${raw.length - maxChars} chars)'
        : raw;
    _onWsMessage(raw);
    wsLog.insert(0, line);
    if (wsLog.length > 16) {
      wsLog.removeLast();
    }
    notifyListeners();
  }

  void _setError(String? error) {
    _onErrorChanged(error);
  }

  void _setErrorFromException(Object error) {
    _setError(describeUserVisibleApiError(_l10nResolved, error));
  }

  void publishWsConnection(bool connected) {
    _onWsConnectionChanged(connected);
  }

  void _publish() {
    notifyListeners();
  }

  Future<void> loadHarnessTools() async {
    final token = _accessToken;
    if (token == null) return;
    loadingHarnessTools = true;
    _setError(null);
    harnessToolsLine = null;
    _publish();
    try {
      final r = await fetchHarnessTools(token);
      harnessToolsLine = r.tools
          .map((t) => '${t.name}: ${t.description}')
          .join('\n');
    } catch (e) {
      _setErrorFromException(e);
    } finally {
      loadingHarnessTools = false;
      _publish();
    }
  }

  Future<void> validateUserWasmProbe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingUserWasmValidate = true;
    _setError(null);
    userWasmValidateLine = null;
    _publish();
    try {
      final r = await validateHarnessUserWasm(token, kHarnessEmbeddedProbeWasm);
      userWasmValidateLine =
          _l10nResolved.skillsHarnessValidateResult(
            '${r.validated}',
            r.sizeBytes,
          );
    } catch (e) {
      _setErrorFromException(e);
    } finally {
      loadingUserWasmValidate = false;
      _publish();
    }
  }

  Future<void> persistUserWasmProbe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingUserWasmPersist = true;
    _setError(null);
    userWasmPersistLine = null;
    _publish();
    try {
      final r = await persistHarnessUserWasm(token, kHarnessEmbeddedProbeWasm);
      final shaShort = r.wasmSha256Hex.length > 12
          ? '${r.wasmSha256Hex.substring(0, 12)}…'
          : r.wasmSha256Hex;
      userWasmPersistLine =
          _l10nResolved.skillsHarnessPersistResult(
            r.id,
            shaShort,
            r.sizeBytes,
            r.createdAt.toIso8601String(),
          );
      userWasmRevokeTargetId = r.id;
    } catch (e) {
      _setErrorFromException(e);
    } finally {
      loadingUserWasmPersist = false;
      _publish();
    }
  }

  Future<void> loadUserWasmList() async {
    final token = _accessToken;
    if (token == null) return;
    loadingUserWasmList = true;
    _setError(null);
    userWasmListLine = null;
    _publish();
    try {
      final r = await listHarnessUserWasm(token);
      if (r.items.isEmpty) {
        userWasmListLine =
            _l10nResolved.skillsHarnessStoredModulesEmpty;
        userWasmRevokeTargetId = null;
      } else {
        final preview = r.items
            .take(5)
            .map((row) => '${row.id}:${row.sizeBytes}b')
            .join(', ');
        userWasmListLine =
            _l10nResolved.skillsHarnessStoredModulesSummary(
              r.items.length,
              preview,
              r.items.length > 5 ? ', …' : '',
            );
        userWasmRevokeTargetId = r.items.first.id;
      }
    } catch (e) {
      _setErrorFromException(e);
    } finally {
      loadingUserWasmList = false;
      _publish();
    }
  }

  Future<void> revokeUserWasmProbe() async {
    final token = _accessToken;
    final id = userWasmRevokeTargetId;
    if (token == null || id == null) return;
    loadingUserWasmRevoke = true;
    _setError(null);
    userWasmRevokeLine = null;
    _publish();
    try {
      final r = await revokeHarnessUserWasm(token, id);
      userWasmRevokeLine =
          _l10nResolved.skillsHarnessRevokeResult(
            r.id,
            r.revokedAt.toIso8601String(),
          );
      userWasmRevokeTargetId = null;
    } catch (e) {
      _setErrorFromException(e);
    } finally {
      loadingUserWasmRevoke = false;
      _publish();
    }
  }

  /// Revoke the currently selected user WASM and then reload the list so
  /// the UI can confirm the revoked item disappears.
  Future<void> revokeUserWasmProbeAndReloadList() async {
    final token = _accessToken;
    final id = userWasmRevokeTargetId;
    if (token == null || id == null) return;
    if (loadingUserWasmRevoke || loadingUserWasmList) return;

    loadingUserWasmRevoke = true;
    _setError(null);
    userWasmRevokeLine = null;
    _publish();

    try {
      final r = await revokeHarnessUserWasm(token, id);
      userWasmRevokeLine =
          _l10nResolved.skillsHarnessRevokeResult(
            r.id,
            r.revokedAt.toIso8601String(),
          );

      // Reload so the list filtering (`revoked_at IS NULL`) is visibly verified.
      await loadUserWasmList();
    } catch (e) {
      _setErrorFromException(e);
    } finally {
      loadingUserWasmRevoke = false;
      _publish();
    }
  }

  Future<void> loadSkillsAggregate() async {
    final token = _accessToken;
    if (token == null) return;
    loadingSkillsSummary = true;
    _setError(null);
    skillsAggregateLine = null;
    _publish();
    try {
      final summary = await fetchSkillsSummary(token);
      skillsAggregateLine =
          _l10nResolved.skillsHarnessAggregateResult(
            summary.scope,
            summary.markdownFileCount,
            summary.totalBytes,
          );
    } catch (e) {
      _setErrorFromException(e);
    } finally {
      loadingSkillsSummary = false;
      _publish();
    }
  }

  Future<void> loadSkillList() async {
    final token = _accessToken;
    if (token == null) return;
    loadingSkillList = true;
    _setError(null);
    skillsListSummary = null;
    _publish();
    try {
      final list = await fetchSkills(token);
      final sample = list.take(5).map((m) => m.path).join(', ');
      skillsListSummary =
          _l10nResolved.skillsHarnessListSummary(
            list.length,
            sample.isEmpty
                ? _l10nResolved.skillsHarnessListSampleEmpty
                : sample,
          );
    } catch (e) {
      _setErrorFromException(e);
    } finally {
      loadingSkillList = false;
      _publish();
    }
  }

  Future<void> closeChannel() async {
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    await _wsSub?.cancel();
    await _ws?.sink.close();
    _ws = null;
    _wsSub = null;
    publishWsConnection(false);
  }

  @override
  void dispose() {
    unawaited(closeChannel());
    skillPathController.dispose();
    skillContentController.dispose();
    super.dispose();
  }
}
