part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsUploadDialogs on _HomePageState {
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
    var selectedScriptNumericId = scriptList.first.numericId;
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
                        initialValue: selectedScriptNumericId,
                        decoration: const InputDecoration(labelText: '目标剧本'),
                        items: scriptList
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s.numericId,
                                child: Text(
                                  '#${s.numericId} ${s.name ?? ""}',
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
        projectId: p.numericId,
        scriptId: selectedScriptNumericId,
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
}
