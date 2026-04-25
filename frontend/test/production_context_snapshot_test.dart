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
              workspaceLastToolResultData: <String, dynamic>{
                'data': <String, dynamic>{
                  'storyboardTable': '''
| 序号 | 画面描述 | 场景 | 时长 | 关联资产ID |
|---|---|---|---|---|
| 1 | 皇帝在大殿中宣布出征，群臣静默。 | 大殿 | 3s | [12, 7] |
| 2 | 将军抬头回应，镜头推进到手中兵符。 | 大殿 | 2s | [7] |
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
      expect(find.textContaining('分镜表 2 行'), findsOneWidget);
      expect(find.textContaining('镜头 #1\n场景: 大殿'), findsOneWidget);
      expect(
        find.textContaining('皇帝在大殿中宣布出征，群臣静默。\n资产: 7, 12'),
        findsOneWidget,
      );

      expect(find.text('flow[storyboard]'), findsOneWidget);
      expect(find.textContaining('缺帧 1 项'), findsOneWidget);
      expect(find.textContaining('结果: 缺帧待补图'), findsOneWidget);
      expect(find.textContaining('镜头 #101\n结果: 缺帧待补图'), findsOneWidget);
      expect(find.textContaining('镜头 #102'), findsNothing);
    },
  );
}
