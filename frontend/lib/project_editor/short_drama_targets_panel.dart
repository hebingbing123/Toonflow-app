import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';

import '../l10n/app_localizations.dart';
import '../rust_api.dart';

/// Wave-1 Moneyprinter-style short-drama flags on the project row, editable
/// outside [`short_video_space`]: mode, aspect ratio, and `short_drama` type.
class ShortDramaTargetsPanel extends StatefulWidget {
  const ShortDramaTargetsPanel({
    super.key,
    required this.accessToken,
    required this.project,
    this.onSaved,
  });

  final String accessToken;
  final ProjectRow project;
  final Future<void> Function()? onSaved;

  @override
  State<ShortDramaTargetsPanel> createState() => _ShortDramaTargetsPanelState();
}

enum _ShortDramaFlavor { animated, liveAction }

class _ShortDramaTargetsPanelState extends State<ShortDramaTargetsPanel> {
  late _ShortDramaFlavor _flavor;
  late String _videoRatio;
  bool _busy = false;
  String? _line;

  @override
  void initState() {
    super.initState();
    _flavor = _flavorFromProject(widget.project);
    _videoRatio = _normalizeVideoRatio(widget.project.videoRatio);
  }

  @override
  void didUpdateWidget(covariant ShortDramaTargetsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _flavor = _flavorFromProject(widget.project);
      _videoRatio = _normalizeVideoRatio(widget.project.videoRatio);
      _line = null;
    }
  }

  static _ShortDramaFlavor _flavorFromProject(ProjectRow project) {
    final value = (project.mode ?? '').trim().toLowerCase();
    if (value.contains('live') ||
        value.contains('real') ||
        value.contains('真人')) {
      return _ShortDramaFlavor.liveAction;
    }
    return _ShortDramaFlavor.animated;
  }

  static String _normalizeVideoRatio(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed == '16:9' || trimmed == '1:1') {
      return trimmed;
    }
    return '9:16';
  }

  String get _storedMode => _flavor == _ShortDramaFlavor.animated
      ? 'animated.short_drama'
      : 'live_action.short_drama';

  Future<void> _save() async {
    if (!mounted) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _busy = true;
      _line = null;
    });
    try {
      await updateProjectByProjectId(widget.accessToken, widget.project.id, {
        'projectType': 'short_drama',
        'mode': _storedMode,
        'videoRatio': _videoRatio,
      });
      if (!mounted) return;
      setState(() {
        _line = l10n.projectEditorShortDramaTargetsSaveSuccess(
          _flavorLabel(l10n),
          _ratioLabel(l10n),
        );
      });
      final hook = widget.onSaved;
      if (hook != null) {
        await hook();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _line = l10n.projectEditorShortDramaTargetsSaveFailed(
            describeUserVisibleApiErrorResolved(context, e),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _flavorLabel(AppLocalizations l10n) =>
      _flavor == _ShortDramaFlavor.animated
      ? l10n.projectEditorShortDramaTargetsFlavorAnimated
      : l10n.projectEditorShortDramaTargetsFlavorLiveAction;

  String _ratioLabel(AppLocalizations l10n) {
    switch (_videoRatio) {
      case '16:9':
        return l10n.projectEditorShortDramaTargetsRatioLandscape169;
      case '1:1':
        return l10n.projectEditorShortDramaTargetsRatioSquare11;
      default:
        return l10n.projectEditorShortDramaTargetsRatioPortrait916;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.projectEditorShortDramaTargetsSectionTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.projectEditorShortDramaTargetsSectionBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.projectEditorShortDramaTargetsFlavorLabel,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          SegmentedButton<_ShortDramaFlavor>(
            segments: [
              ButtonSegment(
                value: _ShortDramaFlavor.animated,
                label: Text(l10n.projectEditorShortDramaTargetsFlavorAnimated),
              ),
              ButtonSegment(
                value: _ShortDramaFlavor.liveAction,
                label: Text(l10n.projectEditorShortDramaTargetsFlavorLiveAction),
              ),
            ],
            selected: {_flavor},
            onSelectionChanged: _busy
                ? null
                : (next) {
                    setState(() {
                      _flavor = next.first;
                      _line = null;
                    });
                  },
          ),
          const SizedBox(height: 12),
          Text(
            l10n.projectEditorShortDramaTargetsAspectLabel,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          StudioDropdownButtonFormField<String>(
            initialValue: _videoRatio,
            decoration: const InputDecoration(isDense: true),
            items: [
              DropdownMenuItem(
                value: '9:16',
                child: Text(l10n.projectEditorShortDramaTargetsRatioPortrait916),
              ),
              DropdownMenuItem(
                value: '16:9',
                child: Text(l10n.projectEditorShortDramaTargetsRatioLandscape169),
              ),
              DropdownMenuItem(
                value: '1:1',
                child: Text(l10n.projectEditorShortDramaTargetsRatioSquare11),
              ),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      _videoRatio = v;
                      _line = null;
                    });
                  },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                _busy
                    ? l10n.projectEditorShortDramaTargetsSaveBusy
                    : l10n.projectEditorShortDramaTargetsSaveButton,
              ),
            ),
          ),
          if (_line != null) ...[
            const SizedBox(height: 8),
            Text(_line!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
