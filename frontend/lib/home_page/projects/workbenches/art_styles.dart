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
  late final TextEditingController _nameCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _fileUrlCtrl;
  late final TextEditingController _extractImagesCtrl;

  List<ArtStyleRow> _rows = const <ArtStyleRow>[];
  ArtStyleRow? _selected;
  Uint8List? _coverBytes;
  String? _statusLine;
  bool _busy = false;
  bool _loadingCover = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _labelCtrl = TextEditingController();
    _promptCtrl = TextEditingController();
    _fileUrlCtrl = TextEditingController();
    _extractImagesCtrl = TextEditingController();
    _rows = List<ArtStyleRow>.from(widget.initialRows);
    if (_rows.isNotEmpty) {
      _applySelection(_rows.first, loadCover: false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _labelCtrl.dispose();
    _promptCtrl.dispose();
    _fileUrlCtrl.dispose();
    _extractImagesCtrl.dispose();
    super.dispose();
  }

  void _applySelection(ArtStyleRow row, {bool loadCover = true}) {
    setState(() {
      _selected = row;
      _nameCtrl.text = row.name;
      _labelCtrl.text = row.label ?? '';
      _promptCtrl.text = row.prompt ?? '';
      _fileUrlCtrl.text = row.fileUrl ?? '';
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
          _nameCtrl.clear();
          _labelCtrl.clear();
          _promptCtrl.clear();
          _fileUrlCtrl.clear();
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
    final name = _nameCtrl.text.trim();
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
        label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
        prompt: _promptCtrl.text.trim().isEmpty
            ? null
            : _promptCtrl.text.trim(),
        fileUrl: _fileUrlCtrl.text.trim().isEmpty
            ? null
            : _fileUrlCtrl.text.trim(),
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
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'label': _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
      'prompt': _promptCtrl.text.trim().isEmpty
          ? null
          : _promptCtrl.text.trim(),
      'file_url': _fileUrlCtrl.text.trim().isEmpty
          ? null
          : _fileUrlCtrl.text.trim(),
    };
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
    final images = _extractImagesCtrl.text
        .split(RegExp(r'[\n,]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
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
        _promptCtrl.text = response.text;
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
    final outline = Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: const Text('画风工作台'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '在同一入口内完成画风列表刷新、封面查看、CRUD 与 prompt 抽取，不再只停留在列表加载与回归探针。',
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
                    onPressed: _busy ? null : _reloadRows,
                    child: Text(_busy ? '处理中…' : '刷新列表'),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy || _loadingCover || _selected == null
                        ? null
                        : _loadCover,
                    child: Text(_loadingCover ? '读取中…' : '查看封面'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _createStyle,
                    child: const Text('新建画风'),
                  ),
                  FilledButton(
                    onPressed: _busy || _selected == null
                        ? null
                        : _saveSelected,
                    child: const Text('保存当前画风'),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy || _selected == null
                        ? null
                        : _deleteSelected,
                    child: const Text('删除当前画风'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_rows.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _selected?.numericId,
                  decoration: const InputDecoration(labelText: '当前画风'),
                  items: _rows
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
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          final row = _rows.firstWhere(
                            (element) => element.numericId == value,
                          );
                          _applySelection(row);
                        },
                )
              else
                Text(
                  '当前还没有画风，填写下面表单后可直接新建。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(labelText: '标签'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _fileUrlCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '封面 URL / data URI',
                  helperText: '可填写可访问 URL，或 data:image/...;base64,...',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _promptCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Prompt'),
              ),
              const SizedBox(height: 12),
              Text('Prompt 抽取', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              TextField(
                controller: _extractImagesCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '图片输入',
                  helperText: '按换行或逗号分隔多个图片 URL / data URI。',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: _busy ? null : _extractPrompt,
                  child: const Text('抽取 Prompt 到编辑区'),
                ),
              ),
              const SizedBox(height: 12),
              if (_coverBytes != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前封面预览',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _coverBytes!,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              if (_statusLine != null) ...[
                const SizedBox(height: 12),
                SelectableText(_statusLine!),
              ],
            ],
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
