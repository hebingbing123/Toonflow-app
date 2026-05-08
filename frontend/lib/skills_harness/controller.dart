import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../rust_api.dart';

part 'files.dart';
part 'websocket.dart';

typedef SkillsHarnessAccessTokenProvider = String? Function();
typedef SkillsHarnessErrorSink = void Function(String? error);
typedef SkillsHarnessWsMessageHandler = void Function(String raw);
typedef SkillsHarnessWsLifecycleHandler = void Function();

class SkillsHarnessController extends ChangeNotifier {
  SkillsHarnessController({
    required SkillsHarnessAccessTokenProvider accessTokenProvider,
    required SkillsHarnessErrorSink onErrorChanged,
    required SkillsHarnessWsMessageHandler onWsMessage,
    required SkillsHarnessWsLifecycleHandler onWsLifecycleSettled,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _onWsMessage = onWsMessage,
       _onWsLifecycleSettled = onWsLifecycleSettled;

  final SkillsHarnessAccessTokenProvider _accessTokenProvider;
  final SkillsHarnessErrorSink _onErrorChanged;
  final SkillsHarnessWsMessageHandler _onWsMessage;
  final SkillsHarnessWsLifecycleHandler _onWsLifecycleSettled;

  final TextEditingController skillPathController = TextEditingController(
    text: 'script_execution_script.md',
  );
  final TextEditingController skillContentController = TextEditingController(
    text: '# flutter probe\n',
  );

  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;

  bool loadingHarnessTools = false;
  bool loadingUserWasmValidate = false;
  bool loadingUserWasmPersist = false;
  bool loadingUserWasmList = false;
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
  String? userWasmValidateLine;
  String? userWasmPersistLine;
  String? userWasmListLine;
  String? skillsAggregateLine;
  String? skillsListSummary;
  String? skillMutationLine;

  String? get _accessToken => _accessTokenProvider();

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
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
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
          'validated=${r.validated}, size_bytes=${r.sizeBytes} (embedded probe)';
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
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
          'stored id=${r.id}, sha256=$shaShort, size=${r.sizeBytes}, at=${r.createdAt.toIso8601String()}';
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
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
        userWasmListLine = '0 stored module(s)';
      } else {
        final preview = r.items
            .take(5)
            .map((row) => '${row.id}:${row.sizeBytes}b')
            .join(', ');
        userWasmListLine =
            '${r.items.length} stored module(s) — $preview${r.items.length > 5 ? ', …' : ''}';
      }
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingUserWasmList = false;
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
          '${summary.markdownFileCount} md files, ${summary.totalBytes} bytes total';
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
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
          '${list.length} files; sample: ${sample.isEmpty ? '—' : sample}';
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingSkillList = false;
      _publish();
    }
  }

  Future<void> closeChannel() async {
    await _wsSub?.cancel();
    await _ws?.sink.close();
    _ws = null;
    _wsSub = null;
  }

  @override
  void dispose() {
    unawaited(closeChannel());
    skillPathController.dispose();
    skillContentController.dispose();
    super.dispose();
  }
}
