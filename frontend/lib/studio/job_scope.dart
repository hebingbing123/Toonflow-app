import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import 'job_center.dart';

/// Subscribes to generation job WS updates for [StudioJobTray] (Wave 1.5).
class StudioJobScope extends StatefulWidget {
  const StudioJobScope({
    super.key,
    required this.accessToken,
    required this.child,
  });

  final String? accessToken;
  final Widget child;

  @override
  State<StudioJobScope> createState() => _StudioJobScopeState();
}

class _StudioJobScopeState extends State<StudioJobScope> {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant StudioJobScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken) {
      _disconnect();
      _connect();
    }
  }

  void _connect() {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final uri = rustWebSocketUri(kApiBaseUrl, accessToken: token);
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        _onMessage,
        onDone: _disconnect,
        onError: (_) => _disconnect(),
        cancelOnError: true,
      );
      unawaited(
        channel.ready.catchError((_) {
          _disconnect();
        }),
      );
    } catch (_) {
      _disconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['type'] != 'generation.job.updated') return;
      final payload = decoded['payload'];
      if (payload is! Map<String, dynamic>) return;
      final id = payload['id']?.toString();
      final status = payload['status']?.toString() ?? '';
      if (id == null) return;
      final snapshot = StudioJobSnapshot(
        jobId: id,
        status: status,
        label: payload['kind']?.toString(),
      );
      if (snapshot.isActive) {
        StudioJobCenter.instance.upsert(snapshot);
      } else {
        StudioJobCenter.instance.remove(id);
      }
    } catch (_) {}
  }

  void _disconnect() {
    unawaited(_sub?.cancel());
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
