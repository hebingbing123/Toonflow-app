import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import 'dialog_view.dart';
import 'support.dart';

part 'dialog_state.dart';
part 'dialog_state_helpers.dart';
part 'dialog_state_mutation_helpers.dart';
part 'dialog_state_selection_helpers.dart';

class AssetGenerationWorkbenchDialog extends StatefulWidget {
  const AssetGenerationWorkbenchDialog({
    super.key,
    required this.token,
    required this.project,
    required this.scriptList,
    required this.visibleAssets,
    required this.assetsFilterScriptNumericId,
    required this.initialSelectedIds,
    required this.initialFocusedAssetNumericId,
    required this.initialScriptNumericId,
    required this.onMutationStart,
    required this.onMutationEnd,
    required this.reloadAssetsAndStats,
  });

  final String token;
  final ProjectRow project;
  final List<ScriptBrief> scriptList;
  final List<AssetRow> Function() visibleAssets;
  final List<int?> assetsFilterScriptNumericId;
  final Iterable<int> initialSelectedIds;
  final int? initialFocusedAssetNumericId;
  final int initialScriptNumericId;
  final VoidCallback onMutationStart;
  final VoidCallback onMutationEnd;
  final Future<void> Function() reloadAssetsAndStats;

  @override
  State<AssetGenerationWorkbenchDialog> createState() =>
      _AssetGenerationWorkbenchDialogState();
}
