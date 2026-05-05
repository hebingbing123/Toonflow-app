import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/task_center/support.dart';

void main() {
  test('parses video.export deep link from error_details and payload fallback',
      () {
    final job = JobRow(
      numericTaskId: 42,
      id: '550e8400-e29b-41d4-a716-446655440000',
      ownerUserId: 'user',
      kind: 'video.export',
      status: 'failed',
      payload: <String, dynamic>{
        'project_numeric_id': 9,
        'script_numeric_id': 3,
        'storyboard_numeric_id': 77,
      },
      errorDetails: <String, dynamic>{
        'code': 'video_download_http',
        'deep_links': <String, dynamic>{
          'project_numeric_id': 9,
          'script_numeric_id': 3,
          'storyboard_numeric_id': 77,
        },
      },
      errorMessage: 'video download HTTP 403',
      createdAt: '2026-05-05T00:00:00Z',
      updatedAt: '2026-05-05T00:00:01Z',
    );

    final link = tryParseVideoExportJobDeepLink(job);
    expect(link, isNotNull);
    expect(link!.projectNumericId, 9);
    expect(link.scriptNumericId, 3);
    expect(link.storyboardNumericId, 77);
    expect(
      videoExportFailureCodeLabelZh('video_download_http'),
      '源视频 HTTP 失败',
    );
  });
}
