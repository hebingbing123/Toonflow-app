part of 'creative_manuals.dart';

class _ProjectsCreativeManualsWorkbenchDialogState
    extends State<ProjectsCreativeManualsWorkbenchDialog> {
  late final _CreativeManualsWorkbenchControllers _ctrls;

  _CreativeManualKind _kind = _CreativeManualKind.director;
  List<_CreativeManualRow> _directorRows = const <_CreativeManualRow>[];
  List<_CreativeManualRow> _visualRows = const <_CreativeManualRow>[];
  _CreativeManualRow? _selected;
  String? _statusLine;
  bool _busy = false;

  List<_CreativeManualRow> get _activeRows =>
      _kind == _CreativeManualKind.director ? _directorRows : _visualRows;

  String get _pathLabel => _kind == _CreativeManualKind.director
      ? 'directorManual 文件夹'
      : 'stylePath';

  String get _selectionLabel =>
      _kind == _CreativeManualKind.director ? '当前导演手册' : '当前视觉手册';

  String get _createLabel =>
      _kind == _CreativeManualKind.director ? '新建导演手册' : '新建视觉手册';

  String get _saveLabel =>
      _kind == _CreativeManualKind.director ? '保存当前导演手册' : '保存当前视觉手册';

  String get _deleteLabel =>
      _kind == _CreativeManualKind.director ? '删除当前导演手册' : '删除当前视觉手册';

  @override
  void initState() {
    super.initState();
    _ctrls = _CreativeManualsWorkbenchControllers.create();
  }

  @override
  void dispose() {
    _ctrls.dispose();
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
    _ctrls.nameCtrl.clear();
    _ctrls.pathCtrl.clear();
    _ctrls.imagesCtrl.clear();
    _ctrls.slotsCtrl.text = _defaultCreativeManualSlotsText;
  }

  void _applyRow(_CreativeManualRow row) {
    _selected = row;
    _ctrls.nameCtrl.text = row.name;
    _ctrls.pathCtrl.text = row.path;
    _ctrls.imagesCtrl.text = row.images.join('\n');
    _ctrls.slotsCtrl.text = encodeCreativeManualSlots(row.slots);
  }

  Future<void> _reloadAll({String? preferredPath}) async {
    setState(() {
      _busy = true;
      _statusLine = '刷新创作手册中…';
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
        _statusLine =
            '导演手册 ${directorRows.length} 条 · 视觉手册 ${visualRows.length} 条 · '
            'visual GET/POST=${visualGet.styles.length}/${visualPost.styles.length}';
        if (target == null) {
          _selected = null;
          _clearForm();
        } else {
          _applyRow(target);
        }
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '刷新失败：$e';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '刷新失败：$e';
      });
    }
  }

  Future<void> _createCurrentKind() async {
    final name = _ctrls.nameCtrl.text.trim();
    final path = _ctrls.pathCtrl.text.trim();
    if (name.isEmpty || path.isEmpty) {
      setState(() => _statusLine = '新建失败：名称与路径不能为空。');
      return;
    }
    final slots = parseCreativeManualSlots(_ctrls.slotsCtrl.text);
    final images = parseCreativeManualImages(_ctrls.imagesCtrl.text);
    setState(() {
      _busy = true;
      _statusLine = '新建手册中…';
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
      setState(() => _statusLine = '已新建 ${creativeManualKindLabel(_kind)}：$path');
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '新建失败：$e';
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '新建失败：${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '新建失败：$e';
      });
    }
  }

  Future<void> _saveCurrentKind() async {
    final path = _ctrls.pathCtrl.text.trim();
    final name = _ctrls.nameCtrl.text.trim();
    if (_selected == null) {
      setState(() => _statusLine = '保存失败：请先选择一条手册。');
      return;
    }
    if (name.isEmpty || path.isEmpty) {
      setState(() => _statusLine = '保存失败：名称与路径不能为空。');
      return;
    }
    final slots = parseCreativeManualSlots(_ctrls.slotsCtrl.text);
    final images = parseCreativeManualImages(_ctrls.imagesCtrl.text);
    setState(() {
      _busy = true;
      _statusLine = '保存手册中…';
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
      setState(() => _statusLine = '已保存 ${creativeManualKindLabel(_kind)}：$path');
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '保存失败：$e';
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '保存失败：${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '保存失败：$e';
      });
    }
  }

  Future<void> _deleteCurrentKind() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _statusLine = '删除失败：请先选择一条手册。');
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = '删除手册中…';
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
        () => _statusLine =
            '已删除 ${creativeManualKindLabel(_kind)}：${selected.path}',
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '删除失败：$e';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '删除失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CreativeManualsWorkbenchView(
      kind: _kind,
      busy: _busy,
      activeRows: _activeRows,
      selected: _selected,
      statusLine: _statusLine,
      nameCtrl: _ctrls.nameCtrl,
      pathCtrl: _ctrls.pathCtrl,
      imagesCtrl: _ctrls.imagesCtrl,
      slotsCtrl: _ctrls.slotsCtrl,
      pathLabel: _pathLabel,
      selectionLabel: _selectionLabel,
      createLabel: _createLabel,
      saveLabel: _saveLabel,
      deleteLabel: _deleteLabel,
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
