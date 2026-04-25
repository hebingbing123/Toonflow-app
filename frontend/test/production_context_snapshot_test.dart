import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/contexts/production/context_snapshot.dart';

void main() {
  testWidgets(
    'ProductionContextSnapshotView summarizes storyboard and storyboardTable previews',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductionContextSnapshotView(
              workspaceLastToolName: 'get_flowData',
              workspaceSuggestedFlowKey: 'storyboard',
              workspaceLastToolResultData: <String, dynamic>{
                'data': <String, dynamic>{
                  'storyboardTable': '''
| 序号 | 画面描述 | 场景 | 时长 | 关联资产ID |
|---|---|---|---|---|
| 101 | 皇帝在大殿中宣布出征，群臣静默。 | 大殿 | 3s | [12, 7] |
| 102 | 将军抬头回应，镜头推进到手中兵符。 | 大殿 | 2s | [7] |
| 103 | 殿外旌旗猎猎，士兵列阵。 | 城门 | 2s | [9] |
''',
                  'storyboard': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 101,
                      'prompt': '大殿广角，皇帝宣布出征',
                      'associateAssetsIds': <int>[12, 7],
                      'shouldGenerateImage': true,
                    },
                    <String, dynamic>{
                      'id': 102,
                      'prompt': '将军握住兵符的特写',
                      'associateAssetsIds': <int>[7],
                      'shouldGenerateImage': false,
                    },
                    <String, dynamic>{
                      'id': 103,
                      'prompt': '殿外旌旗猎猎',
                      'src': 'https://example.com/103.png',
                      'associateAssetsIds': <int>[9],
                      'shouldGenerateImage': true,
                    },
                  ],
                },
              },
            ),
          ),
        ),
      );

      expect(find.text('上下文快照'), findsOneWidget);
      expect(find.text('flow[storyboardTable]'), findsOneWidget);
      expect(find.textContaining('分镜表 3 行'), findsOneWidget);
      expect(find.textContaining('优先展示缺帧相关镜头'), findsOneWidget);
      expect(find.textContaining('镜头 #101\n场景: 大殿'), findsOneWidget);
      expect(
        find.textContaining('皇帝在大殿中宣布出征，群臣静默。\n资产: 7, 12'),
        findsOneWidget,
      );
      expect(find.textContaining('镜头 #102'), findsNothing);
      expect(find.textContaining('其余 2 行已折叠'), findsOneWidget);

      expect(find.text('flow[storyboard]'), findsOneWidget);
      expect(find.textContaining('缺帧 1 项'), findsOneWidget);
      expect(find.textContaining('优先展示缺帧镜头'), findsOneWidget);
      expect(find.textContaining('结果: 缺帧待补图'), findsOneWidget);
      expect(find.textContaining('镜头 #101\n结果: 缺帧待补图'), findsOneWidget);
      expect(find.textContaining('镜头 #102'), findsNothing);
      expect(find.textContaining('其余 2 项已折叠'), findsOneWidget);
    },
  );

  testWidgets(
    'ProductionContextSnapshotView renders single-flow get_flowData preview with compact script digest',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductionContextSnapshotView(
              workspaceLastToolName: 'get_flowData',
              workspaceSuggestedFlowKey: 'script',
              workspaceLastToolResultData: <String, dynamic>{
                'data': '''
第1场 大殿
皇帝宣布出征，群臣静默。

第2场 殿前
将军接旨，兵符特写。

第3场 城门
旌旗猎猎，众军列阵。
''',
              },
            ),
          ),
        ),
      );

      expect(find.text('flow[script]'), findsOneWidget);
      expect(find.textContaining('文本'), findsOneWidget);
      expect(find.textContaining('第1场 大殿\n皇帝宣布出征，群臣静默。'), findsOneWidget);
      expect(find.textContaining('第3场 城门'), findsOneWidget);
    },
  );

  testWidgets(
    'ProductionContextSnapshotView prefers script plan section digest and review summary',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductionContextSnapshotView(
              workspaceLastToolName: 'run_sub_agent_production_supervision',
              workspaceSuggestedFlowKey: 'scriptPlan',
              workspaceLastToolResultData: <String, dynamic>{
                'data': <String, dynamic>{
                  'scriptPlan': '''
<scriptPlan>
① 主题立意与叙事核心
女主复仇线要压住爽感，并保证前两场快速立住目标。

② 视觉风格与画面基调
冷金对比，朝堂压迫感要强，人物特写优先保留眼神戏。
</scriptPlan>
''',
                },
                'review': <String, dynamic>{
                  'target': 'storyboardTable',
                  'grade': 'B',
                  'severeCount': '0',
                  'mediumCount': '1',
                  'minorCount': '0',
                  'nextAction': 'generate_storyboard',
                  'summary': '只需补关键缺帧镜头',
                  'assetIds': '7,12',
                  'storyboardIds': '3,9',
                },
              },
            ),
          ),
        ),
      );

      expect(find.text('flow[scriptPlan]'), findsOneWidget);
      expect(
        find.textContaining('① 主题立意与叙事核心：女主复仇线要压住爽感'),
        findsOneWidget,
      );
      expect(find.textContaining('② 视觉风格与画面基调：冷金对比'), findsOneWidget);
      expect(find.text('审核摘要'), findsOneWidget);
      expect(find.textContaining('聚焦资产: 7, 12'), findsOneWidget);
      expect(find.textContaining('聚焦镜头: 3, 9'), findsOneWidget);
      expect(find.textContaining('下一步: generate_storyboard'), findsOneWidget);
    },
  );
}
