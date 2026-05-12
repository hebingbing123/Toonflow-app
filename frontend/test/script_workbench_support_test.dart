import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/script_editor/support.dart';
import 'package:openflow_app/rust_api.dart';

final _zh = AppLocalizationsZh();

void main() {
  test('findScriptContextByNumericId returns matching row', () {
    final row = findScriptContextByNumericId(const [
      ScriptWorkbenchDetailRow(numericId: 1, relatedAssets: []),
      ScriptWorkbenchDetailRow(
        numericId: 7,
        name: 'target',
        relatedAssets: [],
      ),
    ], 7);

    expect(row?.name, 'target');
  });

  test('findScriptExtractStateByNumericId returns matching row', () {
    final row = findScriptExtractStateByNumericId(const [
      ScriptExtractStatePollRow(numericId: 3, extractState: 0),
      ScriptExtractStatePollRow(
        numericId: 9,
        extractState: -1,
        errorReason: 'llm_not_configured',
      ),
    ], 9);

    expect(row?.extractState, -1);
    expect(row?.errorReason, 'llm_not_configured');
  });

  test('describeScriptExtractState renders empty and error variants', () {
    expect(describeScriptExtractState(_zh), _zh.projectEditorScriptsExtractStateEmpty);
    expect(
      describeScriptExtractState(
        _zh,
        extractState: -1,
        errorReason: 'llm_not_configured',
      ),
      _zh.projectEditorScriptsExtractStateLine(-1, ' · llm_not_configured'),
    );
  });

  test('summarizeRelatedScriptAssets compacts long asset list', () {
    final summary = summarizeRelatedScriptAssets(const [
      ScriptRelatedAssetBrief(numericId: 1, name: '角色 A'),
      ScriptRelatedAssetBrief(numericId: 2, name: '场景 B'),
      ScriptRelatedAssetBrief(numericId: 3, name: '道具 C'),
      ScriptRelatedAssetBrief(numericId: 4, name: '镜头 D'),
      ScriptRelatedAssetBrief(numericId: 5, name: '音乐 E'),
    ]);

    expect(summary, '角色 A、场景 B、道具 C、镜头 D 等 5 项');
  });

  test('diagnoseScriptWorkbench suggests sync before any snapshot exists', () {
    final diagnosis = diagnoseScriptWorkbench(_zh);

    expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisSingleNoSnapshotSummary);
    expect(
      diagnosis.recommendedAction,
      ScriptWorkbenchRecommendedAction.syncWorkbench,
    );
  });

  test('diagnoseScriptWorkbench suggests retry when extract failed', () {
    final diagnosis = diagnoseScriptWorkbench(
      _zh,
      scriptContext: const ScriptWorkbenchDetailRow(
        numericId: 7,
        relatedAssets: [],
      ),
      extractStateRow: const ScriptExtractStatePollRow(
        numericId: 7,
        extractState: -1,
        errorReason: 'llm_not_configured',
      ),
    );

    expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisSingleExtractFailedSummary);
    expect(diagnosis.detail, contains('llm_not_configured'));
    expect(
      diagnosis.recommendedAction,
      ScriptWorkbenchRecommendedAction.startExtractAssets,
    );
  });

  test('diagnoseScriptWorkbench suggests polling while extract runs', () {
    final diagnosis = diagnoseScriptWorkbench(
      _zh,
      scriptContext: const ScriptWorkbenchDetailRow(
        numericId: 7,
        relatedAssets: [],
      ),
      extractStateRow: const ScriptExtractStatePollRow(
        numericId: 7,
        extractState: 2,
      ),
    );

    expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisSingleExtractRunningSummary);
    expect(
      diagnosis.recommendedAction,
      ScriptWorkbenchRecommendedAction.pollExtractState,
    );
  });

  test('diagnoseScriptWorkbench suggests extract when no assets exist', () {
    final diagnosis = diagnoseScriptWorkbench(
      _zh,
      scriptContext: const ScriptWorkbenchDetailRow(
        numericId: 7,
        extractState: 0,
        relatedAssets: [],
      ),
    );

    expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisSingleNoAssetsSummary);
    expect(
      diagnosis.recommendedAction,
      ScriptWorkbenchRecommendedAction.startExtractAssets,
    );
  });

  test(
    'diagnoseScriptWorkbench suggests image workbench when assets exist',
    () {
      final diagnosis = diagnoseScriptWorkbench(
        _zh,
        scriptContext: const ScriptWorkbenchDetailRow(
          numericId: 7,
          extractState: 0,
          relatedAssets: [
            ScriptRelatedAssetBrief(numericId: 1, name: '角色 A'),
          ],
        ),
      );

      expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisSingleHasAssetsSummary);
      expect(
        diagnosis.recommendedAction,
        ScriptWorkbenchRecommendedAction.openEditImageWorkbench,
      );
    },
  );

  test('buildScriptWorkbenchFollowUp appends next step guidance', () {
    final diagnosis = diagnoseScriptWorkbench(
      _zh,
      scriptContext: const ScriptWorkbenchDetailRow(
        numericId: 7,
        extractState: 0,
        relatedAssets: [],
      ),
    );

    expect(
      buildScriptWorkbenchFollowUp(
        _zh,
        actionSummary: '已同步当前剧本。',
        diagnosis: diagnosis,
      ),
      contains('下一步建议：${_zh.projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets}'),
    );
  });

  test(
    'diagnoseScriptBatchWorkbench suggests sync when selection is empty',
    () {
      final diagnosis = diagnoseScriptBatchWorkbench(
        _zh,
        selectedIds: const [],
        scripts: const [],
        previewRows: const [],
      );

      expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisBatchEmptySummary);
      expect(
        diagnosis.recommendedAction,
        ScriptBatchWorkbenchRecommendedAction.syncContext,
      );
    },
  );

  test('diagnoseScriptBatchWorkbench suggests polling for running rows', () {
    final diagnosis = diagnoseScriptBatchWorkbench(
      _zh,
      selectedIds: const [3, 4],
      scripts: const [
        ScriptBrief(numericId: 3, extractState: 2),
        ScriptBrief(numericId: 4, extractState: 0),
      ],
      previewRows: const [],
    );

    expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisBatchRunningSummary(1));
    expect(
      diagnosis.recommendedAction,
      ScriptBatchWorkbenchRecommendedAction.pollSelected,
    );
  });

  test(
    'diagnoseScriptBatchWorkbench suggests syncing context before asset-aware actions',
    () {
      final diagnosis = diagnoseScriptBatchWorkbench(
        _zh,
        selectedIds: const [3, 4],
        scripts: const [
          ScriptBrief(numericId: 3, extractState: 0),
          ScriptBrief(numericId: 4, extractState: 0),
        ],
        previewRows: const [],
      );

      expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisBatchMissingContextSummary(2));
      expect(
        diagnosis.recommendedAction,
        ScriptBatchWorkbenchRecommendedAction.syncContext,
      );
    },
  );

  test('diagnoseScriptBatchWorkbench suggests retry for failed rows', () {
    final diagnosis = diagnoseScriptBatchWorkbench(
      _zh,
      selectedIds: const [3, 4],
      scripts: const [
        ScriptBrief(numericId: 3, extractState: -1),
        ScriptBrief(numericId: 4, extractState: 0),
      ],
      previewRows: const [],
    );

    expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisBatchFailedSummary(1));
    expect(
      diagnosis.recommendedAction,
      ScriptBatchWorkbenchRecommendedAction.startExtractSelected,
    );
  });

  test(
    'diagnoseScriptBatchWorkbench suggests export when all preview rows have assets',
    () {
      final diagnosis = diagnoseScriptBatchWorkbench(
        _zh,
        selectedIds: const [7, 8],
        scripts: const [
          ScriptBrief(numericId: 7, extractState: 0),
          ScriptBrief(numericId: 8, extractState: 0),
        ],
        previewRows: const [
          ScriptWorkbenchDetailRow(
            numericId: 7,
            relatedAssets: [
              ScriptRelatedAssetBrief(numericId: 1, name: '角色 A'),
            ],
          ),
          ScriptWorkbenchDetailRow(
            numericId: 8,
            relatedAssets: [
              ScriptRelatedAssetBrief(numericId: 2, name: '场景 B'),
            ],
          ),
        ],
      );

      expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisBatchAllAssetsSummary(2));
      expect(
        diagnosis.recommendedAction,
        ScriptBatchWorkbenchRecommendedAction.exportSelectedZip,
      );
    },
  );

  test(
    'diagnoseScriptBatchWorkbench suggests extract when assets are still missing',
    () {
      final diagnosis = diagnoseScriptBatchWorkbench(
        _zh,
        selectedIds: const [7, 8],
        scripts: const [
          ScriptBrief(numericId: 7, extractState: 0),
          ScriptBrief(numericId: 8, extractState: 0),
        ],
        previewRows: const [
          ScriptWorkbenchDetailRow(
            numericId: 7,
            relatedAssets: [
              ScriptRelatedAssetBrief(numericId: 1, name: '角色 A'),
            ],
          ),
        ],
      );

      expect(diagnosis.summary, _zh.projectEditorScriptsDiagnosisBatchMissingContextSummary(2));
      expect(
        diagnosis.recommendedAction,
        ScriptBatchWorkbenchRecommendedAction.syncContext,
      );
    },
  );

  test('buildScriptBatchWorkbenchFollowUp appends next step guidance', () {
    final diagnosis = diagnoseScriptBatchWorkbench(
      _zh,
      selectedIds: const [3, 4],
      scripts: const [
        ScriptBrief(numericId: 3, extractState: 2),
        ScriptBrief(numericId: 4, extractState: 0),
      ],
      previewRows: const [],
    );

    expect(
      buildScriptBatchWorkbenchFollowUp(
        _zh,
        actionSummary: '已提交 2 条剧本素材抽取。',
        diagnosis: diagnosis,
      ),
      contains('下一步建议：${_zh.projectEditorScriptsWorkbenchRecommendPollSelected}'),
    );
  });

  test('formatBinarySize formats bytes into readable units', () {
    expect(formatBinarySize(512), '512 B');
    expect(formatBinarySize(1536), '1.5 KB');
    expect(formatBinarySize(2 * 1024 * 1024), '2.0 MB');
  });

  test('parseNumericIdSelection keeps unique positive ids in order', () {
    expect(parseNumericIdSelection('9, 2\n0, x, 9, 4'), [9, 2, 4]);
  });

  test('encodeNumericIdSelection joins ids for text fields', () {
    expect(encodeNumericIdSelection(const [3, 8, 13]), '3,8,13');
  });

  test('syncScriptExtractStates updates matching scripts only', () {
    final synced = syncScriptExtractStates(
      const [
        ScriptBrief(numericId: 1, name: 'a', extractState: 0),
        ScriptBrief(numericId: 2, name: 'b', extractState: 0),
      ],
      const [ScriptExtractStatePollRow(numericId: 2, extractState: -1)],
    );

    expect(synced.first.extractState, 0);
    expect(synced.last.extractState, -1);
  });

  test('syncScriptPreviewExtractStates updates preview rows only', () {
    final synced = syncScriptPreviewExtractStates(
      const [
        ScriptWorkbenchDetailRow(
          numericId: 1,
          extractState: 0,
          relatedAssets: [],
        ),
        ScriptWorkbenchDetailRow(
          numericId: 2,
          extractState: 0,
          relatedAssets: [],
        ),
      ],
      const [
        ScriptExtractStatePollRow(
          numericId: 2,
          extractState: -1,
          errorReason: 'failed',
        ),
      ],
    );

    expect(synced.first.extractState, 0);
    expect(synced.last.extractState, -1);
    expect(synced.last.errorReason, 'failed');
  });

  test('buildBatchAddScriptItems uses prefix and starting index', () {
    final items = buildBatchAddScriptItems(
      count: 3,
      startingIndex: 5,
      prefix: '批量剧本',
      scriptData: 'content',
    );

    expect(items.map((item) => item.toJson()['scriptName']), [
      '批量剧本 5',
      '批量剧本 6',
      '批量剧本 7',
    ]);
  });
}
