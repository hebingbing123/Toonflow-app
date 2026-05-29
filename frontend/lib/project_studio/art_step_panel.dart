import 'dart:async';

import 'package:flutter/material.dart';

import '../demo/product_demo_mode.dart';
import '../demo/studio_demo_data.dart';
import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_async_data_view.dart';
import '../design_system/components/studio_dense_action_row.dart';
import '../design_system/ix/studio_dirty_pop_guard.dart';
import '../design_system/ix/studio_form_keyboard.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../project_editor/style_pack_catalog.dart';
import '../project_editor/style_pack_picker_field.dart';
import '../rust_api.dart';
import 'art_step_brief_sheet.dart';
import 'art_step_checklist_actions.dart';
import 'art_step_readiness_card.dart';
import 'studio_snapshot_bus.dart';

/// Art-direction step: edit style packs, legacy art-style text, and save in place.
typedef StylePackCatalogLoader =
    Future<StylePackCatalog> Function(
      String accessToken,
      AppLocalizations l10n,
    );

/// Persists draft style packs and legacy art-style text (tests may inject a fake).
typedef ArtStepPanelSaver =
    Future<ProjectRow> Function({
      required String accessToken,
      required ProjectRow project,
      required String? artStylePack,
      required String? storyStylePack,
      required String artStyleText,
    });

class ProjectStudioArtStepPanel extends StatefulWidget {
  const ProjectStudioArtStepPanel({
    super.key,
    required this.accessToken,
    required this.project,
    required this.onProjectUpdated,
    this.onOpenBriefContext,
    this.onOpenFullProjectSettings,
    this.onNavigateToScriptStep,
    this.projectHome,
    this.catalogLoader,
    this.saver,
  });

  final String accessToken;
  final ProjectRow project;
  final ValueChanged<ProjectRow> onProjectUpdated;
  final VoidCallback? onOpenBriefContext;
  final VoidCallback? onOpenFullProjectSettings;
  final VoidCallback? onNavigateToScriptStep;
  final ProjectHome? projectHome;

  /// Overrides catalog HTTP for tests; production uses [loadProjectStylePackCatalog].
  @visibleForTesting
  final StylePackCatalogLoader? catalogLoader;

  /// Overrides PATCH calls for tests; production uses REST APIs in [_save].
  @visibleForTesting
  final ArtStepPanelSaver? saver;

  @override
  State<ProjectStudioArtStepPanel> createState() =>
      _ProjectStudioArtStepPanelState();
}

class _ProjectStudioArtStepPanelState extends State<ProjectStudioArtStepPanel> {
  bool _loadingCatalog = true;
  String? _catalogError;
  StylePackCatalog? _catalog;
  bool _catalogLoadStarted = false;

  late String? _draftArtPack;
  late String? _draftStoryPack;
  late String _draftArtStyle;
  late String? _savedArtPack;
  late String? _savedStoryPack;
  late String? _savedArtStyle;

  bool _saving = false;
  late final TextEditingController _artStyleCtrl;
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _styleFormKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _artStyleCtrl = TextEditingController();
    _seedFromProject(widget.project);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_catalogLoadStarted) {
      _catalogLoadStarted = true;
      _loadCatalog();
    }
  }

  @override
  void dispose() {
    _artStyleCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onChecklistItemTap(String key) {
    switch (key) {
      case ArtStepChecklistKey.brief:
      case ArtStepChecklistKey.brandBible:
        _openBriefContext(focusKey: key);
        return;
      case ArtStepChecklistKey.source:
        widget.onNavigateToScriptStep?.call();
        return;
      case ArtStepChecklistKey.styleBible:
        unawaited(_scrollToStyleForm());
        return;
    }
  }

  void _openBriefContext({String? focusKey}) {
    final override = widget.onOpenBriefContext;
    if (override != null) {
      override();
      return;
    }
    showArtStepBriefContextSheet(
      context: context,
      accessToken: widget.accessToken,
      project: widget.project,
      home: widget.projectHome,
      onOpenFullProjectSettings: widget.onOpenFullProjectSettings ?? () {},
      onNavigateToScriptStep: widget.onNavigateToScriptStep,
      onFocusStylePacks: _scrollToStyleForm,
      initialChecklistFocusKey: focusKey,
    );
  }

  Future<void> _scrollToStyleForm() async {
    final target = _styleFormKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  void didUpdateWidget(covariant ProjectStudioArtStepPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _seedFromProject(widget.project);
      _catalogLoadStarted = true;
      _loadCatalog();
    } else if (!_dirty &&
        (oldWidget.project.artStylePack != widget.project.artStylePack ||
            oldWidget.project.storyStylePack != widget.project.storyStylePack ||
            oldWidget.project.artStyle != widget.project.artStyle)) {
      _seedFromProject(widget.project);
    }
  }

  void _seedFromProject(ProjectRow project) {
    _draftArtPack = project.artStylePack;
    _draftStoryPack = project.storyStylePack;
    _draftArtStyle = project.artStyle?.trim() ?? '';
    _artStyleCtrl.text = _draftArtStyle;
    _savedArtPack = project.artStylePack;
    _savedStoryPack = project.storyStylePack;
    _savedArtStyle = project.artStyle;
  }

  bool get _dirty {
    final artStyleDraft = _draftArtStyle.trim();
    final artStyleSaved = (_savedArtStyle ?? '').trim();
    return !artStylePackPathsMatch(_draftArtPack, _savedArtPack) ||
        !storyStylePackPathsMatch(_draftStoryPack, _savedStoryPack) ||
        artStyleDraft != artStyleSaved;
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });
    try {
      final l10n = AppLocalizations.of(context)!;
      if (ProductDemoMode.instance.shouldSkipLiveApi) {
        final catalog = buildDemoStylePackCatalog(l10n);
        if (!mounted) return;
        setState(() {
          _catalog = catalog;
          _loadingCatalog = false;
          _draftArtPack = normalizeArtStylePackPath(_draftArtPack).isEmpty
              ? null
              : normalizeArtStylePackPath(_draftArtPack);
          _draftStoryPack = normalizeStoryStylePackPath(_draftStoryPack).isEmpty
              ? null
              : normalizeStoryStylePackPath(_draftStoryPack);
        });
        return;
      }
      final loadCatalog = widget.catalogLoader ?? loadProjectStylePackCatalog;
      final catalog = await loadCatalog(widget.accessToken, l10n);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadingCatalog = false;
        _draftArtPack = normalizeArtStylePackPath(_draftArtPack).isEmpty
            ? null
            : normalizeArtStylePackPath(_draftArtPack);
        _draftStoryPack = normalizeStoryStylePackPath(_draftStoryPack).isEmpty
            ? null
            : normalizeStoryStylePackPath(_draftStoryPack);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _catalogError = describeUserVisibleApiErrorResolved(context, e);
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      ProjectRow updated = widget.project;
      final artStyleText = _draftArtStyle.trim();

      final saver = widget.saver;
      if (saver != null) {
        updated = await saver(
          accessToken: widget.accessToken,
          project: widget.project,
          artStylePack: _draftArtPack,
          storyStylePack: _draftStoryPack,
          artStyleText: artStyleText,
        );
      } else {
        if (!artStylePackPathsMatch(_draftArtPack, _savedArtPack) ||
            !storyStylePackPathsMatch(_draftStoryPack, _savedStoryPack)) {
          updated = await patchProjectStyleConfigByProjectId(
            widget.accessToken,
            widget.project.id,
            artStylePack: _draftArtPack,
            storyStylePack: _draftStoryPack,
          );
        }

        if (artStyleText != (_savedArtStyle ?? '').trim()) {
          updated = await updateProjectByProjectId(
            widget.accessToken,
            widget.project.id,
            <String, dynamic>{
              'artStyle': artStyleText.isEmpty ? null : artStyleText,
            },
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _seedFromProject(updated);
        _saving = false;
      });
      widget.onProjectUpdated(updated);
      kStudioSnapshotBus.invalidate(
        StudioSnapshotInvalidation.projectOnboarding,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.studioArtStepSaveSuccess)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeUserVisibleApiErrorResolved(context, e)),
        ),
      );
    }
  }

  void _resetDraft() {
    setState(() => _seedFromProject(widget.project));
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showStudioConfirmDialog(
      context: context,
      title: 'Discard changes?',
      message: 'You have unsaved art direction changes. Leave anyway?',
      confirmLabel: 'Discard',
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      destructive: true,
      barrierDismissible: false,
    );
    return discard == true;
  }

  Widget? _buildReadinessCard(AppLocalizations l10n) {
    final home = widget.projectHome;
    if (home == null) return null;
    return ArtStepReadinessCard(
      home: home,
      l10n: l10n,
      onChecklistItemTap: _onChecklistItemTap,
    );
  }

  Widget _buildStyleForm(
    AppLocalizations l10n,
    ThemeData theme,
    StudioTokens tokens,
    StylePackCatalog catalog,
  ) {
    return Container(
      key: _styleFormKey,
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: StudioFormKeyboardScope(
        onEnterSubmit: _saving ? null : _save,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StylePackPickerField(
            label: l10n.projectEditorBasicsLabelArtStylePack,
            options: catalog.artPacks,
            selectedPath: _draftArtPack,
            isArtPack: true,
            enabled: !_saving,
            onChanged: (value) => setState(() => _draftArtPack = value),
          ),
          const SizedBox(height: StudioSpacing.sm),
          StylePackPickerField(
            label: l10n.projectEditorBasicsLabelStoryStylePack,
            options: catalog.storyPacks,
            selectedPath: _draftStoryPack,
            isArtPack: false,
            enabled: !_saving,
            onChanged: (value) => setState(() => _draftStoryPack = value),
          ),
          const SizedBox(height: StudioSpacing.sm),
          TextField(
            enabled: !_saving,
            controller: _artStyleCtrl,
            decoration: InputDecoration(
              labelText: l10n.studioArtStepArtStyleLabel,
              helperText: l10n.studioArtStepLegacyArtStyleHelper,
            ),
            onChanged: (value) => setState(() => _draftArtStyle = value),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.studioArtStepApplyFootnote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final catalog = _catalog;

    return StudioDirtyPopGuard(
      isDirty: _dirty,
      popBlocked: _saving,
      onConfirmDiscard: _confirmDiscard,
      child: LayoutBuilder(
        key: const Key('studio_art_step_panel'),
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final maxWidth = wide ? 1040.0 : 720.0;

          final Widget catalogChild;
          if (catalog != null) {
            final summary = _SelectedPackSummary(
              l10n: l10n,
              artPack: findArtStylePackOption(catalog.artPacks, _draftArtPack),
              storyPack: findStoryStylePackOption(
                catalog.storyPacks,
                _draftStoryPack,
              ),
              legacyArtStyle: _draftArtStyle.trim(),
            );
            final form = _buildStyleForm(l10n, theme, tokens, catalog);
            catalogChild = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 3, child: form),
                      const SizedBox(width: StudioSpacing.sm),
                      Expanded(flex: 2, child: summary),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      form,
                      const SizedBox(height: StudioSpacing.sm),
                      summary,
                    ],
                  );
          } else {
            catalogChild = const SizedBox.shrink();
          }
          final catalogBody = StudioAsyncDataView(
            loading: _loadingCatalog,
            error: _catalogError,
            onRetry: _loadCatalog,
            child: catalogChild,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                  StudioSpacing.sm,
                  StudioSpacing.md,
                  StudioSpacing.sm,
                  StudioSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.palette_outlined,
                          size: 36,
                          color: tokens.primary,
                        ),
                        const SizedBox(width: StudioSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                l10n.studioStepArtTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: StudioSpacing.xs),
                              Text(
                                l10n.studioArtStepEditSubtitle,
                                maxLines: wide ? 3 : 4,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: StudioSpacing.sm),
                    if (_buildReadinessCard(l10n) case final card?) ...<Widget>[
                      card,
                      const SizedBox(height: StudioSpacing.sm),
                    ],
                    catalogBody,
                    const SizedBox(height: StudioSpacing.sm),
                    StudioDenseActionRow(
                      children: <Widget>[
                        FilledButton.icon(
                          key: const Key('studio_art_step_save'),
                          style: studioFormIconLabeledButtonStyle(context),
                          onPressed: _saving || !_dirty || _loadingCatalog
                              ? null
                              : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.save_outlined,
                                  size: StudioIconSize.sm,
                                ),
                          label: Text(
                            _saving
                                ? l10n.projectEditorSavingEllipsis
                                : l10n.studioArtStepSaveButton,
                          ),
                        ),
                        OutlinedButton(
                          style: studioFormSecondaryButtonStyle(context),
                          onPressed: _saving || !_dirty ? null : _resetDraft,
                          child: Text(l10n.studioArtStepResetButton),
                        ),
                        TextButton.icon(
                          style: studioFormTextButtonIconStyle(context),
                          onPressed: _openBriefContext,
                          icon: const Icon(
                            Icons.article_outlined,
                            size: StudioIconSize.sm,
                          ),
                          label: Text(l10n.studioArtStepOpenSettings),
                        ),
                        if (widget.onOpenFullProjectSettings != null)
                          TextButton(
                            style: studioFormButtonStyle(context),
                            onPressed: widget.onOpenFullProjectSettings,
                            child: Text(l10n.studioArtStepOpenFullSettings),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectedPackSummary extends StatelessWidget {
  const _SelectedPackSummary({
    required this.l10n,
    required this.artPack,
    required this.storyPack,
    required this.legacyArtStyle,
  });

  final AppLocalizations l10n;
  final StylePackOption? artPack;
  final StylePackOption? storyPack;
  final String legacyArtStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final hasAny =
        artPack != null || storyPack != null || legacyArtStyle.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(StudioLayoutSpacing.stackMedium),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.studioArtStepSummaryTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          if (!hasAny)
            Text(
              l10n.studioArtStepNoStylePacks,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            )
          else ...<Widget>[
            if (artPack != null)
              _SummaryRow(
                label: l10n.projectEditorBasicsLabelArtStylePack,
                value: artPack!.name,
                detail: artPack!.description,
              ),
            if (storyPack != null)
              _SummaryRow(
                label: l10n.projectEditorBasicsLabelStoryStylePack,
                value: storyPack!.name,
                detail: storyPack!.description,
              ),
            if (legacyArtStyle.isNotEmpty)
              _SummaryRow(
                label: l10n.studioArtStepArtStyleLabel,
                value: legacyArtStyle,
              ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudioSpacing.xs),
            Text(
              detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
