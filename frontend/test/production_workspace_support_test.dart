import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/contexts/production/flow_logic.dart';
import 'package:openflow_app/agent_workspaces/contexts/production/support.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';

final _zh = AppLocalizationsZh();

void main() {
  test('summarizeProductionFlowValue counts prompt and media rows', () {
    final lines = summarizeProductionFlowValue(_zh, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'prompt': 'scene one',
        'src': 'https://example.com/1.png',
        'state': 'done',
      },
      <String, dynamic>{'id': 2, 'prompt': 'scene two', 'state': 'queued'},
    ]);

    expect(lines, contains('列表 2 项'));
    expect(lines, contains('提示词 2'));
    expect(lines, contains('媒体 URL 1'));
    expect(lines, contains('状态类型 2'));
  });

  test('summarizeProductionFlowValue surfaces asset readiness digest', () {
    final lines = summarizeProductionFlowValue(_zh, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': '角色A',
        'src': 'https://example.com/a.png',
        'derive': <Map<String, dynamic>>[
          <String, dynamic>{'id': 11},
        ],
      },
      <String, dynamic>{'id': 2, 'name': '角色B'},
    ], flowKey: 'assets');

    expect(lines, contains('主资产 1/2 已就绪，衍生缺口 1 项，主资产待补 1 项'));
  });

  test(
    'summarizeProductionFlowValue surfaces storyboard generation digest',
    () {
      final lines = summarizeProductionFlowValue(_zh, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'prompt': 'scene one',
          'shouldGenerateImage': true,
        },
        <String, dynamic>{
          'id': 2,
          'prompt': 'scene two',
          'src': 'https://example.com/2.png',
          'shouldGenerateImage': 1,
          'state': 'done',
        },
        <String, dynamic>{
          'id': 3,
          'prompt': 'scene three',
          'shouldGenerateImage': false,
        },
      ], flowKey: 'storyboard');

      expect(lines, contains('列表 3 项'));
      expect(lines, contains('画面结果 1/2 已就绪，待补帧 1 项，纯文本 1 项'));
      expect(lines, contains('需要图片 2'));
      expect(lines, contains('缺帧 1 项'));
      expect(lines, contains('纯文本 1'));
    },
  );

  test(
    'buildProductionWorkspaceRecipes suggests derive-assets for empty assets',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'assets',
        result: <String, dynamic>{'data': <dynamic>[]},
      );

      expect(recipes, hasLength(1));
      expect(recipes.first.subAgentTool, 'run_sub_agent_derive_assets');
      expect(recipes.first.flowKey, 'assets');
    },
  );

  test(
    'buildProductionWorkspaceRecipes suggests storyboard generation when images missing',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'prompt': 'scene one',
              'associateAssetsIds': <int>[12, 7],
            },
            <String, dynamic>{
              'id': 2,
              'prompt': 'scene two',
              'src': 'https://example.com/2.png',
            },
          ],
        },
      );

      expect(recipes.first.subAgentTool, 'run_sub_agent_storyboard_gen');
      expect(recipes.first.flowKey, 'storyboard');
      expect(recipes.first.prompt, contains('仅看这 2 个关联资产'));
      expect(recipes[1].title, '核对关联资产');
      expect(recipes[1].domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[7, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
    },
  );

  test('buildProductionWorkspaceRecipes suggests supervising script plan', () {
    final recipes = buildProductionWorkspaceRecipes(
      toolName: 'get_flowData',
      suggestedFlowKey: 'scriptPlan',
      result: <String, dynamic>{'data': '<scriptPlan>已有导演规划</scriptPlan>'},
    );

    expect(recipes.first.subAgentTool, 'run_sub_agent_production_supervision');
    expect(recipes.first.flowKey, 'scriptPlan');
    expect(recipes.first.title, contains('审核'));
    expect(recipes[1].title, '回看剧本依据');
    expect(recipes[1].domainArgs, <String, dynamic>{
      'key': 'script',
      'lineStart': 1,
      'lineEnd': 48,
      'maxChars': 1400,
    });
    expect(recipes[2].title, '检查关键资产');
    expect(recipes[2].domainArgs, <String, dynamic>{
      'key': 'assets',
      'assetTypes': <String>['role', 'scene'],
      'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      'limit': 12,
    });
    expect(recipes[3].title, '继续导演计划');
    expect(recipes[3].subAgentTool, 'run_sub_agent_director_plan');
    expect(recipes[3].subAgentArgs, <String, dynamic>{
      'assetTypes': <String>['role', 'scene'],
    });
    expect(recipes[4].domainArgs, <String, dynamic>{
      'key': 'storyboardTable',
      'fields': <String>[
        'id',
        'description',
        'scene',
        'duration',
        'camera',
        'associateAssetsIds',
      ],
      'rowStart': 1,
      'rowCount': 8,
    });
    expect(recipes[4].flowKey, 'storyboardTable');
    expect(recipes[4].title, '先看分镜表落地');
  });

  test(
    'summarizeProductionFlowValue marks script plan rewrite constraints as landed',
    () {
      final lines = summarizeProductionFlowValue(_zh, '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。
</scriptPlan>
''', flowKey: 'scriptPlan');

      expect(lines, contains('计划章节 1'));
      expect(lines, contains('改写约束下沉'));
    },
  );

  test(
    'buildProductionWorkspaceRecipes adds tool asset scope when script plan mentions props',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
④ 分场景情绪与画面意图
重点核对玉佩与令牌这类道具状态，避免镜头里错拿主资产。
</scriptPlan>
''',
        },
      );

      expect(recipes[2].domainArgs, <String, dynamic>{
        'key': 'assets',
        'assetTypes': <String>['role', 'scene', 'tool'],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
        'limit': 18,
      });
      expect(recipes[2].detail, contains('角色/场景/道具资产'));
    },
  );

  test(
    'buildProductionWorkspaceRecipes narrows script plan asset checks to explicit ids',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
执行阶段先核对资产 #12、7 和 asset 5 的状态是否可直接上镜。
</scriptPlan>
''',
        },
      );

      expect(recipes[2].domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[5, 7, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(recipes[2].detail, contains('资产 #5, 7, 12'));
      expect(recipes[3].subAgentArgs, <String, dynamic>{
        'assetIds': <int>[5, 7, 12],
      });
      expect(recipes[3].prompt, contains('资产 #5, 7, 12'));
    },
  );

  test(
    'buildProductionPlanningScriptArgs exposes fixed compact script window',
    () {
      expect(buildProductionPlanningScriptArgs(), <String, dynamic>{
        'key': 'script',
        'lineStart': 1,
        'lineEnd': 48,
        'maxChars': 1400,
      });
      expect(summarizeProductionPlanningScriptWindow(), '剧本 1-48 行（<=1400 字）');
    },
  );

  test(
    'buildProductionWorkspaceRecipes adds compact script reread before script-plan follow-ups',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{'data': '<scriptPlan>已有导演规划</scriptPlan>'},
      );

      expect(recipes[1].title, '回看剧本依据');
      expect(recipes[1].flowKey, 'script');
      expect(recipes[1].domainArgs, <String, dynamic>{
        'key': 'script',
        'lineStart': 1,
        'lineEnd': 48,
        'maxChars': 1400,
      });
      expect(recipes[1].detail, contains('剧本 1-48 行（<=1400 字）'));
      expect(recipes[2].title, '检查关键资产');
    },
  );

  test(
    'buildProductionWorkspaceRecipes asks to refine scene intent before reading storyboard table',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。
② 核心人物与关系拉扯
角色关系要有压迫和反制，不要平均输出。
③ 叙事结构与节奏规划
前段尽快起冲突，中段连续抬压，结尾留钩子。
</scriptPlan>
''',
        },
      );

      expect(recipes.last.title, '补足分场景意图');
      expect(recipes.last.flowKey, 'storyboardTable');
      expect(recipes.last.subAgentTool, 'run_sub_agent_director_plan');
      expect(recipes.last.domainTool, isNull);
      expect(recipes.last.prompt, contains('分场景情绪推进'));
      expect(recipes.last.detail, contains('先补这层'));
    },
  );

  test(
    'extractProductionActionCandidateIds restores asset ids from sub-agent prompt scope',
    () {
      final ids = extractProductionActionCandidateIds(
        selectedTool: 'generate_deriveAsset',
        toolName: 'run_sub_agent_generate_assets',
        suggestedFlowKey: 'assets',
        result: <String, dynamic>{'result': 'done'},
        toolArguments: <String, dynamic>{
          'prompt': '请先检查并补跑。优先处理 asset ids=12, 7, 5，不要扩读其他素材。',
        },
      );

      expect(ids, <int>[5, 7, 12]);
    },
  );

  test(
    'buildProductionSuggestedSubAgentArgs narrows derive-assets from script plan asset ids',
    () {
      final args = buildProductionSuggestedSubAgentArgs(
        subAgentTool: 'run_sub_agent_derive_assets',
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
先核对资产 #12、7 和 asset 5，再补齐缺失衍生素材。
</scriptPlan>
''',
        },
      );

      expect(args, <String, dynamic>{
        'assetIds': <int>[5, 7, 12],
      });
    },
  );

  test(
    'buildProductionSuggestedSubAgentArgs narrows storyboard generation to missing shots and related assets',
    () {
      final args = buildProductionSuggestedSubAgentArgs(
        subAgentTool: 'run_sub_agent_storyboard_gen',
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 11,
              'associateAssetsIds': <int>[7, 12],
              'shouldGenerateImage': true,
            },
            <String, dynamic>{
              'id': 12,
              'src': 'https://example.com/12.png',
              'associateAssetsIds': <int>[30],
              'shouldGenerateImage': true,
            },
          ],
        },
      );

      expect(args, <String, dynamic>{
        'storyboardIds': <int>[11],
        'assetIds': <int>[7, 12],
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes narrows asset refresh after asset sub-agent run',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_generate_assets',
        suggestedFlowKey: 'assets',
        result: <String, dynamic>{'result': '已完成'},
        toolArguments: <String, dynamic>{
          'prompt': '先检查 asset ids=12,7，再决定是否补跑。',
        },
      );

      expect(recipes.first.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[7, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(recipes.first.detail, contains('资产 #7, 12'));
    },
  );

  test(
    'buildProductionWorkspaceStages narrows storyboard refresh after sub-agent run',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_storyboard_gen',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{'result': '已完成'},
        toolArguments: <String, dynamic>{
          'prompt': '优先处理 storyboard ids=3, 9, 4，不要重跑已有结果。',
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'fields': <String>[
          'id',
          'index',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
        'ids': <int>[3, 4, 9],
      });
      expect(storyboardStage.detail, contains('镜头 #3, 4, 9'));
    },
  );

  test(
    'buildProductionWorkspaceStages include focused asset ids in storyboard generation prompt',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 3,
              'associateAssetsIds': <int>[12, 7],
              'shouldGenerateImage': true,
            },
            <String, dynamic>{
              'id': 4,
              'associateAssetsIds': <int>[99],
              'src': 'https://example.com/4.png',
              'shouldGenerateImage': true,
            },
          ],
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.prompt, contains('仅看这 2 个关联资产'));
      expect(storyboardStage.prompt, isNot(contains('这 1 个关联资产')));
    },
  );

  test(
    'buildProductionWorkspaceRecipes narrows storyboard refresh after storyboard panel sub-agent run',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_storyboard_panel',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{'result': '已完成'},
        toolArguments: <String, dynamic>{
          'prompt': '请只处理 storyboard ids=8, 2，对已有结果不要重跑。',
        },
      );

      expect(recipes.first.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'fields': <String>[
          'id',
          'index',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
        'ids': <int>[2, 8],
      });
      expect(recipes.first.title, '回读缺帧状态');
      expect(recipes.first.detail, contains('镜头 #2, 8'));
      expect(recipes.first.detail, contains('缺帧状态'));
    },
  );

  test(
    'buildProductionWorkspaceStages narrows storyboard table refresh after storyboard-table sub-agent run',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_storyboard_table',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{'result': '已完成'},
        toolArguments: <String, dynamic>{
          'prompt': '先修订 storyboard ids=12, 4, 12 的分镜表行。',
        },
      );

      final storyboardTableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(storyboardTableStage.domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
        'ids': <int>[4, 12],
      });
      expect(storyboardTableStage.detail, contains('镜头 #4, 12'));
      expect(storyboardTableStage.detail, contains('局部分镜表行'));
    },
  );

  test(
    'buildProductionWorkspaceRecipes narrows storyboard table refresh after storyboard-table sub-agent run',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_storyboard_table',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{'result': '已完成'},
        toolArguments: <String, dynamic>{
          'prompt': '先修订 storyboard ids=12, 4, 12 的分镜表行。',
        },
      );

      expect(recipes.first.title, '回读局部分镜表');
      expect(recipes.first.detail, contains('局部分镜表行'));
      expect(recipes.first.domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
        'ids': <int>[4, 12],
      });
    },
  );

  test('parseProductionSupervisionReview reads structured review payload', () {
    final review = parseProductionSupervisionReview(<String, dynamic>{
      'review': <String, dynamic>{
        'target': 'storyboardTable',
        'grade': 'C',
        'severeCount': '1',
        'mediumCount': '2',
        'minorCount': '0',
        'nextAction': 'revise_storyboardTable',
        'summary': '分镜拆分过粗且关联资产缺失',
      },
    });

    expect(review, isNotNull);
    expect(review!.target, 'storyboardTable');
    expect(review.severeCount, 1);
    expect(review.nextAction, 'revise_storyboardTable');
    expect(review.assetIds, isEmpty);
    expect(review.assetTypes, isEmpty);
    expect(review.storyboardIds, isEmpty);
  });

  test(
    'parseProductionSupervisionReview reads asset type scope for check-assets follow-up',
    () {
      final review = parseProductionSupervisionReview(<String, dynamic>{
        'review': <String, dynamic>{
          'target': 'scriptPlan',
          'grade': 'B',
          'severeCount': '0',
          'mediumCount': '1',
          'minorCount': '0',
          'nextAction': 'check_assets',
          'summary': '先核对角色与场景资产',
          'assetTypes': 'scene,role,scene',
        },
      });

      expect(review, isNotNull);
      expect(review!.assetIds, isEmpty);
      expect(review.assetTypes, <String>['role', 'scene']);
    },
  );

  test(
    'parseProductionSupervisionReview reads storyboard ids for focused follow-up',
    () {
      final review = parseProductionSupervisionReview(<String, dynamic>{
        'review': <String, dynamic>{
          'target': 'storyboardTable',
          'grade': 'B',
          'severeCount': '0',
          'mediumCount': '1',
          'minorCount': '0',
          'nextAction': 'generate_storyboard',
          'summary': '只需补齐缺帧镜头',
          'storyboardIds': '9,3,9',
        },
      });

      expect(review, isNotNull);
      expect(review!.storyboardIds, <int>[3, 9]);
    },
  );

  test(
    'buildProductionStoryboardTableRevisionPrompt includes focused asset ids',
    () {
      final prompt = buildProductionStoryboardTableRevisionPrompt(
        const ProductionSupervisionReview(
          target: 'storyboardTable',
          grade: 'C',
          severeCount: 1,
          mediumCount: 0,
          minorCount: 0,
          nextAction: 'revise_storyboardTable',
          summary: '修正资产一致性',
          assetIds: <int>[7, 12, 7],
          assetTypes: <String>[],
          storyboardIds: <int>[3, 9],
        ),
      );

      expect(prompt, contains('仅看这 2 个关联资产'));
      expect(prompt, contains('优先处理这 2 个镜头'));
    },
  );

  test('buildProductionSubAgentArgs keeps normalized asset type scope', () {
    expect(
      buildProductionSubAgentArgs(
        storyboardIds: const <int>[9, 3, 9],
        assetIds: const <int>[12, 7, 12],
        assetTypes: const <String>['scene', 'tool', 'role', 'scene'],
      ),
      <String, dynamic>{
        'storyboardIds': <int>[3, 9],
        'assetIds': <int>[7, 12],
        'assetTypes': <String>['role', 'scene', 'tool'],
      },
    );
  });

  test('buildProductionStoryboardAssetHint caps long asset id lists', () {
    final hint = buildProductionStoryboardAssetHint(const <int>[
      9,
      1,
      7,
      3,
      5,
      11,
      13,
      15,
      17,
    ]);

    expect(hint, '如需核对素材，仅看这 9 个关联资产。');
  });

  test('buildProductionAssetGenerationPrompt caps long asset id lists', () {
    final prompt = buildProductionAssetGenerationPrompt(
      assetIds: const <int>[9, 1, 7, 3, 5, 11, 13, 15, 17],
    );

    expect(prompt, contains('请优先只核对并生成这 9 个资产'));
    expect(prompt, isNot(contains('ids=')));
  });

  test(
    'buildProductionScriptPlanExecutionHint compacts rewrite constraints for downstream prompts',
    () {
      final hint = buildProductionScriptPlanExecutionHint('''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，前两场快速立目标，但情绪不能像念提纲。
④ 分场景情绪与画面意图
人物情绪要有递进起伏，镜头别平均用力。
</scriptPlan>
''');

      expect(hint, contains('承接 scriptPlan'));
      expect(hint, contains('人物情绪保持递进'));
      expect(hint, contains('女主复仇线要压住爽感'));
    },
  );

  test(
    'buildProductionStoryboardGenerationPrompt caps long storyboard id lists',
    () {
      final prompt = buildProductionStoryboardGenerationPrompt(
        storyboardIds: const <int>[9, 1, 7, 3, 5, 11, 13, 15, 17],
      );

      expect(prompt, contains('优先处理这 9 个镜头'));
      expect(prompt, isNot(contains('ids=')));
    },
  );

  test(
    'buildProductionWorkspaceStages inject script-plan execution hint into asset and storyboard prompts',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_director_plan',
        suggestedFlowKey: null,
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'scriptPlan': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，情绪不能像念提纲。
④ 分场景情绪与画面意图
人物情绪要有递进起伏，镜头别平均用力。
</scriptPlan>
''',
            'assets': <Map<String, dynamic>>[
              <String, dynamic>{'id': 7, 'name': '玉佩'},
            ],
            'storyboard': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 11,
                'associateAssetsIds': <int>[7],
                'shouldGenerateImage': true,
              },
            ],
          },
        },
      );

      final assetStage = stages.firstWhere(
        (stage) => stage.flowKey == 'assets',
      );
      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(assetStage.prompt, contains('执行约束：承接 scriptPlan'));
      expect(storyboardStage.prompt, contains('执行约束：承接 scriptPlan'));
      expect(storyboardStage.prompt, contains('人物情绪保持递进'));
    },
  );

  test(
    'summarizeProductionResultSnapshot surfaces focused asset and storyboard scope',
    () {
      final lines = summarizeProductionResultSnapshot(
        _zh,
        'run_sub_agent_production_supervision',
        <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'generate_storyboard',
            'summary': '先补关键镜头',
            'assetIds': '7,3,7',
            'storyboardIds': '9,3,9',
          },
        },
        'storyboardTable',
      );

      expect(lines, contains('聚焦资产 2 项'));
      expect(lines, contains('聚焦镜头 2 项'));
      expect(lines, contains('镜头 #3, 9'));
      expect(lines, contains('分镜表仅回看镜头 #3, 9对应行；剧本仅回看剧本 7-38 行（<=920 字）'));
    },
  );

  test(
    'buildProductionWorkspaceRecipes narrows storyboard table asset checks to referenced ids',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'rows': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': '1',
                'associateAssetsIds': <Object>[12, '7', 12, 0],
              },
              <String, dynamic>{
                'id': '2',
                'associateAssetsIds': <Object>['3'],
              },
            ],
          },
        },
      );

      expect(recipes[1].title, '核对关联资产');
      expect(recipes[1].domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[3, 7, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(recipes[2].domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'ids': <int>[1, 2],
        'fields': <String>[
          'id',
          'index',
          'duration',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes keeps full storyboard scope in sub-agent args while prompt stays compact',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            for (final id in <int>[9, 1, 7, 3, 5, 11, 13, 15, 17])
              <String, dynamic>{
                'id': id,
                'prompt': 'scene $id',
                'shouldGenerateImage': true,
              },
          ],
        },
      );

      expect(recipes.first.subAgentTool, 'run_sub_agent_storyboard_gen');
      expect(recipes.first.subAgentArgs, <String, dynamic>{
        'storyboardIds': <int>[1, 3, 5, 7, 9, 11, 13, 15, 17],
      });
      expect(recipes.first.prompt, contains('优先处理这 9 个镜头'));
      expect(recipes.first.prompt, isNot(contains('ids=')));
    },
  );

  test(
    'buildProductionWorkspaceRecipes narrows storyboard table asset checks from markdown text',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'data': '''
| 序号 | 画面描述 | 场景 | 关联资产ID |
|---|---|---|---|
| 1 | 首镜 | 大殿 | [12, 7] |
| 2 | 次镜 | 大殿 | [3] |
''',
        },
      );

      expect(recipes[1].title, '核对关联资产');
      expect(recipes[1].domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[3, 7, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(recipes[2].domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'ids': <int>[1, 2],
        'fields': <String>[
          'id',
          'index',
          'duration',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes uses structured supervision next action',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'C',
            'severeCount': '1',
            'mediumCount': '2',
            'minorCount': '0',
            'nextAction': 'revise_storyboardTable',
            'summary': '分镜拆分过粗且关联资产缺失',
          },
        },
      );

      expect(recipes.first.subAgentTool, 'run_sub_agent_storyboard_table');
      expect(recipes.first.title, contains('修分镜表'));
      expect(recipes.last.domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'rowStart': 1,
        'rowCount': 8,
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes keeps review asset type scope in storyboard follow-up sub-agent args',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'generate_storyboard',
            'summary': '只补关键缺帧镜头',
            'storyboardIds': '9,3,9',
            'assetTypes': 'scene,role',
          },
        },
      );

      expect(recipes.first.subAgentArgs, <String, dynamic>{
        'storyboardIds': <int>[3, 9],
        'assetTypes': <String>['role', 'scene'],
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes keeps check-assets follow-up focused and returns to script plan',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'scriptPlan',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_assets',
            'summary': '先核对关键角色与场景素材',
            'assetIds': '12,7,12',
          },
        },
      );

      expect(recipes, hasLength(2));
      expect(recipes.first.flowKey, 'assets');
      expect(recipes.first.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[7, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(recipes.first.detail, contains('资产 #7, 12'));
      expect(recipes.last.flowKey, 'scriptPlan');
      expect(recipes.last.domainArgs, <String, dynamic>{
        'key': 'scriptPlan',
        'maxChars': 2200,
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes re-reads focused storyboard table ids after supervision',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'C',
            'severeCount': '1',
            'mediumCount': '2',
            'minorCount': '0',
            'nextAction': 'revise_storyboardTable',
            'summary': '分镜拆分过粗且关联资产缺失',
            'storyboardIds': <int>[9, 3, 9],
          },
        },
      );

      expect(recipes.last.domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes narrows storyboard table reads to missing storyboard ids',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 9,
              'prompt': 'scene one',
              'associateAssetsIds': <int>[12, 7],
              'shouldGenerateImage': true,
            },
            <String, dynamic>{
              'id': 3,
              'prompt': 'scene two',
              'associateAssetsIds': <int>[7],
              'shouldGenerateImage': true,
            },
            <String, dynamic>{
              'id': 4,
              'prompt': 'scene three',
              'src': 'https://example.com/4.png',
              'shouldGenerateImage': true,
            },
          ],
        },
      );

      expect(recipes[2].domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes falls back to storyboard table window without focused ids',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'C',
            'severeCount': '1',
            'mediumCount': '2',
            'minorCount': '0',
            'nextAction': 'revise_storyboardTable',
            'summary': '分镜拆分过粗且关联资产缺失',
          },
        },
      );

      expect(recipes.last.domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'rowStart': 1,
        'rowCount': 8,
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes shrinks check-script reads to focused window',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_script',
            'summary': '先核对关键镜头对应剧本依据',
            'storyboardIds': '2,5,7',
          },
        },
      );

      expect(recipes, hasLength(1));
      expect(recipes.first.domainArgs, <String, dynamic>{
        'key': 'script',
        'lineStart': 1,
        'lineEnd': 40,
        'maxChars': 1040,
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes narrows check-storyboard follow-ups to focused rows and script window',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_storyboard',
            'summary': '先核对关键镜头画面一致性',
            'storyboardIds': '2,5,7',
          },
        },
      );

      expect(recipes, hasLength(3));
      expect(recipes[0].domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'ids': <int>[2, 5, 7],
        'fields': <String>[
          'id',
          'index',
          'duration',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
      });
      expect(recipes[1].domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'ids': <int>[2, 5, 7],
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
      expect(recipes[2].domainArgs, <String, dynamic>{
        'key': 'script',
        'lineStart': 1,
        'lineEnd': 40,
        'maxChars': 1040,
      });
    },
  );

  test(
    'buildProductionWorkspaceRecipes adds focused storyboard table reread before generation',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'generate_storyboard',
            'summary': '只补关键缺帧镜头',
            'storyboardIds': '9,3,9',
          },
        },
      );

      expect(recipes, hasLength(2));
      expect(recipes[1].domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
      expect(
        recipes.first.detail,
        contains('分镜表仅回看镜头 #3, 9对应行；剧本仅回看剧本 7-38 行（<=920 字）'),
      );
      expect(recipes.first.prompt, contains('优先处理这 2 个镜头'));
      expect(recipes.first.prompt, contains('剧本仅回看剧本 7-38 行'));
    },
  );

  test(
    'buildProductionWorkspaceRecipes adds focused storyboard scope to revision prompt',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'C',
            'severeCount': '1',
            'mediumCount': '2',
            'minorCount': '0',
            'nextAction': 'revise_storyboardTable',
            'summary': '先修第 3、9 镜头对应表格行',
            'storyboardIds': '9,3,9',
          },
        },
      );

      expect(recipes.first.prompt, contains('优先处理这 2 个镜头'));
      expect(recipes.first.prompt, contains('保持其余行不动'));
      expect(recipes.first.prompt, contains('剧本仅回看剧本 7-38 行'));
    },
  );

  test(
    'buildProductionWorkspaceStages shrinks check-script reads to focused window',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_script',
            'summary': '先核对关键镜头对应剧本依据',
            'storyboardIds': '2,5,7',
          },
        },
      );

      final storyboardTableStage = stages.singleWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(storyboardTableStage.domainTool, 'get_flowData');
      expect(storyboardTableStage.domainArgs, <String, dynamic>{
        'key': 'script',
        'lineStart': 1,
        'lineEnd': 40,
        'maxChars': 1040,
      });
    },
  );

  test(
    'buildProductionWorkspaceStages reuses compact script window for script-plan revisions',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'scriptPlan',
            'grade': 'C',
            'severeCount': '1',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'revise_scriptPlan',
            'summary': '先收紧导演规划节奏',
          },
        },
      );

      final scriptPlanStage = stages.singleWhere(
        (stage) => stage.flowKey == 'scriptPlan',
      );
      expect(scriptPlanStage.domainTool, 'get_flowData');
      expect(scriptPlanStage.domainArgs, <String, dynamic>{
        'key': 'script',
        'lineStart': 1,
        'lineEnd': 48,
        'maxChars': 1400,
      });
      expect(scriptPlanStage.subAgentTool, 'run_sub_agent_director_plan');
    },
  );

  test(
    'buildProductionWorkspaceStages promotes check-assets review into focused assets stage',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'scriptPlan',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_assets',
            'summary': '先核对关键角色与场景素材',
            'assetIds': '12,7,12',
          },
        },
      );

      final assetStage = stages.singleWhere(
        (stage) => stage.flowKey == 'assets',
      );
      expect(assetStage.status.localizedLabel(_zh), '可推进');
      expect(assetStage.domainTool, 'get_flowData');
      expect(assetStage.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[7, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(assetStage.detail, contains('资产范围：资产 #7, 12'));
      expect(assetStage.detail, contains('回到 scriptPlan'));
    },
  );

  test(
    'buildProductionWorkspaceStages marks thin script plan as incomplete before downstream advance',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。
</scriptPlan>
''',
        },
      );

      final scriptPlanStage = stages.firstWhere(
        (stage) => stage.flowKey == 'scriptPlan',
      );
      expect(scriptPlanStage.status.localizedLabel(_zh), '待完善');
      expect(scriptPlanStage.subAgentTool, 'run_sub_agent_director_plan');
      expect(scriptPlanStage.detail, contains('至少 3 个规划维度'));
    },
  );

  test(
    'buildProductionWorkspaceStages narrows check-assets review to structured asset types',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'scriptPlan',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_assets',
            'summary': '先核对角色与场景资产',
            'assetTypes': 'scene,role',
          },
        },
      );

      final assetStage = stages.singleWhere(
        (stage) => stage.flowKey == 'assets',
      );
      expect(assetStage.status.localizedLabel(_zh), '可推进');
      expect(assetStage.domainArgs, <String, dynamic>{
        'key': 'assets',
        'assetTypes': <String>['role', 'scene'],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
        'limit': 12,
      });
      expect(assetStage.detail, contains('角色/场景资产'));
    },
  );

  test(
    'buildProductionWorkspaceStages keeps review asset type scope in storyboard generation args',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'generate_storyboard',
            'summary': '先核对角色与场景后补帧',
            'storyboardIds': '2,5,7',
            'assetTypes': 'scene,role',
          },
        },
      );

      final storyboardStage = stages.singleWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.subAgentArgs, <String, dynamic>{
        'storyboardIds': <int>[2, 5, 7],
        'assetTypes': <String>['role', 'scene'],
      });
    },
  );

  test(
    'buildProductionScriptReviewArgs shifts script window toward later storyboard ids',
    () {
      final args = buildProductionScriptReviewArgs(
        review: const ProductionSupervisionReview(
          target: 'storyboardTable',
          grade: 'B',
          severeCount: 0,
          mediumCount: 1,
          minorCount: 0,
          nextAction: 'check_script',
          summary: '后段镜头需要复核剧本依据',
          assetIds: <int>[],
          assetTypes: <String>[],
          storyboardIds: <int>[9, 10],
        ),
      );

      expect(args, <String, dynamic>{
        'key': 'script',
        'lineStart': 43,
        'lineEnd': 74,
        'maxChars': 920,
      });
    },
  );

  test('extractProductionActionCandidateIds reads derive asset ids', () {
    final ids = extractProductionActionCandidateIds(
      selectedTool: 'generate_deriveAsset',
      toolName: 'get_flowData',
      suggestedFlowKey: 'assets',
      result: <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'derive': <Map<String, dynamic>>[
              <String, dynamic>{'id': 11},
              <String, dynamic>{'id': 12},
            ],
          },
          <String, dynamic>{
            'id': 2,
            'derive': <Map<String, dynamic>>[
              <String, dynamic>{'id': 21},
            ],
          },
        ],
      },
    );

    expect(ids, <int>[11, 12, 21]);
  });

  test(
    'extractProductionPendingDeriveAssetIds keeps only missing derive images',
    () {
      final ids = extractProductionPendingDeriveAssetIds(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'derive': <Map<String, dynamic>>[
            <String, dynamic>{'id': 11},
            <String, dynamic>{'id': 12, 'src': 'https://example.com/12.png'},
          ],
        },
        <String, dynamic>{
          'id': 2,
          'derive': <Map<String, dynamic>>[
            <String, dynamic>{'id': 21, 'flowId': 88},
            <String, dynamic>{
              'id': 22,
              'imageUrl': 'https://example.com/22.png',
            },
          ],
        },
      ]);

      expect(ids, <int>[11, 21]);
    },
  );

  test('extractProductionActionCandidateIds reads storyboard ids', () {
    final ids = extractProductionActionCandidateIds(
      selectedTool: 'generate_storyboard',
      toolName: 'get_flowData',
      suggestedFlowKey: 'storyboard',
      result: <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'id': 101},
          <String, dynamic>{'id': 102},
          <String, dynamic>{'id': 103},
        ],
      },
    );

    expect(ids, <int>[101, 102, 103]);
  });

  test(
    'extractProductionActionCandidateIds prefers storyboard ids still missing images',
    () {
      final ids = extractProductionActionCandidateIds(
        selectedTool: 'generate_storyboard',
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 101, 'shouldGenerateImage': true},
            <String, dynamic>{
              'id': 102,
              'shouldGenerateImage': 1,
              'src': 'https://example.com/102.png',
            },
            <String, dynamic>{'id': 103, 'shouldGenerateImage': false},
          ],
        },
      );

      expect(ids, <int>[101]);
    },
  );

  test(
    'extractProductionActionCandidateIds reads focused storyboard ids from supervision review',
    () {
      final ids = extractProductionActionCandidateIds(
        selectedTool: 'generate_storyboard',
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'generate_storyboard',
            'summary': '只需补第 3、9 镜头',
            'storyboardIds': '9,3,9',
          },
        },
      );

      expect(ids, <int>[3, 9]);
    },
  );

  test(
    'extractProductionActionCandidateIds reads generated asset ids from tool result',
    () {
      final ids = extractProductionActionCandidateIds(
        selectedTool: 'generate_deriveAsset',
        toolName: 'generate_deriveAsset',
        suggestedFlowKey: 'assets',
        result: <String, dynamic>{
          'assetIds': <int>[12, 7, 12],
          'total': 2,
        },
      );

      expect(ids, <int>[7, 12]);
    },
  );

  test(
    'extractProductionActionCandidateIds reads generated storyboard ids from tool result',
    () {
      final ids = extractProductionActionCandidateIds(
        selectedTool: 'generate_storyboard',
        toolName: 'generate_storyboard',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'storyboardIds': <int>[9, 3, 9],
          'total': 2,
        },
      );

      expect(ids, <int>[3, 9]);
    },
  );

  test(
    'extractProductionStoryboardPromptScopeIds reads storyboard ids from storyboard-table prompt',
    () {
      final ids = extractProductionStoryboardPromptScopeIds(
        'run_sub_agent_storyboard_table',
        <String, dynamic>{'prompt': '请只修订 storyboard ids=7, 2, 7 对应的表格行。'},
      );

      expect(ids, <int>[2, 7]);
    },
  );

  test(
    'buildProductionActionArgumentSuggestions builds add/delete payloads',
    () {
      final result = <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': '角色A',
            'derive': <Map<String, dynamic>>[
              <String, dynamic>{'id': 11},
              <String, dynamic>{'id': 12},
            ],
          },
        ],
      };

      final addSuggestions = buildProductionActionArgumentSuggestions(
        selectedTool: 'add_deriveAsset',
        toolName: 'get_flowData',
        suggestedFlowKey: 'assets',
        result: result,
      );
      final deleteSuggestions = buildProductionActionArgumentSuggestions(
        selectedTool: 'del_deriveAsset',
        toolName: 'get_flowData',
        suggestedFlowKey: 'assets',
        result: result,
      );

      expect(addSuggestions.first.label, '新增到 #1');
      expect(addSuggestions.first.payload['assetsId'], 1);
      expect(addSuggestions.first.payload['name'], '角色A-衍生');
      expect(deleteSuggestions.first.label, '删除 #11');
      expect(deleteSuggestions.first.payload, <String, dynamic>{
        'assetsId': 1,
        'id': 11,
      });
    },
  );

  test('buildProductionWorkspaceStages marks assets with missing images', () {
    final stages = buildProductionWorkspaceStages(
      l10n: _zh,
      toolName: 'get_flowData',
      suggestedFlowKey: 'assets',
      result: <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': '角色A',
            'src': 'https://a.png',
            'derive': <Map<String, dynamic>>[
              <String, dynamic>{'id': 11, 'src': 'https://example.com/11.png'},
              <String, dynamic>{'id': 12},
            ],
          },
          <String, dynamic>{
            'id': 2,
            'name': '角色B',
            'derive': <Map<String, dynamic>>[
              <String, dynamic>{'id': 21},
            ],
          },
        ],
      },
    );

    final assetsStage = stages.firstWhere((stage) => stage.flowKey == 'assets');
    expect(assetsStage.status.localizedLabel(_zh), '需补图');
    expect(assetsStage.subAgentTool, 'run_sub_agent_generate_assets');
    expect(assetsStage.detail, contains('资产 #12, 21 仍缺图'));
    expect(assetsStage.detail, contains('主资产 1/2 已就绪'));
    expect(assetsStage.detail, contains('衍生缺口 2 项'));
    expect(
      assetsStage.prompt,
      '请优先只核对并生成这 2 个资产；若其中已有结果则跳过，只补剩余缺口，不要扩读无关 assets。',
    );
  });

  test(
    'buildProductionWorkspaceRecipes narrows asset generation prompt to pending derive ids',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'get_flowData',
        suggestedFlowKey: 'assets',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'name': '角色A',
              'src': 'https://a.png',
              'derive': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 11,
                  'src': 'https://example.com/11.png',
                },
                <String, dynamic>{'id': 12},
              ],
            },
            <String, dynamic>{
              'id': 2,
              'name': '角色B',
              'derive': <Map<String, dynamic>>[
                <String, dynamic>{'id': 21},
              ],
            },
          ],
        },
      );

      expect(recipes.first.subAgentTool, 'run_sub_agent_generate_assets');
      expect(recipes.first.detail, contains('资产 #12, 21 仍缺图'));
      expect(
        recipes.first.prompt,
        '请优先只核对并生成这 2 个资产；若其中已有结果则跳过，只补剩余缺口，不要扩读无关 assets。',
      );
    },
  );

  test(
    'buildProductionWorkspaceStages narrows asset reads from storyboard references',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 101,
              'associateAssetsIds': <int>[9, 3],
            },
            <String, dynamic>{
              'id': 102,
              'associateAssetsIds': <Object>['3'],
            },
          ],
        },
      );

      final assetsStage = stages.firstWhere(
        (stage) => stage.flowKey == 'assets',
      );
      expect(assetsStage.status.localizedLabel(_zh), '已定位');
      expect(assetsStage.domainTool, 'get_flowData');
      expect(assetsStage.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[3, 9],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(assetsStage.detail, contains('当前分镜窗口引用了 2 项资产'));
    },
  );

  test(
    'buildProductionWorkspaceStages marks storyboard as refresh-needed after generation',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'generate_storyboard',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{'ok': true},
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.status.localizedLabel(_zh), '建议刷新');
      expect(storyboardStage.domainTool, 'get_flowData');
      expect(storyboardStage.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'fields': <String>[
          'id',
          'index',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
        'limit': 12,
      });
      expect(storyboardStage.detail, contains('刷新分镜结果'));
      expect(storyboardStage.subAgentTool, isNull);
    },
  );

  test(
    'buildProductionWorkspaceStages narrows storyboard refresh to generated ids',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'generate_storyboard',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'storyboardIds': <int>[9, 3, 9],
          'total': 2,
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'index',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
      });
      expect(storyboardStage.detail, contains('#3, 9'));
      expect(storyboardStage.detail, contains('缺帧状态'));
    },
  );

  test(
    'buildProductionWorkspaceStages narrows asset refresh to generated ids',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'generate_deriveAsset',
        suggestedFlowKey: 'assets',
        result: <String, dynamic>{
          'assetIds': <int>[12, 7, 12],
          'total': 2,
        },
      );

      final assetsStage = stages.firstWhere(
        (stage) => stage.flowKey == 'assets',
      );
      expect(assetsStage.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[7, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(assetsStage.detail, contains('本次受影响资产'));
      expect(assetsStage.detail, contains('回读'));
    },
  );

  test(
    'buildProductionWorkspaceRecipes narrows asset refresh to generated ids',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'generate_deriveAsset',
        suggestedFlowKey: 'assets',
        result: <String, dynamic>{
          'assetIds': <int>[12, 7, 12],
          'total': 2,
        },
      );

      expect(recipes.first.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[7, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(recipes.first.title, '回读受影响资产');
      expect(recipes.first.detail, contains('#7, 12'));
      expect(recipes.first.detail, contains('回读'));
      expect(recipes.last.prompt, contains('这 2 个资产'));
    },
  );

  test(
    'buildProductionWorkspaceStages marks storyboard table as review-ready',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'data': '| 序号 | 画面描述 |\n|---|---|\n| 1 | 首镜 |',
        },
      );

      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(tableStage.status.localizedLabel(_zh), '待审核');
      expect(tableStage.subAgentTool, 'run_sub_agent_production_supervision');
    },
  );

  test(
    'buildProductionWorkspaceStages surfaces structured supervision state',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '1',
            'nextAction': 'check_script',
            'summary': '覆盖基本可用，但仍需核对一处剧本映射',
          },
        },
      );

      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(tableStage.status.localizedLabel(_zh), '可推进');
      expect(tableStage.domainTool, 'get_flowData');
      expect(tableStage.domainArgs, <String, dynamic>{
        'key': 'script',
        'lineStart': 1,
        'lineEnd': 60,
        'maxChars': 1400,
      });
    },
  );

  test(
    'buildProductionWorkspaceStages re-read focused storyboard table ids for revision',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'C',
            'severeCount': '1',
            'mediumCount': '2',
            'minorCount': '0',
            'nextAction': 'revise_storyboardTable',
            'summary': '先修第 3、9 镜头对应表格行',
            'storyboardIds': '9,3,9',
          },
        },
      );

      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(tableStage.domainTool, 'get_flowData');
      expect(tableStage.domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
    },
  );

  test(
    'buildProductionWorkspaceStages narrows storyboard checks to review storyboard ids',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_storyboard',
            'summary': '优先核对第 3、9 镜头',
            'storyboardIds': <int>[9, 3, 9],
          },
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.status.localizedLabel(_zh), '待核对');
      expect(storyboardStage.domainTool, 'get_flowData');
      expect(storyboardStage.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'index',
          'duration',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
      });
    },
  );

  test(
    'buildProductionWorkspaceStages adds focused storyboard scope to revision prompt',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'C',
            'severeCount': '1',
            'mediumCount': '2',
            'minorCount': '0',
            'nextAction': 'revise_storyboardTable',
            'summary': '先修第 3、9 镜头对应表格行',
            'storyboardIds': '9,3,9',
          },
        },
      );

      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(
        tableStage.detail,
        contains('局部范围：分镜表仅回看镜头 #3, 9对应行；剧本仅回看剧本 7-38 行（<=920 字）'),
      );
      expect(tableStage.prompt, contains('优先处理这 2 个镜头'));
      expect(tableStage.prompt, contains('保持其余行不动'));
      expect(tableStage.prompt, contains('剧本仅回看剧本 7-38 行'));
    },
  );

  test(
    'buildProductionWorkspaceStages narrows supervision asset checks to review asset ids',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'scriptPlan',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_assets',
            'summary': '先核对女主与玉佩资产',
            'assetIds': <int>[12, 5, 12],
          },
        },
      );

      final scriptPlanStage = stages.firstWhere(
        (stage) => stage.flowKey == 'scriptPlan',
      );
      expect(scriptPlanStage.domainTool, 'get_flowData');
      expect(scriptPlanStage.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[5, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
    },
  );

  test(
    'buildProductionWorkspaceStages prefers storyboard table window args',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'table': 'storyboardTable',
            'rowStart': 1,
            'rowCount': 8,
            'totalRows': 24,
            'rows': <Map<String, dynamic>>[
              <String, dynamic>{'id': '1', 'description': '首镜'},
            ],
          },
        },
      );

      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(tableStage.status.localizedLabel(_zh), '待扩读');
      expect(tableStage.domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'rowStart': 1,
        'rowCount': 8,
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
      expect(tableStage.detail, contains('覆盖还不够'));
    },
  );

  test(
    'buildProductionWorkspaceStages keeps storyboard table as sampled when coverage is advance-ready',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'table': 'storyboardTable',
            'rowStart': 1,
            'rowCount': 12,
            'totalRows': 15,
            'rows': <Map<String, dynamic>>[
              <String, dynamic>{'id': '1', 'description': '首镜'},
            ],
          },
        },
      );

      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(tableStage.status.localizedLabel(_zh), '已抽样');
      expect(tableStage.detail, contains('适合继续审核或修订'));
    },
  );

  test(
    'buildProductionWorkspaceStages routes storyboard-table sampling back to script plan when scene intent is thin',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: null,
        suggestedFlowKey: null,
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'scriptPlan': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。
② 核心人物与关系拉扯
角色关系要有压迫和反制，不要平均输出。
③ 叙事结构与节奏规划
前段尽快起冲突，中段连续抬压，结尾留钩子。
</scriptPlan>
''',
            'storyboardTable': <String, dynamic>{
              'table': 'storyboardTable',
              'rowStart': 1,
              'rowCount': 8,
              'totalRows': 24,
              'rows': <Map<String, dynamic>>[
                <String, dynamic>{'id': '1', 'description': '首镜'},
              ],
            },
          },
        },
      );

      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(tableStage.status.localizedLabel(_zh), '回补导演计划');
      expect(tableStage.domainArgs, <String, dynamic>{
        'key': 'scriptPlan',
        'maxChars': 2200,
      });
      expect(tableStage.detail, contains('先回补导演计划'));
      expect(storyboardStage.status.localizedLabel(_zh), '回补导演计划');
      expect(storyboardStage.domainArgs, <String, dynamic>{
        'key': 'scriptPlan',
        'maxChars': 2200,
      });
      expect(storyboardStage.detail, contains('分场景情绪或画面意图'));
    },
  );

  test(
    'buildProductionWorkspaceStages narrows asset reads from storyboard table markdown text',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'data': '''
| 序号 | 画面描述 | 场景 | 关联资产ID |
|---|---|---|---|
| 1 | 首镜 | 大殿 | [9, 3] |
| 2 | 次镜 | 大殿 | [3] |
''',
        },
      );

      final assetsStage = stages.firstWhere(
        (stage) => stage.flowKey == 'assets',
      );
      expect(assetsStage.status.localizedLabel(_zh), '已定位');
      expect(assetsStage.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[3, 9],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(assetsStage.detail, contains('2 项资产'));
    },
  );

  test(
    'buildProductionWorkspaceStages narrows asset reads from script plan scope',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
① 主题立意与叙事核心
先立住复仇目标，前两场别拖。
② 核心人物与关系拉扯
角色关系要有压迫和反制，不要平均输出。
④ 分场景情绪与画面意图
先核对玉佩与令牌两类道具，再决定是否补衍生状态。
</scriptPlan>
''',
        },
      );

      final assetsStage = stages.firstWhere(
        (stage) => stage.flowKey == 'assets',
      );
      expect(assetsStage.status.localizedLabel(_zh), '已收紧');
      expect(assetsStage.domainArgs, <String, dynamic>{
        'key': 'assets',
        'assetTypes': <String>['role', 'scene', 'tool'],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
        'limit': 18,
      });
      expect(assetsStage.detail, contains('角色/场景/道具资产'));
    },
  );

  test(
    'buildProductionWorkspaceStages prefers explicit asset ids from script plan',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
① 主题立意与叙事核心
先立住复仇目标，前两场别拖。
② 核心人物与关系拉扯
角色关系要有压迫和反制，不要平均输出。
④ 分场景情绪与画面意图
执行计划里先确认资产 #12, 3 与 asset 9 是否可直接复用。
</scriptPlan>
''',
        },
      );

      final assetsStage = stages.firstWhere(
        (stage) => stage.flowKey == 'assets',
      );
      expect(assetsStage.status.localizedLabel(_zh), '已收紧');
      expect(assetsStage.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[3, 9, 12],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(assetsStage.detail, contains('资产 #3, 9, 12'));
    },
  );

  test(
    'buildProductionWorkspaceStages blocks assets until script plan exists',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: null,
        suggestedFlowKey: null,
        result: null,
      );

      final assetsStage = stages.firstWhere(
        (stage) => stage.flowKey == 'assets',
      );
      expect(assetsStage.status.localizedLabel(_zh), '等待导演计划');
      expect(assetsStage.domainArgs, <String, dynamic>{
        'key': 'scriptPlan',
        'maxChars': 2200,
      });
    },
  );

  test(
    'buildProductionWorkspaceStages blocks storyboard table until script plan exists',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: null,
        suggestedFlowKey: null,
        result: null,
      );

      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(tableStage.status.localizedLabel(_zh), '等待导演计划');
      expect(tableStage.domainArgs, <String, dynamic>{
        'key': 'scriptPlan',
        'maxChars': 2200,
      });
    },
  );

  test(
    'buildProductionWorkspaceStages blocks downstream work until script plan is sufficiently complete',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。
</scriptPlan>
''',
        },
      );

      final assetsStage = stages.firstWhere(
        (stage) => stage.flowKey == 'assets',
      );
      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(assetsStage.status.localizedLabel(_zh), '等待导演计划完善');
      expect(tableStage.status.localizedLabel(_zh), '等待导演计划完善');
      expect(storyboardStage.status.localizedLabel(_zh), '等待导演计划完善');
    },
  );

  test(
    'buildProductionWorkspaceStages blocks storyboard until storyboard table exists',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。
② 核心人物与关系拉扯
角色关系要有压迫和反制，不要平均输出。
④ 分场景情绪与画面意图
情绪起伏要递进，镜头别一上来全顶满。
</scriptPlan>
''',
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.status.localizedLabel(_zh), '等待分镜表');
      expect(storyboardStage.domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
        'rowStart': 1,
        'rowCount': 8,
      });
    },
  );

  test(
    'buildProductionWorkspaceStages allows storyboard-table gate only after stronger script plan coverage',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'data': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。
② 核心人物与关系拉扯
角色关系要有压迫和反制，不要平均输出。
④ 分场景情绪与画面意图
情绪起伏要递进，镜头别一上来全顶满。
</scriptPlan>
''',
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.status.localizedLabel(_zh), '等待分镜表');
    },
  );

  test(
    'buildProductionWorkspaceStages blocks storyboard until storyboard table coverage is sufficient',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: null,
        suggestedFlowKey: null,
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'scriptPlan': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。
② 核心人物与关系拉扯
角色关系要有压迫和反制，不要平均输出。
④ 分场景情绪与画面意图
情绪起伏要递进，镜头别一上来全顶满。
</scriptPlan>
''',
            'storyboardTable': <String, dynamic>{
              'table': 'storyboardTable',
              'rowStart': 1,
              'rowCount': 8,
              'totalRows': 24,
              'rows': <Map<String, dynamic>>[
                <String, dynamic>{'id': '1', 'description': '首镜'},
              ],
            },
          },
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.status.localizedLabel(_zh), '等待分镜表完善');
      expect(storyboardStage.domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
        'rowStart': 1,
        'rowCount': 8,
      });
      expect(storyboardStage.detail, contains('覆盖还不够'));
    },
  );

  test(
    'buildProductionWorkspaceStages allows storyboard to move past table gate when coverage is sufficient',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: null,
        suggestedFlowKey: null,
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'scriptPlan': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。
② 核心人物与关系拉扯
角色关系要有压迫和反制，不要平均输出。
④ 分场景情绪与画面意图
情绪起伏要递进，镜头别一上来全顶满。
</scriptPlan>
''',
            'storyboardTable': <String, dynamic>{
              'table': 'storyboardTable',
              'rowStart': 1,
              'rowCount': 12,
              'totalRows': 15,
              'rows': <Map<String, dynamic>>[
                <String, dynamic>{'id': '1', 'description': '首镜'},
              ],
            },
          },
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.status.localizedLabel(_zh), '待读取');
      expect(storyboardStage.domainTool, 'get_flowData');
      expect(storyboardStage.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'fields': <String>[
          'id',
          'index',
          'duration',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
        'limit': 12,
      });
    },
  );

  test(
    'buildProductionWorkspaceStages uses focused script window in missing storyboard prompt',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 3, 'shouldGenerateImage': true},
            <String, dynamic>{'id': 9, 'shouldGenerateImage': true},
            <String, dynamic>{
              'id': 10,
              'src': 'https://example.com/10.png',
              'shouldGenerateImage': true,
            },
          ],
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(
        storyboardStage.detail,
        contains('分镜表仅回看镜头 #3, 9对应行；剧本仅回看剧本 7-38 行（<=920 字）'),
      );
      expect(storyboardStage.prompt, contains('优先处理这 2 个镜头'));
      expect(storyboardStage.prompt, contains('剧本仅回看剧本 7-38 行'));
    },
  );

  test('summarizeProductionFlowValue surfaces storyboard table row digest', () {
    final lines = summarizeProductionFlowValue(_zh, '''
| 序号 | 画面描述 | 场景 | 关联资产ID |
|---|---|---|---|
| 1 | 首镜 | 大殿 | [12, 7] |
| 2 | 次镜 | 大殿 | [3] |
''', flowKey: 'storyboardTable');

    expect(lines, contains('分镜 2 条'));
    expect(lines, contains('关联资产 3'));
  });

  test('summarizeProductionFlowValue surfaces script plan section digest', () {
    final lines = summarizeProductionFlowValue(_zh, '''
<scriptPlan>
① 主题立意与叙事核心
② 视觉风格与画面基调
③ 叙事结构与节奏规划
</scriptPlan>
''', flowKey: 'scriptPlan');

    expect(lines, contains('计划章节 3'));
  });

  test(
    'summarizeProductionScriptPlanSections extracts compact section digest',
    () {
      final sections = summarizeProductionScriptPlanSections('''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。

② 视觉风格与画面基调
冷金对比，朝堂压迫感要强，人物特写优先保留眼神戏。
</scriptPlan>
''');

      expect(sections, <String>[
        '① 主题立意与叙事核心：女主复仇线要压住爽感，并保证前两场快速立住目标。',
        '② 视觉风格与画面基调：冷金对比，朝堂压迫感要强，人物特写优先保留眼神戏。',
      ]);
    },
  );

  test('productionFlowEntryHasMediaResult supports src fields', () {
    expect(
      productionFlowEntryHasMediaResult(<String, dynamic>{
        'src': 'https://example.com/a.png',
      }),
      isTrue,
    );
    expect(
      productionFlowEntryHasMediaResult(<String, dynamic>{
        'url': 'https://example.com/a.png',
      }),
      isTrue,
    );
    expect(
      productionFlowEntryHasMediaResult(<String, dynamic>{'src': '   '}),
      isFalse,
    );
  });

  test('production storyboard generation helpers ignore pure text rows', () {
    final rows = <Map<String, dynamic>>[
      <String, dynamic>{'id': 11, 'shouldGenerateImage': false},
      <String, dynamic>{'id': 12, 'shouldGenerateImage': '0'},
      <String, dynamic>{'id': 13, 'shouldGenerateImage': true},
      <String, dynamic>{
        'id': 14,
        'shouldGenerateImage': 1,
        'src': 'https://example.com/14.png',
      },
    ];

    expect(extractProductionStoryboardMissingImageIds(rows), <int>[13]);
  });

  test(
    'buildProductionWorkspaceStages summarizes missing storyboard ids and skips pure text rows',
    () {
      final stages = buildProductionWorkspaceStages(
        l10n: _zh,
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 101, 'shouldGenerateImage': true},
            <String, dynamic>{
              'id': 102,
              'shouldGenerateImage': true,
              'src': 'https://example.com/102.png',
            },
            <String, dynamic>{'id': 103, 'shouldGenerateImage': false},
          ],
        },
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.status.localizedLabel(_zh), '需补帧');
      expect(storyboardStage.detail, contains('#101'));
      expect(storyboardStage.detail, contains('纯文本模式'));
      expect(storyboardStage.detail, contains('画面结果 1/2 已就绪'));
      expect(storyboardStage.prompt, contains('优先处理这 1 个镜头'));
    },
  );

  test('summarizeProductionStoryboardTableCoverage reports remaining rows', () {
    expect(
      summarizeProductionStoryboardTableCoverage(sampledRows: 8, totalRows: 24),
      '分镜表已读 8/24 行，待展开 16 行',
    );
  });

  test(
    'summarizeProductionPrimaryBlocker picks the first unresolved stage',
    () {
      final summary =
          summarizeProductionPrimaryBlocker(const <ProductionWorkspaceStage>[
            ProductionWorkspaceStage(
              title: '导演计划',
              flowKey: 'scriptPlan',
              status: ProductionWorkspaceStageStatus.storyboardComplete,
              detail: '导演计划可继续沿用。',
            ),
            ProductionWorkspaceStage(
              title: '资产准备',
              flowKey: 'assets',
              status: ProductionWorkspaceStageStatus.needsAssetImages,
              detail: '资产 #12, 21 仍缺图，主资产 1/2 已就绪，衍生缺口 2 项。',
            ),
          ], _zh);

      expect(summary, contains('当前卡点：资产准备 · 需补图'));
      expect(summary, contains('资产 #12, 21 仍缺图'));
    },
  );

  test(
    'summarizeProductionPrimaryBlocker explains storyboard table expansion',
    () {
      final summary = summarizeProductionPrimaryBlocker(const <
        ProductionWorkspaceStage
      >[
        ProductionWorkspaceStage(
          title: '分镜表',
          flowKey: 'storyboardTable',
          status: ProductionWorkspaceStageStatus.storyboardTableExpandRead,
          detail:
              '已窗口读取 8/24 行关键列，但覆盖还不够，先扩读或补齐关键镜头表，再推进 storyboard。分镜表已读 8/24 行，待展开 16 行。',
        ),
      ], _zh);

      expect(summary, '当前卡点：分镜表 · 待扩读；先继续扩读关键分镜表窗口；分镜表已读 8/24 行，待展开 16 行。');
    },
  );

  test(
    'summarizeProductionPrimaryBlocker explains when to refine script plan',
    () {
      final summary = summarizeProductionPrimaryBlocker(const <
        ProductionWorkspaceStage
      >[
        ProductionWorkspaceStage(
          title: '分镜画面',
          flowKey: 'storyboard',
          status: ProductionWorkspaceStageStatus.backfillScriptPlanFromTable,
          detail:
              'storyboardTable 已有基础内容，但当前 scriptPlan 对分场景情绪或画面意图交代还不够，先细化导演计划，再继续扩读分镜表并推进 storyboard。',
        ),
      ], _zh);

      expect(
        summary,
        '当前卡点：分镜画面 · 回补导演计划；当前更缺导演计划里的分场景情绪/画面意图，先细化 scriptPlan 再拆分镜表。',
      );
    },
  );

  test(
    'production stage button labels follow storyboard-table fallback states',
    () {
      const expandStage = ProductionWorkspaceStage(
        title: '分镜表',
        flowKey: 'storyboardTable',
        status: ProductionWorkspaceStageStatus.storyboardTableExpandRead,
        detail: '先扩读关键镜头表。',
        domainTool: 'get_flowData',
        domainArgs: <String, dynamic>{'key': 'storyboardTable'},
      );
      const refineStage = ProductionWorkspaceStage(
        title: '分镜画面',
        flowKey: 'storyboard',
        status: ProductionWorkspaceStageStatus.backfillScriptPlanFromTable,
        detail: '先细化导演计划。',
        subAgentTool: 'run_sub_agent_director_plan',
      );

      expect(productionStageDomainButtonLabel(expandStage, _zh), '扩读分镜表');
      expect(productionStageSubAgentButtonLabel(refineStage, _zh), '细化导演计划');
    },
  );

  test(
    'production stage button labels specialize refresh actions by scope',
    () {
      const scriptRefreshStage = ProductionWorkspaceStage(
        title: '导演计划',
        flowKey: 'scriptPlan',
        status: ProductionWorkspaceStageStatus.suggestRefresh,
        detail: '导演计划刚变更或正在处理，建议重新读取 scriptPlan 确认最新内容。',
        domainTool: 'get_flowData',
      );
      const assetRefreshStage = ProductionWorkspaceStage(
        title: '资产准备',
        flowKey: 'assets',
        status: ProductionWorkspaceStageStatus.suggestRefresh,
        refreshHint: ProductionWorkspaceRefreshHint.rereadAffectedAssets,
        detail: '资产生成动作刚执行，建议先只回读本次受影响资产，确认结果后再决定是否扩读。',
        domainTool: 'get_flowData',
      );
      const tableRefreshStage = ProductionWorkspaceStage(
        title: '分镜表',
        flowKey: 'storyboardTable',
        status: ProductionWorkspaceStageStatus.suggestRefresh,
        refreshHint:
            ProductionWorkspaceRefreshHint.rereadPartialStoryboardTable,
        detail: '分镜表刚变更，建议先只回读镜头 #3, 9 对应的 storyboardTable 行。',
        domainTool: 'get_flowData',
      );
      const storyboardRefreshStage = ProductionWorkspaceStage(
        title: '分镜画面',
        flowKey: 'storyboard',
        status: ProductionWorkspaceStageStatus.suggestRefresh,
        refreshHint: ProductionWorkspaceRefreshHint.rereadMissingFrameState,
        detail: '分镜动作刚执行，建议先只回读本次镜头 #3, 9 的补图状态。',
        domainTool: 'get_flowData',
      );

      expect(
        productionStageDomainButtonLabel(scriptRefreshStage, _zh),
        '刷新导演计划',
      );
      expect(
        productionStageDomainButtonLabel(assetRefreshStage, _zh),
        '回读受影响资产',
      );
      expect(
        productionStageDomainButtonLabel(tableRefreshStage, _zh),
        '回读局部分镜表',
      );
      expect(
        productionStageDomainButtonLabel(storyboardRefreshStage, _zh),
        '回读缺帧状态',
      );
    },
  );

  test(
    'production recipe button labels follow storyboard fallback actions',
    () {
      const expandRecipe = ProductionWorkspaceRecipe(
        title: '先看分镜表落地',
        detail: '先扩读关键窗口。',
        flowKey: 'storyboardTable',
        domainTool: 'get_flowData',
        domainArgs: <String, dynamic>{'key': 'storyboardTable'},
      );
      const refineRecipe = ProductionWorkspaceRecipe(
        title: '补足分场景意图',
        detail: '先补导演计划。',
        flowKey: 'storyboardTable',
        subAgentTool: 'run_sub_agent_director_plan',
      );

      expect(productionRecipeDomainButtonLabel(expandRecipe), '扩读分镜表');
      expect(productionRecipeSubAgentButtonLabel(refineRecipe), '细化导演计划');
    },
  );

  test(
    'production diagnosis headline explains script-plan refinement first',
    () {
      const recipes = <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '补足分场景意图',
          detail: '先补导演计划。',
          flowKey: 'storyboardTable',
          subAgentTool: 'run_sub_agent_director_plan',
        ),
      ];

      expect(
        summarizeProductionDiagnosisHeadline(recipes),
        '当前更建议先细化导演计划里的分场景情绪/画面意图，再继续拆分分镜表。',
      );
    },
  );

  test(
    'production diagnosis headline explains storyboard-table expansion first',
    () {
      const recipes = <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '先看分镜表落地',
          detail: '先扩读分镜表。',
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
        ),
      ];

      expect(
        summarizeProductionDiagnosisHeadline(recipes),
        '当前更建议先扩读关键分镜表窗口，再决定是否推进 storyboard。',
      );
    },
  );

  test(
    'applied production recipe status explains the next cheapest action',
    () {
      const recipe = ProductionWorkspaceRecipe(
        title: '补足分场景意图',
        detail: '先补导演计划。',
        flowKey: 'storyboardTable',
        subAgentTool: 'run_sub_agent_director_plan',
      );

      expect(
        summarizeAppliedProductionRecipeStatus(recipe),
        '已应用任务建议：补足分场景意图，下一步先细化导演计划。',
      );
    },
  );

  test(
    'applied production stage status explains storyboard-table expansion',
    () {
      const stage = ProductionWorkspaceStage(
        title: '分镜表',
        flowKey: 'storyboardTable',
        status: ProductionWorkspaceStageStatus.storyboardTableExpandRead,
        detail: '先扩读分镜表。',
        domainTool: 'get_flowData',
      );

      expect(
        summarizeAppliedProductionStageStatus(stage, _zh),
        '已应用阶段动作：分镜表，下一步先扩读关键分镜表窗口。',
      );
    },
  );

  test(
    'summarizeProductionFlowValue surfaces storyboard table coverage digest',
    () {
      final lines = summarizeProductionFlowValue(_zh, <String, dynamic>{
        'rowStart': 1,
        'rowCount': 8,
        'totalRows': 24,
        'rows': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '1',
            'associateAssetsIds': <int>[3],
          },
        ],
      }, flowKey: 'storyboardTable');

      expect(lines, contains('分镜表已读 8/24 行，待展开 16 行'));
      expect(lines, contains('关联资产 1'));
    },
  );

  test('supervision check assets recipe keeps compact asset read args', () {
    final recipes = buildProductionWorkspaceRecipes(
      toolName: 'run_sub_agent_production_supervision',
      suggestedFlowKey: 'scriptPlan',
      result: <String, dynamic>{
        'review': <String, dynamic>{
          'target': 'scriptPlan',
          'grade': 'B',
          'severeCount': '0',
          'mediumCount': '1',
          'minorCount': '0',
          'nextAction': 'check_assets',
          'summary': '确认资产是否支撑最新导演计划',
        },
      },
    );

    expect(recipes.first.domainArgs, <String, dynamic>{
      'key': 'assets',
      'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      'limit': 24,
    });
    expect(recipes.last.domainArgs, <String, dynamic>{
      'key': 'scriptPlan',
      'maxChars': 2200,
    });
  });

  test(
    'supervision check assets recipe narrows to structured review asset ids',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'scriptPlan',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '2',
            'minorCount': '0',
            'nextAction': 'check_assets',
            'summary': '导演规划可用但第 3、7 号资产需补核对',
            'assetIds': '7,3,7',
          },
        },
      );

      expect(recipes.first.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[3, 7],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
      expect(recipes.last.domainArgs, <String, dynamic>{
        'key': 'scriptPlan',
        'maxChars': 2200,
      });
    },
  );

  test(
    'supervision check assets recipe narrows to structured review asset types',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'scriptPlan',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'scriptPlan',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_assets',
            'summary': '先核对角色与场景资产',
            'assetTypes': 'scene,role',
          },
        },
      );

      expect(recipes.first.domainArgs, <String, dynamic>{
        'key': 'assets',
        'assetTypes': <String>['role', 'scene'],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
        'limit': 12,
      });
      expect(recipes.first.detail, contains('角色/场景资产'));
    },
  );

  test(
    'supervision storyboard recipes narrow to structured review storyboard ids',
    () {
      final checkRecipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'check_storyboard',
            'summary': '先核对第 3、9 镜头',
            'storyboardIds': '9,3,9',
          },
        },
      );

      expect(checkRecipes.first.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'index',
          'duration',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
      });
      expect(checkRecipes[1].domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
      expect(checkRecipes[2].domainArgs, <String, dynamic>{
        'key': 'script',
        'lineStart': 7,
        'lineEnd': 38,
        'maxChars': 920,
      });

      final generateRecipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'generate_storyboard',
            'summary': '只需补第 3、9 镜头',
            'storyboardIds': <int>[9, 3],
          },
        },
      );

      expect(generateRecipes.first.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'index',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
      });
      expect(generateRecipes.first.prompt, contains('优先处理这 2 个镜头'));
      expect(generateRecipes[1].domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'ids': <int>[3, 9],
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
      });
    },
  );

  test(
    'supervision generate storyboard recipe falls back to minimal generation read',
    () {
      final recipes = buildProductionWorkspaceRecipes(
        toolName: 'run_sub_agent_production_supervision',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'storyboardTable',
            'grade': 'B',
            'severeCount': '0',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'generate_storyboard',
            'summary': '只需补缺帧镜头',
          },
        },
      );

      expect(recipes.first.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'fields': <String>[
          'id',
          'index',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
        'limit': 12,
      });
      expect(recipes[1].domainArgs, <String, dynamic>{
        'key': 'storyboardTable',
        'fields': <String>[
          'id',
          'description',
          'scene',
          'duration',
          'camera',
          'associateAssetsIds',
        ],
        'rowStart': 1,
        'rowCount': 8,
      });
    },
  );
}
