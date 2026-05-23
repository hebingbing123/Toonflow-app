import 'package:flutter/material.dart';

import '../design_system/components/studio_model_picker.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../project_studio/studio_step.dart';
import '../project_studio/studio_step_model_routing_bar.dart';
import '../rust_api.dart';

/// **Primary** project-editor surface: configure all Studio steps at once.
class StepModelRoutingSection extends StatefulWidget {
  const StepModelRoutingSection({
    super.key,
    required this.accessToken,
    required this.projectId,
    required this.textModelOptions,
    required this.imageModelOptions,
    required this.videoModelOptions,
    required this.onStepsChanged,
  });

  final String accessToken;
  final String projectId;
  final List<ModelListEntry> textModelOptions;
  final List<ModelListEntry> imageModelOptions;
  final List<ModelListEntry> videoModelOptions;
  final ValueChanged<Map<String, Map<String, String>>> onStepsChanged;

  @override
  State<StepModelRoutingSection> createState() =>
      _StepModelRoutingSectionState();
}

class _StepModelRoutingSectionState extends State<StepModelRoutingSection> {
  bool _loading = true;
  final Map<String, Map<String, String>> _draft = <String, Map<String, String>>{};

  static const List<(StudioStep, List<String>)> _matrix =
      <(StudioStep, List<String>)>[
    (StudioStep.script, <String>['text']),
    (StudioStep.art, <String>['image']),
    (StudioStep.assets, <String>['image']),
    (StudioStep.storyboard, <String>['image', 'multimodal']),
    (StudioStep.video, <String>['text', 'multimodal', 'video']),
    (StudioStep.quality, <String>['text']),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final routing = await fetchProjectModelRoutingV1(
        widget.accessToken,
        widget.projectId,
      );
      if (!mounted) return;
      setState(() {
        _draft.clear();
        for (final (step, slots) in _matrix) {
          final stepSlug = step.slug;
          _draft[stepSlug] = <String, String>{};
          for (final slot in slots) {
            final v =
                routing.steps[stepSlug]?[slot] ??
                routing.effectiveModelFor(step: stepSlug, slot: slot);
            if (v != null && v.isNotEmpty) {
              _draft[stepSlug]![slot] = v;
            }
          }
        }
        _loading = false;
      });
      widget.onStepsChanged(_collect());
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, Map<String, String>> _collect() {
    final out = <String, Map<String, String>>{};
    for (final entry in _draft.entries) {
      final slots = Map<String, String>.from(entry.value)
        ..removeWhere((_, v) => v.trim().isEmpty);
      if (slots.isNotEmpty) out[entry.key] = slots;
    }
    return out;
  }

  List<ModelListEntry> _catalogForSlot(String slot) {
    return switch (slot) {
      'image' => widget.imageModelOptions,
      'video' => widget.videoModelOptions,
      _ => widget.textModelOptions,
    };
  }

  void _setSlot(String stepSlug, String slot, String? modelId) {
    setState(() {
      final map = Map<String, String>.from(_draft[stepSlug] ?? const {});
      if (modelId == null || modelId.isEmpty) {
        map.remove(slot);
      } else {
        map[slot] = modelId;
      }
      _draft[stepSlug] = map;
    });
    widget.onStepsChanged(_collect());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);

    if (_loading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        border: Border.all(color: tokens.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.projectEditorBasicsStepModelRoutingTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.projectEditorBasicsStepModelRoutingHelper,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: StudioSpacing.sm),
          ..._matrix.expand((row) {
            final step = row.$1;
            final slots = row.$2;
            return <Widget>[
              Text(
                projectStudioStepShortLabel(l10n, step),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (step == StudioStep.quality) ...<Widget>[
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.projectEditorModelRoutingQualityStepHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: StudioTokens.of(context).textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: StudioSpacing.xs),
              ...slots.map((slot) {
                final catalog = _catalogForSlot(slot);
                final selected = _draft[step.slug]?[slot];
                return Padding(
                  padding: const EdgeInsets.only(left: StudioSpacing.xs, bottom: StudioLayoutSpacing.inlineGap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _slotLabel(l10n, slot),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      StudioModelPicker(
                        models: catalog,
                        selectedModelId: selected,
                        onChanged: (id) => _setSlot(step.slug, slot, id),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ];
          }),
        ],
      ),
    );
  }

  String _slotLabel(AppLocalizations l10n, String slot) {
    return switch (slot) {
      'multimodal' => l10n.projectEditorBasicsMultimodalModelLabel,
      'image' => l10n.projectEditorBasicsImageModelLabel,
      'video' => l10n.projectEditorBasicsVideoModelLabel,
      _ => l10n.projectEditorBasicsTextModelLabel,
    };
  }
}
