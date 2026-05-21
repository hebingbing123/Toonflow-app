import 'package:flutter/material.dart';

import '../design_system/layout_breakpoints.dart';
import '../design_system/theme.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../shell/navigation_controller.dart';
import '../shell/pipeline_step_chip.dart';

/// Refined production pipeline stepper for the product shell.
class StudioPipelineStrip extends StatefulWidget {
  const StudioPipelineStrip({
    super.key,
    required this.selectedPane,
    required this.onSelectPane,
    required this.jobsPaneEnabled,
    required this.qualityPaneEnabled,
    this.compact = false,
  });

  final ProductWorkspacePane selectedPane;
  final void Function(ProductWorkspacePane pane) onSelectPane;
  final bool jobsPaneEnabled;
  final bool qualityPaneEnabled;
  final bool compact;

  @override
  State<StudioPipelineStrip> createState() => _StudioPipelineStripState();
}

class _StudioPipelineStripState extends State<StudioPipelineStrip> {
  final GlobalKey _selectedChipKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _queueEnsureSelectedChipVisible();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _queueEnsureSelectedChipVisible();
  }

  @override
  void didUpdateWidget(covariant StudioPipelineStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPane != widget.selectedPane ||
        oldWidget.jobsPaneEnabled != widget.jobsPaneEnabled ||
        oldWidget.qualityPaneEnabled != widget.qualityPaneEnabled ||
        oldWidget.compact != widget.compact) {
      _queueEnsureSelectedChipVisible();
    }
  }

  void _queueEnsureSelectedChipVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedContext = _selectedChipKey.currentContext;
      if (selectedContext == null) return;
      Scrollable.ensureVisible(
        selectedContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final studio = StudioColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildStrip(context, tokens, studio, l10n, constraints.maxWidth);
      },
    );
  }

  Widget _buildStrip(
    BuildContext context,
    StudioTokens tokens,
    StudioColors studio,
    AppLocalizations l10n,
    double width,
  ) {
    final narrow = width < 520;
    final inline = width >= kStudioPipelineInlineMinWidth;
    final denseChips = narrow || widget.compact;
    final steps = <(ProductWorkspacePane, String, IconData)>[
      (
        ProductWorkspacePane.projects,
        l10n.productPipelineStripProjects,
        Icons.folder_special_outlined,
      ),
      (
        ProductWorkspacePane.scriptWorkspace,
        l10n.productPipelineStripScripts,
        Icons.menu_book_outlined,
      ),
      (
        ProductWorkspacePane.productionWorkspace,
        l10n.productPipelineStripProduction,
        Icons.theaters_outlined,
      ),
      (
        ProductWorkspacePane.tasks,
        l10n.productPipelineStripTasks,
        Icons.task_alt_outlined,
      ),
      if (widget.jobsPaneEnabled)
        (
          ProductWorkspacePane.jobs,
          l10n.productPipelineStripJobs,
          Icons.cloud_queue_outlined,
        ),
      if (widget.qualityPaneEnabled)
        (
          ProductWorkspacePane.quality,
          l10n.productPipelineStripQuality,
          Icons.verified_outlined,
        ),
      (
        ProductWorkspacePane.shortVideoSpace,
        l10n.productPipelineStripShortVideo,
        Icons.ios_share_outlined,
      ),
    ];
    final stepChips = <Widget>[
      for (final step in steps)
        KeyedSubtree(
          key: step.$1 == widget.selectedPane ? _selectedChipKey : null,
          child: PipelineStepChip(
            useStudioTokens: true,
            compact: denseChips,
            label: step.$2,
            icon: step.$3,
            selected: widget.selectedPane == step.$1,
            onSelected: (_) => widget.onSelectPane(step.$1),
          ),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          inline ? StudioSpacing.xs + 4 : StudioSpacing.xs + 2,
          inline ? StudioSpacing.xs : StudioSpacing.xs + 2,
          inline ? StudioSpacing.xs + 4 : StudioSpacing.xs + 2,
          inline ? StudioSpacing.xs : StudioSpacing.xs + 2,
        ),
        child: inline
            ? _buildInlineHeader(context, tokens, studio, l10n, stepChips)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildTitleBadge(context, tokens, studio, l10n),
                  SizedBox(height: narrow ? StudioSpacing.xs + 2 : StudioSpacing.xs + 4),
                  _buildStepChipsRail(
                    context,
                    tokens,
                    stepChips,
                    framed: true,
                    gap: StudioSpacing.xs,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInlineHeader(
    BuildContext context,
    StudioTokens tokens,
    StudioColors studio,
    AppLocalizations l10n,
    List<Widget> stepChips,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildTitleBadge(context, tokens, studio, l10n),
        const SizedBox(width: StudioSpacing.xs + 4),
        Flexible(
          child: _buildStepChipsRail(
            context,
            tokens,
            stepChips,
            framed: false,
            gap: StudioSpacing.xs - 3,
          ),
        ),
      ],
    );
  }

  Widget _buildStepChipsRail(
    BuildContext context,
    StudioTokens tokens,
    List<Widget> stepChips, {
    required bool framed,
    required double gap,
  }) {
    final scroll = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < stepChips.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == stepChips.length - 1 ? 0 : gap),
              child: stepChips[i],
            ),
        ],
      ),
    );
    if (!framed) return scroll;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.xs - 2,
          vertical: StudioSpacing.xs - 3,
        ),
        child: scroll,
      ),
    );
  }

  Widget _buildTitleBadge(
    BuildContext context,
    StudioTokens tokens,
    StudioColors studio,
    AppLocalizations l10n,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.xs + 1,
          vertical: StudioSpacing.xs / 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.hub_outlined, size: 14, color: tokens.textMuted),
            const SizedBox(width: StudioSpacing.xs - 2),
            Text(
              l10n.productPipelineStripTitle,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
