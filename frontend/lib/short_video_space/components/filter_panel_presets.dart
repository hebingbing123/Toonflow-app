part of 'filter_panel.dart';

class _SavePresetDialog extends StatefulWidget {
  @override
  State<_SavePresetDialog> createState() => _SavePresetDialogState();
}

class _SavePresetDialogState extends State<_SavePresetDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioAlertDialog(
      title: Text(l10n.shortVideoFilterSaveDialogTitle),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.shortVideoFilterSaveDialogNameLabel,
          hintText: l10n.shortVideoFilterSaveDialogNameHint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context).pop(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.notificationsActionCancel),
        ),
        FilledButton(
          style: studioFormPrimaryButtonStyle(context),
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop(name);
            }
          },
          child: Text(l10n.notificationsActionSave),
        ),
      ],
    );
  }
}
