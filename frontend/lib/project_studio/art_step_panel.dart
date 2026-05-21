import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../project_editor/style_pack_catalog.dart';
import '../project_editor/style_pack_picker_field.dart';
import '../rust_api.dart';

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
    required this.onOpenProjectSettings,
    this.catalogLoader,
    this.saver,
  });

  final String accessToken;
  final ProjectRow project;
  final ValueChanged<ProjectRow> onProjectUpdated;
  final VoidCallback onOpenProjectSettings;

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
    super.dispose();
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
      final loadCatalog =
          widget.catalogLoader ?? loadProjectStylePackCatalog;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.studioArtStepSaveSuccess)),
      );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final catalog = _catalog;

    return Align(
      key: const Key('studio_art_step_panel'),
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.palette_outlined, size: 36, color: tokens.primary),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 4),
                        Text(
                          l10n.studioArtStepEditSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_loadingCatalog)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_catalogError != null)
                _ErrorCard(
                  message: _catalogError!,
                  onRetry: _loadCatalog,
                  retryLabel: l10n.studioScriptStepRetry,
                )
              else if (catalog != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      StylePackPickerField(
                        label: l10n.projectEditorBasicsLabelArtStylePack,
                        options: catalog.artPacks,
                        selectedPath: _draftArtPack,
                        isArtPack: true,
                        enabled: !_saving,
                        onChanged: (value) =>
                            setState(() => _draftArtPack = value),
                      ),
                      const SizedBox(height: 16),
                      StylePackPickerField(
                        label: l10n.projectEditorBasicsLabelStoryStylePack,
                        options: catalog.storyPacks,
                        selectedPath: _draftStoryPack,
                        isArtPack: false,
                        enabled: !_saving,
                        onChanged: (value) =>
                            setState(() => _draftStoryPack = value),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        enabled: !_saving,
                        controller: _artStyleCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.studioArtStepArtStyleLabel,
                          helperText: l10n.studioArtStepLegacyArtStyleHelper,
                        ),
                        onChanged: (value) =>
                            setState(() => _draftArtStyle = value),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.studioArtStepApplyFootnote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SelectedPackSummary(
                  l10n: l10n,
                  artPack: findArtStylePackOption(catalog.artPacks, _draftArtPack),
                  storyPack: findStoryStylePackOption(
                    catalog.storyPacks,
                    _draftStoryPack,
                  ),
                  legacyArtStyle: _draftArtStyle.trim(),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    key: const Key('studio_art_step_save'),
                    onPressed: _saving || !_dirty || _loadingCatalog
                        ? null
                        : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _saving
                          ? l10n.projectEditorSavingEllipsis
                          : l10n.studioArtStepSaveButton,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _saving || !_dirty ? null : _resetDraft,
                    child: Text(l10n.studioArtStepResetButton),
                  ),
                  TextButton.icon(
                    onPressed: widget.onOpenProjectSettings,
                    icon: const Icon(Icons.tune_outlined, size: 18),
                    label: Text(l10n.studioArtStepOpenSettings),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(message),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onRetry, child: Text(retryLabel)),
            ),
          ],
        ),
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
        artPack != null ||
        storyPack != null ||
        legacyArtStyle.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 8),
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
  const _SummaryRow({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
            const SizedBox(height: 2),
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
