import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/home_page/project_editor/assets/generation/dialog_view.dart';
import 'package:openflow_app/rust_api.dart';

AssetGenerationWorkbenchDialogViewModel buildDialogModel({
  required TextEditingController modelCtrl,
  required TextEditingController resolutionCtrl,
  required TextEditingController imageUrlCtrl,
  required TextEditingController batchNameCtrl,
  required TextEditingController batchLimitCtrl,
  bool loadingSummary = false,
  bool busyMutation = false,
  List<int> selectedIds = const <int>[7],
  int? selectedSingleAssetId = 7,
  AssetsDataResponseV1? productionData,
  AssetsPollingImageResponseV1? pollingData,
}) {
  return AssetGenerationWorkbenchDialogViewModel(
    scriptList: const <ScriptBrief>[
      ScriptBrief(numericId: 9, name: '第一集', extractState: 0),
    ],
    visibleAssets: const <AssetRow>[
      AssetRow(
        id: 'asset-1',
        numericId: 7,
        name: '角色 A',
        assetType: 'role',
        description: '主角设定',
      ),
    ],
    scopedAssets: const <AssetRow>[
      AssetRow(
        id: 'asset-1',
        numericId: 7,
        name: '角色 A',
        assetType: 'role',
        description: '主角设定',
      ),
    ],
    typeSelections: const <String, List<int>>{
      'role': <int>[7],
    },
    pollingSelections: const <String, List<int>>{
      'done': <int>[7],
    },
    promptSelections: const <String, List<int>>{
      'generated': <int>[7],
    },
    selectedIds: selectedIds,
    selectedSingleAssetId: selectedSingleAssetId,
    filterScriptNumericId: 9,
    selectedScriptNumericId: 9,
    selectedType: '',
    loadingSummary: loadingSummary,
    busyMutation: busyMutation,
    productionData: productionData,
    pollingData: pollingData,
    materialData: null,
    batchData: null,
    promptPollingData: null,
    statusLine: '当前选择 1 条资产，可继续发起出图。',
    modelCtrl: modelCtrl,
    resolutionCtrl: resolutionCtrl,
    imageUrlCtrl: imageUrlCtrl,
    batchNameCtrl: batchNameCtrl,
    batchLimitCtrl: batchLimitCtrl,
  );
}

AssetGenerationWorkbenchDialogViewCallbacks buildDialogCallbacks({
  ValueChanged<int>? onScriptChanged,
  ValueChanged<String>? onImageUrlChanged,
  ValueChanged<String>? onTypeChanged,
  VoidCallback? onSyncWorkbenchSnapshot,
  VoidCallback? onLoadMaterialContext,
  VoidCallback? onLoadBatchCandidates,
  VoidCallback? onSelectAllVisible,
  VoidCallback? onRebuildSelectionByType,
  VoidCallback? onClearSelection,
  VoidCallback? onBatchGenerateImages,
  VoidCallback? onPollImageStatuses,
  VoidCallback? onPollPromptStatuses,
  VoidCallback? onDeleteDerivatives,
  VoidCallback? onUpdateImageUrl,
  void Function(String label, List<int> ids)? onApplyPollingSelection,
  VoidCallback? onApplyMaterialSelection,
  VoidCallback? onApplyBatchSelection,
  void Function(String label, List<int> ids)? onApplyPromptSelection,
  void Function(AssetRow asset, bool checked)? onToggleAsset,
  VoidCallback? onClose,
}) {
  return AssetGenerationWorkbenchDialogViewCallbacks(
    onScriptChanged: onScriptChanged ?? (_) {},
    onImageUrlChanged: onImageUrlChanged ?? (_) {},
    onTypeChanged: onTypeChanged ?? (_) {},
    onSyncWorkbenchSnapshot: onSyncWorkbenchSnapshot ?? noop,
    onLoadMaterialContext: onLoadMaterialContext ?? noop,
    onLoadBatchCandidates: onLoadBatchCandidates ?? noop,
    onSelectAllVisible: onSelectAllVisible ?? noop,
    onRebuildSelectionByType: onRebuildSelectionByType ?? noop,
    onClearSelection: onClearSelection ?? noop,
    onBatchGenerateImages: onBatchGenerateImages ?? noop,
    onPollImageStatuses: onPollImageStatuses ?? noop,
    onPollPromptStatuses: onPollPromptStatuses ?? noop,
    onDeleteDerivatives: onDeleteDerivatives ?? noop,
    onUpdateImageUrl: onUpdateImageUrl ?? noop,
    onApplyPollingSelection: onApplyPollingSelection ?? (_, _) {},
    onApplyMaterialSelection: onApplyMaterialSelection ?? noop,
    onApplyBatchSelection: onApplyBatchSelection ?? noop,
    onApplyPromptSelection: onApplyPromptSelection ?? (_, _) {},
    onToggleAsset: onToggleAsset ?? (_, _) {},
    onClose: onClose ?? noop,
  );
}

void main() {
  late TextEditingController modelCtrl;
  late TextEditingController resolutionCtrl;
  late TextEditingController imageUrlCtrl;
  late TextEditingController batchNameCtrl;
  late TextEditingController batchLimitCtrl;

  setUp(() {
    modelCtrl = TextEditingController(text: 'sdxl');
    resolutionCtrl = TextEditingController(text: '1024x1024');
    imageUrlCtrl = TextEditingController(text: 'https://example.com/cover.png');
    batchNameCtrl = TextEditingController(text: '角色');
    batchLimitCtrl = TextEditingController(text: '10');
  });

  tearDown(() {
    modelCtrl.dispose();
    resolutionCtrl.dispose();
    imageUrlCtrl.dispose();
    batchNameCtrl.dispose();
    batchLimitCtrl.dispose();
  });

  testWidgets('asset generation workbench view renders shared scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetGenerationWorkbenchDialogView(
            model: buildDialogModel(
              modelCtrl: modelCtrl,
              resolutionCtrl: resolutionCtrl,
              imageUrlCtrl: imageUrlCtrl,
              batchNameCtrl: batchNameCtrl,
              batchLimitCtrl: batchLimitCtrl,
              productionData: const AssetsDataResponseV1(
                assets: <AssetDataItemV1>[
                  AssetDataItemV1(id: 7, name: '角色 A', type: 'role'),
                ],
                total: 1,
              ),
              pollingData: const AssetsPollingImageResponseV1(
                statuses: <AssetImageStatusV1>[
                  AssetImageStatusV1(
                    assetId: 7,
                    imageCount: 2,
                    latestState: 'done',
                  ),
                ],
              ),
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('资产出图工作台'), findsOneWidget);
    expect(find.text('同步当前工作台摘要'), findsOneWidget);
    expect(find.text('批量发起资产出图'), findsOneWidget);
    expect(find.text('轮询图片状态'), findsOneWidget);
    expect(find.textContaining('production 资产 1 条'), findsOneWidget);
    expect(find.textContaining('已轮询 1 条资产'), findsOneWidget);
    expect(find.textContaining('#7 角色 A'), findsWidgets);
  });

  testWidgets('asset generation workbench view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetGenerationWorkbenchDialogView(
            model: buildDialogModel(
              modelCtrl: modelCtrl,
              resolutionCtrl: resolutionCtrl,
              imageUrlCtrl: imageUrlCtrl,
              batchNameCtrl: batchNameCtrl,
              batchLimitCtrl: batchLimitCtrl,
              loadingSummary: true,
              busyMutation: true,
            ),
            callbacks: buildDialogCallbacks(
              onSyncWorkbenchSnapshot: null,
              onLoadMaterialContext: null,
              onLoadBatchCandidates: null,
              onSelectAllVisible: null,
              onRebuildSelectionByType: null,
              onClearSelection: null,
              onBatchGenerateImages: null,
              onPollImageStatuses: null,
              onPollPromptStatuses: null,
              onDeleteDerivatives: null,
              onUpdateImageUrl: null,
              onClose: null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('处理中…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '同步中…'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '处理中…'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '关闭'))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'asset generation workbench view disables single update action without single selection',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssetGenerationWorkbenchDialogView(
              model: buildDialogModel(
                modelCtrl: modelCtrl,
                resolutionCtrl: resolutionCtrl,
                imageUrlCtrl: imageUrlCtrl,
                batchNameCtrl: batchNameCtrl,
                batchLimitCtrl: batchLimitCtrl,
                selectedIds: const <int>[7, 8],
                selectedSingleAssetId: null,
              ),
              callbacks: buildDialogCallbacks(),
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '更新封面 URL'))
            .onPressed,
        isNull,
      );
    },
  );
}

void noop() {}
