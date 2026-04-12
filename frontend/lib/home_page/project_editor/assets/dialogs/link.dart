part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsLinkDialogs on _HomePageState {
  /// Handles relation dialogs so assets.dart can stay focused on section composition.
  Future<void> _openScriptAssetLinkDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    required bool unlink,
  }) async {
    final list = assetsRef[0]?.items ?? const <AssetRow>[];
    if (scriptList.isEmpty || list.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先准备至少一个剧本和一个资产')));
      return;
    }
    var selectedScriptNumericId = scriptList.first.numericId;
    var selectedAssetNumericId = list.first.numericId;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: Text(unlink ? '取消剧本-资产关联' : '关联剧本与资产'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedScriptNumericId,
                      decoration: const InputDecoration(labelText: '剧本'),
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
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => selectedScriptNumericId = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAssetNumericId,
                      decoration: const InputDecoration(labelText: '资产'),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: Text(unlink ? '取消关联' : '确认关联'),
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
          p.id,
          selectedScriptNumericId,
          selectedAssetNumericId,
        );
      } else {
        await linkScriptToAssetByProjectIds(
          token,
          p.id,
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
                ? '已取消关联 script#$selectedScriptNumericId · asset#$selectedAssetNumericId'
                : '已关联 script#$selectedScriptNumericId · asset#$selectedAssetNumericId',
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
    }
  }
}
