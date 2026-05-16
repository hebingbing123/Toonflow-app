import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/contexts/script/support.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';

final _zh = AppLocalizationsZh();

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
        l10n: _zh,
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

      expect(
        recipes.map((recipe) => recipe.title),
        contains(_zh.agentWorkspaceScriptRecipeFillStorySkeletonTitle),
      );
      expect(
        recipes.map((recipe) => recipe.title),
        contains(_zh.agentWorkspaceScriptRecipeFillAdaptationTitle),
      );
      expect(
        recipes.map((recipe) => recipe.title),
        contains(_zh.agentWorkspaceScriptRecipeReadScriptBodyTitle),
      );
    },
  );

  test(
    'buildScriptWorkspaceRecipes prefers plan script drafts before wider reads',
    () {
      final recipes = buildScriptWorkspaceRecipes(
        l10n: _zh,
        toolName: 'get_planData',
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'storySkeleton': '三幕骨架',
            'adaptationStrategy': '先压后扬',
            'script': const <Map<String, dynamic>>[
              <String, dynamic>{'id': 9, 'name': '第9集', 'content': '计划剧本草稿'},
            ],
          },
        },
        scopeScriptId: 9,
      );

      expect(
        recipes.map((recipe) => recipe.title),
        contains(_zh.agentWorkspaceScriptRecipeReadPlanScriptDraftTitle),
      );
      final readPlanDraft = recipes.firstWhere(
        (recipe) =>
            recipe.title ==
            _zh.agentWorkspaceScriptRecipeReadPlanScriptDraftTitle,
      );
      expect(readPlanDraft.domainTool, 'get_planData');
      expect(readPlanDraft.args, <String, dynamic>{
        'scriptId': 9,
        'key': 'script',
        'fields': <String>['id', 'name', 'content', 'extract_state'],
        'lineStart': 1,
        'lineEnd': 120,
        'maxChars': 2200,
        'limit': 1,
      });
      final runScript = recipes.firstWhere(
        (recipe) => recipe.subAgentTool == 'run_sub_agent_script',
      );
      expect(runScript.prompt, contains('planData.script'));
    },
  );

  test('summarizeScriptResultSnapshot marks rewrite guidance as ready', () {
    final lines = summarizeScriptResultSnapshot(
      _zh,
      'get_planData',
      <String, dynamic>{
        'data': <String, dynamic>{
          'storySkeleton': '三幕骨架',
          'adaptationStrategy': '先压后扬',
          'script': const <Map<String, dynamic>>[
            <String, dynamic>{'name': '第1集', 'content': '计划剧本草稿'},
          ],
        },
      },
    );

    expect(lines, contains('故事骨架已就绪'));
    expect(lines, contains('改编策略已就绪'));
    expect(lines, contains('计划剧本 1 条'));
    expect(lines, contains('改写约束已可下游消费'));
  });

  test(
    'script workspace support normalizes wrapped persisted plan data across surfaces',
    () {
      final persistedPlanResult = <String, dynamic>{
        'data': <String, dynamic>{
          'id': '18',
          'data': <String, dynamic>{
            'story_skeleton': '三幕骨架',
            'adaptation_strategy': '先压后扬',
            'script': const <Map<String, dynamic>>[
              <String, dynamic>{'id': 9, 'name': '第9集', 'content': '计划剧本草稿'},
            ],
          },
        },
      };

      final summaryLines = summarizeScriptResultSnapshot(
        _zh,
        'get_planData',
        persistedPlanResult,
      );
      final recipes = buildScriptWorkspaceRecipes(
        l10n: _zh,
        toolName: 'get_planData',
        result: persistedPlanResult,
        scopeScriptId: 9,
      );
      final stages = buildScriptWorkspaceStages(
        l10n: _zh,
        toolName: 'get_planData',
        result: persistedPlanResult,
        scopeScriptId: 9,
      );

      expect(summaryLines, contains('故事骨架已就绪'));
      expect(summaryLines, contains('改编策略已就绪'));
      expect(
        recipes.map((recipe) => recipe.title),
        contains(_zh.agentWorkspaceScriptRecipeReadPlanScriptDraftTitle),
      );
      expect(
        stages
            .firstWhere(
              (stage) =>
                  stage.title ==
                  _zh.agentWorkspaceScriptStageTitleStorySkeleton,
            )
            .statusLabel,
        _zh.agentWorkspaceScriptStageStatusReady,
      );
      expect(
        stages
            .firstWhere(
              (stage) =>
                  stage.title ==
                  _zh.agentWorkspaceScriptStageTitleAdaptationStrategy,
            )
            .statusLabel,
        _zh.agentWorkspaceScriptStageStatusReady,
      );
    },
  );

  test(
    'buildScriptWorkspaceArgumentSuggestions offers novel id fill chips',
    () {
      final suggestions = buildScriptWorkspaceArgumentSuggestions(
        l10n: _zh,
        selectedTool: 'get_novel_events',
        toolName: 'get_novel_text',
        result: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'numeric_id': 21},
            <String, dynamic>{'numeric_id': 22},
          ],
        },
      );

      expect(
        suggestions.map((item) => item.label),
        contains(_zh.agentWorkspaceScriptArgFillFirstChapter),
      );
      expect(suggestions.first.payload, <String, dynamic>{
        'novelId': 21,
        'fields': <String>['numeric_id', 'name', 'detail'],
        'limit': 8,
        'maxChars': 1200,
      });
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
        l10n: _zh,
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

      expect(
        recipes.first.title,
        _zh.agentWorkspaceScriptRecipeReviseScriptTitle,
      );
      expect(recipes.first.subAgentTool, 'run_sub_agent_script');
      expect(recipes.first.args, <String, dynamic>{
        'scriptId': 8,
        'lineStart': 61,
        'lineEnd': 120,
        'maxChars': 1600,
      });
    },
  );

  test(
    'previous script tail args only exist when there is a previous episode',
    () {
      final recipes = buildScriptWorkspaceRecipes(
        l10n: _zh,
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
    },
  );

  test(
    'buildScriptWorkspaceStages marks missing story skeleton as pending',
    () {
      final stages = buildScriptWorkspaceStages(
        l10n: _zh,
        toolName: 'get_planData',
        result: <String, dynamic>{
          'data': <String, dynamic>{
            'storySkeleton': '',
            'adaptationStrategy': '聚焦亲情线',
          },
        },
        scopeScriptId: 9,
      );

      final skeletonStage = stages.firstWhere(
        (stage) =>
            stage.title == _zh.agentWorkspaceScriptStageTitleStorySkeleton,
      );
      expect(
        skeletonStage.statusLabel,
        _zh.agentWorkspaceScriptStageStatusPendingGenerate,
      );
      expect(skeletonStage.subAgentTool, 'run_sub_agent_storySkeleton');
    },
  );

  test('buildScriptWorkspaceStages marks script content as completed', () {
    final stages = buildScriptWorkspaceStages(
      l10n: _zh,
      toolName: 'get_script_content',
      result: <String, dynamic>{'content': '第 1 场，站台重逢。'},
      scopeScriptId: 8,
    );

    final scriptStage = stages.firstWhere(
      (stage) => stage.title == _zh.agentWorkspaceScriptStageTitleScriptBody,
    );
    expect(
      scriptStage.statusLabel,
      _zh.agentWorkspaceScriptStageStatusCompleted,
    );
    expect(scriptStage.domainTool, 'get_script_content');
  });

  test(
    'buildScriptWorkspaceStages surfaces script review as revise-needed',
    () {
      final stages = buildScriptWorkspaceStages(
        l10n: _zh,
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

      final scriptStage = stages.firstWhere(
        (stage) => stage.title == _zh.agentWorkspaceScriptStageTitleScriptBody,
      );
      expect(
        scriptStage.statusLabel,
        _zh.agentWorkspaceScriptStageStatusNeedsRevision,
      );
      expect(scriptStage.subAgentTool, 'run_sub_agent_script');
      expect(scriptStage.args, <String, dynamic>{
        'scriptId': 8,
        'lineStart': 61,
        'lineEnd': 120,
        'maxChars': 1600,
      });
    },
  );

  test(
    'buildScriptWorkspaceRecipes narrows novel/event reads with field subsets',
    () {
      final textRecipes = buildScriptWorkspaceRecipes(
        l10n: _zh,
        toolName: 'get_script_content',
        result: <String, dynamic>{'content': '已有剧本内容'},
        scopeScriptId: 8,
      );
      final textRecipe = textRecipes.firstWhere(
        (recipe) =>
            recipe.title ==
            _zh.agentWorkspaceScriptRecipeAddChapterMaterialTitle,
      );
      expect(textRecipe.args, <String, dynamic>{
        'fields': <String>['numeric_id', 'chapter', 'chapter_data'],
        'lineStart': 1,
        'lineEnd': 80,
        'maxChars': 1800,
        'limit': 1,
      });

      final novelRecipes = buildScriptWorkspaceRecipes(
        l10n: _zh,
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
    },
  );
}
