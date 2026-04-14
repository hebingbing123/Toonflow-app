import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/home_page/project_editor/assets/images/workbench_dialog_view.dart';
import 'package:openflow_app/home_page/project_editor/assets/support.dart';
import 'package:openflow_app/rust_api.dart';

AssetImagesWorkbenchDialogViewModel buildDialogModel({
  required TextEditingController createFilePathController,
  required TextEditingController createStateController,
  required TextEditingController createSortController,
  required TextEditingController patchFilePathController,
  required TextEditingController patchStateController,
  required TextEditingController patchSortController,
  bool loadingList = false,
  bool loadingPreview = false,
  bool busyMutation = false,
  Uint8List? previewBytes,
}) {
  return AssetImagesWorkbenchDialogViewModel(
    assets: const [
      AssetRow(id: 'asset-a', numericId: 7, name: '角色 A', assetType: 'role'),
    ],
    imageItems: const [
      AssetImageRow(
        id: 'img-1',
        assetId: 'asset-a',
        filePath: '/tmp/demo.png',
        sortIndex: 1,
        state: 'done',
      ),
    ],
    selectedAssetNumericId: 7,
    selectedImageId: 'img-1',
    diagnosis: const AssetImagesWorkbenchDiagnosis(
      summary: '当前图片已就绪，可继续编辑。',
      detail: '保存当前图片。',
      recommendedAction:
          AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
    ),
    loadingList: loadingList,
    loadingPreview: loadingPreview,
    busyMutation: busyMutation,
    statusLine: '已读取 1 张图片。',
    previewBytes: previewBytes,
    createFilePathController: createFilePathController,
    createStateController: createStateController,
    createSortController: createSortController,
    patchFilePathController: patchFilePathController,
    patchStateController: patchStateController,
    patchSortController: patchSortController,
  );
}

AssetImagesWorkbenchDialogViewCallbacks buildDialogCallbacks({
  VoidCallback? recommendedAction = noop,
  VoidCallback? reloadImages = noop,
  VoidCallback? loadPreview = noop,
  VoidCallback? createImage = noop,
  VoidCallback? patchImage = noop,
  VoidCallback? deleteImage = noop,
}) {
  return AssetImagesWorkbenchDialogViewCallbacks(
    onAssetChanged: (_) {},
    onRecommendedAction: recommendedAction,
    onReloadImages: reloadImages,
    onLoadPreview: loadPreview,
    onImageChanged: (_) {},
    onCreateImage: createImage,
    onPatchImage: patchImage,
    onDeleteImage: deleteImage,
  );
}

void main() {
  late TextEditingController createFilePathController;
  late TextEditingController createStateController;
  late TextEditingController createSortController;
  late TextEditingController patchFilePathController;
  late TextEditingController patchStateController;
  late TextEditingController patchSortController;

  setUp(() {
    createFilePathController = TextEditingController();
    createStateController = TextEditingController();
    createSortController = TextEditingController();
    patchFilePathController = TextEditingController();
    patchStateController = TextEditingController();
    patchSortController = TextEditingController();
  });

  tearDown(() {
    createFilePathController.dispose();
    createStateController.dispose();
    createSortController.dispose();
    patchFilePathController.dispose();
    patchStateController.dispose();
    patchSortController.dispose();
  });

  testWidgets('asset images workbench view renders shared scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetImagesWorkbenchDialogView(
            model: buildDialogModel(
              createFilePathController: createFilePathController,
              createStateController: createStateController,
              createSortController: createSortController,
              patchFilePathController: patchFilePathController,
              patchStateController: patchStateController,
              patchSortController: patchSortController,
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('资产图片工作台'), findsOneWidget);
    expect(find.text('加载图片列表'), findsOneWidget);
    expect(find.text('预览当前图片'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '新增图片'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '保存当前图片'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '删除当前图片'), findsOneWidget);
    expect(find.text('保存当前图片。'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('asset images workbench view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetImagesWorkbenchDialogView(
            model: buildDialogModel(
              createFilePathController: createFilePathController,
              createStateController: createStateController,
              createSortController: createSortController,
              patchFilePathController: patchFilePathController,
              patchStateController: patchStateController,
              patchSortController: patchSortController,
              loadingList: true,
              busyMutation: true,
            ),
            callbacks: buildDialogCallbacks(
              recommendedAction: null,
              reloadImages: null,
              createImage: null,
              patchImage: null,
              deleteImage: null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('加载中…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('asset-images-workbench-recommended-action')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '加载中…'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '新增图片'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('asset images workbench view renders preview when bytes exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetImagesWorkbenchDialogView(
            model: buildDialogModel(
              createFilePathController: createFilePathController,
              createStateController: createStateController,
              createSortController: createSortController,
              patchFilePathController: patchFilePathController,
              patchStateController: patchStateController,
              patchSortController: patchSortController,
              previewBytes: tinyTransparentPng,
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });
}

void noop() {}

final Uint8List tinyTransparentPng = Uint8List.fromList(const <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  167,
  53,
  129,
  132,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);
