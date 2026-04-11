import 'package:flutter/material.dart';

import '../../../rust_api.dart';

enum _CreativeManualKind { director, visual }

class ProjectsCreativeManualsWorkbenchDialog extends StatefulWidget {
  const ProjectsCreativeManualsWorkbenchDialog({
    super.key,
    required this.accessToken,
  });

  final String accessToken;

  @override
  State<ProjectsCreativeManualsWorkbenchDialog> createState() =>
      _ProjectsCreativeManualsWorkbenchDialogState();
}

class _ProjectsCreativeManualsWorkbenchDialogState
    extends State<ProjectsCreativeManualsWorkbenchDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _pathCtrl;
  late final TextEditingController _imagesCtrl;
  late final TextEditingController _slotsCtrl;

  _CreativeManualKind _kind = _CreativeManualKind.director;
  List<_CreativeManualRow> _directorRows = const <_CreativeManualRow>[];
  List<_CreativeManualRow> _visualRows = const <_CreativeManualRow>[];
  _CreativeManualRow? _selected;
  String? _statusLine;
  bool _busy = false;

  List<_CreativeManualRow> get _activeRows => _kind == _CreativeManualKind.director
      ? _directorRows
      : _visualRows;

  String get _pathLabel =>
      _kind == _CreativeManualKind.director ? 'directorManual 文件夹' : 'stylePath';

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
    _nameCtrl = TextEditingController();
    _pathCtrl = TextEditingController();
    _imagesCtrl = TextEditingController();
    _slotsCtrl = TextEditingController(text: '场景|scene|\n角色|role|');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pathCtrl.dispose();
    _imagesCtrl.dispose();
    _slotsCtrl.dispose();
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
    _nameCtrl.clear();
    _pathCtrl.clear();
    _imagesCtrl.clear();
    _slotsCtrl.text = '场景|scene|\n角色|role|';
  }

  void _applyRow(_CreativeManualRow row) {
    _selected = row;
    _nameCtrl.text = row.name;
    _pathCtrl.text = row.path;
    _imagesCtrl.text = row.images.join('\n');
    _slotsCtrl.text = _encodeSlots(row.slots);
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

  List<String> _parseImages() => _imagesCtrl.text
      .split(RegExp(r'[\n,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  List<LegacyDirectorManualDataSlot> _parseSlots() {
    final lines = _slotsCtrl.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    final slots = <LegacyDirectorManualDataSlot>[];
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length < 3) {
        throw FormatException('槽位格式必须为 label|value|data：$line');
      }
      slots.add(
        LegacyDirectorManualDataSlot(
          label: parts[0].trim(),
          value: parts[1].trim(),
          data: parts.sublist(2).join('|').trim(),
        ),
      );
    }
    return slots;
  }

  String _encodeSlots(List<LegacyDirectorManualDataSlot> slots) {
    if (slots.isEmpty) {
      return '场景|scene|\n角色|role|';
    }
    return slots
        .map((slot) => '${slot.label}|${slot.value}|${slot.data}')
        .join('\n');
  }

  Future<void> _createCurrentKind() async {
    final name = _nameCtrl.text.trim();
    final path = _pathCtrl.text.trim();
    if (name.isEmpty || path.isEmpty) {
      setState(() => _statusLine = '新建失败：名称与路径不能为空。');
      return;
    }
    final slots = _parseSlots();
    final images = _parseImages();
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
      setState(() => _statusLine = '已新建 ${_kindLabel()}：$path');
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
    final path = _pathCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (_selected == null) {
      setState(() => _statusLine = '保存失败：请先选择一条手册。');
      return;
    }
    if (name.isEmpty || path.isEmpty) {
      setState(() => _statusLine = '保存失败：名称与路径不能为空。');
      return;
    }
    final slots = _parseSlots();
    final images = _parseImages();
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
      setState(() => _statusLine = '已保存 ${_kindLabel()}：$path');
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
        await postProjectDeleteDirectorManual(widget.accessToken, selected.path);
      } else {
        await postProjectDeleteVisualManual(widget.accessToken, selected.path);
      }
      await _reloadAll();
      if (!mounted) return;
      setState(() => _statusLine = '已删除 ${_kindLabel()}：${selected.path}');
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

  String _kindLabel() =>
      _kind == _CreativeManualKind.director ? '导演手册' : '视觉手册';

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: const Text('创作手册工作台'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '把导演手册与视觉手册从首页探针收口到同一工作台，可直接刷新、查看、创建、更新和删除。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              SegmentedButton<_CreativeManualKind>(
                segments: const <ButtonSegment<_CreativeManualKind>>[
                  ButtonSegment<_CreativeManualKind>(
                    value: _CreativeManualKind.director,
                    label: Text('导演手册'),
                  ),
                  ButtonSegment<_CreativeManualKind>(
                    value: _CreativeManualKind.visual,
                    label: Text('视觉手册'),
                  ),
                ],
                selected: <_CreativeManualKind>{_kind},
                onSelectionChanged: _busy
                    ? null
                    : (selection) {
                        final next = selection.firstOrNull;
                        if (next != null) {
                          _setKind(next);
                        }
                      },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _busy ? null : _reloadAll,
                    child: Text(_busy ? '处理中…' : '刷新全部手册'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _createCurrentKind,
                    child: Text(_createLabel),
                  ),
                  FilledButton(
                    onPressed: _busy || _selected == null
                        ? null
                        : _saveCurrentKind,
                    child: Text(_saveLabel),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy || _selected == null
                        ? null
                        : _deleteCurrentKind,
                    child: Text(_deleteLabel),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_activeRows.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _selected?.path,
                  decoration: InputDecoration(labelText: _selectionLabel),
                  items: _activeRows
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
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          for (final row in _activeRows) {
                            if (row.path == value) {
                              setState(() => _applyRow(row));
                              break;
                            }
                          }
                        },
                )
              else
                Text(
                  '当前类型还没有手册，可直接填写下方表单新建。',
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
                controller: _pathCtrl,
                decoration: InputDecoration(labelText: _pathLabel),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _imagesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '图片列表',
                  helperText: '按换行或逗号分隔多个图片 URL / 路径。',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _slotsCtrl,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '数据槽位',
                  helperText: '每行一个槽位，格式为 label|value|data',
                ),
              ),
              if (_selected != null) ...[
                const SizedBox(height: 12),
                Text('当前摘要', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                SelectableText(
                  '${_selected!.name} · 路径 ${_selected!.path} · '
                  '图片 ${_selected!.images.length} 张 · 槽位 ${_selected!.slots.length} 个',
                ),
              ],
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

class _CreativeManualRow {
  const _CreativeManualRow({
    required this.name,
    required this.path,
    required this.images,
    required this.slots,
  });

  final String name;
  final String path;
  final List<String> images;
  final List<LegacyDirectorManualDataSlot> slots;

  factory _CreativeManualRow.fromDirector(LegacyDirectorManualStyleRow row) {
    return _CreativeManualRow(
      name: row.name,
      path: row.directorManual,
      images: row.image,
      slots: row.data,
    );
  }

  factory _CreativeManualRow.fromVisual(VisualManualStyleV1 row) {
    return _CreativeManualRow(
      name: row.name,
      path: row.stylePath,
      images: row.image,
      slots: row.data
          .map(
            (slot) => LegacyDirectorManualDataSlot(
              label: slot.label,
              value: slot.value,
              data: slot.data,
            ),
          )
          .toList(growable: false),
    );
  }
}
