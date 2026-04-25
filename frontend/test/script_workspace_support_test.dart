import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/contexts/script/support.dart';

void main() {
  test('extractScriptWorkspaceNovelIds reads numeric ids from items', () {
    final ids = extractScriptWorkspaceNovelIds(<String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'numeric_id': 11},
        <String, dynamic>{'numericId': 12},
        <String, dynamic>{'id': 13},
      ],
    });

    expect(ids, <int>[11, 12, 13]);
  });

  test(
    'buildScriptWorkspaceRecipes suggests next actions for planData gaps',
    () {
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
    },
  );

  test(
    'buildScriptWorkspaceArgumentSuggestions offers novel id fill chips',
    () {
      final suggestions = buildScriptWorkspaceArgumentSuggestions(
        selectedTool: 'get_novel_events',
        toolName: 'get_novel_text',
        result: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'numeric_id': 21},
            <String, dynamic>{'numeric_id': 22},
          ],
        },
      );

      expect(suggestions.map((item) => item.label), contains('填充首章'));
      expect(suggestions.first.payload, <String, dynamic>{'novelId': 21});
    },
  );

  test('parseScriptWorkspaceReview reads structured review payload', () {
    final review = parseScriptWorkspaceReview(<String, dynamic>{
      'review': <String, dynamic>{
        'target': 'script',
        'grade': 'C',
        'severeCount': '1',
        'mediumCount': '1',
        'minorCount': '0',
        'nextAction': 'revise_script',
        'summary': '冲突升级不够集中',
      },
    });

    expect(review, isNotNull);
    expect(review!.target, 'script');
    expect(review.severeCount, 1);
    expect(review.nextAction, 'revise_script');
  });

  test(
    'buildScriptWorkspaceRecipes uses structured supervision next action',
    () {
      final recipes = buildScriptWorkspaceRecipes(
        toolName: 'run_supervision_agent',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'script',
            'grade': 'C',
            'severeCount': '1',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'revise_script',
            'summary': '冲突升级不够集中',
          },
        },
        scopeScriptId: 8,
      );

      expect(recipes.first.title, '修剧本正文');
      expect(recipes.first.subAgentTool, 'run_sub_agent_script');
      expect(recipes.first.args, <String, dynamic>{
        'scriptId': 8,
        'lineStart': 61,
        'lineEnd': 120,
        'maxChars': 1600,
      });
    },
  );

  test('previous script tail args only exist when there is a previous episode', () {
    final recipes = buildScriptWorkspaceRecipes(
      toolName: 'get_planData',
      result: <String, dynamic>{
        'data': <String, dynamic>{
          'storySkeleton': 'ready',
          'adaptationStrategy': 'ready',
          'script': const <Map<String, dynamic>>[],
        },
      },
      scopeScriptId: 1,
    );

    expect(
      recipes.any(
        (recipe) =>
            recipe.args?['relativeOffset'] == -1 &&
            recipe.domainTool == 'get_script_content',
      ),
      isFalse,
    );
  });

  test(
    'buildScriptWorkspaceStages marks missing story skeleton as pending',
    () {
      final stages = buildScriptWorkspaceStages(
        toolName: 'get_planData',
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'storySkeleton': '',
            'adaptationStrategy': '聚焦亲情线',
          },
        },
        scopeScriptId: 9,
      );

      final skeletonStage = stages.firstWhere((stage) => stage.title == '故事骨架');
      expect(skeletonStage.statusLabel, '待生成');
      expect(skeletonStage.subAgentTool, 'run_sub_agent_storySkeleton');
    },
  );

  test('buildScriptWorkspaceStages marks script content as completed', () {
    final stages = buildScriptWorkspaceStages(
      toolName: 'get_script_content',
      result: <String, dynamic>{'content': '第 1 场，站台重逢。'},
      scopeScriptId: 8,
    );

    final scriptStage = stages.firstWhere((stage) => stage.title == '剧本正文');
    expect(scriptStage.statusLabel, '已完成');
    expect(scriptStage.domainTool, 'get_script_content');
  });

  test(
    'buildScriptWorkspaceStages surfaces script review as revise-needed',
    () {
      final stages = buildScriptWorkspaceStages(
        toolName: 'run_supervision_agent',
        result: <String, dynamic>{
          'review': <String, dynamic>{
            'target': 'script',
            'grade': 'C',
            'severeCount': '1',
            'mediumCount': '1',
            'minorCount': '0',
            'nextAction': 'revise_script',
            'summary': '冲突升级不够集中',
          },
        },
        scopeScriptId: 8,
      );

      final scriptStage = stages.firstWhere((stage) => stage.title == '剧本正文');
      expect(scriptStage.statusLabel, '待修订');
      expect(scriptStage.subAgentTool, 'run_sub_agent_script');
      expect(scriptStage.args, <String, dynamic>{
        'scriptId': 8,
        'lineStart': 61,
        'lineEnd': 120,
        'maxChars': 1600,
      });
    },
  );

  test('buildScriptWorkspaceRecipes narrows novel/event reads with field subsets', () {
    final textRecipes = buildScriptWorkspaceRecipes(
      toolName: 'get_script_content',
      result: <String, dynamic>{'content': '已有剧本内容'},
      scopeScriptId: 8,
    );
    final textRecipe = textRecipes.firstWhere((recipe) => recipe.title == '补章节材料');
    expect(textRecipe.args, <String, dynamic>{
      'novelId': 1,
      'fields': <String>['numeric_id', 'chapter', 'chapter_data'],
      'lineStart': 1,
      'lineEnd': 80,
      'maxChars': 1800,
    });

    final novelRecipes = buildScriptWorkspaceRecipes(
      toolName: 'get_novel_text',
      result: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'numeric_id': 21},
        ],
      },
      scopeScriptId: 8,
    );
    expect(novelRecipes.first.args, <String, dynamic>{
      'novelId': 21,
      'fields': <String>['numeric_id', 'name', 'detail'],
      'limit': 8,
      'maxChars': 1200,
    });
  });
}
