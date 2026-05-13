import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../../rust_api.dart';

Future<void> openProjectAssetLinkDialog({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<ScriptBrief> scriptList,
  required List<ListAssetsResponse?> assetsRef,
  required List<bool> assetsBusy,
  required Future<void> Function() reloadAssetsAndStats,
  required bool unlink,
}) async {
  final l10n = AppLocalizations.of(ctx)!;
  final assets = assetsRef[0]?.items ?? const <AssetRow>[];
  if (scriptList.isEmpty || assets.isEmpty) {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetLinkNeedScriptAndAssetSnack)));
    return;
  }

  var selectedScriptNumericId = scriptList.first.numericId;
  var selectedAssetNumericId = assets.first.numericId;
  final confirmed = await showDialog<bool>(
    context: ctx,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (dialogCtx, setState) {
          final dlgL10n = AppLocalizations.of(dialogCtx)!;
          return AlertDialog(
            title: Text(
              unlink
                  ? dlgL10n.projectEditorAssetLinkDialogTitleUnlink
                  : dlgL10n.projectEditorAssetLinkDialogTitleLink,
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedScriptNumericId,
                    decoration: InputDecoration(
                      labelText: dlgL10n.projectEditorAssetLinkScriptLabel,
                    ),
                    items: scriptList
                        .map(
                          (script) => DropdownMenuItem<int>(
                            value: script.numericId,
                            child: Text(
                              '#${script.numericId} ${script.name ?? ""}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedScriptNumericId = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedAssetNumericId,
                    decoration: InputDecoration(
                      labelText: dlgL10n.projectEditorAssetLinkAssetLabel,
                    ),
                    items: assets
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
                      if (value == null) return;
                      setState(() => selectedAssetNumericId = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(dlgL10n.storyboardEditorDialogCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(
                  unlink
                      ? dlgL10n.projectEditorAssetLinkConfirmUnlink
                      : dlgL10n.projectEditorAssetLinkConfirmLink,
                ),
              ),
            ],
          );
        },
      );
    },
  );
  if (confirmed != true || !ctx.mounted) return;

  try {
    setDialogState(() => assetsBusy[0] = true);
    if (unlink) {
      await unlinkScriptFromAssetByProjectIds(
        token,
        project.id,
        selectedScriptNumericId,
        selectedAssetNumericId,
      );
    } else {
      await linkScriptToAssetByProjectIds(
        token,
        project.id,
        selectedScriptNumericId,
        selectedAssetNumericId,
      );
    }
    if (!ctx.mounted) return;
    await reloadAssetsAndStats();
    if (!ctx.mounted) return;
    setDialogState(() => assetsBusy[0] = false);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(
          unlink
              ? l10n.projectEditorAssetLinkSuccessUnlinked(
                  selectedScriptNumericId,
                  selectedAssetNumericId,
                )
              : l10n.projectEditorAssetLinkSuccessLinked(
                  selectedScriptNumericId,
                  selectedAssetNumericId,
                ),
        ),
      ),
    );
  } catch (e) {
    if (ctx.mounted) {
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
      );
    }
  }
}
