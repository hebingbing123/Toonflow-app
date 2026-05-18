import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_editor/assets/dialogs/candidate_status_dialog.dart';
import 'package:openflow_app/rust_api.dart';

Widget _wrapApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

AssetRow _assetRow({
  required int numericId,
  required String name,
  String? candidateStatus,
}) {
  return AssetRow(
    id: 'asset-$numericId',
    numericId: numericId,
    name: name,
    assetType: 'role',
    candidateStatus: candidateStatus,
  );
}

class _DialogLauncher extends StatefulWidget {
  const _DialogLauncher({
    required this.assets,
    required this.initialSelectedAssetNumericId,
    required this.initialPendingOnly,
    required this.onResult,
  });

  final List<AssetRow> assets;
  final int initialSelectedAssetNumericId;
  final bool initialPendingOnly;
  final ValueChanged<ProjectAssetCandidateStatusDialogResult?> onResult;

  @override
  State<_DialogLauncher> createState() => _DialogLauncherState();
}

class _DialogLauncherState extends State<_DialogLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await showDialog<ProjectAssetCandidateStatusDialogResult>(
        context: context,
        builder: (context) => ProjectAssetCandidateStatusDialog(
          assets: widget.assets,
          initialSelectedAssetNumericId: widget.initialSelectedAssetNumericId,
          initialPendingOnly: widget.initialPendingOnly,
        ),
      );
      widget.onResult(result);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('defaults to pending-only queue for pending focus', (
    tester,
  ) async {
    ProjectAssetCandidateStatusDialogResult? result;
    final assets = <AssetRow>[
      _assetRow(numericId: 1, name: 'Lead', candidateStatus: 'pending'),
      _assetRow(numericId: 2, name: 'Support', candidateStatus: 'linked'),
      _assetRow(numericId: 3, name: 'Extra', candidateStatus: 'pending'),
    ];

    await tester.pumpWidget(
      _wrapApp(
        child: _DialogLauncher(
          assets: assets,
          initialSelectedAssetNumericId: 1,
          initialPendingOnly: shouldDefaultPendingOnly(assets, 1),
          onResult: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Only show pending assets'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.text('1 of 2'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('enter saves and advances when next pending item exists', (
    tester,
  ) async {
    ProjectAssetCandidateStatusDialogResult? result;
    final assets = <AssetRow>[
      _assetRow(numericId: 1, name: 'Lead', candidateStatus: 'pending'),
      _assetRow(numericId: 2, name: 'Extra', candidateStatus: 'pending'),
    ];

    await tester.pumpWidget(
      _wrapApp(
        child: _DialogLauncher(
          assets: assets,
          initialSelectedAssetNumericId: 1,
          initialPendingOnly: true,
          onResult: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.action, ProjectAssetCandidateStatusDialogAction.saveAndNext);
    expect(result!.assetNumericId, 1);
    expect(result!.selectionKey, 'linked');
  });

  testWidgets('arrow keys navigate queue and enter saves last item', (
    tester,
  ) async {
    ProjectAssetCandidateStatusDialogResult? result;
    final assets = <AssetRow>[
      _assetRow(numericId: 1, name: 'Lead', candidateStatus: 'pending'),
      _assetRow(numericId: 2, name: 'Extra', candidateStatus: 'pending'),
    ];

    await tester.pumpWidget(
      _wrapApp(
        child: _DialogLauncher(
          assets: assets,
          initialSelectedAssetNumericId: 1,
          initialPendingOnly: true,
          onResult: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.action, ProjectAssetCandidateStatusDialogAction.save);
    expect(result!.assetNumericId, 2);
    expect(result!.selectionKey, 'ignored');
  });

  testWidgets('save to visible returns all visible asset ids', (tester) async {
    ProjectAssetCandidateStatusDialogResult? result;
    final assets = <AssetRow>[
      _assetRow(numericId: 1, name: 'Lead', candidateStatus: 'pending'),
      _assetRow(numericId: 2, name: 'Support', candidateStatus: 'linked'),
      _assetRow(numericId: 3, name: 'Extra', candidateStatus: 'pending'),
    ];

    await tester.pumpWidget(
      _wrapApp(
        child: _DialogLauncher(
          assets: assets,
          initialSelectedAssetNumericId: 1,
          initialPendingOnly: true,
          onResult: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    await tester.tap(find.text('Save to visible'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(
      result!.action,
      ProjectAssetCandidateStatusDialogAction.saveToVisible,
    );
    expect(result!.assetNumericIds, <int>[1, 3]);
    expect(result!.selectionKey, 'ignored');
  });

  testWidgets('save to remaining starts from current queue position', (
    tester,
  ) async {
    ProjectAssetCandidateStatusDialogResult? result;
    final assets = <AssetRow>[
      _assetRow(numericId: 1, name: 'Lead', candidateStatus: 'pending'),
      _assetRow(numericId: 2, name: 'Extra', candidateStatus: 'pending'),
      _assetRow(numericId: 3, name: 'Tail', candidateStatus: 'pending'),
    ];

    await tester.pumpWidget(
      _wrapApp(
        child: _DialogLauncher(
          assets: assets,
          initialSelectedAssetNumericId: 1,
          initialPendingOnly: true,
          onResult: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.tap(find.text('Save to remaining'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(
      result!.action,
      ProjectAssetCandidateStatusDialogAction.saveToRemaining,
    );
    expect(result!.assetNumericId, 2);
    expect(result!.assetNumericIds, <int>[2, 3]);
  });
}
