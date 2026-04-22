import 'package:flutter/material.dart';

import 'workbench_dialog_view_contract.dart';
import 'workbench_dialog_view_sections.dart';

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
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 760.0)
        : 760.0;
    return AlertDialog(
      title: const Text('资产图片工作台'),
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
          child: const Text('关闭'),
        ),
      ],
    );
  }

}
