import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/studio_review_pack_export_bridge.dart';
import 'package:openflow_app/rust_api/project/overview_models_assembly.dart';

void main() {
  test('reviewPackTopBlockingExportIssues keeps blocking severity only', () {
    const check = ProjectShortVideoExportCheck(
      schemaVersion: 1,
      exportReady: false,
      summary: ShortVideoExportCheckSummary(
        storyboardCount: 2,
        blockingIssueCount: 2,
        warningIssueCount: 1,
      ),
      issues: <ShortVideoExportCheckIssue>[
        ShortVideoExportCheckIssue(
          severity: 'blocking',
          code: 'NO_VIDEO',
          detail: 'Missing video',
          scriptNumericId: 1,
          storyboardId: 'sb-1',
          storyboardNumericId: 10,
        ),
        ShortVideoExportCheckIssue(
          severity: 'warning',
          code: 'WARN',
          detail: 'Soft gap',
          scriptNumericId: 1,
          storyboardId: 'sb-2',
          storyboardNumericId: 11,
        ),
        ShortVideoExportCheckIssue(
          severity: 'blocking',
          code: 'GAP',
          detail: 'Blocking two',
          scriptNumericId: 1,
          storyboardId: 'sb-3',
          storyboardNumericId: 12,
        ),
      ],
      qualityGate: ShortVideoExportQualityGate(
        schemaVersion: 1,
        strategy: 'off',
        enforced: false,
        pendingReviewBadCaseCount: 0,
      ),
    );

    final top = reviewPackTopBlockingExportIssues(check, limit: 2);
    expect(top, hasLength(2));
    expect(top.every((i) => i.severity == 'blocking'), isTrue);
    expect(top.first.detail, 'Missing video');
  });
}
