import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class EndpointMetricsResponse {
  const EndpointMetricsResponse({
    required this.path,
    required this.totalRequests,
    required this.successCount,
    required this.clientErrorCount,
    required this.serverErrorCount,
    required this.successRate,
    required this.p50LatencyMs,
    required this.p95LatencyMs,
    required this.p99LatencyMs,
    required this.avgLatencyMs,
    required this.errorBreakdown,
    required this.windowStart,
    required this.windowEnd,
  });

  final String path;
  final int totalRequests;
  final int successCount;
  final int clientErrorCount;
  final int serverErrorCount;
  final double successRate;
  final int p50LatencyMs;
  final int p95LatencyMs;
  final int p99LatencyMs;
  final int avgLatencyMs;
  final Map<String, int> errorBreakdown;
  final DateTime windowStart;
  final DateTime windowEnd;

  factory EndpointMetricsResponse.fromJson(Map<String, dynamic> json) {
    return EndpointMetricsResponse(
      path: json['path'] as String,
      totalRequests: (json['totalRequests'] as num).toInt(),
      successCount: (json['successCount'] as num).toInt(),
      clientErrorCount: (json['clientErrorCount'] as num).toInt(),
      serverErrorCount: (json['serverErrorCount'] as num).toInt(),
      successRate: (json['successRate'] as num).toDouble(),
      p50LatencyMs: (json['p50LatencyMs'] as num).toInt(),
      p95LatencyMs: (json['p95LatencyMs'] as num).toInt(),
      p99LatencyMs: (json['p99LatencyMs'] as num).toInt(),
      avgLatencyMs: (json['avgLatencyMs'] as num).toInt(),
      errorBreakdown:
          (json['errorBreakdown'] as Map<String, dynamic>? ?? const {}).map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ),
      windowStart: DateTime.parse(json['windowStart'] as String),
      windowEnd: DateTime.parse(json['windowEnd'] as String),
    );
  }
}

class MetricsResponse {
  const MetricsResponse({required this.endpoints, required this.windowMinutes});

  final Map<String, EndpointMetricsResponse> endpoints;
  final int windowMinutes;

  factory MetricsResponse.fromJson(Map<String, dynamic> json) {
    return MetricsResponse(
      endpoints: (json['endpoints'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(
          key,
          EndpointMetricsResponse.fromJson(value as Map<String, dynamic>),
        ),
      ),
      windowMinutes: (json['windowMinutes'] as num).toInt(),
    );
  }
}

class SliDefinitionResponse {
  const SliDefinitionResponse({
    required this.path,
    required this.name,
    required this.description,
    required this.endpoints,
    required this.targetP95LatencyMs,
    required this.targetSuccessRate,
    required this.targetAvailability,
  });

  final String path;
  final String name;
  final String description;
  final List<String> endpoints;
  final int targetP95LatencyMs;
  final double targetSuccessRate;
  final double targetAvailability;

  factory SliDefinitionResponse.fromJson(Map<String, dynamic> json) {
    return SliDefinitionResponse(
      path: json['path'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      endpoints: (json['endpoints'] as List<dynamic>? ?? const [])
          .map((entry) => entry as String)
          .toList(growable: false),
      targetP95LatencyMs: (json['targetP95LatencyMs'] as num).toInt(),
      targetSuccessRate: (json['targetSuccessRate'] as num).toDouble(),
      targetAvailability: (json['targetAvailability'] as num).toDouble(),
    );
  }
}

class SliSnapshotResponse {
  const SliSnapshotResponse({
    required this.path,
    required this.definition,
    required this.currentP95LatencyMs,
    required this.currentSuccessRate,
    required this.currentAvailability,
    required this.latencyMeetsTarget,
    required this.successRateMeetsTarget,
    required this.availabilityMeetsTarget,
    required this.healthy,
    required this.totalRequests,
  });

  final String path;
  final SliDefinitionResponse definition;
  final int currentP95LatencyMs;
  final double currentSuccessRate;
  final double currentAvailability;
  final bool latencyMeetsTarget;
  final bool successRateMeetsTarget;
  final bool availabilityMeetsTarget;
  final bool healthy;
  final int totalRequests;

  factory SliSnapshotResponse.fromJson(Map<String, dynamic> json) {
    return SliSnapshotResponse(
      path: json['path'] as String,
      definition: SliDefinitionResponse.fromJson(
        json['definition'] as Map<String, dynamic>,
      ),
      currentP95LatencyMs: (json['currentP95LatencyMs'] as num).toInt(),
      currentSuccessRate: (json['currentSuccessRate'] as num).toDouble(),
      currentAvailability: (json['currentAvailability'] as num).toDouble(),
      latencyMeetsTarget: json['latencyMeetsTarget'] == true,
      successRateMeetsTarget: json['successRateMeetsTarget'] == true,
      availabilityMeetsTarget: json['availabilityMeetsTarget'] == true,
      healthy: json['healthy'] == true,
      totalRequests: (json['totalRequests'] as num).toInt(),
    );
  }
}

class SliStatusResponse {
  const SliStatusResponse({
    required this.slis,
    required this.healthy,
    required this.windowMinutes,
  });

  final List<SliSnapshotResponse> slis;
  final bool healthy;
  final int windowMinutes;

  factory SliStatusResponse.fromJson(Map<String, dynamic> json) {
    return SliStatusResponse(
      slis: (json['slis'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                SliSnapshotResponse.fromJson(entry as Map<String, dynamic>),
          )
          .toList(growable: false),
      healthy: json['healthy'] == true,
      windowMinutes: (json['windowMinutes'] as num).toInt(),
    );
  }
}

Future<MetricsResponse> fetchMetricsV1({int windowMinutes = 60}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/metrics').replace(
    queryParameters: <String, String>{'windowMinutes': '$windowMinutes'},
  );
  final res = await http.get(uri).timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MetricsResponse.fromJson(map);
}

Future<SliStatusResponse> fetchSliStatusV1({int windowMinutes = 60}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/metrics/sli').replace(
    queryParameters: <String, String>{'windowMinutes': '$windowMinutes'},
  );
  final res = await http.get(uri).timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SliStatusResponse.fromJson(map);
}

Future<List<SliDefinitionResponse>> fetchSliDefinitionsV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/metrics/sli/definitions');
  final res = await http.get(uri).timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map(
        (entry) =>
            SliDefinitionResponse.fromJson(entry as Map<String, dynamic>),
      )
      .toList(growable: false);
}
