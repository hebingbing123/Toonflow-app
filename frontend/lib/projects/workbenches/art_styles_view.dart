import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../../rust_api.dart';

class ArtStylesWorkbenchDialogViewModel {
  const ArtStylesWorkbenchDialogViewModel({
    required this.rows,
    required this.selected,
    required this.coverBytes,
    required this.statusLine,
    required this.busy,
    required this.loadingCover,
    required this.nameCtrl,
    required this.labelCtrl,
    required this.promptCtrl,
    required this.fileUrlCtrl,
    required this.extractImagesCtrl,
  });

  final List<ArtStyleRow> rows;
  final ArtStyleRow? selected;
  final Uint8List? coverBytes;
  final String? statusLine;
  final bool busy;
  final bool loadingCover;
  final TextEditingController nameCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController promptCtrl;
  final TextEditingController fileUrlCtrl;
  final TextEditingController extractImagesCtrl;
}

class ArtStylesWorkbenchDialogViewCallbacks {
  const ArtStylesWorkbenchDialogViewCallbacks({
    required this.onReloadRows,
    required this.onLoadCover,
    required this.onCreateStyle,
    required this.onSaveSelected,
    required this.onDeleteSelected,
    required this.onExtractPrompt,
    required this.onApplySelection,
    required this.onClose,
  });

  final Future<void> Function({int? preferredNumericId}) onReloadRows;
  final Future<void> Function() onLoadCover;
  final Future<void> Function() onCreateStyle;
  final Future<void> Function() onSaveSelected;
  final Future<void> Function() onDeleteSelected;
  final Future<void> Function() onExtractPrompt;
  final void Function(ArtStyleRow row, {bool loadCover}) onApplySelection;
  final VoidCallback onClose;
}

/// 画风工作台视图，承载表单、列表选择与封面预览布局。
class ArtStylesWorkbenchDialogView extends StatelessWidget {
  const ArtStylesWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ArtStylesWorkbenchDialogViewModel model;
  final ArtStylesWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final outline = Theme.of(context).colorScheme.outline;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 760.0)
        : 760.0;
    return AlertDialog(
      title: Text(l10n.projectsArtWorkbenchTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.projectsArtWorkbenchIntro,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.busy ? null : callbacks.onReloadRows,
                    child: Text(
                      model.busy
                          ? l10n.projectsBusyProcessing
                          : l10n.projectsArtWorkbenchReloadList,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        model.busy ||
                            model.loadingCover ||
                            model.selected == null
                        ? null
                        : callbacks.onLoadCover,
                    child: Text(
                      model.loadingCover
                          ? l10n.projectsArtWorkbenchReadingCover
                          : l10n.projectsArtWorkbenchViewCover,
                    ),
                  ),
                  FilledButton(
                    onPressed: model.busy ? null : callbacks.onCreateStyle,
                    child: Text(l10n.projectsArtWorkbenchNew),
                  ),
                  FilledButton(
                    onPressed: model.busy || model.selected == null
                        ? null
                        : callbacks.onSaveSelected,
                    child: Text(l10n.projectsArtWorkbenchSave),
                  ),
                  FilledButton.tonal(
                    onPressed: model.busy || model.selected == null
                        ? null
                        : callbacks.onDeleteSelected,
                    child: Text(l10n.projectsArtWorkbenchDelete),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (model.rows.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: model.selected?.numericId,
                  decoration: InputDecoration(
                    labelText: l10n.projectsArtWorkbenchCurrentStyle,
                  ),
                  items: model.rows
                      .map(
                        (row) => DropdownMenuItem<int>(
                          value: row.numericId,
                          child: Text(
                            '#${row.numericId} ${row.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: model.busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          final row = model.rows.firstWhere(
                            (element) => element.numericId == value,
                          );
                          callbacks.onApplySelection(row, loadCover: true);
                        },
                )
              else
                Text(
                  l10n.projectsArtWorkbenchEmptyHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: model.nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectsArtWorkbenchFieldName,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.labelCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectsArtWorkbenchFieldTags,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.fileUrlCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.projectsArtWorkbenchFieldCoverUrl,
                  helperText: l10n.projectsArtWorkbenchFieldCoverUrlHelper,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.promptCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.projectsArtWorkbenchFieldPrompt,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.projectsArtWorkbenchExtractTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              TextField(
                controller: model.extractImagesCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.projectsArtWorkbenchExtractImagesLabel,
                  helperText: l10n.projectsArtWorkbenchExtractImagesHelper,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: model.busy ? null : callbacks.onExtractPrompt,
                  child: Text(l10n.projectsArtWorkbenchExtractButton),
                ),
              ),
              const SizedBox(height: 12),
              if (model.coverBytes != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.projectsArtWorkbenchCoverPreview,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        model.coverBytes!,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              if (model.statusLine != null) ...[
                const SizedBox(height: 12),
                SelectableText(model.statusLine!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: callbacks.onClose,
          child: Text(l10n.helpHubDialogClose),
        ),
      ],
    );
  }
}
