part of 'creative_manuals.dart';

class _ProjectsCreativeManualsWorkbenchDialogState
    extends State<ProjectsCreativeManualsWorkbenchDialog> {
  _CreativeManualsWorkbenchControllers? _ctrls;

  _CreativeManualKind _kind = _CreativeManualKind.director;
  List<_CreativeManualRow> _directorRows = const <_CreativeManualRow>[];
  List<_CreativeManualRow> _visualRows = const <_CreativeManualRow>[];
  _CreativeManualRow? _selected;
  String? _statusLine;
  bool _busy = false;

  List<_CreativeManualRow> get _activeRows =>
      _kind == _CreativeManualKind.director ? _directorRows : _visualRows;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrls ??= _CreativeManualsWorkbenchControllers.create(
      resolveAppLocalizationsForErrors(context).projectsCreativeManualDefaultSlotsTemplate,
    );
  }

  @override
  void dispose() {
    _ctrls?.dispose();
    super.dispose();
  }

  void _setKind(_CreativeManualKind next) {
    if (next == _kind) {
      return;
    }
    setState(() {
      _kind = next;
      final rows = _activeRows;
      if (rows.isEmpty) {
        _selected = null;
        _clearForm();
      } else {
        _applyRow(rows.first);
      }
    });
  }

  void _clearForm() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final ctrls = _ctrls!;
    ctrls.nameCtrl.clear();
    ctrls.pathCtrl.clear();
    ctrls.imagesCtrl.clear();
    ctrls.slotsCtrl.text = l10n.projectsCreativeManualDefaultSlotsTemplate;
  }

  void _applyRow(_CreativeManualRow row) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final ctrls = _ctrls!;
    _selected = row;
    ctrls.nameCtrl.text = row.name;
    ctrls.pathCtrl.text = row.path;
    ctrls.imagesCtrl.text = row.images.join('\n');
    ctrls.slotsCtrl.text = encodeCreativeManualSlots(
      row.slots,
      emptyDefault: l10n.projectsCreativeManualDefaultSlotsTemplate,
    );
  }

  Future<void> _reloadAll({String? preferredPath}) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _busy = true;
      _statusLine = l10n.projectsCreativeManualStatusRefreshing;
    });
    try {
      final director = await postProjectQueryDirectorManual(widget.accessToken);
      final visualGet = await fetchVisualManualV1(widget.accessToken);
      final visualPost = await fetchVisualManualPostV1(widget.accessToken);
      if (!mounted) return;
      final directorRows = director.data
          .map(_CreativeManualRow.fromDirector)
          .toList(growable: false);
      final visualRows = visualGet.styles
          .map(_CreativeManualRow.fromVisual)
          .toList(growable: false);
      _CreativeManualRow? target;
      final activeRows = _kind == _CreativeManualKind.director
          ? directorRows
          : visualRows;
      if (preferredPath != null) {
        for (final row in activeRows) {
          if (row.path == preferredPath) {
            target = row;
            break;
          }
        }
      }
      target ??= activeRows.isEmpty ? null : activeRows.first;
      setState(() {
        _directorRows = directorRows;
        _visualRows = visualRows;
        _busy = false;
        _statusLine = l10n.projectsCreativeManualStatusReloadOk(
          directorRows.length,
          visualRows.length,
          visualGet.styles.length,
          visualPost.styles.length,
        );
        if (target == null) {
          _selected = null;
          _clearForm();
        } else {
          _applyRow(target);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = l10n.projectsCreativeManualStatusReloadFail(
          describeUserVisibleApiError(l10n, e),
        );
      });
    }
  }

  Future<void> _createCurrentKind() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final name = _ctrls!.nameCtrl.text.trim();
    final path = _ctrls!.pathCtrl.text.trim();
    if (name.isEmpty || path.isEmpty) {
      setState(
        () => _statusLine = l10n.projectsCreativeManualStatusCreateNeedFields,
      );
      return;
    }
    final slots = parseCreativeManualSlots(_ctrls!.slotsCtrl.text);
    final images = parseCreativeManualImages(_ctrls!.imagesCtrl.text);
    setState(() {
      _busy = true;
      _statusLine = l10n.projectsCreativeManualStatusCreating;
    });
    try {
      if (_kind == _CreativeManualKind.director) {
        await postProjectAddDirectorManual(
          widget.accessToken,
          name: name,
          directorManual: path,
          images: images,
          data: slots,
        );
      } else {
        await postProjectAddVisualManual(
          widget.accessToken,
          name: name,
          stylePath: path,
          images: images,
          data: slots,
        );
      }
      await _reloadAll(preferredPath: path);
      if (!mounted) return;
      setState(
        () => _statusLine = l10n.projectsCreativeManualStatusCreated(
          creativeManualKindLabel(l10n, _kind),
          path,
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = l10n.projectsCreativeManualInvalidSlotLine(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = l10n.projectsCreativeManualStatusOpFail(
          l10n.projectsCreativeManualVerbCreate,
          describeUserVisibleApiError(l10n, e),
        );
      });
    }
  }

  Future<void> _saveCurrentKind() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final path = _ctrls!.pathCtrl.text.trim();
    final name = _ctrls!.nameCtrl.text.trim();
    if (_selected == null) {
      setState(
        () => _statusLine = l10n.projectsCreativeManualStatusSaveNeedSelect,
      );
      return;
    }
    if (name.isEmpty || path.isEmpty) {
      setState(
        () => _statusLine = l10n.projectsCreativeManualStatusSaveNeedFields,
      );
      return;
    }
    final slots = parseCreativeManualSlots(_ctrls!.slotsCtrl.text);
    final images = parseCreativeManualImages(_ctrls!.imagesCtrl.text);
    setState(() {
      _busy = true;
      _statusLine = l10n.projectsCreativeManualStatusSaving;
    });
    try {
      if (_kind == _CreativeManualKind.director) {
        await postProjectEditDirectorManual(
          widget.accessToken,
          name: name,
          directorManual: path,
          images: images,
          data: slots,
        );
      } else {
        await postProjectEditVisualManual(
          widget.accessToken,
          name: name,
          stylePath: path,
          images: images,
          data: slots,
        );
      }
      await _reloadAll(preferredPath: path);
      if (!mounted) return;
      setState(
        () => _statusLine = l10n.projectsCreativeManualStatusSaved(
          creativeManualKindLabel(l10n, _kind),
          path,
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = l10n.projectsCreativeManualInvalidSlotLine(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = l10n.projectsCreativeManualStatusOpFail(
          l10n.projectsCreativeManualVerbSave,
          describeUserVisibleApiError(l10n, e),
        );
      });
    }
  }

  Future<void> _deleteCurrentKind() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final selected = _selected;
    if (selected == null) {
      setState(
        () => _statusLine = l10n.projectsCreativeManualStatusDeleteNeedSelect,
      );
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = l10n.projectsCreativeManualStatusDeleting;
    });
    try {
      if (_kind == _CreativeManualKind.director) {
        await postProjectDeleteDirectorManual(
          widget.accessToken,
          selected.path,
        );
      } else {
        await postProjectDeleteVisualManual(widget.accessToken, selected.path);
      }
      await _reloadAll();
      if (!mounted) return;
      setState(
        () => _statusLine = l10n.projectsCreativeManualStatusDeleted(
          creativeManualKindLabel(l10n, _kind),
          selected.path,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = l10n.projectsCreativeManualStatusOpFail(
          l10n.projectsCreativeManualVerbDelete,
          describeUserVisibleApiError(l10n, e),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final ctrls = _ctrls!;
    return CreativeManualsWorkbenchView(
      kind: _kind,
      busy: _busy,
      activeRows: _activeRows,
      selected: _selected,
      statusLine: _statusLine,
      nameCtrl: ctrls.nameCtrl,
      pathCtrl: ctrls.pathCtrl,
      imagesCtrl: ctrls.imagesCtrl,
      slotsCtrl: ctrls.slotsCtrl,
      pathLabel: _kind == _CreativeManualKind.director
          ? l10n.projectsCreativeManualPathDirectorFolder
          : l10n.projectsCreativeManualPathVisual,
      selectionLabel: _kind == _CreativeManualKind.director
          ? l10n.projectsCreativeManualSelectionDirector
          : l10n.projectsCreativeManualSelectionVisual,
      createLabel: _kind == _CreativeManualKind.director
          ? l10n.projectsCreativeManualCreateDirector
          : l10n.projectsCreativeManualCreateVisual,
      saveLabel: _kind == _CreativeManualKind.director
          ? l10n.projectsCreativeManualSaveDirector
          : l10n.projectsCreativeManualSaveVisual,
      deleteLabel: _kind == _CreativeManualKind.director
          ? l10n.projectsCreativeManualDeleteDirector
          : l10n.projectsCreativeManualDeleteVisual,
      onKindChanged: (next) => _setKind(next),
      onReloadAll: _reloadAll,
      onCreate: _createCurrentKind,
      onSave: _saveCurrentKind,
      onDelete: _deleteCurrentKind,
      onSelectRowPath: (value) {
        for (final row in _activeRows) {
          if (row.path == value) {
            setState(() => _applyRow(row));
            break;
          }
        }
      },
      onClose: () => Navigator.of(context).pop(),
    );
  }
}
