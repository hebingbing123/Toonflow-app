part of '../../home_page.dart';

extension _HomePageProjectEditorAssetsClipUploadWorkbench on _HomePageState {
  Future<void> _openClipUploadDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final nameCtrl = TextEditingController(
      text: 'clip_${DateTime.now().millisecondsSinceEpoch}',
    );
    final typeCtrl = TextEditingController(text: 'clip');
    final base64Ctrl = TextEditingController(
      text: 'data:image/png;base64,AA==',
    );
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return AlertDialog(
            title: const Text('上传 Clip 资产'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '资产名称',
                      helperText: '建议使用可追踪的业务名称',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: '资产类型',
                      helperText: '默认 clip；当前后端仅接受 clip',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: base64Ctrl,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: '图片 data URI / base64',
                      helperText: '支持 data URI 或原始 base64（由后端校验）',
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
      if (confirmed != true || !ctx.mounted) return;

      final name = nameCtrl.text.trim();
      final type = typeCtrl.text.trim();
      final base64Data = base64Ctrl.text.trim();
      if (name.isEmpty || type.isEmpty || base64Data.isEmpty) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('名称、类型和图片数据不能为空')));
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      final response = await postLegacyAssetsUploadClip(
        token,
        projectLegacyId: p.legacyId,
        base64Data: base64Data,
        name: name,
        assetType: type,
      );
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('上传成功：${response.message}')));
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
      base64Ctrl.dispose();
    }
  }
}
