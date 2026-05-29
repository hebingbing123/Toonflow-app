// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

extension _ShortVideoSpaceSectionTimelineExtension
    on _ShortVideoSpaceSectionState {
  Future<void> _loadShortVideoTimeline() async {
    if (ProductDemoMode.instance.shouldSkipLiveApi) {
      final snap = widget.debugOverviewSnapshot;
      if (!mounted) {
        return;
      }
      setState(() {
        _shortVideoTimeline =
            snap?.timeline ?? buildDemoStudioShortVideoTimeline();
        _loadingTimeline = false;
      });
      return;
    }
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    setState(() {
      _loadingTimeline = true;
    });
    try {
      final timeline = await fetchProjectShortVideoTimelineByProjectId(
        token,
        project.id,
      );
      if (!mounted) return;
      setState(() {
        _shortVideoTimeline = timeline;
        _loadingTimeline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _shortVideoTimeline = null;
        _loadingTimeline = false;
      });
    }
  }

  Widget? _buildShortVideoTimelinePanel() {
    final project = _selectedProject;
    if (project == null) {
      return null;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final timeline = _shortVideoTimeline;
    if (timeline == null && !_loadingTimeline) {
      unawaited(_loadShortVideoTimeline());
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.shortVideoTimelinePanelTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  style: studioFormTextButtonIconStyle(context),
                  onPressed: _loadingTimeline ? null : _loadShortVideoTimeline,
                  icon: const Icon(Icons.refresh, size: StudioIconSize.sm),
                  label: Text(l10n.shortVideoCharactersRefresh),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.xs),
            if (_loadingTimeline)
              Text(
                l10n.shortVideoTimelineLoading,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: studioPanelMutedColor(context),
                ),
              )
            else if (timeline == null || timeline.scripts.isEmpty)
              StudioEmptyState.emptyData(
                title: l10n.shortVideoTimelineEmpty,
                icon: Icons.timeline_outlined,
              )
            else
              _TimelineNleEditor(
                timeline: timeline,
                projectId: project.id,
                accessToken: widget.accessToken!,
                saveBusy: _timelineSaveBusy,
                previewBusy: _timelinePreviewBusy,
                previewUrl: _timelinePreviewUrl,
                onSave: _saveTimelineTracks,
                onPreview: _generateTimelinePreview,
                onReordered: () async {
                  await _loadShortVideoTimeline();
                  await _loadProjectOverview();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTimelineTracks(ShortVideoTimelineTracksV1 tracks) async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || project == null || _timelineSaveBusy) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _timelineSaveBusy = true;
    });
    try {
      final resp = await putProjectShortVideoTimeline(
        token,
        project.id,
        tracks: tracks,
        expectedTimelineVersion: _shortVideoTimeline?.timelineVersion,
        expectedRevision: _shortVideoTimeline?.revision,
      );
      if (!mounted) return;
      await _loadShortVideoTimeline();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.shortVideoTimelineSaveDone} (${resp.updatedClipCount})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoTimelineSaveFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _timelineSaveBusy = false;
        });
      }
    }
  }

  Future<void> _generateTimelinePreview() async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || project == null || _timelinePreviewBusy) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _timelinePreviewBusy = true;
      _timelinePreviewUrl = null;
    });
    try {
      final enqueued = await postProjectShortVideoTimelinePreview(
        token,
        project.id,
      );
      final url = await pollTimelinePreviewJobFileUrl(token, enqueued.jobId);
      if (!mounted) return;
      setState(() {
        _timelinePreviewUrl = url;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoTimelinePreviewDone)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoTimelinePreviewFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _timelinePreviewBusy = false;
        });
      }
    }
  }
}

class _TimelineNleEditor extends StatefulWidget {
  const _TimelineNleEditor({
    required this.timeline,
    required this.projectId,
    required this.accessToken,
    required this.saveBusy,
    required this.previewBusy,
    required this.previewUrl,
    required this.onSave,
    required this.onPreview,
    required this.onReordered,
  });

  final ProjectShortVideoTimelineV1 timeline;
  final String projectId;
  final String accessToken;
  final bool saveBusy;
  final bool previewBusy;
  final String? previewUrl;
  final Future<void> Function(ShortVideoTimelineTracksV1 tracks) onSave;
  final Future<void> Function() onPreview;
  final Future<void> Function() onReordered;

  @override
  State<_TimelineNleEditor> createState() => _TimelineNleEditorState();
}

class _TimelineNleEditorState extends State<_TimelineNleEditor> {
  late ShortVideoTimelineTracksV1 _tracks;
  late ShortVideoTimelineBgmTrackV1 _bgm;
  bool _templateBusy = false;
  final _TimelineTracksUndoStack _undoStack = _TimelineTracksUndoStack();

  @override
  void initState() {
    super.initState();
    _tracks = widget.timeline.tracks;
    _bgm =
        widget.timeline.tracks.bgm ??
        const ShortVideoTimelineBgmTrackV1(enabled: false, volume: 0.35);
  }

  @override
  void didUpdateWidget(covariant _TimelineNleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeline.timelineVersion != widget.timeline.timelineVersion ||
        oldWidget.timeline.revision != widget.timeline.revision) {
      _tracks = widget.timeline.tracks;
      _bgm =
          widget.timeline.tracks.bgm ??
          const ShortVideoTimelineBgmTrackV1(enabled: false, volume: 0.35);
      _undoStack.clear();
    }
  }

  ShortVideoTimelineTracksV1 _buildTracksPayload() {
    return ShortVideoTimelineTracksV1(
      video: _tracks.video,
      bgm: _bgm,
      subtitles: _tracks.subtitles,
      transitions: _tracks.transitions,
      voiceover: _tracks.voiceover,
      templateId: _tracks.templateId,
    );
  }

  void _updateClipEffect(int storyboardNumericId, String? presetId) {
    _mutateTracks(() {
      final idx = _tracks.video.indexWhere(
        (c) => c.storyboardNumericId == storyboardNumericId,
      );
      if (idx < 0) {
        return;
      }
      final next = [..._tracks.video];
      next[idx] = next[idx].copyWith(effectPresetId: presetId);
      _tracks = _tracks.copyWith(video: next);
    });
  }

  void _updateClipTrim(
    int storyboardNumericId, {
    int? inMs,
    int? outMs,
    String? fallbackSourceUrl,
  }) {
    _mutateTracks(() {
      final idx = _tracks.video.indexWhere(
        (c) => c.storyboardNumericId == storyboardNumericId,
      );
      List<ShortVideoTimelineVideoClipV1> next;
      if (idx < 0) {
        final url = (fallbackSourceUrl ?? '').trim();
        if (url.isEmpty) {
          return;
        }
        next = [
          ..._tracks.video,
          ShortVideoTimelineVideoClipV1(
            storyboardNumericId: storyboardNumericId,
            sourceUrl: url,
            inMs: inMs ?? 0,
            outMs: outMs ?? 5000,
          ),
        ];
      } else {
        next = _tracks.video
            .map(
              (c) => c.storyboardNumericId == storyboardNumericId
                  ? c.copyWith(inMs: inMs, outMs: outMs)
                  : c,
            )
            .toList(growable: false);
      }
      _tracks = _tracks.copyWith(video: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildM4Toolbar(l10n),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.shortVideoTimelineEffectApplyAll,
          style: theme.textTheme.labelMedium,
        ),
        _buildEffectPresetDropdown(
          l10n,
          value: null,
          onChanged: _applyGlobalEffectPreset,
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioSwitchListRow(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shortVideoTimelineBgmEnabled),
          subtitle: _bgm.bgmStrategy?.trim().isNotEmpty == true
              ? Text(_bgm.bgmStrategy!)
              : null,
          value: _bgm.enabled,
          onChanged: (v) {
            _pushUndoSnapshot();
            setState(() => _bgm = _bgm.copyWith(enabled: v));
          },
        ),
        if (_bgm.enabled)
          Row(
            children: [
              Text(l10n.shortVideoTimelineBgmVolume),
              Expanded(
                child: Slider(
                  value: _bgm.volume.clamp(0.0, 1.0),
                  onChanged: (v) {
                    _pushUndoSnapshot();
                    setState(() => _bgm = _bgm.copyWith(volume: v));
                  },
                ),
              ),
              Text(_bgm.volume.toStringAsFixed(2)),
            ],
          ),
        StudioDenseActionRow(
          children: [
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: widget.saveBusy
                  ? null
                  : () => widget.onSave(_buildTracksPayload()),
              child: widget.saveBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.shortVideoTimelineSave),
            ),
            FilledButton(
              style: studioFormPrimaryButtonStyle(context),
              onPressed: widget.previewBusy ? null : widget.onPreview,
              child: widget.previewBusy
                  ? Text(l10n.shortVideoTimelinePreviewBusy)
                  : Text(l10n.shortVideoTimelineGeneratePreview),
            ),
            if (widget.previewUrl != null && widget.previewUrl!.isNotEmpty)
              OutlinedButton.icon(
                style: studioFormOutlinedIconLabeledButtonStyle(context),
                onPressed: () async {
                  final uri = Uri.tryParse(widget.previewUrl!);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.play_arrow, size: StudioIconSize.sm),
                label: Text(l10n.shortVideoTimelinePlayPreview),
              ),
          ],
        ),
        const SizedBox(height: StudioSpacing.sm),
        _buildM2M3TracksPanel(l10n, theme),
        const SizedBox(height: StudioSpacing.sm),
        ...widget.timeline.scripts.toList().asMap().entries.map((entry) {
          return studioStaggeredItem(
            entry.key,
            entranceKey: widget.timeline.scripts.length,
            child: _TimelineScriptGroup(
              group: entry.value,
              projectId: widget.projectId,
              accessToken: widget.accessToken,
              clipByStoryboardId: {
                for (final c in _tracks.video) c.storyboardNumericId: c,
              },
              onTrimChanged: _updateClipTrim,
              onEffectChanged: _updateClipEffect,
              onReordered: widget.onReordered,
            ),
          );
        }),
        if (_tracks.video.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: StudioSpacing.xs),
            child: Text(
              l10n.shortVideoTimelineEmpty,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _TimelineScriptGroup extends StatefulWidget {
  const _TimelineScriptGroup({
    required this.group,
    required this.projectId,
    required this.accessToken,
    required this.clipByStoryboardId,
    required this.onTrimChanged,
    required this.onEffectChanged,
    required this.onReordered,
  });

  final ShortVideoTimelineScriptGroupV1 group;
  final String projectId;
  final String accessToken;
  final Map<int, ShortVideoTimelineVideoClipV1> clipByStoryboardId;
  final void Function(
    int storyboardNumericId, {
    int? inMs,
    int? outMs,
    String? fallbackSourceUrl,
  })
  onTrimChanged;
  final void Function(int storyboardNumericId, String? presetId)
  onEffectChanged;
  final Future<void> Function() onReordered;

  @override
  State<_TimelineScriptGroup> createState() => _TimelineScriptGroupState();
}

class _TimelineScriptGroupState extends State<_TimelineScriptGroup> {
  late List<ShortVideoTimelineShotV1> _shots;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _shots = List<ShortVideoTimelineShotV1>.from(widget.group.shots);
  }

  void _move(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= _shots.length) {
      return;
    }
    setState(() {
      final item = _shots.removeAt(index);
      _shots.insert(next, item);
    });
    unawaited(studioLightImpact());
  }

  Future<void> _persist() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _busy = true;
    });
    try {
      await postProjectShortVideoTimelineReorder(
        widget.accessToken,
        widget.projectId,
        scriptNumericId: widget.group.scriptNumericId,
        orderedStoryboardIds: _shots
            .map((s) => s.storyboardNumericId)
            .toList(growable: false),
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoTimelineReorderDone)),
      );
      await widget.onReordered();
      unawaited(studioMediumImpact());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoTimelineReorderFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final title = widget.group.scriptName?.trim().isNotEmpty == true
        ? widget.group.scriptName!
        : 'Script ${widget.group.scriptNumericId}';
    return Padding(
      padding: const EdgeInsets.only(bottom: StudioSpacing.radiusComfort),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: StudioSpacing.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = studioClampedPaneWidth(
                constraints.maxWidth,
                fraction: 0.28,
                min: 200,
                max: 300,
              );
              final laneHeight = studioPreviewImageHeight(
                320,
                fraction: 0.65,
                min: 180,
                max: 280,
              );
              return SizedBox(
                height: laneHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _shots.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: StudioSpacing.xs),
                  itemBuilder: (context, index) {
                    final shot = _shots[index];
                    final clip =
                        widget.clipByStoryboardId[shot.storyboardNumericId];
                    return studioStaggeredItem(
                      index,
                      entranceKey: _shots.length,
                      child: _TimelineShotCard(
                        shot: shot,
                        clip: clip,
                        index: index,
                        total: _shots.length,
                        cardWidth: cardWidth,
                        onMoveUp: index > 0 ? () => _move(index, -1) : null,
                        onMoveDown: index < _shots.length - 1
                            ? () => _move(index, 1)
                            : null,
                        onTrimChanged: (id, {inMs, outMs, fallbackSourceUrl}) =>
                            widget.onTrimChanged(
                              id,
                              inMs: inMs,
                              outMs: outMs,
                              fallbackSourceUrl:
                                  fallbackSourceUrl ??
                                  shot.sourceUrl ??
                                  shot.selectedVideoUrl,
                            ),
                        onEffectChanged: widget.onEffectChanged,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: StudioSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: _busy ? null : _persist,
              child: Text(l10n.shortVideoTimelinePersistOrder),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineShotCard extends StatelessWidget {
  const _TimelineShotCard({
    required this.shot,
    required this.clip,
    required this.index,
    required this.total,
    required this.cardWidth,
    this.onMoveUp,
    this.onMoveDown,
    required this.onTrimChanged,
    required this.onEffectChanged,
  });

  final ShortVideoTimelineShotV1 shot;
  final ShortVideoTimelineVideoClipV1? clip;
  final int index;
  final int total;
  final double cardWidth;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final void Function(
    int storyboardNumericId, {
    int? inMs,
    int? outMs,
    String? fallbackSourceUrl,
  })
  onTrimChanged;
  final void Function(int storyboardNumericId, String? presetId)
  onEffectChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final preview = (shot.thumbnailUrl ?? shot.selectedVideoUrl ?? '').trim();
    final inMs = clip?.inMs ?? shot.inMs;
    final outMs = clip?.outMs ?? shot.outMs;
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(StudioSpacing.xs),
        decoration: BoxDecoration(
          border: Border.all(color: studioPanelBorderColor(context)),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${shot.storyboardNumericId} (${index + 1}/$total)',
              style: theme.textTheme.labelLarge,
            ),
            if (preview.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: StudioSpacing.xs),
                child: Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: StudioSpacing.xs),
            _TrimField(
              label: l10n.shortVideoTimelineTrimInMs,
              value: inMs,
              onSubmitted: (v) => onTrimChanged(
                shot.storyboardNumericId,
                inMs: v,
                fallbackSourceUrl: shot.sourceUrl ?? shot.selectedVideoUrl,
              ),
            ),
            _TrimField(
              label: l10n.shortVideoTimelineTrimOutMs,
              value: outMs,
              onSubmitted: (v) => onTrimChanged(
                shot.storyboardNumericId,
                outMs: v,
                fallbackSourceUrl: shot.sourceUrl ?? shot.selectedVideoUrl,
              ),
            ),
            Builder(
              builder: (ctx) {
                final editor = ctx
                    .findAncestorStateOfType<_TimelineNleEditorState>();
                if (editor == null) {
                  return const SizedBox.shrink();
                }
                return editor._buildEffectPresetDropdown(
                  l10n,
                  value: clip?.effectPresetId,
                  onChanged: (preset) => onEffectChanged(
                    shot.storyboardNumericId,
                    preset == 'none' ? null : preset,
                  ),
                );
              },
            ),
            const Spacer(),
            Row(
              children: [
                StudioIconButton(
                  icon: Icons.arrow_upward,
                  label: l10n.shortVideoTimelineMoveUp,
                  style: studioUtilityIconButtonStyle(context),
                  onPressed: onMoveUp,
                ),
                StudioIconButton(
                  icon: Icons.arrow_downward,
                  label: l10n.shortVideoTimelineMoveDown,
                  style: studioUtilityIconButtonStyle(context),
                  onPressed: onMoveDown,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrimField extends StatefulWidget {
  const _TrimField({
    required this.label,
    required this.value,
    required this.onSubmitted,
  });

  final String label;
  final int value;
  final void Function(int value) onSubmitted;

  @override
  State<_TrimField> createState() => _TrimFieldState();
}

class _TrimFieldState extends State<_TrimField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(covariant _TrimField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != '${widget.value}') {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(isDense: true, labelText: widget.label),
      onSubmitted: (text) {
        final parsed = int.tryParse(text.trim());
        if (parsed != null) {
          widget.onSubmitted(parsed);
        }
      },
    );
  }
}
