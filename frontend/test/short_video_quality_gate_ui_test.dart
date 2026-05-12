import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/rust_api/project/overview_models_assembly.dart';
import 'package:openflow_app/short_video_space/support_publish_api.dart';

void main() {
  final zh = AppLocalizationsZh();
  group('Quality Gate UI Tests', () {
    test('Quality gate strategy "off" displays correct message', () {
      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: true,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 10,
          blockingIssueCount: 0,
          warningIssueCount: 0,
        ),
        issues: const [],
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'off',
          enforced: false,
          pendingReviewBadCaseCount: 0,
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        l10n: zh,
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.qualityGateLine, contains('已关闭'));
      expect(ui.qualityGateLine, contains('不检查质量问题'));
      expect(ui.qualityGateBlockingLines, isEmpty);
    });

    test('Quality gate strategy "warn" with bad cases displays warning', () {
      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: true,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 10,
          blockingIssueCount: 0,
          warningIssueCount: 0,
        ),
        issues: const [],
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'warn',
          enforced: false,
          pendingReviewBadCaseCount: 5,
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        l10n: zh,
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.qualityGateLine, contains('警告模式'));
      expect(ui.qualityGateLine, contains('待复核坏例 5 条'));
      expect(ui.qualityGateLine, contains('允许导出但建议修复'));
      expect(ui.qualityGateBlockingLines, isEmpty);
    });

    test('Quality gate strategy "warn" without bad cases displays clean state',
        () {
      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: true,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 10,
          blockingIssueCount: 0,
          warningIssueCount: 0,
        ),
        issues: const [],
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'warn',
          enforced: false,
          pendingReviewBadCaseCount: 0,
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        l10n: zh,
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.qualityGateLine, contains('警告模式'));
      expect(ui.qualityGateLine, contains('暂无待复核坏例'));
      expect(ui.qualityGateLine, contains('允许导出'));
      expect(ui.qualityGateBlockingLines, isEmpty);
    });

    test('Quality gate strategy "block" enforced with bad cases blocks export',
        () {
      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: false,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 10,
          blockingIssueCount: 0,
          warningIssueCount: 0,
        ),
        issues: const [],
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'block',
          enforced: true,
          pendingReviewBadCaseCount: 3,
          blockingReasons: [
            QualityGateBlockingReason(
              code: 'QUALITY_ISSUE_001',
              message: '存在未复核的质量问题',
              reworkRoute: '/quality-review',
            ),
            QualityGateBlockingReason(
              code: 'QUALITY_ISSUE_002',
              message: '镜头质量不达标',
            ),
          ],
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        l10n: zh,
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.qualityGateLine, contains('阻断模式'));
      expect(ui.qualityGateLine, contains('待复核坏例 3 条'));
      expect(ui.qualityGateLine, contains('阻止导出，需先修复'));
      expect(ui.qualityGateBlockingLines, hasLength(2));
      expect(ui.qualityGateBlockingLines[0], contains('QUALITY_ISSUE_001'));
      expect(ui.qualityGateBlockingLines[0], contains('存在未复核的质量问题'));
      expect(ui.qualityGateBlockingLines[0], contains('[返工: /quality-review]'));
      expect(ui.qualityGateBlockingLines[1], contains('QUALITY_ISSUE_002'));
      expect(ui.qualityGateBlockingLines[1], contains('镜头质量不达标'));
      expect(ui.qualityGateBlockingLines[1], isNot(contains('[返工:')));
    });

    test(
        'Quality gate strategy "block" not enforced with bad cases shows warning',
        () {
      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: true,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 10,
          blockingIssueCount: 0,
          warningIssueCount: 0,
        ),
        issues: const [],
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'block',
          enforced: false,
          pendingReviewBadCaseCount: 2,
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        l10n: zh,
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.qualityGateLine, contains('阻断模式'));
      expect(ui.qualityGateLine, contains('待复核坏例 2 条'));
      expect(ui.qualityGateLine, contains('暂未强制执行'));
      expect(ui.qualityGateBlockingLines, isEmpty);
    });

    test('Quality gate strategy "block" without bad cases allows export', () {
      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: true,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 10,
          blockingIssueCount: 0,
          warningIssueCount: 0,
        ),
        issues: const [],
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'block',
          enforced: true,
          pendingReviewBadCaseCount: 0,
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        l10n: zh,
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.qualityGateLine, contains('阻断模式'));
      expect(ui.qualityGateLine, contains('暂无待复核坏例'));
      expect(ui.qualityGateLine, contains('允许导出'));
      expect(ui.qualityGateBlockingLines, isEmpty);
    });

    test('Quality gate with unknown strategy displays error message', () {
      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: true,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 10,
          blockingIssueCount: 0,
          warningIssueCount: 0,
        ),
        issues: const [],
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'unknown_strategy',
          enforced: false,
          pendingReviewBadCaseCount: 0,
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        l10n: zh,
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.qualityGateLine, contains('未知策略'));
      expect(ui.qualityGateLine, contains('unknown_strategy'));
    });

    test('Quality gate model parses from JSON correctly', () {
      final json = {
        'schema_version': 1,
        'strategy': 'block',
        'enforced': true,
        'pending_review_bad_case_count': 5,
        'blocking_reasons': [
          {
            'code': 'TEST_CODE',
            'message': 'Test message',
            'rework_route': '/test-route',
          },
        ],
      };

      final qualityGate = ShortVideoExportQualityGate.fromJson(json);

      expect(qualityGate.schemaVersion, 1);
      expect(qualityGate.strategy, 'block');
      expect(qualityGate.enforced, true);
      expect(qualityGate.pendingReviewBadCaseCount, 5);
      expect(qualityGate.blockingReasons, hasLength(1));
      expect(qualityGate.blockingReasons![0].code, 'TEST_CODE');
      expect(qualityGate.blockingReasons![0].message, 'Test message');
      expect(qualityGate.blockingReasons![0].reworkRoute, '/test-route');
    });

    test('Quality gate model handles missing blocking_reasons', () {
      final json = {
        'schema_version': 1,
        'strategy': 'warn',
        'enforced': false,
        'pending_review_bad_case_count': 0,
      };

      final qualityGate = ShortVideoExportQualityGate.fromJson(json);

      expect(qualityGate.schemaVersion, 1);
      expect(qualityGate.strategy, 'warn');
      expect(qualityGate.enforced, false);
      expect(qualityGate.pendingReviewBadCaseCount, 0);
      expect(qualityGate.blockingReasons, isNull);
    });

    test('Export check model parses quality_gate from JSON', () {
      final json = {
        'schema_version': 1,
        'data_version': '2024-01-01T00:00:00Z',
        'export_ready': false,
        'summary': {
          'storyboard_count': 10,
          'blocking_issue_count': 2,
          'warning_issue_count': 1,
        },
        'issues': [],
        'quality_gate': {
          'schema_version': 1,
          'strategy': 'block',
          'enforced': true,
          'pending_review_bad_case_count': 3,
        },
      };

      final exportCheck = ProjectShortVideoExportCheck.fromJson(json);

      expect(exportCheck.qualityGate.strategy, 'block');
      expect(exportCheck.qualityGate.enforced, true);
      expect(exportCheck.qualityGate.pendingReviewBadCaseCount, 3);
    });

    test('Export check model uses default quality_gate when missing', () {
      final json = {
        'schema_version': 1,
        'export_ready': true,
        'summary': {
          'storyboard_count': 10,
          'blocking_issue_count': 0,
          'warning_issue_count': 0,
        },
        'issues': [],
      };

      final exportCheck = ProjectShortVideoExportCheck.fromJson(json);

      expect(exportCheck.qualityGate.strategy, 'off');
      expect(exportCheck.qualityGate.enforced, false);
      expect(exportCheck.qualityGate.pendingReviewBadCaseCount, 0);
    });
  });
}
