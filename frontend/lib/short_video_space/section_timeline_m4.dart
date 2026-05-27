part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

/// In-memory undo/redo for unsaved timeline edits (**NLE M4a**).
class _TimelineTracksUndoStack {
  final List<ShortVideoTimelineTracksV1> _undo = [];
  final List<ShortVideoTimelineTracksV1> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void push(ShortVideoTimelineTracksV1 snapshot) {
    _undo.add(snapshot);
    _redo.clear();
    if (_undo.length > 50) {
      _undo.removeAt(0);
    }
  }

  ShortVideoTimelineTracksV1? popUndo(ShortVideoTimelineTracksV1 current) {
    if (_undo.isEmpty) {
      return null;
    }
    _redo.add(current);
    return _undo.removeLast();
  }

  ShortVideoTimelineTracksV1? popRedo(ShortVideoTimelineTracksV1 current) {
    if (_redo.isEmpty) {
      return null;
    }
    _undo.add(current);
    return _redo.removeLast();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}

extension _ShortVideoTimelineM4 on _TimelineNleEditorState {
  void _pushUndoSnapshot() {
    _undoStack.push(_buildTracksPayload());
  }

  void _applyTracksFromUndo(ShortVideoTimelineTracksV1 next) {
    setState(() {
      _tracks = next;
      _bgm = next.bgm ??
          const ShortVideoTimelineBgmTrackV1(enabled: false, volume: 0.35);
    });
  }

  void _undoLocal() {
    final next = _undoStack.popUndo(_buildTracksPayload());
    if (next != null) {
      _applyTracksFromUndo(next);
    }
  }

  void _redoLocal() {
    final next = _undoStack.popRedo(_buildTracksPayload());
    if (next != null) {
      _applyTracksFromUndo(next);
    }
  }

  void _mutateTracks(void Function() mutate) {
    _pushUndoSnapshot();
    mutate();
  }

  Widget _buildM4Toolbar(AppLocalizations l10n) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: l10n.shortVideoTimelineUndo,
          onPressed: _undoStack.canUndo ? _undoLocal : null,
          icon: const Icon(Icons.undo, size: 20),
        ),
        IconButton(
          tooltip: l10n.shortVideoTimelineRedo,
          onPressed: _undoStack.canRedo ? _redoLocal : null,
          icon: const Icon(Icons.redo, size: 20),
        ),
        TextButton.icon(
          onPressed: _showRevisionHistorySheet,
          icon: const Icon(Icons.history, size: 18),
          label: Text(l10n.shortVideoTimelineRevisionHistory),
        ),
      ],
    );
  }

  Future<void> _showRevisionHistorySheet() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    try {
      final revisions = await fetchProjectShortVideoTimelineRevisions(
        widget.accessToken,
        widget.projectId,
      );
      if (!mounted) {
        return;
      }
      await showStudioBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          if (revisions.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: StudioEmptyState.emptyData(
                title: l10n.shortVideoTimelineRevisionEmpty,
                icon: Icons.history_outlined,
              ),
            );
          }
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: revisions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = revisions[index];
                final subtitle = [
                  if (item.summary?.trim().isNotEmpty == true) item.summary!,
                  item.createdAt,
                ].join(' · ');
                return ListTile(
                  title: Text(
                    l10n.shortVideoTimelineRevisionLabel(item.revision),
                  ),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.restore, size: 20),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _restoreRevision(item.revision);
                  },
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoTimelineRevisionLoadFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _restoreRevision(int revision) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    try {
      await postProjectShortVideoTimelineRestore(
        widget.accessToken,
        widget.projectId,
        revision: revision,
      );
      if (!mounted) {
        return;
      }
      _undoStack.clear();
      await widget.onReordered();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoTimelineRevisionRestored)),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoTimelineRevisionRestoreFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildEffectPresetDropdown(
    AppLocalizations l10n, {
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final normalized = (value ?? 'none').trim();
    final selected = normalized.isEmpty ? 'none' : normalized;
    return StudioDropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: kShortVideoTimelineEffectPresets.contains(selected)
          ? selected
          : 'none',
      decoration: InputDecoration(
        isDense: true,
        labelText: l10n.shortVideoTimelineEffectPreset,
      ),
      items: kShortVideoTimelineEffectPresets
          .map(
            (id) => DropdownMenuItem(
              value: id,
              child: Text(_effectPresetLabel(l10n, id)),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  String _effectPresetLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case 'vivid':
        return l10n.shortVideoTimelineEffectVivid;
      case 'cinematic':
        return l10n.shortVideoTimelineEffectCinematic;
      case 'bw':
        return l10n.shortVideoTimelineEffectBw;
      case 'speed_110':
        return l10n.shortVideoTimelineEffectSpeed110;
      default:
        return l10n.shortVideoTimelineEffectNone;
    }
  }

  void _applyGlobalEffectPreset(String? presetId) {
    _mutateTracks(() {
      final normalized =
          presetId == null || presetId == 'none' ? null : presetId;
      _tracks = _tracks.copyWith(
        video: _tracks.video
            .map((c) => c.copyWith(effectPresetId: normalized))
            .toList(growable: false),
      );
    });
  }
}

