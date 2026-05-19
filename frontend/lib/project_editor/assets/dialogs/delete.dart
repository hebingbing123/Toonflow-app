import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsDialogs on _HomePageState {

  /// Handles delete dialogs so assets.dart can stay focused on section composition.
  Future<void> _openDeleteAssetDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    final list = assetsRef[0]?.items ?? const <AssetRow>[];
    if (list.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetDeleteDialogNoAssetsSnack)));
      return;
    }
    var selectedAssetNumericId = list.first.numericId;
    final confirmed = await showStudioDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        final dlgL10n = resolveAppLocalizationsForErrors(dialogCtx);
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return StudioAlertDialog(
              title: Text(dlgL10n.projectEditorAssetDeleteDialogTitle),
              content: SizedBox(
                width: 420,
                child: StudioDropdownButtonFormField<int>(
                  initialValue: selectedAssetNumericId,
                  decoration: InputDecoration(
                    labelText: dlgL10n.projectEditorAssetDeleteDialogTargetLabel,
                  ),
                  items: list
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
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selectedAssetNumericId = v);
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: Text(dlgL10n.projectEditorAssetDeleteDialogCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: Text(dlgL10n.projectEditorAssetDeleteDialogConfirm),
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
      await deleteProjectAssetByProjectIds(
        token,
        p.id,
        selectedAssetNumericId,
      );
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetDeleteSuccessSnack(selectedAssetNumericId))));
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
        );
      }
    }
  }

}
