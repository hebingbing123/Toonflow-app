import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/components/studio_async_data_view.dart';
import '../design_system/components/studio_loading_placeholders.dart';
import '../design_system/components/studio_toolbar_button.dart';
import '../design_system/ix/studio_scroll_behavior.dart';
import '../design_system/layout_breakpoints.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api/jobs/video_export.dart';
import '../short_video_space/components/preview_player.dart';
import '../short_video_space/short_video_aspect_ratio.dart';

enum StudioVideoFrameMode { firstFrame, lastFrame, storyboardBoard }

/// Step ⑤: frame mode selector (persisted per project) + optional preview pane.
class StudioVideoStepPanel extends StatefulWidget {
  const StudioVideoStepPanel({
    super.key,
    required this.projectNumericId,
    required this.onOpenProduction,
    this.embeddedChild,
    this.previewVideoUrl,
    this.accessToken,
    this.projectUuid,
    this.videoRatio = '9:16',
  });

  final int projectNumericId;
  final VoidCallback onOpenProduction;
  final Widget? embeddedChild;
  final String? previewVideoUrl;
  final String? accessToken;
  final String? projectUuid;
  final String videoRatio;

  @override
  State<StudioVideoStepPanel> createState() => _StudioVideoStepPanelState();
}

class _StudioVideoStepPanelState extends State<StudioVideoStepPanel> {
  StudioVideoFrameMode _mode = StudioVideoFrameMode.firstFrame;
  var _loaded = false;
  var _previewLoading = false;
  String? _fetchedPreviewUrl;

  String get _prefsKey => 'studio_video_frame_mode_${widget.projectNumericId}';

  @override
  void initState() {
    super.initState();
    _loadMode();
    _loadExportPreview();
  }

  @override
  void didUpdateWidget(covariant StudioVideoStepPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectUuid != widget.projectUuid ||
        oldWidget.accessToken != widget.accessToken ||
        oldWidget.previewVideoUrl != widget.previewVideoUrl) {
      _loadExportPreview();
    }
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (!mounted) return;
    setState(() {
      _mode = switch (raw) {
        'last' => StudioVideoFrameMode.lastFrame,
        'board' => StudioVideoFrameMode.storyboardBoard,
        _ => StudioVideoFrameMode.firstFrame,
      };
      _loaded = true;
    });
  }

  Future<void> _loadExportPreview() async {
    final explicit = (widget.previewVideoUrl ?? '').trim();
    if (explicit.isNotEmpty) {
      if (_fetchedPreviewUrl != null || _previewLoading) {
        setState(() {
          _fetchedPreviewUrl = null;
          _previewLoading = false;
        });
      }
      return;
    }
    final token = widget.accessToken?.trim();
    final projectUuid = widget.projectUuid?.trim();
    if (token == null || token.isEmpty || projectUuid == null || projectUuid.isEmpty) {
      if (mounted) {
        setState(() {
          _fetchedPreviewUrl = null;
          _previewLoading = false;
        });
      }
      return;
    }
    setState(() => _previewLoading = true);
    try {
      final url = await fetchLatestProjectVideoPreviewOutputUrl(
        token,
        projectUuid,
      );
      if (!mounted) return;
      setState(() {
        _fetchedPreviewUrl = url;
        _previewLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fetchedPreviewUrl = null;
        _previewLoading = false;
      });
    }
  }

  Future<void> _saveMode(StudioVideoFrameMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (mode) {
      StudioVideoFrameMode.lastFrame => 'last',
      StudioVideoFrameMode.storyboardBoard => 'board',
      StudioVideoFrameMode.firstFrame => 'first',
    };
    await prefs.setString(_prefsKey, raw);
    setState(() => _mode = mode);
  }

  String? get _effectivePreviewUrl {
    final explicit = (widget.previewVideoUrl ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return (_fetchedPreviewUrl ?? '').trim().isEmpty ? null : _fetchedPreviewUrl!.trim();
  }

  Widget _buildControls(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.studioVideoFrameModeTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: StudioSpacing.xs),
        SegmentedButton<StudioVideoFrameMode>(
          segments: <ButtonSegment<StudioVideoFrameMode>>[
            ButtonSegment(
              value: StudioVideoFrameMode.firstFrame,
              label: Text(l10n.studioVideoFrameFirst),
            ),
            ButtonSegment(
              value: StudioVideoFrameMode.lastFrame,
              label: Text(l10n.studioVideoFrameLast),
            ),
            ButtonSegment(
              value: StudioVideoFrameMode.storyboardBoard,
              label: Text(l10n.studioVideoFrameBoard),
            ),
          ],
          selected: <StudioVideoFrameMode>{_mode},
          onSelectionChanged: (s) => _saveMode(s.first),
        ),
        const SizedBox(height: StudioSpacing.sm),
        StudioToolbarButton(
          label: l10n.studioStepOpenProduction,
          onPressed: widget.onOpenProduction,
        ),
        const SizedBox(height: StudioSpacing.sm),
        if (widget.embeddedChild != null)
          Expanded(child: widget.embeddedChild!),
      ],
    );
  }

  Widget _buildPreviewColumn(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final url = _effectivePreviewUrl;
    if (_previewLoading) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(StudioSpacing.sm),
          child: AspectRatio(
            aspectRatio: shortVideoAspectRatioFromLabel(widget.videoRatio),
            child: const StudioMediaTileSkeleton(),
          ),
        ),
      );
    }
    if (url == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(StudioSpacing.sm),
          child: AspectRatio(
            aspectRatio: shortVideoAspectRatioFromLabel(widget.videoRatio),
            child: Center(
              child: Text(
                l10n.shortVideoPreviewPaneEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: PreviewPlayer(
          videoUrl: url,
          videoRatio: widget.videoRatio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudioAsyncDataView(
      loading: !_loaded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= kStudioTwoColumnMinWidth;
          final controls = _buildControls(context);
          final showPreviewColumn =
              wide &&
              ((widget.previewVideoUrl ?? '').trim().isNotEmpty ||
                  (widget.accessToken ?? '').trim().isNotEmpty &&
                      (widget.projectUuid ?? '').trim().isNotEmpty);

          if (!showPreviewColumn) {
            return controls;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: controls),
              const SizedBox(width: StudioSpacing.sm),
              Expanded(
                flex: 2,
                child: StudioScrollbar(
                  child: SingleChildScrollView(
                    child: _buildPreviewColumn(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
