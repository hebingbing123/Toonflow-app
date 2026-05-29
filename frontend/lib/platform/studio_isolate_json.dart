import 'dart:convert';
import 'dart:isolate';

/// Decode large JSON payloads off the UI isolate (9.4).
Future<Map<String, dynamic>> studioDecodeJsonMapInIsolate(String raw) {
  return Isolate.run(() {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return decoded;
  });
}

Future<List<dynamic>> studioDecodeJsonListInIsolate(String raw) {
  return Isolate.run(() {
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Expected JSON array');
    }
    return decoded;
  });
}
