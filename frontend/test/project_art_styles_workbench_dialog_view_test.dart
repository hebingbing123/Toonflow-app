import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/projects/workbenches/art_styles_view.dart';
import 'package:openflow_app/rust_api.dart';

Widget _appWithZh({required Widget child}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('zh'),
  home: Scaffold(body: child),
);

ArtStyleRow buildStyle({
  required int numericId,
  required String name,
  String? label,
  String? prompt,
  String? fileUrl,
}) {
  return ArtStyleRow(
    id: 'style-$numericId',
    numericId: numericId,
    name: name,
    label: label,
    prompt: prompt,
    fileUrl: fileUrl,
  );
}

ArtStylesWorkbenchDialogViewModel buildModel({
  required TextEditingController nameCtrl,
  required TextEditingController labelCtrl,
  required TextEditingController promptCtrl,
  required TextEditingController fileUrlCtrl,
  required TextEditingController extractImagesCtrl,
  List<ArtStyleRow>? rows,
  ArtStyleRow? selected,
  Uint8List? coverBytes,
  String? statusLine = '已刷新 2 条画风。',
  bool busy = false,
  bool loadingCover = false,
}) {
  final seededRows =
      rows ??
      <ArtStyleRow>[
        buildStyle(
          numericId: 11,
          name: '水墨古风',
          label: 'ink',
          prompt: 'soft ink wash',
          fileUrl: '/cover/11',
        ),
        buildStyle(
          numericId: 12,
          name: '赛博霓虹',
          label: 'cyber',
          prompt: 'neon city',
          fileUrl: '/cover/12',
        ),
      ];
  return ArtStylesWorkbenchDialogViewModel(
    rows: seededRows,
    selected: selected ?? seededRows.first,
    coverBytes: coverBytes,
    statusLine: statusLine,
    busy: busy,
    loadingCover: loadingCover,
    nameCtrl: nameCtrl,
    labelCtrl: labelCtrl,
    promptCtrl: promptCtrl,
    fileUrlCtrl: fileUrlCtrl,
    extractImagesCtrl: extractImagesCtrl,
  );
}

ArtStylesWorkbenchDialogViewCallbacks buildCallbacks({
  Future<void> Function({int? preferredNumericId})? onReloadRows,
  Future<void> Function()? onLoadCover,
  Future<void> Function()? onCreateStyle,
  Future<void> Function()? onSaveSelected,
  Future<void> Function()? onDeleteSelected,
  Future<void> Function()? onExtractPrompt,
  void Function(ArtStyleRow row, {bool loadCover})? onApplySelection,
  VoidCallback? onClose,
}) {
  return ArtStylesWorkbenchDialogViewCallbacks(
    onReloadRows: onReloadRows ?? ({int? preferredNumericId}) async {},
    onLoadCover: onLoadCover ?? () async {},
    onCreateStyle: onCreateStyle ?? () async {},
    onSaveSelected: onSaveSelected ?? () async {},
    onDeleteSelected: onDeleteSelected ?? () async {},
    onExtractPrompt: onExtractPrompt ?? () async {},
    onApplySelection: onApplySelection ?? (_, {bool loadCover = true}) {},
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
  final zh = AppLocalizationsZh();
  late TextEditingController nameCtrl;
  late TextEditingController labelCtrl;
  late TextEditingController promptCtrl;
  late TextEditingController fileUrlCtrl;
  late TextEditingController extractImagesCtrl;

  setUp(() {
    nameCtrl = TextEditingController(text: '水墨古风');
    labelCtrl = TextEditingController(text: 'ink');
    promptCtrl = TextEditingController(text: 'soft ink wash');
    fileUrlCtrl = TextEditingController(text: '/cover/11');
    extractImagesCtrl = TextEditingController(
      text: 'https://example.com/a.png',
    );
  });

  tearDown(() {
    nameCtrl.dispose();
    labelCtrl.dispose();
    promptCtrl.dispose();
    fileUrlCtrl.dispose();
    extractImagesCtrl.dispose();
  });

  testWidgets('art styles workbench view renders scaffold and fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appWithZh(
        child: ArtStylesWorkbenchDialogView(
          model: buildModel(
            nameCtrl: nameCtrl,
            labelCtrl: labelCtrl,
            promptCtrl: promptCtrl,
            fileUrlCtrl: fileUrlCtrl,
            extractImagesCtrl: extractImagesCtrl,
          ),
          callbacks: buildCallbacks(),
        ),
      ),
    );

    expect(find.text(zh.projectsArtWorkbenchTitle), findsOneWidget);
    expect(find.text(zh.projectsArtWorkbenchExtractTitle), findsOneWidget);
    expect(find.text(zh.projectsArtWorkbenchExtractButton), findsOneWidget);
    expect(find.textContaining('#11 水墨古风'), findsOneWidget);
    expect(find.widgetWithText(TextField, '水墨古风'), findsOneWidget);
    expect(find.text('已刷新 2 条画风。'), findsOneWidget);
  });

  testWidgets('art styles workbench view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appWithZh(
        child: ArtStylesWorkbenchDialogView(
          model: buildModel(
            nameCtrl: nameCtrl,
            labelCtrl: labelCtrl,
            promptCtrl: promptCtrl,
            fileUrlCtrl: fileUrlCtrl,
            extractImagesCtrl: extractImagesCtrl,
            busy: true,
            loadingCover: true,
            statusLine: null,
          ),
          callbacks: buildCallbacks(),
        ),
      ),
    );

    expect(find.text(zh.projectsBusyProcessing), findsOneWidget);
    expect(find.text(zh.projectsArtWorkbenchReadingCover), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(
            disabledButtonWithText(zh.projectsBusyProcessing),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ButtonStyleButton>(
            disabledButtonWithText(zh.projectsArtWorkbenchReadingCover),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ButtonStyleButton>(
            disabledButtonWithText(zh.projectsArtWorkbenchNew),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'art styles workbench view forwards selection and close actions',
    (WidgetTester tester) async {
      ArtStyleRow? picked;
      var closeTapped = 0;

      await tester.pumpWidget(
        _appWithZh(
          child: ArtStylesWorkbenchDialogView(
            model: buildModel(
              nameCtrl: nameCtrl,
              labelCtrl: labelCtrl,
              promptCtrl: promptCtrl,
              fileUrlCtrl: fileUrlCtrl,
              extractImagesCtrl: extractImagesCtrl,
              coverBytes: _transparentPng,
            ),
            callbacks: buildCallbacks(
              onApplySelection: (row, {bool loadCover = true}) => picked = row,
              onClose: () => closeTapped++,
            ),
          ),
        ),
      );

      await tester.tap(find.text(zh.shortVideoSpaceClose));
      await tester.pump();
      expect(closeTapped, 1);

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#12 赛博霓虹').last);
      await tester.pumpAndSettle();

      expect(picked?.numericId, 12);
      expect(find.text(zh.projectsArtWorkbenchCoverPreview), findsOneWidget);
    },
  );
}
