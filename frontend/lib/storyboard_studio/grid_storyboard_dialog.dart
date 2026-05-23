import 'package:flutter/material.dart';

import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_primary_button.dart';
import '../l10n/app_localizations.dart';

class GridStoryboardDialogResult {
  const GridStoryboardDialogResult({
    required this.rows,
    required this.cols,
    this.basePrompt,
  });

  final int rows;
  final int cols;
  final String? basePrompt;
}

/// Configure rows/cols and optional scene prompt before grid generate.
Future<GridStoryboardDialogResult?> showGridStoryboardDialog({
  required BuildContext context,
  required int shotCount,
  int initialRows = 2,
  int initialCols = 2,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final rowsCtrl = TextEditingController(text: initialRows.toString());
  final colsCtrl = TextEditingController(text: initialCols.toString());
  final promptCtrl = TextEditingController();

  final result = await showStudioDialog<GridStoryboardDialogResult>(
    context: context,
    builder: (ctx) {
      String? errorText;
      return StatefulBuilder(
        builder: (ctx, setState) {
          return StudioAlertDialog(
            title: Text(l10n.studioGridStoryboardDialogTitle),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(l10n.studioGridStoryboardDialogSubtitle(shotCount)),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: rowsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.studioGridStoryboardRowsLabel,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: colsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.studioGridStoryboardColsLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.studioGridStoryboardBasePromptLabel,
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (errorText != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: studioAccentBannerBodyStyle(
                        ctx,
                        Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.storyboardEditorDialogCancel),
              ),
              StudioPrimaryButton(
                label: l10n.studioGridStoryboardCta,
                onPressed: () {
                  final rows = int.tryParse(rowsCtrl.text.trim());
                  final cols = int.tryParse(colsCtrl.text.trim());
                  if (rows == null ||
                      cols == null ||
                      rows <= 0 ||
                      cols <= 0 ||
                      rows > 4 ||
                      cols > 4) {
                    setState(() {
                      errorText = l10n.studioGridStoryboardInvalidDimensions;
                    });
                    return;
                  }
                  final cells = rows * cols;
                  if (cells != shotCount) {
                    setState(() {
                      errorText = l10n.studioGridStoryboardCellMismatch(
                        cells,
                        shotCount,
                      );
                    });
                    return;
                  }
                  Navigator.of(ctx).pop(
                    GridStoryboardDialogResult(
                      rows: rows,
                      cols: cols,
                      basePrompt: promptCtrl.text.trim().isEmpty
                          ? null
                          : promptCtrl.text.trim(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );

  rowsCtrl.dispose();
  colsCtrl.dispose();
  promptCtrl.dispose();
  return result;
}
