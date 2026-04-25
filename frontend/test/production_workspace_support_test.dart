import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/contexts/production/flow_logic.dart';
import 'package:openflow_app/agent_workspaces/contexts/production/support.dart';

void main() {
  test('summarizeProductionFlowValue counts prompt and media rows', () {
    final lines = summarizeProductionFlowValue(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'prompt': 'scene one',
        'src': 'https://example.com/1.png',
        'state': 'done',
      },
      <String, dynamic>{'id': 2, 'prompt': 'scene two', 'state': 'queued'},
    ]);

    expect(lines, contains('列表 2 项'));
    expect(lines, contains('含提示词 2 项'));
    expect(lines, contains('含媒体地址 1 项'));
    expect(lines, contains('状态种类 2 个'));
  });

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
            <String, dynamic>{'id': 1, 'prompt': 'scene one'},
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
    expect(recipes[1].domainArgs, <String, dynamic>{
      'key': 'assets',
      'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      'limit': 24,
    });
    expect(recipes[2].domainArgs, <String, dynamic>{
      'key': 'storyboard',
      'fields': <String>[
        'id',
        'index',
        'duration',
        'src',
        'state',
        'flowId',
        'associateAssetsIds',
      ],
      'limit': 24,
    });
  });

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
  });

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
      toolName: 'get_flowData',
      suggestedFlowKey: 'assets',
      result: <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'name': '角色A', 'src': 'https://a.png'},
          <String, dynamic>{'id': 2, 'name': '角色B'},
        ],
      },
    );

    final assetsStage = stages.firstWhere((stage) => stage.flowKey == 'assets');
    expect(assetsStage.statusLabel, '需补图');
    expect(assetsStage.subAgentTool, 'run_sub_agent_generate_assets');
    expect(assetsStage.detail, contains('仍有 1 项缺少图像结果'));
  });

  test(
    'buildProductionWorkspaceStages marks storyboard as refresh-needed after generation',
    () {
      final stages = buildProductionWorkspaceStages(
        toolName: 'generate_storyboard',
        suggestedFlowKey: 'storyboard',
        result: <String, dynamic>{'ok': true},
      );

      final storyboardStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboard',
      );
      expect(storyboardStage.statusLabel, '建议刷新');
      expect(storyboardStage.domainTool, 'get_flowData');
      expect(storyboardStage.domainArgs, <String, dynamic>{
        'key': 'storyboard',
        'fields': <String>[
          'id',
          'index',
          'duration',
          'src',
          'state',
          'flowId',
          'associateAssetsIds',
        ],
        'limit': 24,
      });
      expect(storyboardStage.subAgentTool, isNull);
    },
  );

  test(
    'buildProductionWorkspaceStages marks storyboard table as review-ready',
    () {
      final stages = buildProductionWorkspaceStages(
        toolName: 'get_flowData',
        suggestedFlowKey: 'storyboardTable',
        result: <String, dynamic>{
          'data': '| 序号 | 画面描述 |\n|---|---|\n| 1 | 首镜 |',
        },
      );

      final tableStage = stages.firstWhere(
        (stage) => stage.flowKey == 'storyboardTable',
      );
      expect(tableStage.statusLabel, '待审核');
      expect(tableStage.subAgentTool, 'run_sub_agent_production_supervision');
    },
  );

  test(
    'buildProductionWorkspaceStages surfaces structured supervision state',
    () {
      final stages = buildProductionWorkspaceStages(
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
      expect(tableStage.statusLabel, '可推进');
      expect(tableStage.domainTool, 'get_flowData');
      expect(tableStage.domainArgs, <String, dynamic>{
        'key': 'script',
        'maxChars': 1800,
      });
    },
  );

  test(
    'buildProductionWorkspaceStages narrows supervision asset checks to review asset ids',
    () {
      final stages = buildProductionWorkspaceStages(
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
      expect(tableStage.statusLabel, '已抽样');
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

    expect(recipes.single.domainArgs, <String, dynamic>{
      'key': 'assets',
      'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      'limit': 24,
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

      expect(recipes.single.domainArgs, <String, dynamic>{
        'key': 'assets',
        'ids': <int>[3, 7],
        'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
      });
    },
  );
}
