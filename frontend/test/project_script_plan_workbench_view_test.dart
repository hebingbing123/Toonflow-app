import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_editor/scripts/plan_workbench_support.dart';
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
            eventSummaryLine: '当前 3 条事件，覆盖 5/6 条章节',
            draftSummaryLine: '已生成 1 份剧本初稿，覆盖 2 条章节',
            draftPackets: const [
              ScriptDraftPacket(
                name: '第1集',
                content: '【剧本定位】\n首集冲突起手',
                chapterIndexes: [1, 2],
                eventNames: ['主角撞见秘密'],
              ),
            ],
            guidanceSummaryLine: '已生成 1 份结构化改写 guidance',
            guidanceRows: const [
              StructuredRewriteGuidance(
                name: '第1集',
                chapterIndexes: [1, 2],
                eventNames: ['主角撞见秘密'],
                content: '【改写目标】\n先把主冲突拉满',
              ),
            ],
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
            onFillStorySkeletonSeed: null,
            onFillAdaptationStrategySeed: null,
            onGenerateDraftPackets: null,
            onWriteDraftPackets: null,
            onGenerateGuidance: null,
            onClose: null,
          ),
        ),
      ),
    );

    expect(find.text('骨架与改编策略'), findsOneWidget);
    expect(find.text('Story Skeleton'), findsOneWidget);
    expect(find.text('Adaptation Strategy'), findsOneWidget);
    expect(find.textContaining('planId 12'), findsOneWidget);
    expect(find.textContaining('覆盖 5/6 条章节'), findsOneWidget);
    expect(find.textContaining('已生成 1 份剧本初稿'), findsOneWidget);
    expect(find.textContaining('已生成 1 份结构化改写 guidance'), findsOneWidget);
    expect(find.widgetWithText(TextField, '三幕结构'), findsOneWidget);
    expect(find.widgetWithText(TextField, '角色先压后扬'), findsOneWidget);
    expect(find.text('用事件填充骨架草稿'), findsOneWidget);
    expect(find.text('用事件填充策略草稿'), findsOneWidget);
    expect(find.text('生成剧本初稿包'), findsOneWidget);
    expect(find.text('生成结构化改写 guidance'), findsOneWidget);
    expect(find.text('写入剧本初稿'), findsOneWidget);
    expect(find.text('剧本初稿预览'), findsOneWidget);
    expect(find.text('结构化改写 Guidance'), findsOneWidget);
    expect(find.text('第1集'), findsNWidgets(2));
    expect(find.text('刷新计划'), findsOneWidget);
    expect(find.text('保存计划'), findsOneWidget);
  });
}
