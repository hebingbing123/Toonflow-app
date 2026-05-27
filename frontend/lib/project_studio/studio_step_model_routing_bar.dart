import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';

import '../design_system/components/studio_async_data_view.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../design_system/components/studio_model_picker.dart';
import '../design_system/components/studio_skeleton.dart';
import '../design_system/ix/studio_api_error_callout.dart';
import '../design_system/tokens.dart';
import '../design_system/studio_motion.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'project_studio_model_routing_scope.dart';
import 'studio_step.dart';
import 'studio_step_model_slots.dart';

/// Primary Studio surface: configure models for the **current step** (large card).
class StudioStepModelRoutingBar extends StatefulWidget {
  const StudioStepModelRoutingBar({
    super.key,
    required this.accessToken,
    required this.projectId,
    required this.step,
    this.onOpenProjectSettings,
    this.onOpenGlobalModelVendorSettings,
    this.onRoutingUpdated,
  });

  final String accessToken;
  final String projectId;
  final StudioStep step;
  final VoidCallback? onOpenProjectSettings;
  final VoidCallback? onOpenGlobalModelVendorSettings;
  final ValueChanged<ProjectModelRoutingResponse>? onRoutingUpdated;

  @override
  State<StudioStepModelRoutingBar> createState() =>
      _StudioStepModelRoutingBarState();
}

class _StudioStepModelRoutingBarState extends State<StudioStepModelRoutingBar> {
  bool _expanded = false;
  bool _loading = true;
  bool _saving = false;
  bool _hydratedFromScope = false;
  String? _error;
  ProjectModelRoutingResponse? _routing;
  final Map<String, List<ModelListEntry>> _catalogByFilter =
      <String, List<ModelListEntry>>{};
  final Map<String, String?> _draftBySlot = <String, String?>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydratedFromScope) {
      return;
    }
    _hydratedFromScope = true;
    _hydrateFromScope();
  }

  @override
  void didUpdateWidget(covariant StudioStepModelRoutingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step ||
        oldWidget.projectId != widget.projectId) {
      _expanded = false;
      _hydratedFromScope = false;
      _hydrateFromScope();
      _load();
    }
  }

  void _hydrateFromScope() {
    final cached = ProjectStudioModelRoutingScope.routingOf(context);
    if (cached != null) {
      _routing = cached;
      _seedDraftFromRouting(cached);
    }
  }

  void _seedDraftFromRouting(ProjectModelRoutingResponse routing) {
    _draftBySlot.clear();
    final stepSlug = widget.step.slug;
    for (final slot in widget.step.modelSlotKeys) {
      final fromStep = routing.steps[stepSlug]?[slot];
      final effective = routing.effectiveModelFor(step: stepSlug, slot: slot);
      _draftBySlot[slot] = fromStep ?? effective;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final routing = await fetchProjectModelRoutingV1(
        widget.accessToken,
        widget.projectId,
      );
      final filters = widget.step.modelSlotKeys
          .map(widget.step.typeFilterForSlot)
          .toSet();
      for (final filter in filters) {
        if (_catalogByFilter.containsKey(filter)) continue;
        _catalogByFilter[filter] = await fetchModelsCatalog(
          widget.accessToken,
          typeFilter: filter,
          includePricing: true,
        );
      }
      if (!mounted) return;
      setState(() {
        _routing = routing;
        _seedDraftFromRouting(routing);
        _loading = false;
      });
      widget.onRoutingUpdated?.call(routing);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = describeUserVisibleApiErrorResolved(context, e);
      });
    }
  }

  Future<void> _saveSlot(String slot, String? modelId) async {
    if (_routing == null || modelId == null || modelId.isEmpty) return;
    setState(() => _saving = true);
    try {
      final steps = Map<String, Map<String, String>>.from(
        _routing!.steps.map((k, v) => MapEntry(k, Map<String, String>.from(v))),
      );
      final stepMap = Map<String, String>.from(
        steps[widget.step.slug] ?? const <String, String>{},
      );
      stepMap[slot] = modelId;
      steps[widget.step.slug] = stepMap;

      final updated = await patchProjectModelRoutingV1(
        widget.accessToken,
        widget.projectId,
        steps: steps,
      );
      if (!mounted) return;
      setState(() {
        _routing = updated;
        _seedDraftFromRouting(updated);
        _saving = false;
      });
      widget.onRoutingUpdated?.call(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = describeUserVisibleApiErrorResolved(context, e);
      });
    }
  }

  List<ModelRoutingEffectiveEntry> _deliverInheritedEffective() {
    final routing = _routing;
    if (routing == null) return const <ModelRoutingEffectiveEntry>[];
    return routing.effective
        .where(
          (ModelRoutingEffectiveEntry e) => e.step == StudioStep.deliver.slug,
        )
        .toList();
  }

  List<ModelListEntry> _modelsForSlot(String slot) {
    return _catalogByFilter[widget.step.typeFilterForSlot(slot)] ??
        const <ModelListEntry>[];
  }

  String _slotLabel(AppLocalizations l10n, String slot) {
    return switch (slot) {
      'multimodal' => l10n.projectEditorBasicsMultimodalModelLabel,
      'image' => l10n.projectEditorBasicsImageModelLabel,
      'video' => l10n.projectEditorBasicsVideoModelLabel,
      'voice' => l10n.projectEditorBasicsVoiceModelLabel,
      _ => l10n.projectEditorBasicsTextModelLabel,
    };
  }

  String _sourceLabel(AppLocalizations l10n, String source) {
    return switch (source) {
      'step_override' => l10n.studioModelRoutingSourceStep,
      'modality_default' => l10n.studioModelRoutingSourceModality,
      'user_preferred_text' => l10n.studioModelRoutingSourceUser,
      'agent_deploy' => l10n.studioModelRoutingSourceLegacy,
      'catalog_default' => l10n.studioModelRoutingSourceCatalog,
      'request_override' => l10n.studioModelRoutingSourceOverride,
      _ => source,
    };
  }

  ModelRoutingEffectiveEntry? _effectiveEntry(String slot) {
    final routing = _routing;
    if (routing == null) return null;
    for (final e in routing.effective) {
      if (e.step == widget.step.slug && e.slot == slot) return e;
    }
    return null;
  }

  String? _displayNameForSlot(String slot) {
    final id = _draftBySlot[slot];
    if (id == null || id.isEmpty) return null;
    for (final m in _modelsForSlot(slot)) {
      if (m.effectiveModelId == id) return m.label;
    }
    return id;
  }

  String _collapsedSummary(AppLocalizations l10n, List<String> slots) {
    if (_loading) return l10n.studioModelRoutingCollapsedLoading;
    final parts = <String>[];
    for (final slot in slots) {
      final name = _displayNameForSlot(slot);
      if (name != null && name.isNotEmpty) {
        parts.add('${_slotLabel(l10n, slot)}: $name');
      }
    }
    if (parts.isEmpty) return l10n.studioModelRoutingCollapsedEmpty;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final slots = widget.step.modelSlotKeys;

    if (slots.isEmpty) {
      final inherited = _deliverInheritedEffective();
      return _secondaryShell(
        context,
        tokens,
        child: StudioAsyncDataView(
          loading: _loading,
          scrollableLoading: false,
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.alt_route_outlined,
                        size: StudioIconSize.xs,
                        color: StudioTokens.of(context).textSecondary,
                      ),
                      const SizedBox(width: StudioSpacing.xs),
                      Expanded(
                        child: Text(
                          l10n.studioModelRoutingDeliverInherit,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: StudioTokens.of(context).textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: StudioSpacing.xs),
                    StudioApiErrorCallout(
                      error: _error!,
                      onRetry: _load,
                      emphasis: StudioApiErrorCalloutEmphasis.subtle,
                    ),
                  ],
                  if (inherited.isNotEmpty) ...<Widget>[
                    const SizedBox(height: StudioSpacing.xs),
                    Wrap(
                      spacing: StudioSpacing.xs,
                      runSpacing: StudioSpacing.xs,
                      children: <Widget>[
                        for (final entry in inherited)
                          StudioChip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.padded,
                            label: Text(
                              '${_slotLabel(l10n, entry.slot)} · ${_sourceLabel(l10n, entry.source)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
        ),
      );
    }

    final catalogEmpty = !_loading &&
        slots.isNotEmpty &&
        slots.every((slot) => _modelsForSlot(slot).isEmpty);

    final expandedBody = StudioAsyncDataView(
      loading: _loading,
      scrollableLoading: false,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null) ...<Widget>[
                StudioApiErrorCallout(
                  error: _error!,
                  onRetry: _load,
                  emphasis: StudioApiErrorCalloutEmphasis.subtle,
                ),
                const SizedBox(height: StudioSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _load,
                    child: Text(l10n.studioScriptStepRetry),
                  ),
                ),
              ],
              if (catalogEmpty) ...<Widget>[
                _ModelCatalogEmptyCallout(
                  l10n: l10n,
                  tokens: tokens,
                  onOpenSettings: widget.onOpenGlobalModelVendorSettings,
                ),
                const SizedBox(height: StudioSpacing.sm),
              ],
              ...slots.toList().asMap().entries.map((entry) {
                final slot = entry.value;
                final models = _modelsForSlot(slot);
                final effective = _effectiveEntry(slot);
                final selected = _draftBySlot[slot];
                return studioStaggeredItem(
                  entry.key,
                  entranceKey: slots.length,
                  child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: StudioSpacing.radiusComfort,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _slotLabel(l10n, slot),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (effective != null)
                            StudioChip(
                              label: Text(
                                _sourceLabel(l10n, effective.source),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      StudioModelPicker(
                        models: models,
                        selectedModelId: selected,
                        enabled: !_saving && models.isNotEmpty,
                        onChanged: (id) {
                          if (id == null) return;
                          setState(() => _draftBySlot[slot] = id);
                          _saveSlot(slot, id);
                        },
                      ),
                    ],
                  ),
                ),
              );
              }),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(top: StudioSpacing.xs),
                  child: StudioSkeleton(height: 4, borderRadius: 2),
                ),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.studioModelRoutingPrimaryFootnote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: StudioTokens.of(context).textSecondary,
                ),
              ),
              if (widget.onOpenProjectSettings != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onOpenProjectSettings,
                    icon: const Icon(Icons.tune_outlined, size: StudioIconSize.sm),
                    label: Text(l10n.studioModelRoutingOpenAdvancedSettings),
                  ),
                ),
            ],
          ),
    );

    return _primaryShell(
      context,
      tokens,
      l10n: l10n,
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      collapsedSummary: _collapsedSummary(l10n, slots),
      child: expandedBody,
    );
  }

  Widget _primaryShell(
    BuildContext context,
    StudioTokens tokens, {
    required AppLocalizations l10n,
    required bool expanded,
    required VoidCallback onToggle,
    required String collapsedSummary,
    required Widget child,
  }) {
    return Material(
      color: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(StudioSpacing.radiusComfort, StudioSpacing.radiusComfort, StudioSpacing.xs, StudioSpacing.radiusComfort),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.hub_outlined, color: tokens.primary, size: StudioIconSize.md),
                  const SizedBox(width: StudioSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                l10n.studioModelRoutingPrimaryTitle,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              projectStudioStepShortLabel(l10n, widget.step),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: tokens.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: StudioSpacing.xs),
                        Text(
                          expanded
                              ? l10n.studioModelRoutingPrimarySubtitle
                              : collapsedSummary,
                          maxLines: expanded ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: StudioTokens.of(context).textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: StudioTokens.of(context).textSecondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(StudioSpacing.radiusComfort, 0, StudioSpacing.radiusComfort, StudioSpacing.radiusComfort),
              child: child,
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: studioAnimationDuration(
              context,
              const Duration(milliseconds: 180),
            ),
            sizeCurve: studioAnimationCurve(context, Curves.easeOut),
          ),
        ],
      ),
    );
  }

  Widget _secondaryShell(
    BuildContext context,
    StudioTokens tokens, {
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.insetDense, vertical: StudioLayoutSpacing.inlineGap),
      decoration: BoxDecoration(
        color: tokens.bgSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: child,
    );
  }
}

class _ModelCatalogEmptyCallout extends StatelessWidget {
  const _ModelCatalogEmptyCallout({
    required this.l10n,
    required this.tokens,
    this.onOpenSettings,
  });

  final AppLocalizations l10n;
  final StudioTokens tokens;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.studioModelRoutingCatalogEmptyTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.studioModelRoutingCatalogEmptyBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).textSecondary,
                height: 1.45,
              ),
            ),
            if (onOpenSettings != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined, size: StudioIconSize.sm),
                  label: Text(l10n.studioModelRoutingOpenVendorSettings),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String projectStudioStepShortLabel(AppLocalizations l10n, StudioStep step) {
  switch (step) {
    case StudioStep.script:
      return l10n.studioStepScriptShort;
    case StudioStep.art:
      return l10n.studioStepArtShort;
    case StudioStep.assets:
      return l10n.studioStepAssetsShort;
    case StudioStep.storyboard:
      return l10n.studioStepStoryboardShort;
    case StudioStep.video:
      return l10n.studioStepVideoShort;
    case StudioStep.deliver:
      return l10n.studioStepDeliverShort;
    case StudioStep.quality:
      return l10n.studioDeliverTabQuality;
  }
}
