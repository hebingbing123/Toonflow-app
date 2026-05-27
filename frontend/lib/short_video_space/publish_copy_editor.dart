import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';

import '../design_system/components/studio_surfaces.dart';
import '../design_system/tokens.dart';

import '../rust_api.dart';

typedef PublishPlatformCopyCommit =
    Future<void> Function(
      String platformId,
      String title,
      String description,
      String tagsComma,
    );

bool publishPlatformCopyBlockChanged(
  Map<String, dynamic> oldPlatformCopy,
  Map<String, dynamic> newPlatformCopy,
  String platformId,
) {
  Map<String, dynamic>? normalizeBlock(Map<String, dynamic> source) {
    final raw = source[platformId];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  List<String> normalizeTags(Map<String, dynamic>? block) {
    final tags = block?['tags'];
    if (tags is! List) {
      return const <String>[];
    }
    return tags.map((e) => '$e'.trim()).toList(growable: false);
  }

  final oldBlock = normalizeBlock(oldPlatformCopy);
  final newBlock = normalizeBlock(newPlatformCopy);
  final oldTitle = (oldBlock?['title'] as String?)?.trim() ?? '';
  final newTitle = (newBlock?['title'] as String?)?.trim() ?? '';
  if (oldTitle != newTitle) {
    return true;
  }
  final oldDescription = (oldBlock?['description'] as String?)?.trim() ?? '';
  final newDescription = (newBlock?['description'] as String?)?.trim() ?? '';
  if (oldDescription != newDescription) {
    return true;
  }
  final oldTags = normalizeTags(oldBlock);
  final newTags = normalizeTags(newBlock);
  if (oldTags.length != newTags.length) {
    return true;
  }
  for (var i = 0; i < oldTags.length; i++) {
    if (oldTags[i] != newTags[i]) {
      return true;
    }
  }
  return false;
}

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
    final platformGroupsChanged =
        !listEquals(
          oldWidget.domesticPlatformIds,
          widget.domesticPlatformIds,
        ) ||
        !listEquals(oldWidget.overseasPlatformIds, widget.overseasPlatformIds);
    if (oldWidget.draftId != widget.draftId || platformGroupsChanged) {
      if (!ids.contains(_platformId)) {
        _platformId = ids.isNotEmpty ? ids.first : '';
      }
      _loadFieldsForPlatform(_platformId);
      return;
    }
    if (publishPlatformCopyBlockChanged(
      oldWidget.platformCopy,
      widget.platformCopy,
      _platformId,
    )) {
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
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: outline),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            for (final id in ids)
              StudioChoiceChip(
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
    final muted = studioPanelMutedColor(context);
    final ids = _allIds;
    if (ids.isEmpty || widget.onCommit == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shortVideoPublishCopyEditorSectionTitle,
          style: theme.textTheme.labelSmall?.copyWith(color: muted),
        ),
        const SizedBox(height: StudioSpacing.xs),
        _chipRow(
          l10n.shortVideoSpaceTargetMarketDomestic,
          widget.domesticPlatformIds,
          muted,
        ),
        const SizedBox(height: StudioSpacing.xs),
        _chipRow(
          l10n.shortVideoSpaceTargetMarketOverseas,
          widget.overseasPlatformIds,
          muted,
        ),
        const SizedBox(height: StudioLayoutSpacing.inlineGap),
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
        const SizedBox(height: StudioSpacing.xs),
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
        const SizedBox(height: StudioSpacing.xs),
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
        const SizedBox(height: StudioLayoutSpacing.inlineGap),
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
