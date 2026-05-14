import 'package:flutter/material.dart';

import '../../rust_api.dart';

Future<void> openProjectAssetClipUploadDialog({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<bool> assetsBusy,
  required Future<void> Function() reloadAssetsAndStats,
}) async {
  final l10n = resolveAppLocalizationsForErrors(ctx);
  final nameCtrl = TextEditingController(
    text: 'clip_${DateTime.now().millisecondsSinceEpoch}',
  );
  final typeCtrl = TextEditingController(text: 'clip');
  final base64Ctrl = TextEditingController(text: 'data:image/png;base64,AA==');
  try {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        final dlgL10n = resolveAppLocalizationsForErrors(dialogCtx);
        return AlertDialog(
          title: Text(dlgL10n.projectEditorAssetClipUploadDialogTitle),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: dlgL10n.projectEditorAssetClipUploadNameLabel,
                    helperText: dlgL10n.projectEditorAssetClipUploadNameHelper,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: typeCtrl,
                  decoration: InputDecoration(
                    labelText: dlgL10n.projectEditorAssetClipUploadTypeLabel,
                    helperText: dlgL10n.projectEditorAssetClipUploadTypeHelper,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: base64Ctrl,
                  minLines: 4,
                  maxLines: 7,
                  decoration: InputDecoration(
                    labelText: dlgL10n.projectEditorAssetClipUploadImageDataLabel,
                    helperText: dlgL10n.projectEditorAssetClipUploadImageDataHelper,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(dlgL10n.projectEditorAssetClipUploadCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(dlgL10n.projectEditorAssetClipUploadUpload),
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
      ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetClipUploadFieldsRequiredSnack)));
      return;
    }

    setDialogState(() => assetsBusy[0] = true);
    final response = await postWorkbenchAssetsUploadClip(
      token,
      projectId: project.id,
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
    ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetClipUploadSuccessSnack(response.message))));
  } catch (e) {
    if (ctx.mounted) {
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
      );
    }
  } finally {
    nameCtrl.dispose();
    typeCtrl.dispose();
    base64Ctrl.dispose();
  }
}
