// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

extension _ShortVideoTimelineM2M3 on _TimelineNleEditorState {
  Future<void> _applyRoughCutTemplate(String templateId) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _templateBusy = true;
    });
    try {
      await postProjectShortVideoTimelineApplyTemplate(
        widget.accessToken,
        widget.projectId,
        templateId: templateId,
      );
      if (!mounted) return;
      await widget.onReordered();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoTimelineTemplateApplied)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoTimelineTemplateFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _templateBusy = false;
        });
      }
    }
  }

  Widget _buildM2M3TracksPanel(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StudioMenuAnchor(
              menuChildren: [
                StudioSelectMenuItem(
                  label: l10n.shortVideoTimelineTemplateShortDrama,
                  selected: false,
                  enabled: !_templateBusy,
                  onPressed: _templateBusy
                      ? null
                      : () => _applyRoughCutTemplate('short_drama_default'),
                ),
                StudioSelectMenuItem(
                  label: l10n.shortVideoTimelineTemplateDialoguePunch,
                  selected: false,
                  enabled: !_templateBusy,
                  onPressed: _templateBusy
                      ? null
                      : () => _applyRoughCutTemplate('dialogue_punch'),
                ),
              ],
              builder: (context, controller, child) {
                return FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed: _templateBusy
                      ? null
                      : () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                  child: Text(l10n.shortVideoTimelineApplyTemplate),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.shortVideoTimelineSubtitlesTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _SubtitleCueList(
          cues: _tracks.subtitles,
          onChanged: (next) => setState(() {
            _tracks = _tracks.copyWith(subtitles: next);
          }),
        ),
        const SizedBox(height: 16),
        Text(l10n.shortVideoTimelineTransitionsTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _TransitionList(
          transitions: _tracks.transitions,
          onChanged: (next) => setState(() {
            _tracks = _tracks.copyWith(transitions: next);
          }),
        ),
        const SizedBox(height: 16),
        Text(l10n.shortVideoTimelineVoiceoverTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _VoiceoverTrackPanel(
          clips: _tracks.voiceover,
          peaks: widget.timeline.voiceoverWaveformPeaks,
          onVolumeChanged: (id, vol) {
            setState(() {
              _tracks = _tracks.copyWith(
                voiceover: _tracks.voiceover
                    .map(
                      (c) => c.storyboardNumericId == id
                          ? c.copyWith(volume: vol)
                          : c,
                    )
                    .toList(growable: false),
              );
            });
          },
        ),
      ],
    );
  }
}

class _SubtitleCueList extends StatelessWidget {
  const _SubtitleCueList({required this.cues, required this.onChanged});

  final List<ShortVideoTimelineSubtitleCueV1> cues;
  final void Function(List<ShortVideoTimelineSubtitleCueV1> cues) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      children: [
        ...cues.asMap().entries.map((entry) {
          final idx = entry.key;
          final cue = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l10n.shortVideoTimelineSubtitleText,
                    ),
                    controller: TextEditingController(text: cue.text)
                      ..selection = TextSelection.collapsed(offset: cue.text.length),
                    onSubmitted: (v) {
                      final next = List<ShortVideoTimelineSubtitleCueV1>.from(cues);
                      next[idx] = cue.copyWith(text: v);
                      onChanged(next);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l10n.shortVideoTimelineSubtitleStartMs,
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: '${cue.startMs}'),
                    onSubmitted: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null) return;
                      final next = List<ShortVideoTimelineSubtitleCueV1>.from(cues);
                      next[idx] = cue.copyWith(startMs: parsed);
                      onChanged(next);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l10n.shortVideoTimelineSubtitleEndMs,
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: '${cue.endMs}'),
                    onSubmitted: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null) return;
                      final next = List<ShortVideoTimelineSubtitleCueV1>.from(cues);
                      next[idx] = cue.copyWith(endMs: parsed);
                      onChanged(next);
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              onChanged([
                ...cues,
                const ShortVideoTimelineSubtitleCueV1(
                  startMs: 0,
                  endMs: 3000,
                  text: '',
                ),
              ]);
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.shortVideoTimelineAddSubtitle),
          ),
        ),
      ],
    );
  }
}

class _TransitionList extends StatelessWidget {
  const _TransitionList({
    required this.transitions,
    required this.onChanged,
  });

  final List<ShortVideoTimelineTransitionV1> transitions;
  final void Function(List<ShortVideoTimelineTransitionV1> transitions) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (transitions.isEmpty) {
      return Text(
        l10n.shortVideoTimelineEmpty,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      children: transitions.asMap().entries.map((entry) {
        final idx = entry.key;
        final tr = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                l10n.shortVideoTimelineTransitionBetweenShots(idx + 1, idx + 2),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 16),
              StudioDropdownButton<String>(
                value: tr.type,
                items: [
                  DropdownMenuItem(
                    value: 'cut',
                    child: Text(l10n.shortVideoTimelineTransitionCut),
                  ),
                  DropdownMenuItem(
                    value: 'crossfade',
                    child: Text(l10n.shortVideoTimelineTransitionCrossfade),
                  ),
                  DropdownMenuItem(
                    value: 'fade_black',
                    child: Text(l10n.shortVideoTimelineTransitionFadeBlack),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  final next = List<ShortVideoTimelineTransitionV1>.from(transitions);
                  next[idx] = ShortVideoTimelineTransitionV1(
                    type: v,
                    durationMs: v == 'cut' ? 0 : (tr.durationMs > 0 ? tr.durationMs : 500),
                  );
                  onChanged(next);
                },
              ),
              if (tr.type != 'cut') ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l10n.shortVideoTimelineTransitionDurationMs,
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: '${tr.durationMs}'),
                    onSubmitted: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null) return;
                      final next = List<ShortVideoTimelineTransitionV1>.from(transitions);
                      next[idx] = ShortVideoTimelineTransitionV1(
                        type: tr.type,
                        durationMs: parsed.clamp(1, 2000),
                      );
                      onChanged(next);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _VoiceoverTrackPanel extends StatelessWidget {
  const _VoiceoverTrackPanel({
    required this.clips,
    required this.peaks,
    required this.onVolumeChanged,
  });

  final List<ShortVideoTimelineVoiceoverClipV1> clips;
  final List<double>? peaks;
  final void Function(int storyboardNumericId, double volume) onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    if (clips.isEmpty) {
      return StudioEmptyState.emptyData(
        title: l10n.shortVideoTimelineEmpty,
        icon: Icons.graphic_eq_outlined,
      );
    }
    return Column(
      children: [
        if (peaks != null && peaks!.isNotEmpty)
          SizedBox(
            height: 48,
            child: CustomPaint(
              painter: _WaveformBarsPainter(
                peaks!,
                StudioTokens.of(context).primary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ...clips.map((clip) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '#${clip.storyboardNumericId} @ ${clip.startMs}ms',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(l10n.shortVideoTimelineVoiceoverVolume),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: clip.volume.clamp(0.0, 2.0),
                    min: 0,
                    max: 2,
                    onChanged: (v) =>
                        onVolumeChanged(clip.storyboardNumericId, v),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _WaveformBarsPainter extends CustomPainter {
  _WaveformBarsPainter(this.peaks, this.barColor);

  final List<double> peaks;
  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = barColor;
    final barW = size.width / peaks.length;
    for (var i = 0; i < peaks.length; i++) {
      final h = peaks[i].clamp(0.0, 1.0) * size.height;
      final x = i * barW;
      canvas.drawRect(
        Rect.fromLTWH(x + 1, size.height - h, barW - 2, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformBarsPainter oldDelegate) {
    return oldDelegate.peaks != peaks || oldDelegate.barColor != barColor;
  }
}
