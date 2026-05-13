part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsFilterDialogs on _HomePageState {
  Future<void> _openAssetFilterDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptNumericId,
    required List<bool> assetsBusy,
  }) async {
    final typeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final pageCtrl = TextEditingController(text: '1');
    final limitCtrl = TextEditingController(text: '20');
    int? selectedScriptNumericId = assetsFilterScriptNumericId[0];
    final l10n = AppLocalizations.of(ctx)!;
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              return AlertDialog(
                title: Text(l10n.projectEditorAssetFilterDialogTitle),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: selectedScriptNumericId,
                        decoration: InputDecoration(
                          labelText: l10n.projectEditorAssetFilterByScript,
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(l10n.projectEditorAssetFilterAllScripts),
                          ),
                          ...scriptList.map(
                            (script) => DropdownMenuItem<int?>(
                              value: script.numericId,
                              child: Text(
                                '#${script.numericId} ${script.name ?? ""}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          selectedScriptNumericId = v;
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: typeCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.projectEditorAssetFilterAssetTypeOptional,
                          hintText: l10n.projectEditorAssetFilterAssetTypeHint,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.projectEditorAssetFilterNameContainsOptional,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.projectEditorAssetFilterPage,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: limitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.projectEditorAssetFilterLimit,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: Text(l10n.storyboardEditorDialogCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    child: Text(l10n.projectEditorAssetFilterApply),
                  ),
                ],
              );
            },
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;

      final page = int.tryParse(pageCtrl.text.trim());
      final limit = int.tryParse(limitCtrl.text.trim());
      if ((page != null && page <= 0) || (limit != null && limit <= 0)) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(l10n.projectEditorAssetFilterSnackbarPageLimitPositive),
          ),
        );
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      final filtered = await fetchProjectAssetsByProjectId(
        token,
        p.id,
        scriptNumericId: selectedScriptNumericId,
        assetType: typeCtrl.text.trim().isEmpty ? null : typeCtrl.text.trim(),
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
        page: page,
        limit: limit,
      );
      if (!ctx.mounted) return;
      setDialogState(() {
        assetsRef[0] = filtered;
        assetsFilterScriptNumericId[0] = selectedScriptNumericId;
        if (selectedScriptNumericId != null) {
          assetsForScriptRef[0] = filtered;
        } else {
          assetsForScriptRef[0] = null;
        }
        assetsBusy[0] = false;
      });
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            l10n.projectEditorAssetFilterSnackbarApplied(
              filtered.items.length,
              filtered.total,
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
    } finally {
      typeCtrl.dispose();
      nameCtrl.dispose();
      pageCtrl.dispose();
      limitCtrl.dispose();
    }
  }
}
