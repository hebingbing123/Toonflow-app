part of '../home_page.dart';

extension _HomePageProjectEditorAssets on _HomePageState {
  Future<void> _openEditImageUploadDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<bool> assetsBusy,
  }) async {
    if (scriptList.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先创建剧本再上传编辑图片')));
      return;
    }
    final base64Ctrl = TextEditingController(
      text: 'data:image/png;base64,AA==',
    );
    var selectedScriptLegacyId = scriptList.first.legacyId;
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              return AlertDialog(
                title: const Text('上传编辑图片'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedScriptLegacyId,
                        decoration: const InputDecoration(labelText: '目标剧本'),
                        items: scriptList
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s.legacyId,
                                child: Text(
                                  '#${s.legacyId} ${s.name ?? ""}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => selectedScriptLegacyId = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: base64Ctrl,
                        minLines: 4,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: '图片 data URI',
                          helperText: '支持 jpeg/jpg/png 的 base64 data URI',
                        ),
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
                    child: const Text('上传'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final payload = base64Ctrl.text.trim();
      if (payload.isEmpty) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('base64 data URI 不能为空')));
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      final uploaded = await postProductionEditImageUploadImageV1(
        token,
        projectId: p.legacyId,
        scriptId: selectedScriptLegacyId,
        base64Data: payload,
      );
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('上传成功：${uploaded.url}')));
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
      base64Ctrl.dispose();
    }
  }

  Widget _buildProjectAssetsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptLegacyId,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetsRef[0] != null)
          Text(
            assetsRef[0]!.items.isEmpty
                ? '当前没有资产'
                : '资产 ${assetsRef[0]!.total} 条 · ${assetsRef[0]!.items.take(6).map((a) => '#${a.legacyId}:${a.assetType}').join(', ')}${assetsRef[0]!.items.length > 6 ? '…' : ''}',
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          Text(
            '资产列表尚未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
        if (assetsFilterScriptLegacyId[0] != null) ...[
          const SizedBox(height: 6),
          if (assetsScriptFilterLoading[0])
            Text(
              '正在按剧本筛选资产…',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.outline,
              ),
            )
          else if (assetsForScriptRef[0] != null)
            Text(
              assetsForScriptRef[0]!.items.isEmpty
                  ? '当前剧本下没有关联资产'
                  : '当前剧本下 ${assetsForScriptRef[0]!.total} 条 · ${assetsForScriptRef[0]!.items.take(6).map((a) => '#${a.legacyId}:${a.assetType}').join(', ')}${assetsForScriptRef[0]!.items.length > 6 ? '…' : ''}',
              style: Theme.of(ctx).textTheme.bodySmall,
            )
          else
            Text(
              '当前剧本资产尚未加载',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.outline,
              ),
            ),
        ],
        if (scriptList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButton<int?>(
              value: assetsFilterScriptLegacyId[0],
              isExpanded: true,
              hint: const Text('按剧本筛选资产列表'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('（全部，不按剧本筛选）'),
                ),
                ...scriptList.map(
                  (s) => DropdownMenuItem<int?>(
                    value: s.legacyId,
                    child: Text(
                      '#${s.legacyId} ${s.name ?? ""}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged:
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : (v) async {
                      setDialogState(() => assetsScriptFilterLoading[0] = true);
                      assetsFilterScriptLegacyId[0] = v;
                      if (v == null) {
                        assetsForScriptRef[0] = null;
                      }
                      try {
                        await reloadAssetsAndStats();
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(
                            () => assetsScriptFilterLoading[0] = false,
                          );
                        }
                      }
                    },
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: assetsLoading[0] || assetsScriptFilterLoading[0]
                ? null
                : () async {
                    setDialogState(() => assetsLoading[0] = true);
                    try {
                      await reloadAssetsAndStats();
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => assetsLoading[0] = false);
                      }
                    }
                  },
            child: Text(assetsLoading[0] ? '刷新资产…' : '刷新资产'),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed:
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () => _openEditImageUploadDialog(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      token: token,
                      p: p,
                      scriptList: scriptList,
                      assetsBusy: assetsBusy,
                    ),
              child: const Text('上传编辑图片'),
            ),
            ..._buildProjectAssetsPrimaryActions(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              assetsRef: assetsRef,
              assetsFilterScriptLegacyId: assetsFilterScriptLegacyId,
              assetsLoading: assetsLoading,
              assetsScriptFilterLoading: assetsScriptFilterLoading,
              assetsBusy: assetsBusy,
              reloadAssetsAndStats: reloadAssetsAndStats,
            ),
            ..._buildProjectAssetsRelationActions(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              scriptList: scriptList,
              assetsRef: assetsRef,
              assetsLoading: assetsLoading,
              assetsScriptFilterLoading: assetsScriptFilterLoading,
              assetsBusy: assetsBusy,
              reloadAssetsAndStats: reloadAssetsAndStats,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留旧资产轮询、历史图片和 legacy 形检查入口，默认折叠',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
          children: [
            _buildProjectAssetsImagesCompatibilitySection(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              assetsRef: assetsRef,
              assetsLoading: assetsLoading,
              assetsScriptFilterLoading: assetsScriptFilterLoading,
              assetsBusy: assetsBusy,
              reloadAssetsAndStats: reloadAssetsAndStats,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                ..._buildProjectAssetsQueryCompatibilityActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: assetsRef,
                  assetsFilterScriptLegacyId: assetsFilterScriptLegacyId,
                  assetsLoading: assetsLoading,
                  assetsScriptFilterLoading: assetsScriptFilterLoading,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
