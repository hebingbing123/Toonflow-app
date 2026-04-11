import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'previews.dart';
import 'workbenches/agent_memory.dart';
import 'workbenches/creative_manuals.dart';
import '../../rust_api.dart';

class ProjectsSection extends StatelessWidget {
  const ProjectsSection({
    super.key,
    required this.accessToken,
    required this.loadingProjects,
    required this.loadingProjectsSummary,
    required this.loadingArtStyles,
    required this.creatingProject,
    required this.loadingAgentMemory,
    required this.projects,
    required this.artStyles,
    required this.projectsSummaryLine,
    required this.artStylesLine,
    required this.agentMemoryBody,
    required this.onLoadProjects,
    required this.onLoadProjectsSummary,
    required this.onLoadArtStyles,
    required this.onCreateEmptyProject,
    required this.onOpenProjectDetail,
    required this.onProbeAgentMemory,
  });

  final String? accessToken;
  final bool loadingProjects;
  final bool loadingProjectsSummary;
  final bool loadingArtStyles;
  final bool creatingProject;
  final bool loadingAgentMemory;
  final List<ProjectRow>? projects;
  final List<ArtStyleRow>? artStyles;
  final String? projectsSummaryLine;
  final String? artStylesLine;
  final String? agentMemoryBody;
  final VoidCallback onLoadProjects;
  final VoidCallback onLoadProjectsSummary;
  final Future<void> Function() onLoadArtStyles;
  final VoidCallback onCreateEmptyProject;
  final ValueChanged<ProjectRow> onOpenProjectDetail;
  final VoidCallback onProbeAgentMemory;

  Future<void> _openArtStylesWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取美术风格')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _ArtStylesWorkbenchDialog(
        accessToken: token,
        initialRows: artStyles ?? const <ArtStyleRow>[],
        onRefreshParent: onLoadArtStyles,
      ),
    );
  }

  Future<void> _openCreativeManualsWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取创作手册')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) =>
          ProjectsCreativeManualsWorkbenchDialog(accessToken: token),
    );
  }

  Future<void> _openAgentMemoryWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取 Agent 记忆')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => ProjectsAgentMemoryWorkbenchDialog(
        accessToken: token,
        initialProjects: projects ?? const <ProjectRow>[],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('项目列表', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '查看项目、摘要、美术风格与创作手册，并进入项目详情继续编辑。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: (loadingProjects || creatingProject)
                  ? null
                  : onLoadProjects,
              child: Text(loadingProjects ? '加载中…' : '加载项目列表'),
            ),
            FilledButton.tonal(
              onPressed: (loadingProjectsSummary || creatingProject)
                  ? null
                  : onLoadProjectsSummary,
              child: Text(loadingProjectsSummary ? '加载中…' : '查看项目摘要'),
            ),
            FilledButton.tonal(
              onPressed: (loadingArtStyles || creatingProject)
                  ? null
                  : onLoadArtStyles,
              child: Text(loadingArtStyles ? '加载中…' : '加载美术风格'),
            ),
            FilledButton.tonal(
              onPressed: creatingProject
                  ? null
                  : () => _openArtStylesWorkbench(context),
              child: const Text('打开画风工作台'),
            ),
            FilledButton.tonal(
              onPressed: creatingProject
                  ? null
                  : () => _openCreativeManualsWorkbench(context),
              child: const Text('打开创作手册工作台'),
            ),
            FilledButton.tonal(
              onPressed: creatingProject
                  ? null
                  : () => _openAgentMemoryWorkbench(context),
              child: const Text('打开记忆工作台'),
            ),
            FilledButton.tonal(
              onPressed: (loadingProjects || creatingProject)
                  ? null
                  : onCreateEmptyProject,
              child: Text(creatingProject ? '创建中…' : '新建空项目'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留首项目 Agent memory probe 作为回归入口，默认折叠',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: loadingAgentMemory ? null : onProbeAgentMemory,
                child: Text(loadingAgentMemory ? '请求中…' : '查询首个项目记忆'),
              ),
            ),
          ],
        ),
        if (projectsSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('项目摘要：$projectsSummaryLine'),
        ],
        if (artStylesLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('美术风格：$artStylesLine'),
        ],
        if (artStyles != null) ...[
          ProjectsArtStylesPreview(
            artStyles: artStyles!,
            onManage: () => _openArtStylesWorkbench(context),
          ),
        ],
        if (projects != null) ...[
          ProjectsListPreview(
            projects: projects!,
            onOpenProjectDetail: onOpenProjectDetail,
            agentMemoryBody: agentMemoryBody,
          ),
        ],
      ],
    );
  }
}

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

  Future<void> _reloadRows({int? preferredLegacyId}) async {
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
      if (preferredLegacyId == null) {
        if (_rows.isNotEmpty) {
          target = _rows.first;
        }
      } else {
        for (final row in _rows) {
          if (row.legacyId == preferredLegacyId) {
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
      final bytes = await fetchArtStyleCoverByLegacyId(
        widget.accessToken,
        legacyId: selected.legacyId,
      );
      if (!mounted) return;
      setState(() {
        _coverBytes = bytes;
        _loadingCover = false;
        _statusLine = '已读取画风 #${selected.legacyId} 封面。';
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
      await _reloadRows(preferredLegacyId: created.legacyId);
      if (!mounted) return;
      setState(() => _statusLine = '已新建画风 #${created.legacyId}。');
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
      final updated = await patchArtStyleByLegacyId(
        widget.accessToken,
        selected.legacyId,
        body,
      );
      await _reloadRows(preferredLegacyId: updated.legacyId);
      if (!mounted) return;
      setState(() => _statusLine = '已更新画风 #${updated.legacyId}。');
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
      await deleteArtStyleByLegacyId(widget.accessToken, selected.legacyId);
      await _reloadRows();
      if (!mounted) return;
      setState(() => _statusLine = '已删除画风 #${selected.legacyId}。');
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
                  initialValue: _selected?.legacyId,
                  decoration: const InputDecoration(labelText: '当前画风'),
                  items: _rows
                      .map(
                        (row) => DropdownMenuItem<int>(
                          value: row.legacyId,
                          child: Text(
                            '#${row.legacyId} ${row.name}',
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
                            (element) => element.legacyId == value,
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
