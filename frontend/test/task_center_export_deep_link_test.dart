import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/task_center/support.dart';

void main() {
  test('extracts project scope from payload using uuid-first semantics', () {
    final scope = taskCenterProjectScopeFromMap(const <String, dynamic>{
      'project_id': '550e8400-e29b-41d4-a716-446655440999',
      'project_numeric_id': 19,
    });

    expect(scope.projectNumericId, 19);
    expect(scope.projectUuid, '550e8400-e29b-41d4-a716-446655440999');
  });

  test('extracts project scope from legacy numeric project_id payload', () {
    final scope = taskCenterProjectScopeFromMap(const <String, dynamic>{
      'project_id': '23',
    });

    expect(scope.projectNumericId, 23);
    expect(scope.projectUuid, isNull);
  });

  test(
    'parses video.export deep link from error_details and payload fallback',
    () {
      final job = JobRow(
        numericTaskId: 42,
        id: '550e8400-e29b-41d4-a716-446655440000',
        ownerUserId: 'user',
        kind: 'video.export',
        status: 'failed',
        payload: <String, dynamic>{
          'project_numeric_id': 9,
          'project_uuid': '550e8400-e29b-41d4-a716-446655440111',
          'script_numeric_id': 3,
          'storyboard_numeric_id': 77,
          'workspace_id': '550e8400-e29b-41d4-a716-446655440222',
        },
        errorDetails: <String, dynamic>{
          'code': 'video_download_http',
          'deep_links': <String, dynamic>{
            'project_numeric_id': 9,
            'project_uuid': '550e8400-e29b-41d4-a716-446655440111',
            'script_numeric_id': 3,
            'storyboard_numeric_id': 77,
            'workspace_id': '550e8400-e29b-41d4-a716-446655440222',
          },
        },
        errorMessage: 'video download HTTP 403',
        createdAt: '2026-05-05T00:00:00Z',
        updatedAt: '2026-05-05T00:00:01Z',
      );

      final link = tryParseVideoExportJobDeepLink(job);
      expect(link, isNotNull);
      expect(link!.projectNumericId, 9);
      expect(link.projectUuid, '550e8400-e29b-41d4-a716-446655440111');
      expect(link.scriptNumericId, 3);
      expect(link.storyboardNumericId, 77);
      expect(link.workspaceId, '550e8400-e29b-41d4-a716-446655440222');
      expect(
        videoExportFailureCodeLabel(
          AppLocalizationsZh(),
          'video_download_http',
        ),
        '源视频 HTTP 失败',
      );
    },
  );

  test(
    'parses domain deep link with uuid-first metadata while keeping numeric fallback',
    () {
      final job = JobRow(
        numericTaskId: 88,
        id: '550e8400-e29b-41d4-a716-446655440333',
        ownerUserId: 'user',
        kind: 'storyboard.render',
        status: 'failed',
        payload: const <String, dynamic>{
          'project_numeric_id': 12,
          'project_uuid': '550e8400-e29b-41d4-a716-446655440444',
          'script_numeric_id': 5,
          'workspace_id': '550e8400-e29b-41d4-a716-446655440555',
        },
        errorDetails: const <String, dynamic>{
          'deep_links': <String, dynamic>{
            'project_numeric_id': 12,
            'project_id': '550e8400-e29b-41d4-a716-446655440444',
            'script_numeric_id': 5,
            'workspace_id': '550e8400-e29b-41d4-a716-446655440555',
          },
        },
        createdAt: '2026-05-05T00:00:00Z',
        updatedAt: '2026-05-05T00:00:01Z',
      );

      final link = tryParseTaskCenterDomainDeepLink(job);
      expect(link, isNotNull);
      expect(link!.target, TaskCenterDomainDeepLinkTarget.storyboard);
      expect(link.projectNumericId, 12);
      expect(link.projectUuid, '550e8400-e29b-41d4-a716-446655440444');
      expect(link.scriptNumericId, 5);
      expect(link.workspaceId, '550e8400-e29b-41d4-a716-446655440555');
    },
  );

  test('parses task-center deep links when only project uuid is available', () {
    final job = JobRow(
      numericTaskId: 77,
      id: '550e8400-e29b-41d4-a716-446655440777',
      ownerUserId: 'user',
      kind: 'video.export',
      status: 'failed',
      payload: const <String, dynamic>{
        'project_uuid': '550e8400-e29b-41d4-a716-446655440111',
        'script_numeric_id': 3,
        'workspace_id': '550e8400-e29b-41d4-a716-446655440222',
      },
      errorDetails: const <String, dynamic>{
        'deep_links': <String, dynamic>{
          'project_uuid': '550e8400-e29b-41d4-a716-446655440111',
          'script_numeric_id': 3,
          'workspace_id': '550e8400-e29b-41d4-a716-446655440222',
        },
      },
      createdAt: '2026-05-05T00:00:00Z',
      updatedAt: '2026-05-05T00:00:01Z',
    );

    final exportLink = tryParseVideoExportJobDeepLink(job);
    final domainLink = tryParseTaskCenterDomainDeepLink(job);
    expect(exportLink, isNotNull);
    expect(exportLink!.projectNumericId, isNull);
    expect(exportLink.projectUuid, '550e8400-e29b-41d4-a716-446655440111');
    expect(domainLink, isNotNull);
    expect(domainLink!.projectNumericId, isNull);
    expect(domainLink.projectUuid, '550e8400-e29b-41d4-a716-446655440111');
    expect(domainLink.target, TaskCenterDomainDeepLinkTarget.script);
  });

  test(
    'parses task-center deep links from result metadata when payload is sparse',
    () {
      final job = JobRow(
        numericTaskId: 101,
        id: '550e8400-e29b-41d4-a716-446655440901',
        ownerUserId: 'user',
        kind: 'video.export',
        status: 'succeeded',
        payload: const <String, dynamic>{},
        result: const <String, dynamic>{
          'project_uuid': '550e8400-e29b-41d4-a716-446655440902',
          'project_numeric_id': 44,
          'scriptNumericId': 7,
          'storyboardNumericId': 18,
          'workspaceId': '550e8400-e29b-41d4-a716-446655440903',
        },
        createdAt: '2026-05-05T00:00:00Z',
        updatedAt: '2026-05-05T00:00:01Z',
      );

      final exportLink = tryParseVideoExportJobDeepLink(job);
      final domainLink = tryParseTaskCenterDomainDeepLink(job);

      expect(exportLink, isNotNull);
      expect(exportLink!.projectNumericId, 44);
      expect(exportLink.projectUuid, '550e8400-e29b-41d4-a716-446655440902');
      expect(exportLink.scriptNumericId, 7);
      expect(exportLink.storyboardNumericId, 18);
      expect(exportLink.workspaceId, '550e8400-e29b-41d4-a716-446655440903');

      expect(domainLink, isNotNull);
      expect(domainLink!.projectNumericId, 44);
      expect(domainLink.projectUuid, '550e8400-e29b-41d4-a716-446655440902');
      expect(domainLink.scriptNumericId, 7);
      expect(domainLink.storyboardNumericId, 18);
      expect(domainLink.workspaceId, '550e8400-e29b-41d4-a716-446655440903');
      expect(domainLink.target, TaskCenterDomainDeepLinkTarget.storyboard);
    },
  );
}
