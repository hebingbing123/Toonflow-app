import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/section.dart';
import 'package:openflow_app/short_video_space/view.dart';

void main() {
  group('recommendExportFailureAction', () {
    test('recommends opening production workspace for source asset failures', () {
      expect(
        recommendExportFailureAction(
          'loading_assets',
          'payload_missing_source_url',
        ),
        ShortVideoLatestExportAction.openProductionWorkspace,
      );
      expect(
        recommendExportFailureAction(
          null,
          'video_download_http',
        ),
        ShortVideoLatestExportAction.openProductionWorkspace,
      );
    });

    test('recommends retry for execution-side failures', () {
      expect(
        recommendExportFailureAction(
          'encoding',
          'export_provider_failed',
        ),
        ShortVideoLatestExportAction.retry,
      );
      expect(
        recommendExportFailureAction(
          null,
          'export_file_persist_failed',
        ),
        ShortVideoLatestExportAction.retry,
      );
    });
  });
}
