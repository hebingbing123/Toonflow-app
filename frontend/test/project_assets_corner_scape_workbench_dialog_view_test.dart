import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_editor/assets/corner_scape_view.dart';
import 'package:openflow_app/rust_api.dart';

CornerScapeHistoryImage buildHistoryImage({
  required String id,
  required int sortIndex,
  String? state,
}) {
  return CornerScapeHistoryImage(id: id, sortIndex: sortIndex, state: state);
}

CornerScapeAssetItem buildAsset({
  required int numericId,
  required String name,
  required String assetType,
  List<CornerScapeHistoryImage>? historyImages,
}) {
  return CornerScapeAssetItem(
    id: 'asset-$numericId',
    numericId: numericId,
    name: name,
    assetType: assetType,
    metadata: const <String, dynamic>{},
    historyImages: historyImages ?? const <CornerScapeHistoryImage>[],
  );
}

CornerScapeWorkbenchDialogViewModel buildModel({
  required TextEditingController typesCtrl,
  List<CornerScapeAssetItem>? assets,
  int? selectedAssetNumericId,
  String? selectedHistoryImageId,
  Uint8List? selectedPreviewBytes,
  bool busy = false,
  bool loading = false,
  bool loadingPreview = false,
  String? summaryLine = '历史图过滤：role；已加载 2 条资产。',
}) {
  final seededAssets =
      assets ??
      <CornerScapeAssetItem>[
        buildAsset(
          numericId: 21,
          name: '女主角',
          assetType: 'role',
          historyImages: <CornerScapeHistoryImage>[
            buildHistoryImage(
              id: 'img-alpha-001',
              sortIndex: 1,
              state: 'ready',
            ),
            buildHistoryImage(id: 'img-alpha-002', sortIndex: 2, state: 'done'),
          ],
        ),
        buildAsset(numericId: 22, name: '街道', assetType: 'scene'),
      ];
  final selectedAsset = seededAssets.isEmpty
      ? null
      : seededAssets.firstWhere(
          (asset) =>
              asset.numericId ==
              (selectedAssetNumericId ?? seededAssets.first.numericId),
          orElse: () => seededAssets.first,
        );
  CornerScapeHistoryImage? selectedImage;
  if (selectedAsset != null) {
    if (selectedHistoryImageId != null) {
      for (final image in selectedAsset.historyImages) {
        if (image.id == selectedHistoryImageId) {
          selectedImage = image;
          break;
        }
      }
    } else if (selectedAsset.historyImages.isNotEmpty) {
      selectedImage = selectedAsset.historyImages.first;
      selectedHistoryImageId = selectedImage.id;
    }
  }
  return CornerScapeWorkbenchDialogViewModel(
    typesCtrl: typesCtrl,
    busy: busy,
    assets: seededAssets,
    selectedAssetNumericId: selectedAsset?.numericId,
    selectedHistoryImageId: selectedHistoryImageId,
    selectedPreviewBytes: selectedPreviewBytes,
    loading: loading,
    loadingPreview: loadingPreview,
    summaryLine: summaryLine,
    selectedAsset: selectedAsset,
    selectedImage: selectedImage,
  );
}

CornerScapeWorkbenchDialogViewCallbacks buildCallbacks({
  Future<void> Function()? onRefresh,
  Future<void> Function()? onClearFilter,
  Future<void> Function(String type)? onPresetType,
  Future<void> Function(int assetNumericId)? onAssetSelected,
  Future<void> Function(String historyImageId)? onHistoryImageSelected,
  VoidCallback? onClose,
}) {
  return CornerScapeWorkbenchDialogViewCallbacks(
    onRefresh: onRefresh ?? () async {},
    onClearFilter: onClearFilter ?? () async {},
    onPresetType: onPresetType ?? (_) async {},
    onAssetSelected: onAssetSelected ?? (_) async {},
    onHistoryImageSelected: onHistoryImageSelected ?? (_) async {},
    onClose: onClose ?? () {},
  );
}

final Uint8List _transparentPng = Uint8List.fromList(<int>[
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
  15,
  4,
  0,
  9,
  251,
  3,
  253,
  160,
  90,
  146,
  223,
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

void main() {
  late TextEditingController typesCtrl;

  setUp(() {
    typesCtrl = TextEditingController(text: 'role');
  });

  tearDown(() {
    typesCtrl.dispose();
  });

  testWidgets('corner scape workbench view renders assets and preview', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CornerScapeWorkbenchDialogView(
            model: buildModel(
              typesCtrl: typesCtrl,
              selectedPreviewBytes: _transparentPng,
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('资产历史图工作台'), findsOneWidget);
    expect(find.text('查询历史图资产'), findsOneWidget);
    expect(find.textContaining('#21 女主角'), findsOneWidget);
    expect(find.text('当前图片：sort=1 · state=ready'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('corner scape workbench view disables refresh while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CornerScapeWorkbenchDialogView(
            model: buildModel(
              typesCtrl: typesCtrl,
              busy: true,
              loading: true,
              loadingPreview: true,
              summaryLine: null,
              assets: const <CornerScapeAssetItem>[],
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '加载中…'),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('正在加载历史图资产…'), findsOneWidget);
  });

  testWidgets('corner scape workbench view forwards interactions', (
    WidgetTester tester,
  ) async {
    int? tappedAssetId;
    String? tappedHistoryImageId;
    String? presetType;
    var cleared = false;
    var refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CornerScapeWorkbenchDialogView(
            model: buildModel(typesCtrl: typesCtrl),
            callbacks: buildCallbacks(
              onRefresh: () async {
                refreshed = true;
              },
              onClearFilter: () async {
                cleared = true;
              },
              onPresetType: (type) async {
                presetType = type;
              },
              onAssetSelected: (assetNumericId) async {
                tappedAssetId = assetNumericId;
              },
              onHistoryImageSelected: (historyImageId) async {
                tappedHistoryImageId = historyImageId;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('清空类型过滤'));
    await tester.pump();
    await tester.tap(find.text('props'));
    await tester.pump();
    await tester.tap(find.textContaining('#21 女主角'));
    await tester.pump();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('#2 · done'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '查询历史图资产'));
    await tester.tap(find.widgetWithText(FilledButton, '查询历史图资产'));
    await tester.pump();

    expect(cleared, isTrue);
    expect(presetType, 'props');
    expect(tappedAssetId, 21);
    expect(tappedHistoryImageId, 'img-alpha-002');
    expect(refreshed, isTrue);
  });
}
