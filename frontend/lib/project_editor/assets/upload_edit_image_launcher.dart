import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';

import 'package:openflow_app/design_system/layout_breakpoints.dart';
import '../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/design_system/ix/studio_form_keyboard.dart';

Future<void> openProjectAssetEditImageUploadDialog({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<ScriptBrief> scriptList,
  required List<bool> assetsBusy,
}) async {
  final l10n = resolveAppLocalizationsForErrors(ctx);
  if (scriptList.isEmpty) {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetEditImageNeedScriptSnack)));
    return;
  }
  final base64Ctrl = TextEditingController(text: 'data:image/png;base64,AA==');
  var selectedScriptNumericId = scriptList.first.numericId;
  try {
    final confirmed = await showStudioDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            final dlgL10n = resolveAppLocalizationsForErrors(dialogCtx);
            return StudioAlertDialog(
              title: Text(dlgL10n.projectEditorAssetEditImageDialogTitle),
              content: SizedBox(
                width: studioConstrainedDialogWidth(dialogCtx, maxWidth: 520),
                child: StudioFormKeyboardScope(
                  onEnterSubmit: () => Navigator.of(dialogCtx).pop(true),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StudioDropdownButtonFormField<int>(
                      initialValue: selectedScriptNumericId,
                      decoration: InputDecoration(
                        labelText: dlgL10n.projectEditorAssetEditImageTargetScriptLabel,
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
                    const SizedBox(height: StudioSpacing.xs),
                    TextField(
                      controller: base64Ctrl,
                      minLines: 4,
                      maxLines: 7,
                      decoration: InputDecoration(
                        labelText: dlgL10n.projectEditorAssetEditImageDataUriLabel,
                        helperText: dlgL10n.projectEditorAssetEditImageDataUriHelper,
                      ),
                    ),
                  ],
                ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: Text(dlgL10n.storyboardEditorDialogCancel),
                ),
                FilledButton(
                  style: studioFormPrimaryButtonStyle(dialogCtx),
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: Text(dlgL10n.projectEditorAssetEditImageUploadButton),
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
      ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetEditImageEmptyDataUriSnack)));
      return;
    }

    setDialogState(() => assetsBusy[0] = true);
    final uploaded = await postProductionEditImageUploadImageV1(
      token,
      projectId: project.numericId,
      scriptId: selectedScriptNumericId,
      base64Data: payload,
    );
    if (!ctx.mounted) return;
    setDialogState(() => assetsBusy[0] = false);
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetEditImageUploadSuccess(uploaded.url))));
  } catch (e) {
    if (ctx.mounted) {
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))),
      );
    }
  } finally {
    base64Ctrl.dispose();
  }
}
