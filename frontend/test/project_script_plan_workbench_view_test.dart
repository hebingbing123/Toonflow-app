import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_editor/scripts/plan_workbench_view.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  testWidgets('script plan workbench view renders plan fields and actions', (
    WidgetTester tester,
  ) async {
    final storySkeletonCtrl = TextEditingController(text: '三幕结构');
    final adaptationStrategyCtrl = TextEditingController(text: '角色先压后扬');
    addTearDown(storySkeletonCtrl.dispose);
    addTearDown(adaptationStrategyCtrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectScriptPlanWorkbenchView(
          model: ProjectScriptPlanWorkbenchViewModel(
            localBusy: false,
            infoLine: '已载入 plan 12',
            storySkeletonCtrl: storySkeletonCtrl,
            adaptationStrategyCtrl: adaptationStrategyCtrl,
            planData: const ScriptAgentPlanData(
              planId: 12,
              storySkeleton: '三幕结构',
              adaptationStrategy: '角色先压后扬',
              scriptRows: [
                ScriptAgentPlanScriptRow(id: 1, name: '第1集', content: '正文'),
              ],
            ),
          ),
          callbacks: const ProjectScriptPlanWorkbenchViewCallbacks(
            onReload: null,
            onSave: null,
            onClose: null,
          ),
        ),
      ),
    );

    expect(find.text('骨架与改编策略'), findsOneWidget);
    expect(find.text('Story Skeleton'), findsOneWidget);
    expect(find.text('Adaptation Strategy'), findsOneWidget);
    expect(find.textContaining('planId 12'), findsOneWidget);
    expect(find.widgetWithText(TextField, '三幕结构'), findsOneWidget);
    expect(find.widgetWithText(TextField, '角色先压后扬'), findsOneWidget);
    expect(find.text('刷新计划'), findsOneWidget);
    expect(find.text('保存计划'), findsOneWidget);
  });
}
