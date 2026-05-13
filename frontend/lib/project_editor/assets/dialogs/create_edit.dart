part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsCreateEditDialogs on _HomePageState {
  /// Handles asset create and edit dialogs so the main assets section stays thin.
  Future<void> _openCreateAssetDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final l10n = AppLocalizations.of(ctx)!;
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'role');
    final descriptionCtrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          final dlgL10n = AppLocalizations.of(dialogCtx)!;
          return AlertDialog(
            title: Text(dlgL10n.projectEditorAssetCrudCreateTitle),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: dlgL10n.projectEditorAssetCrudFieldNameLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: typeCtrl,
                    decoration: InputDecoration(
                      labelText: dlgL10n.projectEditorAssetCrudFieldTypeLabel,
                      helperText:
                          dlgL10n.projectEditorAssetCrudFieldTypeHelperCreate,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: dlgL10n.projectEditorAssetCrudFieldDescriptionLabel,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(dlgL10n.projectEditorAssetCrudCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(dlgL10n.projectEditorAssetCrudCreate),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final name = nameCtrl.text.trim();
      final type = typeCtrl.text.trim();
      if (name.isEmpty || type.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(l10n.projectEditorAssetCrudCreateNameTypeRequiredSnack),
          ),
        );
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      await createProjectAssetUnderProject(
        token,
        p.id,
        name: name,
        type: type,
        description: descriptionCtrl.text.trim().isEmpty
            ? null
            : descriptionCtrl.text.trim(),
      );
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(l10n.projectEditorAssetCrudCreateSuccessSnack)),
      );
    } on RustApiException catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      nameCtrl.dispose();
      typeCtrl.dispose();
      descriptionCtrl.dispose();
    }
  }

  /// Handles asset create and edit dialogs so the main assets section stays thin.
  Future<void> _openEditAssetDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final l10n = AppLocalizations.of(ctx)!;
    final list = assetsRef[0]?.items ?? const <AssetRow>[];
    if (list.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(l10n.projectEditorAssetCrudEditNoneSnack)),
      );
      return;
    }
    var selectedAssetNumericId = list.first.numericId;
    final nameCtrl = TextEditingController(text: list.first.name);
    final typeCtrl = TextEditingController(text: list.first.assetType);
    final descriptionCtrl = TextEditingController(
      text: list.first.description ?? '',
    );
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          final dlgL10n = AppLocalizations.of(dialogCtx)!;
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              return AlertDialog(
                title: Text(dlgL10n.projectEditorAssetCrudEditTitle),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedAssetNumericId,
                        decoration: InputDecoration(
                          labelText: dlgL10n.projectEditorAssetCrudEditTargetLabel,
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
                          final selected = list.firstWhere(
                            (asset) => asset.numericId == v,
                          );
                          setState(() {
                            selectedAssetNumericId = v;
                            nameCtrl.text = selected.name;
                            typeCtrl.text = selected.assetType;
                            descriptionCtrl.text = selected.description ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: dlgL10n.projectEditorAssetCrudFieldNameLabel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: typeCtrl,
                        decoration: InputDecoration(
                          labelText: dlgL10n.projectEditorAssetCrudFieldTypeLabel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText:
                              dlgL10n.projectEditorAssetCrudFieldDescriptionLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: Text(dlgL10n.projectEditorAssetCrudCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    child: Text(dlgL10n.projectEditorAssetCrudSave),
                  ),
                ],
              );
            },
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final body = <String, dynamic>{};
      final name = nameCtrl.text.trim();
      final type = typeCtrl.text.trim();
      if (name.isNotEmpty) {
        body['name'] = name;
      }
      if (type.isNotEmpty) {
        body['asset_type'] = type;
      }
      body['description'] = descriptionCtrl.text.trim().isEmpty
          ? null
          : descriptionCtrl.text.trim();
      if (body.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(l10n.projectEditorAssetCrudEditEmptyPatchSnack)),
        );
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      await patchProjectAssetByProjectIds(
        token,
        p.id,
        selectedAssetNumericId,
        body,
      );
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            l10n.projectEditorAssetCrudEditSuccessSnack(selectedAssetNumericId),
          ),
        ),
      );
    } on RustApiException catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      nameCtrl.dispose();
      typeCtrl.dispose();
      descriptionCtrl.dispose();
    }
  }
}
