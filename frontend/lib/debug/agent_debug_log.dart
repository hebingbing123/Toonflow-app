import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'agent_debug_log_file_stub.dart'
    if (dart.library.io) 'agent_debug_log_file_io.dart';

/// Debug-mode NDJSON ingest (session 2b69d7). Fire-and-forget; never throws.
void agentDebugLog({
  required String location,
  required String message,
  required Map<String, Object?> data,
  String? hypothesisId,
  String runId = 'pre-fix',
}) {
  if (!kDebugMode) {
    return;
  }
  final payload = <String, Object?>{
    'sessionId': '2b69d7',
    'runId': runId,
    ...?hypothesisId == null
        ? null
        : <String, Object?>{'hypothesisId': hypothesisId},
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  final line = jsonEncode(payload);
  debugPrint('AGENT_DEBUG $line');
  unawaited(appendAgentDebugLogLine(line));
  unawaited(
    http
        .post(
          Uri.parse(
            'http://127.0.0.1:7400/ingest/f1688356-55a3-4934-bb53-d1fea14c94da',
          ),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': '2b69d7',
          },
          body: line,
        )
        .catchError((_) => http.Response('', 500)),
  );
}
