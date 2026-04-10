import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/script_workspace_support.dart';

void main() {
  test('extractScriptWorkspaceNovelIds reads legacy ids from items', () {
    final ids = extractScriptWorkspaceNovelIds(<String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'legacy_id': 11},
        <String, dynamic>{'legacyId': 12},
        <String, dynamic>{'id': 13},
      ],
    });

    expect(ids, <int>[11, 12, 13]);
  });

  test('buildScriptWorkspaceRecipes suggests next actions for planData gaps', () {
    final recipes = buildScriptWorkspaceRecipes(
      toolName: 'get_planData',
      result: <String, dynamic>{
        'data': <String, dynamic>{
          'storySkeleton': '',
          'adaptationStrategy': '',
          'script': const <Map<String, dynamic>>[],
        },
      },
      scopeScriptId: 9,
    );

    expect(recipes.map((recipe) => recipe.title), contains('补故事骨架'));
    expect(recipes.map((recipe) => recipe.title), contains('补改编策略'));
    expect(recipes.map((recipe) => recipe.title), contains('读取当前剧本正文'));
  });

  test('buildScriptWorkspaceArgumentSuggestions offers novel id fill chips', () {
    final suggestions = buildScriptWorkspaceArgumentSuggestions(
      selectedTool: 'get_novel_events',
      toolName: 'get_novel_text',
      result: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'legacy_id': 21},
          <String, dynamic>{'legacy_id': 22},
        ],
      },
    );

    expect(suggestions.map((item) => item.label), contains('填充首章'));
    expect(
      suggestions.first.payload,
      <String, dynamic>{'novelId': 21},
    );
  });
}
