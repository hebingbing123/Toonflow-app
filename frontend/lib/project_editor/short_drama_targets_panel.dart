import 'package:flutter/material.dart';

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
        _line = '已写回短剧参数：${_flavorLabel()} · ${_ratioLabel()}';
      });
      final hook = widget.onSaved;
      if (hook != null) {
        await hook();
      }
    } on RustApiException catch (e) {
      if (mounted) {
        setState(() {
          _line = '保存失败：${e.statusCode ?? '-'}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _line = '保存失败：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _flavorLabel() =>
      _flavor == _ShortDramaFlavor.animated ? '动漫短剧' : '真人短剧';

  String _ratioLabel() {
    switch (_videoRatio) {
      case '16:9':
        return '横屏 16:9';
      case '1:1':
        return '方形 1:1';
      default:
        return '竖屏 9:16';
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text('短视频编排', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '与短视频 Space 相同的项目级写回（PATCH …/projects），在此可从项目对话框直接调整。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Text('短剧形态', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<_ShortDramaFlavor>(
            segments: const [
              ButtonSegment(
                value: _ShortDramaFlavor.animated,
                label: Text('动漫短剧'),
              ),
              ButtonSegment(
                value: _ShortDramaFlavor.liveAction,
                label: Text('真人短剧'),
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
          Text('画幅', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _videoRatio,
            decoration: const InputDecoration(isDense: true),
            items: const [
              DropdownMenuItem(value: '9:16', child: Text('竖屏 9:16')),
              DropdownMenuItem(value: '16:9', child: Text('横屏 16:9')),
              DropdownMenuItem(value: '1:1', child: Text('方形 1:1')),
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
              label: Text(_busy ? '写回中…' : '写回短剧参数'),
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
