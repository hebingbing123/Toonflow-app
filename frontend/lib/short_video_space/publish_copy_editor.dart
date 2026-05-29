import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';

import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_debounced_action.dart';
import '../design_system/ix/studio_dirty_pop_guard.dart';
import '../design_system/ix/studio_form_keyboard.dart';
import '../design_system/ix/studio_mobile_affordances.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/tokens.dart';

import '../l10n/app_localizations.dart';
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

class _PublishPlatformCopyEditorState extends State<PublishPlatformCopyEditor>
    with SingleTickerProviderStateMixin {
  late String _platformId;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagsController;
  late AnimationController _shakeController;
  String? _titleInlineError;
  String _savedPlatformId = '';
  String _savedTitle = '';
  String _savedDescription = '';
  String _savedTags = '';
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
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
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
    _shakeController.dispose();
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
    final title = (b?['title'] as String?)?.trim() ?? '';
    final description = (b?['description'] as String?)?.trim() ?? '';
    final tags = b?['tags'];
    final tagsText = tags is List
        ? tags.map((e) => '$e'.trim()).join(', ')
        : '';
    _titleController.text = title;
    _descriptionController.text = description;
    if (tags is List) {
      _tagsController.text = tagsText;
    } else {
      _tagsController.text = '';
    }
    _savedPlatformId = pid;
    _savedTitle = title;
    _savedDescription = description;
    _savedTags = tagsText;
  }

  void _selectPlatform(String pid) {
    setState(() {
      _platformId = pid;
      _loadFieldsForPlatform(pid);
    });
  }

  bool get _dirty =>
      _platformId != _savedPlatformId ||
      _titleController.text.trim() != _savedTitle ||
      _descriptionController.text.trim() != _savedDescription ||
      _tagsController.text.trim() != _savedTags;

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context)!;
    final discard = await showStudioConfirmDialog(
      context: context,
      title: l10n.studioDiscardChangesTitle,
      message: l10n.studioDiscardPublishCopyMessage,
      confirmLabel: l10n.studioDiscardAction,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      destructive: true,
      barrierDismissible: false,
    );
    return discard == true;
  }

  Future<void> _save() async {
    final fn = widget.onCommit;
    if (fn == null || _platformId.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _titleInlineError = l10n.shortVideoPublishCopyFieldTitle;
      });
      unawaited(_shakeController.forward(from: 0));
      unawaited(studioLightImpact());
      return;
    }
    setState(() => _titleInlineError = null);
    await fn(
      _platformId,
      _titleController.text,
      _descriptionController.text,
      _tagsController.text,
    );
    if (!mounted) return;
    setState(() {
      _savedPlatformId = _platformId;
      _savedTitle = _titleController.text.trim();
      _savedDescription = _descriptionController.text.trim();
      _savedTags = _tagsController.text.trim();
    });
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

    return StudioDirtyPopGuard(
      isDirty: _dirty,
      popBlocked: widget.busy,
      onConfirmDiscard: _confirmDiscard,
      child: StudioFormKeyboardScope(
        onEnterSubmit: widget.busy ? null : () => unawaited(_save()),
        child: Column(
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
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final t = _shakeController.value;
              final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.shortVideoPublishCopyFieldTitle,
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _titleInlineError,
            ),
            enabled: !widget.busy,
            maxLines: 1,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_titleInlineError != null) {
                setState(() => _titleInlineError = null);
              }
            },
          ),
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
            child: StudioDebouncedAction(
              enabled: !widget.busy,
              onPressed: widget.busy ? null : () async => _save(),
              builder: (context, onPressed) => FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: widget.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: StudioControlSize.progressStroke,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.shortVideoPublishCopySaveToCurrentDraft),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
