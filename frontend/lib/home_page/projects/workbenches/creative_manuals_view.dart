// ignore_for_file: library_private_types_in_public_api

part of 'creative_manuals.dart';

/// View shell for the creative manuals workbench. Keeping it separate lets the
/// dialog state focus on manual mutations and selection rules.
class CreativeManualsWorkbenchView extends StatelessWidget {
  const CreativeManualsWorkbenchView({
    super.key,
    required this.kind,
    required this.busy,
    required this.activeRows,
    required this.selected,
    required this.statusLine,
    required this.nameCtrl,
    required this.pathCtrl,
    required this.imagesCtrl,
    required this.slotsCtrl,
    required this.pathLabel,
    required this.selectionLabel,
    required this.createLabel,
    required this.saveLabel,
    required this.deleteLabel,
    required this.onKindChanged,
    required this.onReloadAll,
    required this.onCreate,
    required this.onSave,
    required this.onDelete,
    required this.onSelectRowPath,
    required this.onClose,
  });

  final _CreativeManualKind kind;
  final bool busy;
  final List<_CreativeManualRow> activeRows;
  final _CreativeManualRow? selected;
  final String? statusLine;
  final TextEditingController nameCtrl;
  final TextEditingController pathCtrl;
  final TextEditingController imagesCtrl;
  final TextEditingController slotsCtrl;
  final String pathLabel;
  final String selectionLabel;
  final String createLabel;
  final String saveLabel;
  final String deleteLabel;
  final ValueChanged<_CreativeManualKind> onKindChanged;
  final Future<void> Function() onReloadAll;
  final Future<void> Function() onCreate;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final ValueChanged<String> onSelectRowPath;
  final VoidCallback onClose;

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
                selected: <_CreativeManualKind>{kind},
                onSelectionChanged: busy
                    ? null
                    : (selection) {
                        final next = selection.firstOrNull;
                        if (next != null) {
                          onKindChanged(next);
                        }
                      },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: busy ? null : onReloadAll,
                    child: Text(busy ? '处理中…' : '刷新全部手册'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : onCreate,
                    child: Text(createLabel),
                  ),
                  FilledButton(
                    onPressed: busy || selected == null ? null : onSave,
                    child: Text(saveLabel),
                  ),
                  FilledButton.tonal(
                    onPressed: busy || selected == null ? null : onDelete,
                    child: Text(deleteLabel),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (activeRows.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selected?.path,
                  decoration: InputDecoration(labelText: selectionLabel),
                  items: activeRows
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
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) {
                            onSelectRowPath(value);
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
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pathCtrl,
                decoration: InputDecoration(labelText: pathLabel),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: imagesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '图片列表',
                  helperText: '按换行或逗号分隔多个图片 URL / 路径。',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: slotsCtrl,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '数据槽位',
                  helperText: '每行一个槽位，格式为 label|value|data',
                ),
              ),
              if (selected != null) ...[
                const SizedBox(height: 12),
                Text('当前摘要', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                SelectableText(
                  '${selected!.name} · 路径 ${selected!.path} · '
                  '图片 ${selected!.images.length} 张 · 槽位 ${selected!.slots.length} 个',
                ),
              ],
              if (statusLine != null) ...[
                const SizedBox(height: 12),
                SelectableText(statusLine!),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: onClose, child: const Text('关闭'))],
    );
  }
}
