import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/home_page/agent_workspaces/contexts/production/flow_logic.dart';
import 'package:openflow_app/home_page/agent_workspaces/contexts/production/support.dart';

void main() {
  test('summarizeProductionFlowValue counts prompt and media rows', () {
    final lines = summarizeProductionFlowValue(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'prompt': 'scene one',
        'url': 'https://example.com/1.png',
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
              'url': 'https://example.com/2.png',
            },
          ],
        },
      );

      expect(recipes.first.subAgentTool, 'run_sub_agent_storyboard_gen');
      expect(recipes.first.flowKey, 'storyboard');
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
          <String, dynamic>{'id': 1, 'name': '角色A', 'url': 'https://a.png'},
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
      expect(storyboardStage.subAgentTool, isNull);
    },
  );
}
