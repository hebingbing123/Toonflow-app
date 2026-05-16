import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/system/metrics.dart';

void main() {
  test('MetricsResponse parses endpoint aggregates', () {
    final response = MetricsResponse.fromJson(<String, dynamic>{
      'endpoints': <String, dynamic>{
        '/api/v1/projects': <String, dynamic>{
          'path': '/api/v1/projects',
          'totalRequests': 12,
          'successCount': 10,
          'clientErrorCount': 1,
          'serverErrorCount': 1,
          'successRate': 0.833,
          'p50LatencyMs': 40,
          'p95LatencyMs': 120,
          'p99LatencyMs': 220,
          'avgLatencyMs': 55,
          'errorBreakdown': <String, dynamic>{'forbidden': 1},
          'windowStart': '2026-05-20T00:00:00Z',
          'windowEnd': '2026-05-20T01:00:00Z',
        },
      },
      'windowMinutes': 60,
    });

    expect(response.windowMinutes, 60);
    expect(response.endpoints['/api/v1/projects']?.successCount, 10);
    expect(
      response.endpoints['/api/v1/projects']?.errorBreakdown['forbidden'],
      1,
    );
  });

  test('SliStatusResponse parses nested sli snapshots', () {
    final response = SliStatusResponse.fromJson(<String, dynamic>{
      'slis': <dynamic>[
        <String, dynamic>{
          'path': 'project_overview',
          'definition': <String, dynamic>{
            'path': 'project_overview',
            'name': 'Project Overview Loading',
            'description': 'Dashboard aggregation and overview loading',
            'endpoints': <dynamic>[
              '/api/v1/projects/{project_id}/production-overview',
            ],
            'targetP95LatencyMs': 500,
            'targetSuccessRate': 0.99,
            'targetAvailability': 0.995,
          },
          'currentP95LatencyMs': 320,
          'currentSuccessRate': 1.0,
          'currentAvailability': 1.0,
          'latencyMeetsTarget': true,
          'successRateMeetsTarget': true,
          'availabilityMeetsTarget': true,
          'healthy': true,
          'totalRequests': 8,
        },
      ],
      'healthy': true,
      'windowMinutes': 60,
    });

    expect(response.healthy, isTrue);
    expect(response.slis.single.definition.name, 'Project Overview Loading');
    expect(response.slis.single.totalRequests, 8);
  });
}
