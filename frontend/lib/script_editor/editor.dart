part of '../../home_page.dart';

extension _HomePageScriptEditor on _HomePageState {
  Future<void> _openScriptEditor(
    String token,
    int scriptNumericId, {
    required int projectNumericId,
    required String projectId,
    Future<void> Function()? onScriptTreeMutated,
  }) async {
    try {
      final script = await fetchScriptByProjectAndNumericId(
        token,
        projectId,
        scriptNumericId,
      );
      if (!mounted) return;
      await showStudioDialog<void>(
        context: context,
        builder: (dialogContext) {
          return _ScriptEditorDialog(
            hostContext: context,
            dialogContext: dialogContext,
            token: token,
            projectNumericId: projectNumericId,
            projectId: projectId,
            script: script,
            onScriptTreeMutated: onScriptTreeMutated,
            onOpenEditImageWorkbench: () => _openScriptEditImageWorkbenchDialog(
              token: token,
              projectId: projectId,
              scriptNumericId: script.numericId,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      _setErrorFromException(e);
    }
  }
}

class _ScriptEditorDialog extends StatefulWidget {
  const _ScriptEditorDialog({
    required this.hostContext,
    required this.dialogContext,
    required this.token,
    required this.projectNumericId,
    required this.projectId,
    required this.script,
    required this.onOpenEditImageWorkbench,
    this.onScriptTreeMutated,
  });

  final BuildContext hostContext;
  final BuildContext dialogContext;
  final String token;
  final int projectNumericId;
  final String projectId;
  final ScriptRow script;
  final Future<void> Function() onOpenEditImageWorkbench;
  final Future<void> Function()? onScriptTreeMutated;

  @override
  State<_ScriptEditorDialog> createState() => _ScriptEditorDialogState();
}

class _ScriptEditorDialogState extends State<_ScriptEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _stateCtrl;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.script.name ?? '');
    _contentCtrl = TextEditingController(text: widget.script.content ?? '');
    _stateCtrl = TextEditingController(
      text: widget.script.extractState?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contentCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _openStoryboardStep() async {
    await Navigator.of(widget.dialogContext).maybePop();
    if (!widget.hostContext.mounted) return;
    goProjectStudioStoryboardForScript(
      widget.hostContext,
      projectNumericId: widget.projectNumericId,
      scriptNumericId: widget.script.numericId,
    );
  }

  Future<void> _deleteScript(AppLocalizations l10n) async {
    final ok = await showStudioDialog<bool>(
      context: widget.dialogContext,
      builder: (c) {
        final confirmL10n = resolveAppLocalizationsForErrors(c);
        return StudioAlertDialog(
          title: Text(confirmL10n.scriptEditorDeleteConfirmTitle),
          content: Text(
            confirmL10n.scriptEditorDeleteConfirmBody(widget.script.numericId),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: Text(confirmL10n.projectEditorScriptsBatchAddCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: Text(confirmL10n.scriptEditorDeleteConfirmDelete),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await deleteScriptByProjectAndNumericId(
        widget.token,
        widget.projectId,
        widget.script.numericId,
      );
      if (!mounted) return;
      await widget.onScriptTreeMutated?.call();
      if (!widget.dialogContext.mounted) return;
      await Navigator.of(widget.dialogContext).maybePop();
      if (!widget.hostContext.mounted) return;
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(widget.hostContext)
                .scriptEditorDeletedSnackBar,
          ),
        ),
      );
    } catch (e) {
      if (!widget.dialogContext.mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
        SnackBar(
          content: Text(
            describeUserVisibleApiErrorResolved(widget.dialogContext, e),
          ),
        ),
      );
    }
  }

  Future<void> _saveChanges(AppLocalizations l10n) async {
    setState(() => _saving = true);
    int? extractParsed;
    final st = _stateCtrl.text.trim();
    if (st.isNotEmpty) {
      extractParsed = int.tryParse(st);
      if (extractParsed == null) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
            SnackBar(
              content: Text(l10n.scriptEditorExtractStateMustBeInteger),
            ),
          );
        }
        return;
      }
    }
    try {
      await updateScriptByProjectAndNumericId(
        widget.token,
        widget.projectId,
        widget.script.numericId,
        {
          'name': _nameCtrl.text.isEmpty ? null : _nameCtrl.text,
          'content': _contentCtrl.text.isEmpty ? null : _contentCtrl.text,
          'extract_state': st.isEmpty ? null : extractParsed,
        },
      );
      if (!widget.dialogContext.mounted) return;
      await Navigator.of(widget.dialogContext).maybePop();
    } catch (e) {
      if (!widget.dialogContext.mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
        SnackBar(
          content: Text(
            describeUserVisibleApiErrorResolved(widget.dialogContext, e),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(widget.dialogContext);
    final viewportWidth = MediaQuery.sizeOf(widget.dialogContext).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 720.0)
        : 720.0;

    return StudioAlertDialog(
      title: Text(l10n.scriptEditorDialogTitle(widget.script.numericId)),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: l10n.scriptEditorFieldNameLabelClearIfEmpty,
                ),
              ),
              const SizedBox(height: StudioLayoutSpacing.listItem),
              TextField(
                controller: _contentCtrl,
                enabled: !_saving,
                minLines: 4,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: l10n.scriptEditorFieldContentLabelClearIfEmpty,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: StudioLayoutSpacing.listItem),
              TextField(
                controller: _stateCtrl,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      l10n.scriptEditorFieldExtractStateLabelClearIfEmpty,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _saving ? null : _openStoryboardStep,
                  child: Text(l10n.scriptEditorOpenStoryboards),
                ),
              ),
              const SizedBox(height: StudioLayoutSpacing.insetComfortable),
              _ScriptWorkbenchPanel(
                token: widget.token,
                projectId: widget.projectId,
                scriptNumericId: widget.script.numericId,
                onExtractStateSynced: (extractState) {
                  if (!mounted) return;
                  _stateCtrl.text = extractState?.toString() ?? '';
                },
                onOpenEditImageWorkbench: widget.onOpenEditImageWorkbench,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(widget.dialogContext).pop(),
          child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
        ),
        TextButton(
          onPressed: _saving ? null : () => _deleteScript(l10n),
          child: Text(l10n.scriptEditorDeleteScriptButton),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _saveChanges(l10n),
          child: Text(
            _saving ? l10n.scriptEditorSaveSaving : l10n.scriptEditorSaveChanges,
          ),
        ),
      ],
    );
  }
}
