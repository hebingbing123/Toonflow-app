import 'package:flutter/material.dart';

import '../rust_api.dart';

typedef PublishPlatformCopyCommit = Future<void> Function(
  String platformId,
  String title,
  String description,
  String tagsComma,
);

/// Minimal per-platform `platform_copy` editor (F4): domestic / overseas chip groups and title, description, tags.
class PublishPlatformCopyEditor extends StatefulWidget {
  const PublishPlatformCopyEditor({
    super.key,
    required this.draftId,
    required this.domesticPlatformIds,
    required this.overseasPlatformIds,
    required this.platformLabels,
    required this.platformCopy,
    required this.busy,
    this.onCommit,
  });

  final String draftId;
  final List<String> domesticPlatformIds;
  final List<String> overseasPlatformIds;
  final Map<String, String> platformLabels;
  final Map<String, dynamic> platformCopy;
  final bool busy;
  final PublishPlatformCopyCommit? onCommit;

  @override
  State<PublishPlatformCopyEditor> createState() =>
      _PublishPlatformCopyEditorState();
}

class _PublishPlatformCopyEditorState extends State<PublishPlatformCopyEditor> {
  late String _platformId;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagsController;

  List<String> get _allIds => <String>[
        ...widget.domesticPlatformIds,
        ...widget.overseasPlatformIds,
      ];

  @override
  void initState() {
    super.initState();
    final ids = _allIds;
    _platformId = ids.isNotEmpty ? ids.first : '';
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagsController = TextEditingController();
    _loadFieldsForPlatform(_platformId);
  }

  @override
  void didUpdateWidget(covariant PublishPlatformCopyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = _allIds;
    if (oldWidget.draftId != widget.draftId ||
        oldWidget.domesticPlatformIds != widget.domesticPlatformIds ||
        oldWidget.overseasPlatformIds != widget.overseasPlatformIds) {
      if (!ids.contains(_platformId)) {
        _platformId = ids.isNotEmpty ? ids.first : '';
      }
      _loadFieldsForPlatform(_platformId);
      return;
    }
    if (oldWidget.platformCopy != widget.platformCopy) {
      _loadFieldsForPlatform(_platformId);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _blockFor(String pid) {
    final raw = widget.platformCopy[pid];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  void _loadFieldsForPlatform(String pid) {
    final b = _blockFor(pid);
    _titleController.text = (b?['title'] as String?)?.trim() ?? '';
    _descriptionController.text = (b?['description'] as String?)?.trim() ?? '';
    final tags = b?['tags'];
    if (tags is List) {
      _tagsController.text = tags.map((e) => '$e'.trim()).join(', ');
    } else {
      _tagsController.text = '';
    }
  }

  void _selectPlatform(String pid) {
    setState(() {
      _platformId = pid;
      _loadFieldsForPlatform(pid);
    });
  }

  Future<void> _save() async {
    final fn = widget.onCommit;
    if (fn == null || _platformId.isEmpty) {
      return;
    }
    await fn(
      _platformId,
      _titleController.text,
      _descriptionController.text,
      _tagsController.text,
    );
  }

  Widget _chipRow(String heading, List<String> ids, Color outline) {
    if (ids.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final id in ids)
              ChoiceChip(
                label: Text(widget.platformLabels[id] ?? id),
                selected: _platformId == id,
                onSelected: widget.busy ? null : (_) => _selectPlatform(id),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final ids = _allIds;
    if (ids.isEmpty || widget.onCommit == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shortVideoPublishCopyEditorSectionTitle,
          style: theme.textTheme.labelSmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 6),
        _chipRow(
          l10n.shortVideoSpaceTargetMarketDomestic,
          widget.domesticPlatformIds,
          outline,
        ),
        const SizedBox(height: 8),
        _chipRow(
          l10n.shortVideoSpaceTargetMarketOverseas,
          widget.overseasPlatformIds,
          outline,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: l10n.shortVideoPublishCopyFieldTitle,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          enabled: !widget.busy,
          maxLines: 1,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: l10n.shortVideoPublishCopyFieldDescription,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          enabled: !widget.busy,
          minLines: 2,
          maxLines: 5,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tagsController,
          decoration: InputDecoration(
            labelText: l10n.shortVideoPublishCopyFieldTagsCommaHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          enabled: !widget.busy,
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: widget.busy ? null : _save,
            icon: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(l10n.shortVideoPublishCopySaveToCurrentDraft),
          ),
        ),
      ],
    );
  }
}
