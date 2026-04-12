part of '../section.dart';

/// 画风工作台视图，承载表单、列表选择与封面预览布局。
extension _ArtStylesWorkbenchDialogView on _ArtStylesWorkbenchDialogState {
  Widget _buildArtStylesWorkbenchDialogView(BuildContext context) {
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
