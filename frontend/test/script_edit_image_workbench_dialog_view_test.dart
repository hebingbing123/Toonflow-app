import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/home_page/script_editor/edit_image/workbench_view.dart';
import 'package:openflow_app/rust_api.dart';

ScriptEditImageWorkbenchDialogViewModel buildModel({
  required TextEditingController uploadCtrl,
  required TextEditingController flowIdCtrl,
  required TextEditingController promptCtrl,
  required TextEditingController modelCtrl,
  required TextEditingController stepIdCtrl,
  required TextEditingController stepStatusCtrl,
  bool loading = false,
  bool busy = false,
  List<ImageFlowStepV1>? steps,
  ImageDefaultModelResponseV1? defaultModel,
  String? uploadedImageUrl = 'https://cdn.openflow.test/source.png',
  String? statusLine = 'Flow flow-main 已保存',
}) {
  return ScriptEditImageWorkbenchDialogViewModel(
    loading: loading,
    busy: busy,
    steps:
        steps ??
        const <ImageFlowStepV1>[
          ImageFlowStepV1(
            stepId: 'step-1',
            stepName: '上传源图',
            status: 'completed',
          ),
          ImageFlowStepV1(
            stepId: 'step-2',
            stepName: '生成主图',
            status: 'pending',
          ),
        ],
    defaultModel:
        defaultModel ??
        const ImageDefaultModelResponseV1(
          model: 'flux-dev',
          resolution: '1024x1024',
        ),
    uploadedImageUrl: uploadedImageUrl,
    statusLine: statusLine,
    uploadCtrl: uploadCtrl,
    flowIdCtrl: flowIdCtrl,
    promptCtrl: promptCtrl,
    modelCtrl: modelCtrl,
    stepIdCtrl: stepIdCtrl,
    stepStatusCtrl: stepStatusCtrl,
  );
}

ScriptEditImageWorkbenchDialogViewCallbacks buildCallbacks({
  Future<void> Function()? onRefresh,
  Future<void> Function()? onUploadSourceImage,
  Future<void> Function()? onGenerateFlowImage,
  Future<void> Function()? onSaveFlow,
  ValueChanged<ImageFlowStepV1>? onSelectStep,
  Future<void> Function()? onUpdateStepStatus,
  VoidCallback? onClose,
}) {
  return ScriptEditImageWorkbenchDialogViewCallbacks(
    onRefresh: onRefresh ?? () async {},
    onUploadSourceImage: onUploadSourceImage ?? () async {},
    onGenerateFlowImage: onGenerateFlowImage ?? () async {},
    onSaveFlow: onSaveFlow ?? () async {},
    onSelectStep: onSelectStep ?? (_) {},
    onUpdateStepStatus: onUpdateStepStatus ?? () async {},
    onClose: onClose ?? () {},
  );
}

Finder disabledButtonWithText(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is ButtonStyleButton &&
        widget.onPressed == null &&
        widget.child is Text &&
        (widget.child as Text).data == text,
  );
}

void main() {
  late TextEditingController uploadCtrl;
  late TextEditingController flowIdCtrl;
  late TextEditingController promptCtrl;
  late TextEditingController modelCtrl;
  late TextEditingController stepIdCtrl;
  late TextEditingController stepStatusCtrl;

  setUp(() {
    uploadCtrl = TextEditingController(text: 'data:image/png;base64,abc');
    flowIdCtrl = TextEditingController(text: 'flow-main');
    promptCtrl = TextEditingController(text: '补齐夜景霓虹反射');
    modelCtrl = TextEditingController(text: 'flux-dev');
    stepIdCtrl = TextEditingController(text: 'step-1');
    stepStatusCtrl = TextEditingController(text: 'completed');
  });

  tearDown(() {
    uploadCtrl.dispose();
    flowIdCtrl.dispose();
    promptCtrl.dispose();
    modelCtrl.dispose();
    stepIdCtrl.dispose();
    stepStatusCtrl.dispose();
  });

  testWidgets('edit image workbench view renders status and uploaded url', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptEditImageWorkbenchDialogView(
            model: buildModel(
              uploadCtrl: uploadCtrl,
              flowIdCtrl: flowIdCtrl,
              promptCtrl: promptCtrl,
              modelCtrl: modelCtrl,
              stepIdCtrl: stepIdCtrl,
              stepStatusCtrl: stepStatusCtrl,
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('编辑图片工作台'), findsOneWidget);
    expect(find.text('默认模型 flux-dev · 1024x1024'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '上传源图'), findsOneWidget);
    expect(find.text('发起流程出图'), findsOneWidget);
    expect(find.text('保存当前 Flow'), findsOneWidget);
    expect(find.text('https://cdn.openflow.test/source.png'), findsOneWidget);
    expect(find.text('上传源图'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit image workbench view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptEditImageWorkbenchDialogView(
            model: buildModel(
              uploadCtrl: uploadCtrl,
              flowIdCtrl: flowIdCtrl,
              promptCtrl: promptCtrl,
              modelCtrl: modelCtrl,
              stepIdCtrl: stepIdCtrl,
              stepStatusCtrl: stepStatusCtrl,
              loading: true,
              busy: true,
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(disabledButtonWithText('同步中…'), findsOneWidget);
    expect(disabledButtonWithText('处理中…'), findsOneWidget);
    expect(disabledButtonWithText('发起流程出图'), findsOneWidget);
    expect(disabledButtonWithText('保存当前 Flow'), findsOneWidget);
    expect(disabledButtonWithText('更新单个步骤状态'), findsOneWidget);
    expect(disabledButtonWithText('关闭'), findsOneWidget);
  });

  testWidgets('edit image workbench view forwards action callbacks', (
    WidgetTester tester,
  ) async {
    var refreshCalls = 0;
    var uploadCalls = 0;
    var generateCalls = 0;
    var saveCalls = 0;
    var updateCalls = 0;
    var closeCalls = 0;
    ImageFlowStepV1? selectedStep;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptEditImageWorkbenchDialogView(
            model: buildModel(
              uploadCtrl: uploadCtrl,
              flowIdCtrl: flowIdCtrl,
              promptCtrl: promptCtrl,
              modelCtrl: modelCtrl,
              stepIdCtrl: stepIdCtrl,
              stepStatusCtrl: stepStatusCtrl,
            ),
            callbacks: buildCallbacks(
              onRefresh: () async => refreshCalls += 1,
              onUploadSourceImage: () async => uploadCalls += 1,
              onGenerateFlowImage: () async => generateCalls += 1,
              onSaveFlow: () async => saveCalls += 1,
              onSelectStep: (step) => selectedStep = step,
              onUpdateStepStatus: () async => updateCalls += 1,
              onClose: () => closeCalls += 1,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '重新同步 Flow'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '上传源图').first);
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '发起流程出图'));
    await tester.tap(find.widgetWithText(FilledButton, '发起流程出图'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(TextButton, '保存当前 Flow'));
    await tester.tap(find.widgetWithText(TextButton, '保存当前 Flow'));
    await tester.pump();
    await tester.ensureVisible(find.text('生成主图'));
    await tester.tap(find.text('生成主图'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(TextButton, '更新单个步骤状态'));
    await tester.tap(find.widgetWithText(TextButton, '更新单个步骤状态'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '关闭'));
    await tester.pump();

    expect(refreshCalls, 1);
    expect(uploadCalls, 1);
    expect(generateCalls, 1);
    expect(saveCalls, 1);
    expect(updateCalls, 1);
    expect(closeCalls, 1);
    expect(selectedStep?.stepId, 'step-2');
  });
}
