import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/components/studio_primary_button.dart';
import '../l10n/app_localizations.dart';

enum StudioVideoFrameMode { firstFrame, lastFrame, storyboardBoard }

/// Step ⑤: frame mode selector (persisted per project).
class StudioVideoStepPanel extends StatefulWidget {
  const StudioVideoStepPanel({
    super.key,
    required this.projectNumericId,
    required this.onOpenProduction,
    this.embeddedChild,
  });

  final int projectNumericId;
  final VoidCallback onOpenProduction;
  final Widget? embeddedChild;

  @override
  State<StudioVideoStepPanel> createState() => _StudioVideoStepPanelState();
}

class _StudioVideoStepPanelState extends State<StudioVideoStepPanel> {
  StudioVideoFrameMode _mode = StudioVideoFrameMode.firstFrame;
  var _loaded = false;

  String get _prefsKey => 'studio_video_frame_mode_${widget.projectNumericId}';

  @override
  void initState() {
    super.initState();
    _loadMode();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.studioVideoFrameModeTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
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
        const SizedBox(height: 12),
        StudioPrimaryButton(
          label: l10n.studioStepOpenProduction,
          onPressed: widget.onOpenProduction,
        ),
        const SizedBox(height: 16),
        if (widget.embeddedChild != null)
          Expanded(child: widget.embeddedChild!),
      ],
    );
  }
}
