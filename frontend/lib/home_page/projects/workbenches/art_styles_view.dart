import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../rust_api.dart';

class ArtStylesWorkbenchDialogViewModel {
  const ArtStylesWorkbenchDialogViewModel({
    required this.rows,
    required this.selected,
    required this.coverBytes,
    required this.statusLine,
    required this.busy,
    required this.loadingCover,
    required this.nameCtrl,
    required this.labelCtrl,
    required this.promptCtrl,
    required this.fileUrlCtrl,
    required this.extractImagesCtrl,
  });

  final List<ArtStyleRow> rows;
  final ArtStyleRow? selected;
  final Uint8List? coverBytes;
  final String? statusLine;
  final bool busy;
  final bool loadingCover;
  final TextEditingController nameCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController promptCtrl;
  final TextEditingController fileUrlCtrl;
  final TextEditingController extractImagesCtrl;
}

class ArtStylesWorkbenchDialogViewCallbacks {
  const ArtStylesWorkbenchDialogViewCallbacks({
    required this.onReloadRows,
    required this.onLoadCover,
    required this.onCreateStyle,
    required this.onSaveSelected,
    required this.onDeleteSelected,
    required this.onExtractPrompt,
    required this.onApplySelection,
    required this.onClose,
  });

  final Future<void> Function({int? preferredNumericId}) onReloadRows;
  final Future<void> Function() onLoadCover;
  final Future<void> Function() onCreateStyle;
  final Future<void> Function() onSaveSelected;
  final Future<void> Function() onDeleteSelected;
  final Future<void> Function() onExtractPrompt;
  final void Function(ArtStyleRow row, {bool loadCover}) onApplySelection;
  final VoidCallback onClose;
}

/// 画风工作台视图，承载表单、列表选择与封面预览布局。
class ArtStylesWorkbenchDialogView extends StatelessWidget {
  const ArtStylesWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ArtStylesWorkbenchDialogViewModel model;
  final ArtStylesWorkbenchDialogViewCallbacks callbacks;

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
                    onPressed: model.busy ? null : callbacks.onReloadRows,
                    child: Text(model.busy ? '处理中…' : '刷新列表'),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        model.busy ||
                            model.loadingCover ||
                            model.selected == null
                        ? null
                        : callbacks.onLoadCover,
                    child: Text(model.loadingCover ? '读取中…' : '查看封面'),
                  ),
                  FilledButton(
                    onPressed: model.busy ? null : callbacks.onCreateStyle,
                    child: const Text('新建画风'),
                  ),
                  FilledButton(
                    onPressed: model.busy || model.selected == null
                        ? null
                        : callbacks.onSaveSelected,
                    child: const Text('保存当前画风'),
                  ),
                  FilledButton.tonal(
                    onPressed: model.busy || model.selected == null
                        ? null
                        : callbacks.onDeleteSelected,
                    child: const Text('删除当前画风'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (model.rows.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: model.selected?.numericId,
                  decoration: const InputDecoration(labelText: '当前画风'),
                  items: model.rows
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
                  onChanged: model.busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          final row = model.rows.firstWhere(
                            (element) => element.numericId == value,
                          );
                          callbacks.onApplySelection(row, loadCover: true);
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
                controller: model.nameCtrl,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.labelCtrl,
                decoration: const InputDecoration(labelText: '标签'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.fileUrlCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '封面 URL / data URI',
                  helperText: '可填写可访问 URL，或 data:image/...;base64,...',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.promptCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Prompt'),
              ),
              const SizedBox(height: 12),
              Text('Prompt 抽取', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              TextField(
                controller: model.extractImagesCtrl,
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
                  onPressed: model.busy ? null : callbacks.onExtractPrompt,
                  child: const Text('抽取 Prompt 到编辑区'),
                ),
              ),
              const SizedBox(height: 12),
              if (model.coverBytes != null)
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
                        model.coverBytes!,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              if (model.statusLine != null) ...[
                const SizedBox(height: 12),
                SelectableText(model.statusLine!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: callbacks.onClose, child: const Text('关闭')),
      ],
    );
  }
}
