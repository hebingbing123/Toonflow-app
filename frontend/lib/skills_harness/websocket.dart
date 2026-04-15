part of 'controller.dart';

extension SkillsHarnessWebSocketController on SkillsHarnessController {
  Future<WebSocketChannel?> openHarnessChannel(String token) async {
    await _wsSub?.cancel();
    await _ws?.sink.close();
    try {
      final uri = rustWebSocketUri(kApiBaseUrl, accessToken: token);
      final channel = WebSocketChannel.connect(uri);
      _ws = channel;
      _wsSub = channel.stream.listen(
        (message) => appendWsLog(message.toString()),
        onError: (Object e) {
          _setError('ws: $e');
          resetWsBusyFlags();
          _onWsLifecycleSettled();
          _publish();
        },
        onDone: () {
          resetWsBusyFlags();
          _onWsLifecycleSettled();
          _publish();
        },
      );
      return channel;
    } catch (e) {
      _setError(e.toString());
      resetWsBusyFlags();
      _publish();
      return null;
    }
  }

  Future<void> testWebSocket() async {
    final token = _accessToken;
    if (token == null) return;

    loadingWs = true;
    wsLog.clear();
    _setError(null);
    _publish();

    final channel = await openHarnessChannel(token);
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
  }

  Future<void> testHarnessToolWebSocket() async {
    final token = _accessToken;
    if (token == null) return;

    loadingWsHarness = true;
    wsLog.clear();
    _setError(null);
    _publish();

    final channel = await openHarnessChannel(token);
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
  }

  Future<void> testHarnessIsolatedEchoWebSocket() async {
    final token = _accessToken;
    if (token == null) return;

    loadingWsIsolatedEcho = true;
    wsLog.clear();
    _setError(null);
    _publish();

    final channel = await openHarnessChannel(token);
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
  }

  Future<void> testHarnessSkillsReadWebSocket() async {
    final token = _accessToken;
    if (token == null) return;

    loadingWsSkillsRead = true;
    wsLog.clear();
    _setError(null);
    _publish();

    final path = skillPathController.text.trim().isEmpty
        ? 'script_execution_script.md'
        : skillPathController.text.trim();
    final channel = await openHarnessChannel(token);
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
  }

  Future<void> testHarnessWasmProbeWebSocket() async {
    final token = _accessToken;
    if (token == null) return;

    loadingWsWasmProbe = true;
    wsLog.clear();
    _setError(null);
    _publish();

    final channel = await openHarnessChannel(token);
    if (channel == null) return;

    channel.sink.add(
      jsonEncode({
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': {'name': 'wasm.probe', 'arguments': <String, Object?>{}},
      }),
    );
  }

  Future<void> testHarnessAgentRunWebSocket() async {
    final token = _accessToken;
    if (token == null) return;

    loadingWsHarnessAgent = true;
    wsLog.clear();
    _setError(null);
    _publish();

    final channel = await openHarnessChannel(token);
    if (channel == null) return;

    channel.sink.add(
      jsonEncode({
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': {'isolation_key': 'flutter-harness-agent', 'project_id': 1},
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
  }
}
