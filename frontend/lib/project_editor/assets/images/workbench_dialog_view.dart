import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import 'workbench_dialog_view_contract.dart';
import 'workbench_dialog_view_sections.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

export 'workbench_dialog_view_contract.dart';

const double assetImagesWorkbenchSectionSpacing = 8;

class AssetImagesWorkbenchDialogView extends StatelessWidget {
  const AssetImagesWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final AssetImagesWorkbenchDialogViewModel model;
  final AssetImagesWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 760.0)
        : 760.0;
    return StudioAlertDialog(
      title: Text(l10n.projectEditorAssetImagesWorkbenchDialogTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: buildAssetImagesWorkbenchSections(
              context,
              model: model,
              callbacks: callbacks,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
        ),
      ],
    );
  }

}
