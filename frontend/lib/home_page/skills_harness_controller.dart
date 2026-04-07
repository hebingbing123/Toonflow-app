// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageSkillsHarnessController on _HomePageState {
  Future<void> _loadHarnessTools() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingHarnessTools = true;
      _error = null;
      _harnessToolsLine = null;
    });
    try {
      final r = await fetchHarnessTools(token);
      if (!mounted) return;
      setState(() {
        _harnessToolsLine = r.tools
            .map((t) => '${t.name}: ${t.description}')
            .join('\n');
        _loadingHarnessTools = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHarnessTools = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHarnessTools = false;
      });
    }
  }

  Future<void> _loadSkillsAggregate() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingSkillsSummary = true;
      _error = null;
      _skillsAggregateLine = null;
    });
    try {
      final s = await fetchSkillsSummary(token);
      if (!mounted) return;
      setState(() {
        _skillsAggregateLine =
            '${s.markdownFileCount} md files, ${s.totalBytes} bytes total';
        _loadingSkillsSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsSummary = false;
      });
    }
  }

  Future<void> _loadSkillList() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingSkillList = true;
      _error = null;
      _skillsListSummary = null;
    });
    try {
      final list = await fetchSkills(token);
      if (!mounted) return;
      final sample = list.take(5).map((m) => m.path).join(', ');
      setState(() {
        _skillsListSummary =
            '${list.length} files; sample: ${sample.isEmpty ? '—' : sample}';
        _loadingSkillList = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillList = false;
      });
    }
  }

  Future<void> _previewSkillFile() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPreview = true;
      _error = null;
    });
    try {
      final r = await fetchSkillContent(token, path);
      if (!mounted) return;
      setState(() => _loadingSkillPreview = false);
      final text = r.content.length > 12000
          ? '${r.content.substring(0, 12000)}…\n\n(truncated)'
          : r.content;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(r.path),
          content: SingleChildScrollView(
            child: SelectableText(
              text,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPreview = false;
      });
    }
  }

  Future<void> _putSkillProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPut = true;
      _error = null;
      _skillMutationLine = null;
    });
    try {
      final r = await saveSkillContent(token, path, _skillContentCtrl.text);
      if (!mounted) return;
      setState(() {
        _loadingSkillPut = false;
        _skillMutationLine =
            'PUT 200: ${r.path} (${r.content.length} chars written)';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPut = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPut = false;
      });
    }
  }

  Future<void> _postSkillProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPost = true;
      _error = null;
      _skillMutationLine = null;
    });
    try {
      final r = await createSkillContent(token, path, _skillContentCtrl.text);
      if (!mounted) return;
      setState(() {
        _loadingSkillPost = false;
        _skillMutationLine =
            'POST 201: ${r.path} (${r.content.length} chars written)';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPost = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPost = false;
      });
    }
  }

  Future<void> _deleteSkillProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillDelete = true;
      _error = null;
      _skillMutationLine = null;
    });
    try {
      await deleteSkillContent(token, path);
      if (!mounted) return;
      setState(() {
        _loadingSkillDelete = false;
        _skillMutationLine = 'DELETE 204: $path';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillDelete = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillDelete = false;
      });
    }
  }

  Future<void> _testWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWs = true;
      _wsLog.clear();
      _error = null;
    });

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
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWs = false;
        });
      }
    }
  }

  Future<void> _testHarnessToolWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWsHarness = true;
      _wsLog.clear();
      _error = null;
    });

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
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWsHarness = false;
        });
      }
    }
  }

  Future<void> _testHarnessIsolatedEchoWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWsIsolatedEcho = true;
      _wsLog.clear();
      _error = null;
    });

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
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWsIsolatedEcho = false;
        });
      }
    }
  }

  Future<void> _testHarnessSkillsReadWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWsSkillsRead = true;
      _wsLog.clear();
      _error = null;
    });

    final path = _skillPathCtrl.text.trim().isEmpty
        ? 'script_execution_script.md'
        : _skillPathCtrl.text.trim();

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
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWsSkillsRead = false;
        });
      }
    }
  }

  Future<void> _testHarnessAgentRunWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWsHarnessAgent = true;
      _wsLog.clear();
      _error = null;
    });

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
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWsHarnessAgent = false;
        });
      }
    }
  }
}
