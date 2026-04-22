part of '../section.dart';

/// 画风工作台，集中处理封面、CRUD 与 prompt 抽取。
class _ArtStylesWorkbenchDialog extends StatefulWidget {
  const _ArtStylesWorkbenchDialog({
    required this.accessToken,
    required this.initialRows,
    required this.onRefreshParent,
  });

  final String accessToken;
  final List<ArtStyleRow> initialRows;
  final Future<void> Function() onRefreshParent;

  @override
  State<_ArtStylesWorkbenchDialog> createState() =>
      _ArtStylesWorkbenchDialogState();
}

class _ArtStylesWorkbenchDialogState extends State<_ArtStylesWorkbenchDialog> {
  late final _ArtStylesWorkbenchControllers _ctrls;

  List<ArtStyleRow> _rows = const <ArtStyleRow>[];
  ArtStyleRow? _selected;
  Uint8List? _coverBytes;
  String? _statusLine;
  bool _busy = false;
  bool _loadingCover = false;

  @override
  void initState() {
    super.initState();
    _ctrls = _ArtStylesWorkbenchControllers.create();
    _rows = List<ArtStyleRow>.from(widget.initialRows);
    if (_rows.isNotEmpty) {
      _applySelection(_rows.first, loadCover: false);
    }
  }

  @override
  void dispose() {
    _ctrls.dispose();
    super.dispose();
  }

  void _applySelection(ArtStyleRow row, {bool loadCover = true}) {
    setState(() {
      _selected = row;
      _ctrls.nameCtrl.text = row.name;
      _ctrls.labelCtrl.text = row.label ?? '';
      _ctrls.promptCtrl.text = row.prompt ?? '';
      _ctrls.fileUrlCtrl.text = row.fileUrl ?? '';
      _coverBytes = null;
    });
    if (loadCover) {
      _loadCover();
    }
  }

  Future<void> _reloadRows({int? preferredNumericId}) async {
    setState(() {
      _busy = true;
      _statusLine = '刷新画风列表中…';
    });
    try {
      final response = await fetchArtStyles(widget.accessToken);
      await widget.onRefreshParent();
      if (!mounted) return;
      setState(() {
        _rows = response.items;
        _busy = false;
        _statusLine = '已刷新 ${response.total} 条画风。';
      });
      ArtStyleRow? target;
      if (preferredNumericId == null) {
        if (_rows.isNotEmpty) {
          target = _rows.first;
        }
      } else {
        for (final row in _rows) {
          if (row.numericId == preferredNumericId) {
            target = row;
            break;
          }
        }
      }
      if (target != null) {
        _applySelection(target, loadCover: true);
      } else if (mounted) {
        setState(() {
          _selected = null;
          _coverBytes = null;
          _ctrls.nameCtrl.clear();
          _ctrls.labelCtrl.clear();
          _ctrls.promptCtrl.clear();
          _ctrls.fileUrlCtrl.clear();
        });
      }
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

  Future<void> _loadCover() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _loadingCover = true;
      _statusLine = '读取封面中…';
    });
    try {
      final bytes = await fetchArtStyleCoverByNumericId(
        widget.accessToken,
        numericId: selected.numericId,
      );
      if (!mounted) return;
      setState(() {
        _coverBytes = bytes;
        _loadingCover = false;
        _statusLine = '已读取画风 #${selected.numericId} 封面。';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _coverBytes = null;
        _loadingCover = false;
        _statusLine = '读取封面失败：$e';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _coverBytes = null;
        _loadingCover = false;
        _statusLine = '读取封面失败：$e';
      });
    }
  }

  Future<void> _createStyle() async {
    final name = _ctrls.nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _statusLine = '新建失败：名称不能为空。');
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = '新建画风中…';
    });
    try {
      final created = await createArtStyle(
        widget.accessToken,
        name: name,
        label: _ctrls.labelCtrl.text.trim().isEmpty
            ? null
            : _ctrls.labelCtrl.text.trim(),
        prompt: _ctrls.promptCtrl.text.trim().isEmpty
            ? null
            : _ctrls.promptCtrl.text.trim(),
        fileUrl: _ctrls.fileUrlCtrl.text.trim().isEmpty
            ? null
            : _ctrls.fileUrlCtrl.text.trim(),
      );
      await _reloadRows(preferredNumericId: created.numericId);
      if (!mounted) return;
      setState(() => _statusLine = '已新建画风 #${created.numericId}。');
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '新建失败：$e';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '新建失败：$e';
      });
    }
  }

  Future<void> _saveSelected() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _statusLine = '保存失败：请先选择画风。');
      return;
    }
    final body = buildArtStylePatchBody(
      name: _ctrls.nameCtrl.text,
      label: _ctrls.labelCtrl.text,
      prompt: _ctrls.promptCtrl.text,
      fileUrl: _ctrls.fileUrlCtrl.text,
    );
    setState(() {
      _busy = true;
      _statusLine = '保存画风中…';
    });
    try {
      final updated = await patchArtStyleByNumericId(
        widget.accessToken,
        selected.numericId,
        body,
      );
      await _reloadRows(preferredNumericId: updated.numericId);
      if (!mounted) return;
      setState(() => _statusLine = '已更新画风 #${updated.numericId}。');
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '保存失败：$e';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '保存失败：$e';
      });
    }
  }

  Future<void> _deleteSelected() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _statusLine = '删除失败：请先选择画风。');
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = '删除画风中…';
    });
    try {
      await deleteArtStyleByNumericId(widget.accessToken, selected.numericId);
      await _reloadRows();
      if (!mounted) return;
      setState(() => _statusLine = '已删除画风 #${selected.numericId}。');
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

  Future<void> _extractPrompt() async {
    final images = parseArtStyleExtractImages(_ctrls.extractImagesCtrl.text);
    if (images.isEmpty) {
      setState(() => _statusLine = '抽取失败：请至少输入一个图片 URL 或 data URI。');
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = '抽取画风 prompt 中…';
    });
    try {
      final response = await extractArtStylePrompt(widget.accessToken, images);
      if (!mounted) return;
      setState(() {
        _ctrls.promptCtrl.text = response.text;
        _busy = false;
        _statusLine = '已生成画风 prompt，可直接保存到当前画风。';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '抽取失败：$e';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusLine = '抽取失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArtStylesWorkbenchDialogView(
      model: ArtStylesWorkbenchDialogViewModel(
        rows: _rows,
        selected: _selected,
        coverBytes: _coverBytes,
        statusLine: _statusLine,
        busy: _busy,
        loadingCover: _loadingCover,
        nameCtrl: _ctrls.nameCtrl,
        labelCtrl: _ctrls.labelCtrl,
        promptCtrl: _ctrls.promptCtrl,
        fileUrlCtrl: _ctrls.fileUrlCtrl,
        extractImagesCtrl: _ctrls.extractImagesCtrl,
      ),
      callbacks: ArtStylesWorkbenchDialogViewCallbacks(
        onReloadRows: _reloadRows,
        onLoadCover: _loadCover,
        onCreateStyle: _createStyle,
        onSaveSelected: _saveSelected,
        onDeleteSelected: _deleteSelected,
        onExtractPrompt: _extractPrompt,
        onApplySelection: _applySelection,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
