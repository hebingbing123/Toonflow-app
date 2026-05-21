part of 'creative_manuals.dart';

// ignore_for_file: library_private_types_in_public_api

class CreativeManualsWorkbenchView extends StatelessWidget {
  const CreativeManualsWorkbenchView({
    super.key,
    required this.kind,
    required this.busy,
    required this.activeRows,
    required this.selected,
    required this.statusLine,
    required this.nameCtrl,
    required this.pathCtrl,
    required this.imagesCtrl,
    required this.slotsCtrl,
    required this.pathLabel,
    required this.selectionLabel,
    required this.createLabel,
    required this.saveLabel,
    required this.deleteLabel,
    required this.onKindChanged,
    required this.onReloadAll,
    required this.onCreate,
    required this.onSave,
    required this.onDelete,
    required this.onSelectRowPath,
    required this.onClose,
  });

  final _CreativeManualKind kind;
  final bool busy;
  final List<_CreativeManualRow> activeRows;
  final _CreativeManualRow? selected;
  final String? statusLine;
  final TextEditingController nameCtrl;
  final TextEditingController pathCtrl;
  final TextEditingController imagesCtrl;
  final TextEditingController slotsCtrl;
  final String pathLabel;
  final String selectionLabel;
  final String createLabel;
  final String saveLabel;
  final String deleteLabel;
  final ValueChanged<_CreativeManualKind> onKindChanged;
  final Future<void> Function() onReloadAll;
  final Future<void> Function() onCreate;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final ValueChanged<String> onSelectRowPath;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioAlertDialog(
      title: Text(l10n.projectsCreativeManualTitle),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.projectsCreativeManualIntro,
                style: studioHintStyle(context),
              ),
              const SizedBox(height: 12),
              SegmentedButton<_CreativeManualKind>(
                segments: <ButtonSegment<_CreativeManualKind>>[
                  ButtonSegment<_CreativeManualKind>(
                    value: _CreativeManualKind.director,
                    label: Text(l10n.projectsCreativeManualSegmentDirector),
                  ),
                  ButtonSegment<_CreativeManualKind>(
                    value: _CreativeManualKind.visual,
                    label: Text(l10n.projectsCreativeManualSegmentVisual),
                  ),
                ],
                selected: <_CreativeManualKind>{kind},
                onSelectionChanged: busy
                    ? null
                    : (selection) {
                        final next = selection.firstOrNull;
                        if (next != null) {
                          onKindChanged(next);
                        }
                      },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: busy ? null : onReloadAll,
                    child: Text(
                      busy
                          ? l10n.projectsBusyProcessing
                          : l10n.projectsCreativeManualReloadAll,
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : onCreate,
                    child: Text(createLabel),
                  ),
                  FilledButton(
                    onPressed: busy || selected == null ? null : onSave,
                    child: Text(saveLabel),
                  ),
                  FilledButton.tonal(
                    onPressed: busy || selected == null ? null : onDelete,
                    child: Text(deleteLabel),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (activeRows.isNotEmpty)
                StudioDropdownButtonFormField<String>(
                  initialValue: selected?.path,
                  decoration: InputDecoration(labelText: selectionLabel),
                  items: activeRows
                      .map(
                        (row) => DropdownMenuItem<String>(
                          value: row.path,
                          child: Text(
                            '${row.path} · ${row.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) {
                            onSelectRowPath(value);
                          }
                        },
                )
              else
                Text(
                  l10n.projectsCreativeManualEmptyKind,
                  style: studioHintStyle(context),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectsCreativeManualFieldName,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pathCtrl,
                decoration: InputDecoration(labelText: pathLabel),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: imagesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.projectsCreativeManualFieldImagesList,
                  helperText: l10n.projectsCreativeManualFieldImagesHelper,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: slotsCtrl,
                minLines: 5,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l10n.projectsCreativeManualFieldSlots,
                  helperText: l10n.projectsCreativeManualFieldSlotsHelper,
                ),
              ),
              if (selected != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.projectsCreativeManualSummaryTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  l10n.projectsCreativeManualSummaryLine(
                    selected!.name,
                    selected!.path,
                    selected!.images.length,
                    selected!.slots.length,
                  ),
                ),
              ],
              if (statusLine != null) ...[
                const SizedBox(height: 12),
                SelectableText(statusLine!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: onClose, child: Text(l10n.helpHubDialogClose)),
      ],
    );
  }
}
