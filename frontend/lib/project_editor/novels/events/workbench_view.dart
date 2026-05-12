import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../../../rust_api.dart';

class NovelEventsWorkbenchDialogViewModel {
  const NovelEventsWorkbenchDialogViewModel({
    required this.infoLine,
    required this.previewRows,
    required this.localBusy,
    required this.searchCtrl,
    required this.createNameCtrl,
    required this.createDetailCtrl,
    required this.createChapterIdsCtrl,
    required this.selectedEventIdCtrl,
    required this.patchNameCtrl,
    required this.patchDetailCtrl,
    required this.patchChapterIdsCtrl,
    required this.batchDeleteIdsCtrl,
  });

  final String infoLine;
  final List<NovelEventRow> previewRows;
  final bool localBusy;
  final TextEditingController searchCtrl;
  final TextEditingController createNameCtrl;
  final TextEditingController createDetailCtrl;
  final TextEditingController createChapterIdsCtrl;
  final TextEditingController selectedEventIdCtrl;
  final TextEditingController patchNameCtrl;
  final TextEditingController patchDetailCtrl;
  final TextEditingController patchChapterIdsCtrl;
  final TextEditingController batchDeleteIdsCtrl;
}

class NovelEventsWorkbenchDialogViewCallbacks {
  const NovelEventsWorkbenchDialogViewCallbacks({
    required this.onSearch,
    required this.onRefresh,
    required this.onCreate,
    required this.onSave,
    required this.onDeleteCurrent,
    required this.onBatchDelete,
    required this.onClose,
  });

  final VoidCallback? onSearch;
  final VoidCallback? onRefresh;
  final VoidCallback? onCreate;
  final VoidCallback? onSave;
  final VoidCallback? onDeleteCurrent;
  final VoidCallback? onBatchDelete;
  final VoidCallback? onClose;
}

class NovelEventsWorkbenchDialogView extends StatelessWidget {
  const NovelEventsWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final NovelEventsWorkbenchDialogViewModel model;
  final NovelEventsWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 760.0)
        : 760.0;
    return AlertDialog(
      title: Text(l10n.projectEditorNovelsEventsWorkbenchTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.infoLine,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (model.previewRows.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.projectEditorNovelsEventsPreviewSectionTitle,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      ...model.previewRows.map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            l10n.projectEditorNovelsEventsPreviewRow(
                              row.numericId,
                              row.name,
                              row.chapterIndexes.join('/'),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: model.searchCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsEventsSearchLabel,
                  helperText: l10n.projectEditorNovelsEventsSearchHelper,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: callbacks.onSearch,
                    child: Text(l10n.projectEditorNovelsEventsSearchButton),
                  ),
                  OutlinedButton(
                    onPressed: callbacks.onRefresh,
                    child: Text(l10n.projectEditorNovelsEventsRefreshListButton),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.projectEditorNovelsEventsNewEventHeading, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: model.createNameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsEventsFieldEventName,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createDetailCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsEventsFieldEventDescription,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createChapterIdsCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsEventsFieldChapterIdsLabel,
                  helperText: l10n.projectEditorNovelsEventsFieldChapterIdsHelper,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: callbacks.onCreate,
                child: Text(l10n.projectEditorNovelsEventsCreateButton),
              ),
              const SizedBox(height: 16),
              Text(l10n.projectEditorNovelsEventsUpdateHeading, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: model.selectedEventIdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsEventsFieldNumericId,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.patchNameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsEventsFieldUpdatedName,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.patchDetailCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsEventsFieldUpdatedDescription,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.patchChapterIdsCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsEventsFieldUpdatedChapterIds,
                  helperText: l10n.projectEditorNovelsEventsFieldUpdatedChapterIdsHelper,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: callbacks.onSave,
                child: Text(l10n.projectEditorNovelsEventsSaveButton),
              ),
              const SizedBox(height: 16),
              Text(l10n.projectEditorNovelsEventsDeleteHeading, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: callbacks.onDeleteCurrent,
                    child: Text(l10n.projectEditorNovelsEventsDeleteCurrentButton),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.batchDeleteIdsCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsEventsBatchDeleteIdsLabel,
                  helperText: l10n.projectEditorNovelsEventsBatchDeleteIdsHelper,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: callbacks.onBatchDelete,
                child: Text(l10n.projectEditorNovelsEventsBatchDeleteButton),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: callbacks.onClose,
          child: Text(l10n.projectEditorNovelsEventsCloseButton),
        ),
      ],
    );
  }
}
