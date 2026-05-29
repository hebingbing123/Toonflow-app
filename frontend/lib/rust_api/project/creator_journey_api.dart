import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// Client-side creator journey event payload (mirrors OpenAPI ingest body).
class CreatorJourneyEventPayload {
  const CreatorJourneyEventPayload({
    required this.name,
    this.properties = const <String, Object?>{},
  });

  final String name;
  final Map<String, Object?> properties;
}

class CreatorJourneyEventCount {
  const CreatorJourneyEventCount({required this.name, required this.count});

  final String name;
  final int count;

  factory CreatorJourneyEventCount.fromJson(Map<String, dynamic> json) {
    return CreatorJourneyEventCount(
      name: json['name'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreatorJourneyStepCount {
  const CreatorJourneyStepCount({required this.step, required this.count});

  final String step;
  final int count;

  factory CreatorJourneyStepCount.fromJson(Map<String, dynamic> json) {
    return CreatorJourneyStepCount(
      step: json['step'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreatorJourneySummary {
  const CreatorJourneySummary({
    required this.topEvents,
    required this.stepSelections,
    required this.retryEventCount,
    required this.totalEvents,
  });

  final List<CreatorJourneyEventCount> topEvents;
  final List<CreatorJourneyStepCount> stepSelections;
  final int retryEventCount;
  final int totalEvents;

  factory CreatorJourneySummary.fromJson(Map<String, dynamic> json) {
    final topRaw = json['topEvents'] as List<dynamic>? ?? const <dynamic>[];
    final stepRaw =
        json['stepSelections'] as List<dynamic>? ?? const <dynamic>[];
    return CreatorJourneySummary(
      topEvents: topRaw
          .map(
            (dynamic e) =>
                CreatorJourneyEventCount.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      stepSelections: stepRaw
          .map(
            (dynamic e) =>
                CreatorJourneyStepCount.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      retryEventCount: (json['retryEventCount'] as num?)?.toInt() ?? 0,
      totalEvents: (json['totalEvents'] as num?)?.toInt() ?? 0,
    );
  }
}

Map<String, dynamic> _encodeProperties(Map<String, Object?> properties) {
  return properties.map(
    (String key, Object? value) => MapEntry<String, dynamic>(key, value),
  );
}

/// `POST /api/v1/projects/{project_id}/creator-journey-events`
Future<void> postCreatorJourneyEvents(
  String accessToken,
  String projectUuid, {
  required List<CreatorJourneyEventPayload> events,
}) async {
  if (events.isEmpty) {
    return;
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectUuid/creator-journey-events',
  );
  final body = <String, dynamic>{
    'events': events
        .map(
          (CreatorJourneyEventPayload event) => <String, dynamic>{
            'name': event.name,
            'properties': _encodeProperties(event.properties),
          },
        )
        .toList(growable: false),
  };
  final res = await http
      .post(
        uri,
        headers: <String, String>{
      ...rustApiAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 10));
  ensureHttpSuccess(res);
}

/// `GET /api/v1/projects/{project_id}/creator-journey-summary`
Future<CreatorJourneySummary> fetchCreatorJourneySummary(
  String accessToken,
  String projectUuid, {
  int days = 7,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectUuid/creator-journey-summary',
  ).replace(queryParameters: <String, String>{'days': '$days'});
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return CreatorJourneySummary.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}
