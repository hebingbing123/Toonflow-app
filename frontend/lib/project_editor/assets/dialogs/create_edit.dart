part of '../../../home_page.dart';

extension _HomePageProjectEditorAssetsCreateEditDialogs on _HomePageState {
  int? _chooseInitialAssetNumericId(
    Iterable<AssetRow> assets, {
    int? preferredNumericId,
  }) {
    final rows = assets.toList(growable: false);
    if (rows.isEmpty) {
      return null;
    }
    if (preferredNumericId != null) {
      for (final asset in rows) {
        if (asset.numericId == preferredNumericId) {
          return preferredNumericId;
        }
      }
    }
    return rows.first.numericId;
  }

  /// Handles asset create and edit dialogs so the main assets section stays thin.
  Future<void> _openCreateAssetDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'role');
    final descriptionCtrl = TextEditingController();
    try {
      final confirmed = await showStudioDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          final dlgL10n = resolveAppLocalizationsForErrors(dialogCtx);
          return StudioAlertDialog(
            title: Text(dlgL10n.projectEditorAssetCrudCreateTitle),
            content: SizedBox(
              width: studioConstrainedDialogWidth(context, maxWidth: 520),
              child: StudioFormKeyboardScope(
                onEnterSubmit: () => Navigator.of(dialogCtx).pop(true),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: dlgL10n.projectEditorAssetCrudFieldNameLabel,
                    ),
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  TextField(
                    controller: typeCtrl,
                    decoration: InputDecoration(
                      labelText: dlgL10n.projectEditorAssetCrudFieldTypeLabel,
                      helperText:
                          dlgL10n.projectEditorAssetCrudFieldTypeHelperCreate,
                    ),
                  ),
                  const SizedBox(height: StudioSpacing.xs),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(dlgL10n.projectEditorAssetCrudCancel),
              ),
              FilledButton(
                style: studioFormPrimaryButtonStyle(dialogCtx),
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
            content: Text(
              l10n.projectEditorAssetCrudCreateNameTypeRequiredSnack,
            ),
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
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))),
        );
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
    final l10n = resolveAppLocalizationsForErrors(ctx);
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
      final confirmed = await showStudioDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          final dlgL10n = resolveAppLocalizationsForErrors(dialogCtx);
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              return StudioAlertDialog(
                title: Text(dlgL10n.projectEditorAssetCrudEditTitle),
                content: SizedBox(
                  width: studioConstrainedDialogWidth(context, maxWidth: 520),
                  child: StudioFormKeyboardScope(
                    onEnterSubmit: () => Navigator.of(dialogCtx).pop(true),
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StudioDropdownButtonFormField<int>(
                        initialValue: selectedAssetNumericId,
                        decoration: InputDecoration(
                          labelText:
                              dlgL10n.projectEditorAssetCrudEditTargetLabel,
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
                      const SizedBox(height: StudioSpacing.xs),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText:
                              dlgL10n.projectEditorAssetCrudFieldNameLabel,
                        ),
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      TextField(
                        controller: typeCtrl,
                        decoration: InputDecoration(
                          labelText:
                              dlgL10n.projectEditorAssetCrudFieldTypeLabel,
                        ),
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      TextField(
                        controller: descriptionCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: dlgL10n
                              .projectEditorAssetCrudFieldDescriptionLabel,
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: Text(dlgL10n.projectEditorAssetCrudCancel),
                  ),
                  FilledButton(
                    style: studioFormPrimaryButtonStyle(dialogCtx),
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
          SnackBar(
            content: Text(l10n.projectEditorAssetCrudEditEmptyPatchSnack),
          ),
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
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))),
        );
      }
    } finally {
      nameCtrl.dispose();
      typeCtrl.dispose();
      descriptionCtrl.dispose();
    }
  }

  Future<void> _openCandidateStatusDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    int? preferredAssetNumericId,
  }) async {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    var list = assetsRef[0]?.items ?? const <AssetRow>[];
    if (list.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(l10n.projectEditorAssetCrudEditNoneSnack)),
      );
      return;
    }
    var selectedAssetNumericId =
        _chooseInitialAssetNumericId(
          list,
          preferredNumericId: preferredAssetNumericId,
        ) ??
        list.first.numericId;
    var pendingOnly = shouldDefaultPendingOnly(list, selectedAssetNumericId);
    try {
      while (ctx.mounted) {
        final hasPendingAssets = list.any(
          (asset) => asset.candidateStatus == 'pending',
        );
        if (!hasPendingAssets) {
          pendingOnly = false;
        }
        final visibleAssets = candidateStatusVisibleAssets(
          list,
          pendingOnly: pendingOnly,
        );
        if (visibleAssets.isEmpty) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(l10n.projectEditorAssetCandidateQueueDoneSnack),
            ),
          );
          return;
        }
        if (!visibleAssets.any(
          (asset) => asset.numericId == selectedAssetNumericId,
        )) {
          selectedAssetNumericId = visibleAssets.first.numericId;
        }
        final decision =
            await showStudioDialog<ProjectAssetCandidateStatusDialogResult>(
              context: ctx,
              builder: (dialogCtx) => ProjectAssetCandidateStatusDialog(
                assets: list,
                initialSelectedAssetNumericId: selectedAssetNumericId,
                initialPendingOnly: pendingOnly,
              ),
            );
        if (decision == null || !ctx.mounted) {
          return;
        }
        pendingOnly = decision.pendingOnly && hasPendingAssets;
        final previousVisibleAssets = visibleAssets;
        final previousIndex = previousVisibleAssets.indexWhere(
          (asset) => asset.numericId == decision.assetNumericId,
        );
        final targetAssetNumericIds = decision.assetNumericIds.isEmpty
            ? <int>[decision.assetNumericId]
            : decision.assetNumericIds;
        final savedAssetNumericId = decision.assetNumericId;
        final savedCandidateStatus = decision.selectionKey;
        setDialogState(() => assetsBusy[0] = true);
        for (final assetNumericId in targetAssetNumericIds) {
          await patchProjectAssetByProjectIds(token, p.id, assetNumericId, {
            'candidate_status': assetCandidateStatusPatchValue(
              savedCandidateStatus,
            ),
          });
        }
        if (!ctx.mounted) {
          return;
        }
        await reloadAssetsAndStats();
        if (!ctx.mounted) {
          return;
        }
        list = assetsRef[0]?.items ?? const <AssetRow>[];
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              targetAssetNumericIds.length == 1
                  ? l10n.projectEditorAssetCandidateSaveSuccessSnack(
                      savedAssetNumericId,
                      assetCandidateStatusLabel(
                        l10n,
                        assetCandidateStatusPatchValue(savedCandidateStatus),
                      ),
                    )
                  : l10n.projectEditorAssetCandidateBulkSaveSuccessSnack(
                      targetAssetNumericIds.length,
                      assetCandidateStatusLabel(
                        l10n,
                        assetCandidateStatusPatchValue(savedCandidateStatus),
                      ),
                    ),
            ),
          ),
        );
        if (decision.action ==
            ProjectAssetCandidateStatusDialogAction.saveToVisible) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(l10n.projectEditorAssetCandidateQueueDoneSnack),
            ),
          );
          return;
        }
        if (decision.action ==
            ProjectAssetCandidateStatusDialogAction.saveToRemaining) {
          final nextVisibleAssets = candidateStatusVisibleAssets(
            list,
            pendingOnly: pendingOnly,
          );
          if (nextVisibleAssets.isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(l10n.projectEditorAssetCandidateQueueDoneSnack),
              ),
            );
            return;
          }
          final firstUntouched = nextVisibleAssets.firstWhere(
            (asset) => !targetAssetNumericIds.contains(asset.numericId),
            orElse: () => nextVisibleAssets.first,
          );
          selectedAssetNumericId = firstUntouched.numericId;
          continue;
        }
        if (decision.action !=
            ProjectAssetCandidateStatusDialogAction.saveAndNext) {
          return;
        }
        final nextVisibleAssets = candidateStatusVisibleAssets(
          list,
          pendingOnly: pendingOnly,
        );
        if (nextVisibleAssets.isEmpty) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(l10n.projectEditorAssetCandidateQueueDoneSnack),
            ),
          );
          return;
        }
        final nextIndex = previousIndex < nextVisibleAssets.length
            ? previousIndex
            : nextVisibleAssets.length - 1;
        selectedAssetNumericId = nextVisibleAssets[nextIndex].numericId;
      }
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))),
        );
      }
    }
  }
}
