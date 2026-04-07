// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageSkillsHarnessWebSocket on _HomePageState {
  void _resetWsBusyFlags() {
    _loadingWs = false;
    _loadingWsHarness = false;
    _loadingWsIsolatedEcho = false;
    _loadingWsWasmProbe = false;
    _loadingWsHarnessAgent = false;
    _loadingWsSkillsRead = false;
  }

  Future<WebSocketChannel?> _openHarnessChannel(String token) async {
    _wsSub?.cancel();
    await _ws?.sink.close();

    try {
      final uri = rustWebSocketUri(kApiBaseUrl, accessToken: token);
      final channel = WebSocketChannel.connect(uri);
      _ws = channel;
      _wsSub = channel.stream.listen(
        (message) => _appendWsLog(message.toString()),
        onError: (Object e) {
          if (mounted) setState(() => _error = 'ws: $e');
        },
        onDone: () {
          if (mounted) {
            setState(_resetWsBusyFlags);
          }
        },
      );
      return channel;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _resetWsBusyFlags();
        });
      }
      return null;
    }
  }

  Future<void> _testWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    setState(() {
      _loadingWs = true;
      _wsLog.clear();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;

    channel.sink.add(
      jsonEncode({
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': {'isolation_key': 'flutter-dev', 'project_id': 1},
      }),
    );
    channel.sink.add(
      jsonEncode({
        'type': 'agent.chat.send',
        'schema_version': 1,
        'payload': {'content': 'hello from Flutter'},
      }),
    );

    if (mounted) setState(() => _loadingWs = false);
  }

  Future<void> _testHarnessToolWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    setState(() {
      _loadingWsHarness = true;
      _wsLog.clear();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;

    channel.sink.add(
      jsonEncode({
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': {
          'name': 'echo',
          'arguments': {
            'source': 'flutter',
            'probe': 'harness.tool.invoke',
            'at': DateTime.now().toUtc().toIso8601String(),
          },
        },
      }),
    );

    if (mounted) setState(() => _loadingWsHarness = false);
  }

  Future<void> _testHarnessIsolatedEchoWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    setState(() {
      _loadingWsIsolatedEcho = true;
      _wsLog.clear();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;

    channel.sink.add(
      jsonEncode({
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': {
          'name': 'isolated.echo',
          'arguments': {
            'source': 'flutter',
            'probe': 'harness.tool.invoke (isolated)',
            'at': DateTime.now().toUtc().toIso8601String(),
          },
        },
      }),
    );

    if (mounted) setState(() => _loadingWsIsolatedEcho = false);
  }

  Future<void> _testHarnessSkillsReadWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    setState(() {
      _loadingWsSkillsRead = true;
      _wsLog.clear();
      _error = null;
    });

    final path = _skillPathCtrl.text.trim().isEmpty
        ? 'script_execution_script.md'
        : _skillPathCtrl.text.trim();
    final channel = await _openHarnessChannel(token);
    if (channel == null) return;

    channel.sink.add(
      jsonEncode({
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': {
          'name': 'skills.read',
          'arguments': {'path': path},
        },
      }),
    );

    if (mounted) setState(() => _loadingWsSkillsRead = false);
  }

  Future<void> _testHarnessWasmProbeWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    setState(() {
      _loadingWsWasmProbe = true;
      _wsLog.clear();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;

    channel.sink.add(
      jsonEncode({
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': {
          'name': 'wasm.probe',
          'arguments': <String, Object?>{},
        },
      }),
    );

    if (mounted) setState(() => _loadingWsWasmProbe = false);
  }

  Future<void> _testHarnessAgentRunWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    setState(() {
      _loadingWsHarnessAgent = true;
      _wsLog.clear();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;

    channel.sink.add(
      jsonEncode({
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': {
          'isolation_key': 'flutter-harness-agent',
          'project_id': 1,
        },
      }),
    );
    channel.sink.add(
      jsonEncode({
        'type': 'harness.agent.run',
        'schema_version': 1,
        'payload': {
          'content':
              'Call the wasm.probe tool once with empty object arguments. Reply with only the numeric value from the tool result.',
          'max_tool_rounds': 6,
        },
      }),
    );

    if (mounted) setState(() => _loadingWsHarnessAgent = false);
  }
}
