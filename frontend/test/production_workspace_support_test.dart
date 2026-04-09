import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/production_workspace_support.dart';

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
}
