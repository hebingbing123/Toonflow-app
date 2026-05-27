import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import '../../../design_system/tokens.dart';

import 'package:openflow_app/design_system/layout_breakpoints.dart';
import '../../../l10n/app_localizations.dart';
import '../../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

enum ProjectAssetCandidateStatusDialogAction {
  save,
  saveAndNext,
  saveToVisible,
  saveToRemaining,
}

class ProjectAssetCandidateStatusDialogResult {
  const ProjectAssetCandidateStatusDialogResult({
    required this.action,
    required this.assetNumericId,
    required this.selectionKey,
    required this.pendingOnly,
    required this.assetNumericIds,
  });

  final ProjectAssetCandidateStatusDialogAction action;
  final int assetNumericId;
  final String selectionKey;
  final bool pendingOnly;
  final List<int> assetNumericIds;
}

class ProjectAssetCandidateStatusDialog extends StatefulWidget {
  const ProjectAssetCandidateStatusDialog({
    super.key,
    required this.assets,
    required this.initialSelectedAssetNumericId,
    required this.initialPendingOnly,
  });

  final List<AssetRow> assets;
  final int initialSelectedAssetNumericId;
  final bool initialPendingOnly;

  @override
  State<ProjectAssetCandidateStatusDialog> createState() =>
      _ProjectAssetCandidateStatusDialogState();
}

class _ProjectAssetCandidateStatusDialogState
    extends State<ProjectAssetCandidateStatusDialog> {
  late int _selectedAssetNumericId;
  late bool _pendingOnly;
  late String _selectedCandidateStatus;

  @override
  void initState() {
    super.initState();
    _selectedAssetNumericId = widget.initialSelectedAssetNumericId;
    _pendingOnly = widget.initialPendingOnly;
    _selectedCandidateStatus = assetCandidateStatusSelectionKey(
      _findAssetByNumericId(
        widget.assets,
        _selectedAssetNumericId,
      )?.candidateStatus,
    );
  }

  bool get _hasPendingAssets =>
      widget.assets.any((asset) => asset.candidateStatus == 'pending');

  List<AssetRow> get _visibleAssets =>
      candidateStatusVisibleAssets(widget.assets, pendingOnly: _pendingOnly);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visibleAssets = _visibleAssets;
    if (visibleAssets.isNotEmpty &&
        !visibleAssets.any(
          (asset) => asset.numericId == _selectedAssetNumericId,
        )) {
      _selectedAssetNumericId = visibleAssets.first.numericId;
      _selectedCandidateStatus = assetCandidateStatusSelectionKey(
        visibleAssets.first.candidateStatus,
      );
    }
    final selectedAsset = _findAssetByNumericId(
      visibleAssets,
      _selectedAssetNumericId,
    );
    final selectedIndex = visibleAssets.indexWhere(
      (asset) => asset.numericId == _selectedAssetNumericId,
    );
    final previousAssetNumericId = candidateStatusNeighborId(
      visibleAssets,
      _selectedAssetNumericId,
      offset: -1,
    );
    final nextAssetNumericId = candidateStatusNeighborId(
      visibleAssets,
      _selectedAssetNumericId,
      offset: 1,
    );
    final remainingAssetNumericIds = visibleAssets
        .skip(selectedIndex < 0 ? 0 : selectedIndex)
        .map((asset) => asset.numericId)
        .toList(growable: false);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            const _CandidateNavigateIntent(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const _CandidateNavigateIntent(1),
        const SingleActivator(LogicalKeyboardKey.digit1):
            const _CandidateSetStatusIntent(assetCandidateStatusUnsetKey),
        const SingleActivator(LogicalKeyboardKey.digit2):
            const _CandidateSetStatusIntent('pending'),
        const SingleActivator(LogicalKeyboardKey.digit3):
            const _CandidateSetStatusIntent('linked'),
        const SingleActivator(LogicalKeyboardKey.digit4):
            const _CandidateSetStatusIntent('ignored'),
        const SingleActivator(LogicalKeyboardKey.numpad1):
            const _CandidateSetStatusIntent(assetCandidateStatusUnsetKey),
        const SingleActivator(LogicalKeyboardKey.numpad2):
            const _CandidateSetStatusIntent('pending'),
        const SingleActivator(LogicalKeyboardKey.numpad3):
            const _CandidateSetStatusIntent('linked'),
        const SingleActivator(LogicalKeyboardKey.numpad4):
            const _CandidateSetStatusIntent('ignored'),
        const SingleActivator(LogicalKeyboardKey.enter):
            const _CandidateSubmitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CandidateNavigateIntent: CallbackAction<_CandidateNavigateIntent>(
            onInvoke: (intent) {
              final targetAssetNumericId = candidateStatusNeighborId(
                visibleAssets,
                _selectedAssetNumericId,
                offset: intent.offset,
              );
              if (targetAssetNumericId == null) {
                return null;
              }
              _selectAsset(targetAssetNumericId, visibleAssets);
              return null;
            },
          ),
          _CandidateSetStatusIntent: CallbackAction<_CandidateSetStatusIntent>(
            onInvoke: (intent) {
              setState(() {
                _selectedCandidateStatus = intent.selectionKey;
              });
              return null;
            },
          ),
          _CandidateSubmitIntent: CallbackAction<_CandidateSubmitIntent>(
            onInvoke: (intent) {
              _submit(
                nextAssetNumericId == null
                    ? ProjectAssetCandidateStatusDialogAction.save
                    : ProjectAssetCandidateStatusDialogAction.saveAndNext,
              );
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: StudioAlertDialog(
            scrollable: true,
            title: Text(l10n.projectEditorAssetCandidateDialogTitle),
            content: SizedBox(
              width: studioConstrainedDialogWidth(context, maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.projectEditorAssetCandidateDialogIntro,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: StudioSpacing.sm),
                  if (_hasPendingAssets) ...[
                    StudioSwitchListRow(
                      contentPadding: EdgeInsets.zero,
                      value: _pendingOnly,
                      onChanged: (value) {
                        setState(() {
                          _pendingOnly = value;
                        });
                      },
                      title: Text(
                        l10n.projectEditorAssetCandidatePendingOnlyLabel,
                      ),
                      subtitle: Text(
                        l10n.projectEditorAssetCandidatePendingOnlyHelper,
                      ),
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                  ],
                  StudioDropdownButtonFormField<int>(
                    initialValue: _selectedAssetNumericId,
                    decoration: InputDecoration(
                      labelText: l10n.projectEditorAssetCandidateTargetLabel,
                    ),
                    items: visibleAssets
                        .map(
                          (asset) => DropdownMenuItem<int>(
                            value: asset.numericId,
                            child: Text(
                              '#${asset.numericId} ${asset.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      _selectAsset(value, visibleAssets);
                    },
                  ),
                  const SizedBox(height: StudioSpacing.sm),
                  Row(
                    children: [
                      IconButton(
                        tooltip: l10n.projectEditorAssetCandidatePrevious,
                        onPressed: previousAssetNumericId == null
                            ? null
                            : () => _selectAsset(
                                previousAssetNumericId,
                                visibleAssets,
                              ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          l10n.projectEditorAssetCandidateQueuePosition(
                            selectedIndex + 1,
                            visibleAssets.length,
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.projectEditorAssetCandidateNext,
                        onPressed: nextAssetNumericId == null
                            ? null
                            : () => _selectAsset(
                                nextAssetNumericId,
                                visibleAssets,
                              ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: StudioSpacing.sm),
                  Text(
                    selectedAsset == null
                        ? l10n.projectEditorAssetCandidateCurrentStatusEmpty
                        : l10n.projectEditorAssetCandidateCurrentStatusLine(
                            assetCandidateStatusLabel(
                              l10n,
                              selectedAsset.candidateStatus,
                            ),
                          ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: StudioSpacing.sm),
                  Text(
                    l10n.projectEditorAssetCandidateNextStatusLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: assetCandidateStatusUnsetKey,
                        label: Text(
                          l10n.projectEditorAssetCandidateStatusUnset,
                        ),
                      ),
                      ButtonSegment<String>(
                        value: 'pending',
                        label: Text(
                          l10n.projectEditorAssetCandidateStatusPending,
                        ),
                      ),
                      ButtonSegment<String>(
                        value: 'linked',
                        label: Text(
                          l10n.projectEditorAssetCandidateStatusLinked,
                        ),
                      ),
                      ButtonSegment<String>(
                        value: 'ignored',
                        label: Text(
                          l10n.projectEditorAssetCandidateStatusIgnored,
                        ),
                      ),
                    ],
                    selected: <String>{_selectedCandidateStatus},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      setState(() {
                        _selectedCandidateStatus = selection.first;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.projectEditorAssetCrudCancel),
              ),
              OutlinedButton(
                style: studioFormSecondaryButtonStyle(context),
                onPressed: () =>
                    _submit(ProjectAssetCandidateStatusDialogAction.save),
                child: Text(l10n.projectEditorAssetCandidateSaveStatus),
              ),
              OutlinedButton(
                style: studioFormSecondaryButtonStyle(context),
                onPressed: visibleAssets.length < 2
                    ? null
                    : () => _submit(
                        ProjectAssetCandidateStatusDialogAction.saveToVisible,
                        assetNumericIds: visibleAssets
                            .map((asset) => asset.numericId)
                            .toList(growable: false),
                      ),
                child: Text(l10n.projectEditorAssetCandidateSaveToVisible),
              ),
              OutlinedButton(
                style: studioFormSecondaryButtonStyle(context),
                onPressed: remainingAssetNumericIds.length < 2
                    ? null
                    : () => _submit(
                        ProjectAssetCandidateStatusDialogAction.saveToRemaining,
                        assetNumericIds: remainingAssetNumericIds,
                      ),
                child: Text(l10n.projectEditorAssetCandidateSaveToRemaining),
              ),
              FilledButton(
                style: studioFormPrimaryButtonStyle(context),
                onPressed: nextAssetNumericId == null
                    ? null
                    : () => _submit(
                        ProjectAssetCandidateStatusDialogAction.saveAndNext,
                      ),
                child: Text(l10n.projectEditorAssetCandidateSaveAndNext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectAsset(int assetNumericId, List<AssetRow> visibleAssets) {
    final asset = _findAssetByNumericId(visibleAssets, assetNumericId);
    setState(() {
      _selectedAssetNumericId = assetNumericId;
      _selectedCandidateStatus = assetCandidateStatusSelectionKey(
        asset?.candidateStatus,
      );
    });
  }

  void _submit(
    ProjectAssetCandidateStatusDialogAction action, {
    List<int>? assetNumericIds,
  }) {
    Navigator.of(context).pop(
      ProjectAssetCandidateStatusDialogResult(
        action: action,
        assetNumericId: _selectedAssetNumericId,
        selectionKey: _selectedCandidateStatus,
        pendingOnly: _pendingOnly,
        assetNumericIds: assetNumericIds ?? <int>[_selectedAssetNumericId],
      ),
    );
  }
}

const String assetCandidateStatusUnsetKey = 'unset';

bool shouldDefaultPendingOnly(
  List<AssetRow> assets,
  int? selectedAssetNumericId,
) {
  if (!assets.any((asset) => asset.candidateStatus == 'pending')) {
    return false;
  }
  return _findAssetByNumericId(
        assets,
        selectedAssetNumericId,
      )?.candidateStatus ==
      'pending';
}

List<AssetRow> candidateStatusVisibleAssets(
  List<AssetRow> assets, {
  required bool pendingOnly,
}) {
  if (!pendingOnly) {
    return assets;
  }
  return assets
      .where((asset) => asset.candidateStatus == 'pending')
      .toList(growable: false);
}

int? candidateStatusNeighborId(
  List<AssetRow> assets,
  int? selectedAssetNumericId, {
  required int offset,
}) {
  if (selectedAssetNumericId == null) {
    return null;
  }
  final index = assets.indexWhere(
    (asset) => asset.numericId == selectedAssetNumericId,
  );
  if (index < 0) {
    return null;
  }
  final targetIndex = index + offset;
  if (targetIndex < 0 || targetIndex >= assets.length) {
    return null;
  }
  return assets[targetIndex].numericId;
}

String assetCandidateStatusSelectionKey(String? candidateStatus) {
  switch (candidateStatus) {
    case 'pending':
    case 'linked':
    case 'ignored':
      return candidateStatus!;
    default:
      return assetCandidateStatusUnsetKey;
  }
}

String? assetCandidateStatusPatchValue(String selectionKey) {
  return selectionKey == assetCandidateStatusUnsetKey ? null : selectionKey;
}

String assetCandidateStatusLabel(
  AppLocalizations l10n,
  String? candidateStatus,
) {
  switch (candidateStatus) {
    case 'pending':
      return l10n.projectEditorAssetCandidateStatusPending;
    case 'linked':
      return l10n.projectEditorAssetCandidateStatusLinked;
    case 'ignored':
      return l10n.projectEditorAssetCandidateStatusIgnored;
    default:
      return l10n.projectEditorAssetCandidateStatusUnset;
  }
}

AssetRow? _findAssetByNumericId(List<AssetRow> assets, int? numericId) {
  if (numericId == null) {
    return null;
  }
  for (final asset in assets) {
    if (asset.numericId == numericId) {
      return asset;
    }
  }
  return null;
}

class _CandidateNavigateIntent extends Intent {
  const _CandidateNavigateIntent(this.offset);

  final int offset;
}

class _CandidateSetStatusIntent extends Intent {
  const _CandidateSetStatusIntent(this.selectionKey);

  final String selectionKey;
}

class _CandidateSubmitIntent extends Intent {
  const _CandidateSubmitIntent();
}
