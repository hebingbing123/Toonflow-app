import 'package:flutter/material.dart';

import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';

/// Inline single / batch storyboard creation (no nested dialogs).
class StoryboardShotIntakePanel extends StatefulWidget {
  const StoryboardShotIntakePanel({
    super.key,
    required this.accessToken,
    required this.projectUuid,
    required this.scriptNumericId,
    required this.onShotsChanged,
    this.compact = false,
  });

  final String accessToken;
  final String projectUuid;
  final int scriptNumericId;
  final Future<void> Function() onShotsChanged;
  final bool compact;

  @override
  State<StoryboardShotIntakePanel> createState() =>
      _StoryboardShotIntakePanelState();
}

enum _StoryboardIntakeMode { none, single, batch }

class _StoryboardShotIntakePanelState extends State<StoryboardShotIntakePanel> {
  _StoryboardIntakeMode _mode = _StoryboardIntakeMode.none;
  var _busy = false;
  final _singlePromptCtrl = TextEditingController();
  final _singleDurationCtrl = TextEditingController();
  final _batchPromptsCtrl = TextEditingController();
  final _batchDurationCtrl = TextEditingController();

  @override
  void dispose() {
    _singlePromptCtrl.dispose();
    _singleDurationCtrl.dispose();
    _batchPromptsCtrl.dispose();
    _batchDurationCtrl.dispose();
    super.dispose();
  }

  void _setMode(_StoryboardIntakeMode mode) {
    setState(() {
      _mode = _mode == mode ? _StoryboardIntakeMode.none : mode;
    });
  }

  int? _parseOptionalPositiveDuration(String raw, AppLocalizations l10n) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final duration = int.tryParse(trimmed);
    if (duration == null) {
      _snack(l10n.scriptEditorStoryboardDurationMustBeIntegerSnackBar);
      return null;
    }
    if (duration <= 0) {
      _snack(l10n.scriptEditorStoryboardDurationMustBePositiveSnackBar);
      return null;
    }
    return duration;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitSingle(AppLocalizations l10n) async {
    final prompt = _singlePromptCtrl.text.trim();
    if (prompt.isEmpty) {
      _snack(l10n.scriptEditorStoryboardAddPromptRequiredSnackBar);
      return;
    }
    final duration = _parseOptionalPositiveDuration(
      _singleDurationCtrl.text,
      l10n,
    );
    if (duration == null && _singleDurationCtrl.text.trim().isNotEmpty) {
      return;
    }

    setState(() => _busy = true);
    try {
      await postStoryboardAddV1(
        widget.accessToken,
        projectUuid: widget.projectUuid,
        scriptId: widget.scriptNumericId,
        prompt: prompt,
        duration: duration,
      );
      if (!mounted) return;
      _singlePromptCtrl.clear();
      _singleDurationCtrl.clear();
      setState(() => _mode = _StoryboardIntakeMode.none);
      await widget.onShotsChanged();
      if (!mounted) return;
      _snack(l10n.studioStoryboardIntakeAddedSnackBar);
    } catch (e) {
      if (!mounted) return;
      _snack(describeUserVisibleApiErrorResolved(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitBatch(AppLocalizations l10n) async {
    final prompts = _batchPromptsCtrl.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (prompts.isEmpty) {
      _snack(l10n.scriptEditorStoryboardBatchAddNeedOnePromptSnackBar);
      return;
    }
    final duration = _parseOptionalPositiveDuration(
      _batchDurationCtrl.text,
      l10n,
    );
    if (duration == null && _batchDurationCtrl.text.trim().isNotEmpty) {
      return;
    }

    final payload = prompts
        .map(
          (prompt) =>
              StoryboardBatchAddInfoItem(prompt: prompt, duration: duration),
        )
        .toList(growable: false);

    setState(() => _busy = true);
    try {
      final added = await postStoryboardBatchAddInfoV1(
        widget.accessToken,
        projectUuid: widget.projectUuid,
        scriptId: widget.scriptNumericId,
        storyboards: payload,
      );
      if (!mounted) return;
      _batchPromptsCtrl.clear();
      _batchDurationCtrl.clear();
      setState(() => _mode = _StoryboardIntakeMode.none);
      await widget.onShotsChanged();
      if (!mounted) return;
      _snack(
        l10n.scriptEditorStoryboardBatchAddFollowUpSummary(added.added),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(describeUserVisibleApiErrorResolved(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _modeChip({
    required String label,
    required _StoryboardIntakeMode mode,
    required IconData icon,
  }) {
    final selected = _mode == mode;
    return FilledButton.tonal(
      onPressed: _busy ? null : () => _setMode(mode),
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? StudioTokens.of(context).accent.withValues(alpha: 0.18)
            : null,
      ),
      child: Row(
        mainAxisSize: widget.compact ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: StudioSpacing.xs),
          Expanded(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _singlePromptCtrl,
          enabled: !_busy,
          minLines: widget.compact ? 2 : 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: l10n.scriptEditorStoryboardAddPromptLabel,
            helperText: l10n.scriptEditorStoryboardAddPromptHelper,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _singleDurationCtrl,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.scriptEditorStoryboardAddDurationOptionalLabel,
            helperText: l10n.scriptEditorStoryboardAddDurationOptionalHelper,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: StudioPrimaryButton(
            label: l10n.scriptEditorStoryboardAddConfirmButton,
            onPressed: _busy ? null : () => _submitSingle(l10n),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _batchPromptsCtrl,
          enabled: !_busy,
          minLines: widget.compact ? 4 : 6,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: l10n.scriptEditorStoryboardBatchAddPromptsLabel,
            helperText: l10n.scriptEditorStoryboardBatchAddPromptsHelper,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _batchDurationCtrl,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.scriptEditorStoryboardBatchAddUnifiedDurationLabel,
            helperText: l10n.scriptEditorStoryboardBatchAddUnifiedDurationHelper,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: StudioPrimaryButton(
            label: l10n.scriptEditorStoryboardBatchAddConfirmButton,
            onPressed: _busy ? null : () => _submitBatch(l10n),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final intro = widget.compact
        ? l10n.studioStoryboardIntakeIntroCompact
        : l10n.studioStoryboardIntakeIntro;

    return DecoratedBox(
      decoration: studioRecessedPanelDecoration(context),
      child: Padding(
        padding: EdgeInsets.all(
          widget.compact ? StudioSpacing.sm : StudioSpacing.sm + 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(intro, style: studioSectionIntroStyle(context)),
            const SizedBox(height: 12),
            if (widget.compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _modeChip(
                    label: l10n.scriptEditorStoryboardAddDialogTitle,
                    mode: _StoryboardIntakeMode.single,
                    icon: Icons.add_outlined,
                  ),
                  const SizedBox(height: 8),
                  _modeChip(
                    label: l10n.scriptEditorStoryboardBatchAddDialogTitle,
                    mode: _StoryboardIntakeMode.batch,
                    icon: Icons.playlist_add_outlined,
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _modeChip(
                    label: l10n.scriptEditorStoryboardAddDialogTitle,
                    mode: _StoryboardIntakeMode.single,
                    icon: Icons.add_outlined,
                  ),
                  _modeChip(
                    label: l10n.scriptEditorStoryboardBatchAddDialogTitle,
                    mode: _StoryboardIntakeMode.batch,
                    icon: Icons.playlist_add_outlined,
                  ),
                ],
              ),
            if (_mode == _StoryboardIntakeMode.single) ...<Widget>[
              const SizedBox(height: 12),
              _buildSingleForm(l10n),
            ],
            if (_mode == _StoryboardIntakeMode.batch) ...<Widget>[
              const SizedBox(height: 12),
              _buildBatchForm(l10n),
            ],
            if (_busy) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }
}
