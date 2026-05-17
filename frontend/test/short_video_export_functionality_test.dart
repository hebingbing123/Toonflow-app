import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/rust_api/project/overview_models_assembly.dart';
import 'package:openflow_app/short_video_space/support_publish_api.dart';

void main() {
  final zh = AppLocalizationsZh();
  group('Export Functionality Unit Tests', () {
    group('Export Settings Logic', () {
      test(
        'Export check correctly identifies ready state with no blocking issues',
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

          expect(ui.exportReady, true);
          expect(ui.visible, true);
          expect(ui.loading, false);
          expect(ui.unavailable, false);
          expect(ui.headline, contains('未发现阻塞级问题'));
        },
      );

      test(
        'Export check correctly identifies not ready state with blocking issues',
        () {
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
            ],
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

          expect(ui.exportReady, false);
          expect(ui.headline, contains('存在阻塞项'));
          expect(ui.blockingLines, hasLength(2));
        },
      );

      test('storyboard_gaps drive per-shot expandable entries', () {
        const gap = ShortVideoExportCheckStoryboardGap(
          scriptNumericId: 1,
          storyboardId: '00000000-0000-0000-0000-000000000101',
          storyboardNumericId: 101,
          sbIndex: 1,
          gapCodes: ['missing_selected_media', 'subtitle_placeholder'],
          hasBlocking: true,
          missingSelectedVideo: true,
          missingSubtitle: true,
          missingVoiceover: false,
          durationAnomaly: false,
        );
        final exportCheck = ProjectShortVideoExportCheck(
          schemaVersion: 1,
          exportReady: false,
          summary: const ShortVideoExportCheckSummary(
            storyboardCount: 1,
            blockingIssueCount: 2,
            warningIssueCount: 0,
          ),
          issues: const [],
          storyboardGaps: [gap],
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
        expect(ui.storyboardGapEntries, hasLength(1));
        expect(ui.storyboardGapEntries.first.facetSummary, contains('未选成片视频'));
        expect(ui.storyboardGapEntries.first.facetSummary, contains('字幕'));
        expect(ui.blockingLines, isEmpty);
      });

      test('Export settings correctly validates quality gate block mode', () {
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
            ],
          ),
        );

        final ui = buildShortVideoExportCheckPanelUi(
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          exportCheck: exportCheck,
        );

        expect(ui.exportReady, false);
        expect(ui.qualityGateLine, contains('阻断模式'));
        expect(ui.qualityGateLine, contains('待复核坏例 5 条'));
        expect(ui.qualityGateLine, contains('阻止导出，需先修复'));
        expect(ui.qualityGateBlockingLines, hasLength(1));
        expect(ui.qualityGateBlockingLines[0], contains('QUALITY_GATE_001'));
        expect(
          ui.qualityGateBlockingLines[0],
          contains('[返工: /quality-review]'),
        );
      });

      test('Export settings correctly validates quality gate warn mode', () {
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
            pendingReviewBadCaseCount: 3,
          ),
        );

        final ui = buildShortVideoExportCheckPanelUi(
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          exportCheck: exportCheck,
        );

        expect(ui.qualityGateLine, contains('警告模式'));
        expect(ui.qualityGateLine, contains('待复核坏例 3 条'));
        expect(ui.qualityGateLine, contains('允许导出但建议修复'));
      });

      test('Export settings correctly handles off quality gate mode', () {
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
      });

      test('Export settings correctly maps issue codes to Chinese labels', () {
        expect(shortVideoExportIssueLabel(zh, 'candidate_pending'), '候选待确认');
        expect(
          shortVideoExportIssueLabel(zh, 'missing_selected_media'),
          '未选成片媒体',
        );
        expect(
          shortVideoExportIssueLabel(zh, 'selected_media_not_video'),
          '所选媒体非视频',
        );
        expect(
          shortVideoExportIssueLabel(zh, 'subtitle_placeholder'),
          '字幕 / 口播文案缺失',
        );
        expect(shortVideoExportIssueLabel(zh, 'subtitle_empty'), '字幕为空');
        expect(shortVideoExportIssueLabel(zh, 'voiceover_failed'), '旁白生成失败');
        expect(
          shortVideoExportIssueLabel(zh, 'voiceover_audio_missing'),
          '旁白音频未就绪',
        );
        expect(shortVideoExportIssueLabel(zh, 'voiceover_not_ready'), '配音未就绪');
        expect(
          shortVideoExportIssueLabel(zh, 'duration_not_explicit'),
          '时长未标明（导出默认）',
        );
        expect(shortVideoExportIssueLabel(zh, 'duration_not_set'), '时长未设定');
        expect(shortVideoExportIssueLabel(zh, 'duration_unparsable'), '时长格式异常');
        expect(
          shortVideoExportIssueLabel(zh, 'completion_uncertain'),
          '成片状态未标「已完成」',
        );
        expect(shortVideoExportIssueLabel(zh, 'unknown_code'), 'unknown_code');
      });
    });

    group('Progress Tracking', () {
      test('Progress tracking shows loading state correctly', () {
        final ui = buildShortVideoExportCheckPanelUi(
          l10n: zh,
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

      test('Progress tracking shows unavailable state when no data', () {
        final ui = buildShortVideoExportCheckPanelUi(
          l10n: zh,
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

      test('Progress tracking hides when no project selected', () {
        final ui = buildShortVideoExportCheckPanelUi(
          l10n: zh,
          projectSelected: false,
          loadingProjectOverview: false,
          exportCheck: null,
        );

        expect(ui.visible, false);
      });

      test('Progress tracking correctly displays metrics', () {
        final exportCheck = ProjectShortVideoExportCheck(
          schemaVersion: 1,
          dataVersion: '2024-01-01T00:00:00Z',
          exportReady: true,
          summary: const ShortVideoExportCheckSummary(
            storyboardCount: 25,
            blockingIssueCount: 3,
            warningIssueCount: 7,
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

        expect(ui.metrics, hasLength(4));
        expect(ui.metrics[0].label, '分镜');
        expect(ui.metrics[0].value, '25');
        expect(ui.metrics[1].label, '阻塞');
        expect(ui.metrics[1].value, '3');
        expect(ui.metrics[2].label, '提醒');
        expect(ui.metrics[2].value, '7');
        expect(ui.metrics[3].label, '可导出');
        expect(ui.metrics[3].value, '是');
      });

      test(
        'Progress tracking correctly updates export ready status in metrics',
        () {
          final exportCheck = ProjectShortVideoExportCheck(
            schemaVersion: 1,
            dataVersion: '2024-01-01T00:00:00Z',
            exportReady: false,
            summary: const ShortVideoExportCheckSummary(
              storyboardCount: 10,
              blockingIssueCount: 1,
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

          expect(ui.metrics[3].label, '可导出');
          expect(ui.metrics[3].value, '否');
        },
      );

      test('Progress tracking correctly handles zero blocking issues', () {
        final exportCheck = ProjectShortVideoExportCheck(
          schemaVersion: 1,
          dataVersion: '2024-01-01T00:00:00Z',
          exportReady: true,
          summary: const ShortVideoExportCheckSummary(
            storyboardCount: 15,
            blockingIssueCount: 0,
            warningIssueCount: 5,
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

        expect(ui.exportReady, true);
        expect(ui.metrics[1].value, '0');
        expect(ui.blockingLines, isEmpty);
      });
    });

    group('History Viewing', () {
      test('History viewing correctly displays blocking issues', () {
        final exportCheck = ProjectShortVideoExportCheck(
          schemaVersion: 1,
          dataVersion: '2024-01-01T00:00:00Z',
          exportReady: false,
          summary: const ShortVideoExportCheckSummary(
            storyboardCount: 10,
            blockingIssueCount: 2,
            warningIssueCount: 0,
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
              scriptNumericId: 2,
              storyboardId: '00000000-0000-0000-0000-000000000201',
              storyboardNumericId: 201,
              sbIndex: 2,
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
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          exportCheck: exportCheck,
        );

        expect(ui.blockingLines, hasLength(2));
        expect(ui.blockingLines[0], contains('剧本 #1'));
        expect(ui.blockingLines[0], contains('分镜 #101'));
        expect(ui.blockingLines[0], contains('序 1'));
        expect(ui.blockingLines[0], contains('未选成片媒体'));
        expect(ui.blockingLines[1], contains('剧本 #2'));
        expect(ui.blockingLines[1], contains('分镜 #201'));
        expect(ui.blockingLines[1], contains('序 2'));
        expect(ui.blockingLines[1], contains('时长未设定'));
      });

      test('History viewing correctly displays warning issues', () {
        final exportCheck = ProjectShortVideoExportCheck(
          schemaVersion: 1,
          dataVersion: '2024-01-01T00:00:00Z',
          exportReady: true,
          summary: const ShortVideoExportCheckSummary(
            storyboardCount: 10,
            blockingIssueCount: 0,
            warningIssueCount: 2,
          ),
          issues: const [
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
              severity: 'warning',
              code: 'voiceover_not_ready',
              detail: '配音未就绪',
              scriptNumericId: 2,
              storyboardId: '00000000-0000-0000-0000-000000000202',
              storyboardNumericId: 202,
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
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          exportCheck: exportCheck,
        );

        expect(ui.warningLines, hasLength(2));
        expect(ui.warningLines[0], contains('分镜 #102'));
        expect(ui.warningLines[0], contains('序 2'));
        expect(ui.warningLines[0], contains('字幕为空'));
        expect(ui.warningLines[1], contains('分镜 #202'));
        expect(ui.warningLines[1], contains('序 3'));
        expect(ui.warningLines[1], contains('配音未就绪'));
      });

      test(
        'History viewing correctly handles mixed blocking and warning issues',
        () {
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
            ],
            qualityGate: const ShortVideoExportQualityGate(
              schemaVersion: 1,
              strategy: 'warn',
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

          expect(ui.exportReady, false);
          expect(ui.blockingLines, hasLength(2));
          expect(ui.warningLines, hasLength(1));
          expect(ui.qualityGateLine, contains('警告模式'));
        },
      );

      test('History viewing limits blocking lines to 14 maximum', () {
        final issues = List<ShortVideoExportCheckIssue>.generate(
          20,
          (i) => ShortVideoExportCheckIssue(
            severity: 'blocking',
            code: 'test_issue_$i',
            detail: '测试问题 $i',
            scriptNumericId: 1,
            storyboardId:
                '00000000-0000-0000-0000-0000000001${i.toString().padLeft(2, '0')}',
            storyboardNumericId: 100 + i,
            sbIndex: i,
          ),
        );

        final exportCheck = ProjectShortVideoExportCheck(
          schemaVersion: 1,
          dataVersion: '2024-01-01T00:00:00Z',
          exportReady: false,
          summary: const ShortVideoExportCheckSummary(
            storyboardCount: 20,
            blockingIssueCount: 20,
            warningIssueCount: 0,
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
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          exportCheck: exportCheck,
        );

        expect(ui.blockingLines.length, lessThanOrEqualTo(14));
      });

      test('History viewing limits warning lines to 14 maximum', () {
        final issues = List<ShortVideoExportCheckIssue>.generate(
          20,
          (i) => ShortVideoExportCheckIssue(
            severity: 'warning',
            code: 'test_warning_$i',
            detail: '测试警告 $i',
            scriptNumericId: 1,
            storyboardId:
                '00000000-0000-0000-0000-0000000001${i.toString().padLeft(2, '0')}',
            storyboardNumericId: 100 + i,
            sbIndex: i,
          ),
        );

        final exportCheck = ProjectShortVideoExportCheck(
          schemaVersion: 1,
          dataVersion: '2024-01-01T00:00:00Z',
          exportReady: true,
          summary: const ShortVideoExportCheckSummary(
            storyboardCount: 20,
            blockingIssueCount: 0,
            warningIssueCount: 20,
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
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          exportCheck: exportCheck,
        );

        expect(ui.warningLines.length, lessThanOrEqualTo(14));
      });

      test('History viewing correctly handles issues without sbIndex', () {
        final exportCheck = ProjectShortVideoExportCheck(
          schemaVersion: 1,
          dataVersion: '2024-01-01T00:00:00Z',
          exportReady: false,
          summary: const ShortVideoExportCheckSummary(
            storyboardCount: 10,
            blockingIssueCount: 1,
            warningIssueCount: 0,
          ),
          issues: const [
            ShortVideoExportCheckIssue(
              severity: 'blocking',
              code: 'missing_selected_media',
              detail: '未选择成片媒体',
              scriptNumericId: 1,
              storyboardId: '00000000-0000-0000-0000-000000000101',
              storyboardNumericId: 101,
              sbIndex: null,
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
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          exportCheck: exportCheck,
        );

        expect(ui.blockingLines, hasLength(1));
        expect(ui.blockingLines[0], contains('剧本 #1'));
        expect(ui.blockingLines[0], contains('分镜 #101'));
        expect(ui.blockingLines[0], isNot(contains('序')));
      });

      test(
        'History viewing correctly displays detail message for ready state',
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

          expect(ui.detail, contains('阻塞计数为 0'));
          expect(ui.detail, contains('服务端聚合路径上暂无硬阻塞'));
        },
      );

      test(
        'History viewing correctly displays detail message for not ready state',
        () {
          final exportCheck = ProjectShortVideoExportCheck(
            schemaVersion: 1,
            dataVersion: '2024-01-01T00:00:00Z',
            exportReady: false,
            summary: const ShortVideoExportCheckSummary(
              storyboardCount: 10,
              blockingIssueCount: 2,
              warningIssueCount: 1,
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

          expect(ui.detail, contains('下方列出部分阻塞项'));
          expect(ui.detail, contains('完整列表请在制作工作区逐镜核对'));
        },
      );
    });
  });
}
