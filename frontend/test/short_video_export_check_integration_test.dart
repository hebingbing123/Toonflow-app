import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/project/overview_models_assembly.dart';
import 'package:openflow_app/short_video_space/support_publish_api.dart';

void main() {
  group('Export Check Integration Tests', () {
    test('Export check displays ready state when no blocking issues', () {
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
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.visible, true);
      expect(ui.loading, false);
      expect(ui.unavailable, false);
      expect(ui.exportReady, true);
      expect(ui.headline, contains('未发现阻塞级问题'));
      expect(ui.metrics, hasLength(4));
      expect(ui.metrics[0].label, '分镜');
      expect(ui.metrics[0].value, '10');
      expect(ui.metrics[1].label, '阻塞');
      expect(ui.metrics[1].value, '0');
      expect(ui.metrics[2].label, '提醒');
      expect(ui.metrics[2].value, '0');
      expect(ui.metrics[3].label, '可导出');
      expect(ui.metrics[3].value, '是');
    });

    test('Export check displays blocking issues correctly', () {
      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: false,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 10,
          blockingIssueCount: 2,
          warningIssueCount: 1,
        ),
        issues: const [
          ShortVideoExportCheckIssue(
            severity: 'blocking',
            code: 'missing_selected_media',
            detail: '未选择成片媒体',
            scriptNumericId: 1,
            storyboardId: '00000000-0000-0000-0000-000000000101',
            storyboardNumericId: 101,
            sbIndex: 1,
          ),
          ShortVideoExportCheckIssue(
            severity: 'blocking',
            code: 'duration_not_set',
            detail: '时长未设定',
            scriptNumericId: 1,
            storyboardId: '00000000-0000-0000-0000-000000000102',
            storyboardNumericId: 102,
            sbIndex: 2,
          ),
          ShortVideoExportCheckIssue(
            severity: 'warning',
            code: 'subtitle_empty',
            detail: '字幕为空',
            scriptNumericId: 1,
            storyboardId: '00000000-0000-0000-0000-000000000103',
            storyboardNumericId: 103,
            sbIndex: 3,
          ),
        ],
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'off',
          enforced: false,
          pendingReviewBadCaseCount: 0,
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.visible, true);
      expect(ui.exportReady, false);
      expect(ui.headline, contains('存在阻塞项'));
      expect(ui.metrics[1].value, '2'); // blocking count
      expect(ui.metrics[2].value, '1'); // warning count
      expect(ui.metrics[3].value, '否'); // not ready
      expect(ui.blockingLines, hasLength(2));
      expect(ui.blockingLines[0], contains('剧本 #1'));
      expect(ui.blockingLines[0], contains('分镜 #101'));
      expect(ui.blockingLines[0], contains('序 1'));
      expect(ui.blockingLines[0], contains('未选成片媒体'));
      expect(ui.blockingLines[1], contains('分镜 #102'));
      expect(ui.blockingLines[1], contains('序 2'));
      expect(ui.warningLines, hasLength(1));
      expect(ui.warningLines[0], contains('分镜 #103'));
      expect(ui.warningLines[0], contains('序 3'));
    });

    test('Export check displays loading state correctly', () {
      final ui = buildShortVideoExportCheckPanelUi(
        projectSelected: true,
        loadingProjectOverview: true,
        exportCheck: null,
      );

      expect(ui.visible, true);
      expect(ui.loading, true);
      expect(ui.unavailable, false);
      expect(ui.headline, contains('正在读取导出前检查'));
      expect(ui.detail, contains('聚合分镜阻塞与提醒'));
    });

    test('Export check displays unavailable state when no data', () {
      final ui = buildShortVideoExportCheckPanelUi(
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: null,
      );

      expect(ui.visible, true);
      expect(ui.loading, false);
      expect(ui.unavailable, true);
      expect(ui.headline, contains('导出前检查暂不可用'));
      expect(ui.detail, contains('可稍后刷新页面'));
    });

    test('Export check hidden when no project selected', () {
      final ui = buildShortVideoExportCheckPanelUi(
        projectSelected: false,
        loadingProjectOverview: false,
        exportCheck: null,
      );

      expect(ui.visible, false);
    });

    test('Export check displays quality gate block with reasons', () {
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
          pendingReviewBadCaseCount: 5,
          blockingReasons: [
            QualityGateBlockingReason(
              code: 'QUALITY_GATE_001',
              message: '存在5条待复核坏例',
              reworkRoute: '/quality-review',
            ),
            QualityGateBlockingReason(
              code: 'QUALITY_GATE_002',
              message: '质量评分低于阈值',
            ),
          ],
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.qualityGateLine, contains('阻断模式'));
      expect(ui.qualityGateLine, contains('待复核坏例 5 条'));
      expect(ui.qualityGateLine, contains('阻止导出，需先修复'));
      expect(ui.qualityGateBlockingLines, hasLength(2));
      expect(ui.qualityGateBlockingLines[0], contains('QUALITY_GATE_001'));
      expect(ui.qualityGateBlockingLines[0], contains('存在5条待复核坏例'));
      expect(ui.qualityGateBlockingLines[0], contains('[返工: /quality-review]'));
      expect(ui.qualityGateBlockingLines[1], contains('QUALITY_GATE_002'));
      expect(ui.qualityGateBlockingLines[1], contains('质量评分低于阈值'));
    });

    test('Export check handles mixed blocking and warning issues', () {
      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: false,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 20,
          blockingIssueCount: 3,
          warningIssueCount: 5,
        ),
        issues: const [
          ShortVideoExportCheckIssue(
            severity: 'blocking',
            code: 'missing_selected_media',
            detail: '未选择成片媒体',
            scriptNumericId: 1,
            storyboardId: '00000000-0000-0000-0000-000000000101',
            storyboardNumericId: 101,
            sbIndex: 1,
          ),
          ShortVideoExportCheckIssue(
            severity: 'warning',
            code: 'subtitle_empty',
            detail: '字幕为空',
            scriptNumericId: 1,
            storyboardId: '00000000-0000-0000-0000-000000000102',
            storyboardNumericId: 102,
            sbIndex: 2,
          ),
          ShortVideoExportCheckIssue(
            severity: 'blocking',
            code: 'duration_not_set',
            detail: '时长未设定',
            scriptNumericId: 2,
            storyboardId: '00000000-0000-0000-0000-000000000201',
            storyboardNumericId: 201,
            sbIndex: 1,
          ),
          ShortVideoExportCheckIssue(
            severity: 'warning',
            code: 'voiceover_not_ready',
            detail: '配音未就绪',
            scriptNumericId: 2,
            storyboardId: '00000000-0000-0000-0000-000000000202',
            storyboardNumericId: 202,
            sbIndex: 2,
          ),
        ],
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'warn',
          enforced: false,
          pendingReviewBadCaseCount: 2,
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      expect(ui.exportReady, false);
      expect(ui.metrics[0].value, '20'); // storyboard count
      expect(ui.metrics[1].value, '3'); // blocking count
      expect(ui.metrics[2].value, '5'); // warning count
      expect(ui.blockingLines, hasLength(2));
      expect(ui.warningLines, hasLength(2));
      expect(ui.qualityGateLine, contains('警告模式'));
      expect(ui.qualityGateLine, contains('待复核坏例 2 条'));
    });

    test('Export check issue code mapping works correctly', () {
      expect(shortVideoExportIssueLabelZh('candidate_pending'), '候选待确认');
      expect(shortVideoExportIssueLabelZh('missing_selected_media'), '未选成片媒体');
      expect(shortVideoExportIssueLabelZh('selected_media_not_video'), '所选媒体非视频');
      expect(shortVideoExportIssueLabelZh('subtitle_placeholder'), '字幕 / 口播文案缺失');
      expect(shortVideoExportIssueLabelZh('subtitle_empty'), '字幕为空');
      expect(shortVideoExportIssueLabelZh('voiceover_failed'), '旁白生成失败');
      expect(shortVideoExportIssueLabelZh('voiceover_audio_missing'), '旁白音频未就绪');
      expect(shortVideoExportIssueLabelZh('voiceover_not_ready'), '配音未就绪');
      expect(shortVideoExportIssueLabelZh('duration_not_explicit'), '时长未标明（导出默认）');
      expect(shortVideoExportIssueLabelZh('duration_not_set'), '时长未设定');
      expect(shortVideoExportIssueLabelZh('duration_unparsable'), '时长格式异常');
      expect(shortVideoExportIssueLabelZh('completion_uncertain'), '成片状态未标「已完成」');
      expect(shortVideoExportIssueLabelZh('unknown_code'), 'unknown_code');
    });

    test('Export check limits blocking and warning lines to 14 each', () {
      final issues = List<ShortVideoExportCheckIssue>.generate(
        30,
        (i) => ShortVideoExportCheckIssue(
          severity: i < 20 ? 'blocking' : 'warning',
          code: 'test_issue_$i',
          detail: '测试问题 $i',
          scriptNumericId: 1,
          storyboardId: '00000000-0000-0000-0000-0000000001${i.toString().padLeft(2, '0')}',
          storyboardNumericId: 100 + i,
          sbIndex: i,
        ),
      );

      final exportCheck = ProjectShortVideoExportCheck(
        schemaVersion: 1,
        dataVersion: '2024-01-01T00:00:00Z',
        exportReady: false,
        summary: const ShortVideoExportCheckSummary(
          storyboardCount: 30,
          blockingIssueCount: 20,
          warningIssueCount: 10,
        ),
        issues: issues,
        qualityGate: const ShortVideoExportQualityGate(
          schemaVersion: 1,
          strategy: 'off',
          enforced: false,
          pendingReviewBadCaseCount: 0,
        ),
      );

      final ui = buildShortVideoExportCheckPanelUi(
        projectSelected: true,
        loadingProjectOverview: false,
        exportCheck: exportCheck,
      );

      // Should limit to 14 blocking and 14 warning lines
      expect(ui.blockingLines.length, lessThanOrEqualTo(14));
      expect(ui.warningLines.length, lessThanOrEqualTo(14));
    });
  });
}
