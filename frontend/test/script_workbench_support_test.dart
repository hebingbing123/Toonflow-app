import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/script_workbench_support.dart';
import 'package:toonflow_app/rust_api.dart';

void main() {
  test('findScriptContextByLegacyId returns matching row', () {
    final row = findScriptContextByLegacyId(const [
      LegacyScriptsGetScriptApiItem(legacyId: 1, relatedAssets: []),
      LegacyScriptsGetScriptApiItem(
        legacyId: 7,
        name: 'target',
        relatedAssets: [],
      ),
    ], 7);

    expect(row?.name, 'target');
  });

  test('findScriptExtractStateByLegacyId returns matching row', () {
    final row = findScriptExtractStateByLegacyId(const [
      ScriptExtractStatePollRow(legacyId: 3, extractState: 0),
      ScriptExtractStatePollRow(
        legacyId: 9,
        extractState: -1,
        errorReason: 'llm_not_configured',
      ),
    ], 9);

    expect(row?.extractState, -1);
    expect(row?.errorReason, 'llm_not_configured');
  });

  test('describeScriptExtractState renders empty and error variants', () {
    expect(describeScriptExtractState(), '当前脚本提取状态为空：通常表示 idle 或已完成。');
    expect(
      describeScriptExtractState(
        extractState: -1,
        errorReason: 'llm_not_configured',
      ),
      '提取状态 -1 · llm_not_configured',
    );
  });

  test('summarizeRelatedScriptAssets compacts long asset list', () {
    final summary = summarizeRelatedScriptAssets(const [
      LegacyScriptRelatedAssetBrief(legacyId: 1, name: '角色 A'),
      LegacyScriptRelatedAssetBrief(legacyId: 2, name: '场景 B'),
      LegacyScriptRelatedAssetBrief(legacyId: 3, name: '道具 C'),
      LegacyScriptRelatedAssetBrief(legacyId: 4, name: '镜头 D'),
      LegacyScriptRelatedAssetBrief(legacyId: 5, name: '音乐 E'),
    ]);

    expect(summary, '角色 A、场景 B、道具 C、镜头 D 等 5 项');
  });

  test('diagnoseScriptWorkbench suggests sync before any snapshot exists', () {
    final diagnosis = diagnoseScriptWorkbench();

    expect(diagnosis.summary, '还没有当前剧本的工作台快照。');
    expect(
      diagnosis.recommendedAction,
      ScriptWorkbenchRecommendedAction.syncWorkbench,
    );
  });

  test('diagnoseScriptWorkbench suggests retry when extract failed', () {
    final diagnosis = diagnoseScriptWorkbench(
      scriptContext: const LegacyScriptsGetScriptApiItem(
        legacyId: 7,
        relatedAssets: [],
      ),
      extractStateRow: const ScriptExtractStatePollRow(
        legacyId: 7,
        extractState: -1,
        errorReason: 'llm_not_configured',
      ),
    );

    expect(diagnosis.summary, '素材提取最近一次执行失败。');
    expect(diagnosis.detail, contains('llm_not_configured'));
    expect(
      diagnosis.recommendedAction,
      ScriptWorkbenchRecommendedAction.startExtractAssets,
    );
  });

  test('diagnoseScriptWorkbench suggests polling while extract runs', () {
    final diagnosis = diagnoseScriptWorkbench(
      scriptContext: const LegacyScriptsGetScriptApiItem(
        legacyId: 7,
        relatedAssets: [],
      ),
      extractStateRow: const ScriptExtractStatePollRow(
        legacyId: 7,
        extractState: 2,
      ),
    );

    expect(diagnosis.summary, '素材提取正在进行中。');
    expect(
      diagnosis.recommendedAction,
      ScriptWorkbenchRecommendedAction.pollExtractState,
    );
  });

  test('diagnoseScriptWorkbench suggests extract when no assets exist', () {
    final diagnosis = diagnoseScriptWorkbench(
      scriptContext: const LegacyScriptsGetScriptApiItem(
        legacyId: 7,
        extractState: 0,
        relatedAssets: [],
      ),
    );

    expect(diagnosis.summary, '当前剧本还没有关联素材。');
    expect(
      diagnosis.recommendedAction,
      ScriptWorkbenchRecommendedAction.startExtractAssets,
    );
  });

  test(
    'diagnoseScriptWorkbench suggests image workbench when assets exist',
    () {
      final diagnosis = diagnoseScriptWorkbench(
        scriptContext: const LegacyScriptsGetScriptApiItem(
          legacyId: 7,
          extractState: 0,
          relatedAssets: [
            LegacyScriptRelatedAssetBrief(legacyId: 1, name: '角色 A'),
          ],
        ),
      );

      expect(diagnosis.summary, '当前剧本已有关联素材。');
      expect(
        diagnosis.recommendedAction,
        ScriptWorkbenchRecommendedAction.openEditImageWorkbench,
      );
    },
  );

  test('buildScriptWorkbenchFollowUp appends next step guidance', () {
    final diagnosis = diagnoseScriptWorkbench(
      scriptContext: const LegacyScriptsGetScriptApiItem(
        legacyId: 7,
        extractState: 0,
        relatedAssets: [],
      ),
    );

    expect(
      buildScriptWorkbenchFollowUp(
        actionSummary: '已同步当前剧本。',
        diagnosis: diagnosis,
      ),
      contains('下一步建议：提取当前剧本素材。'),
    );
  });

  test(
    'diagnoseScriptBatchWorkbench suggests sync when selection is empty',
    () {
      final diagnosis = diagnoseScriptBatchWorkbench(
        selectedIds: const [],
        scripts: const [],
        previewRows: const [],
      );

      expect(diagnosis.summary, '还没有选择要处理的剧本。');
      expect(
        diagnosis.recommendedAction,
        ScriptBatchWorkbenchRecommendedAction.syncContext,
      );
    },
  );

  test('diagnoseScriptBatchWorkbench suggests polling for running rows', () {
    final diagnosis = diagnoseScriptBatchWorkbench(
      selectedIds: const [3, 4],
      scripts: const [
        ScriptBrief(legacyId: 3, extractState: 2),
        ScriptBrief(legacyId: 4, extractState: 0),
      ],
      previewRows: const [],
    );

    expect(diagnosis.summary, '所选剧本里有 1 条仍在提取中。');
    expect(
      diagnosis.recommendedAction,
      ScriptBatchWorkbenchRecommendedAction.pollSelected,
    );
  });

  test('diagnoseScriptBatchWorkbench suggests retry for failed rows', () {
    final diagnosis = diagnoseScriptBatchWorkbench(
      selectedIds: const [3, 4],
      scripts: const [
        ScriptBrief(legacyId: 3, extractState: -1),
        ScriptBrief(legacyId: 4, extractState: 0),
      ],
      previewRows: const [],
    );

    expect(diagnosis.summary, '所选剧本里有 1 条最近提取失败。');
    expect(
      diagnosis.recommendedAction,
      ScriptBatchWorkbenchRecommendedAction.startExtractSelected,
    );
  });

  test(
    'diagnoseScriptBatchWorkbench suggests export when all preview rows have assets',
    () {
      final diagnosis = diagnoseScriptBatchWorkbench(
        selectedIds: const [7, 8],
        scripts: const [
          ScriptBrief(legacyId: 7, extractState: 0),
          ScriptBrief(legacyId: 8, extractState: 0),
        ],
        previewRows: const [
          LegacyScriptsGetScriptApiItem(
            legacyId: 7,
            relatedAssets: [
              LegacyScriptRelatedAssetBrief(legacyId: 1, name: '角色 A'),
            ],
          ),
          LegacyScriptsGetScriptApiItem(
            legacyId: 8,
            relatedAssets: [
              LegacyScriptRelatedAssetBrief(legacyId: 2, name: '场景 B'),
            ],
          ),
        ],
      );

      expect(diagnosis.summary, '所选 2 条剧本都已有关联素材。');
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
        selectedIds: const [7, 8],
        scripts: const [
          ScriptBrief(legacyId: 7, extractState: 0),
          ScriptBrief(legacyId: 8, extractState: 0),
        ],
        previewRows: const [
          LegacyScriptsGetScriptApiItem(
            legacyId: 7,
            relatedAssets: [
              LegacyScriptRelatedAssetBrief(legacyId: 1, name: '角色 A'),
            ],
          ),
        ],
      );

      expect(diagnosis.summary, '所选 2 条剧本仍有待抽取素材的项。');
      expect(
        diagnosis.recommendedAction,
        ScriptBatchWorkbenchRecommendedAction.startExtractSelected,
      );
    },
  );

  test('buildScriptBatchWorkbenchFollowUp appends next step guidance', () {
    final diagnosis = diagnoseScriptBatchWorkbench(
      selectedIds: const [3, 4],
      scripts: const [
        ScriptBrief(legacyId: 3, extractState: 2),
        ScriptBrief(legacyId: 4, extractState: 0),
      ],
      previewRows: const [],
    );

    expect(
      buildScriptBatchWorkbenchFollowUp(
        actionSummary: '已提交 2 条剧本素材抽取。',
        diagnosis: diagnosis,
      ),
      contains('下一步建议：轮询所选状态。'),
    );
  });

  test('formatBinarySize formats bytes into readable units', () {
    expect(formatBinarySize(512), '512 B');
    expect(formatBinarySize(1536), '1.5 KB');
    expect(formatBinarySize(2 * 1024 * 1024), '2.0 MB');
  });

  test('parseLegacyIdSelection keeps unique positive ids in order', () {
    expect(parseLegacyIdSelection('9, 2\n0, x, 9, 4'), [9, 2, 4]);
  });

  test('encodeLegacyIdSelection joins ids for text fields', () {
    expect(encodeLegacyIdSelection(const [3, 8, 13]), '3,8,13');
  });

  test('syncScriptExtractStates updates matching scripts only', () {
    final synced = syncScriptExtractStates(
      const [
        ScriptBrief(legacyId: 1, name: 'a', extractState: 0),
        ScriptBrief(legacyId: 2, name: 'b', extractState: 0),
      ],
      const [ScriptExtractStatePollRow(legacyId: 2, extractState: -1)],
    );

    expect(synced.first.extractState, 0);
    expect(synced.last.extractState, -1);
  });

  test('syncScriptPreviewExtractStates updates preview rows only', () {
    final synced = syncScriptPreviewExtractStates(
      const [
        LegacyScriptsGetScriptApiItem(
          legacyId: 1,
          extractState: 0,
          relatedAssets: [],
        ),
        LegacyScriptsGetScriptApiItem(
          legacyId: 2,
          extractState: 0,
          relatedAssets: [],
        ),
      ],
      const [
        ScriptExtractStatePollRow(
          legacyId: 2,
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
