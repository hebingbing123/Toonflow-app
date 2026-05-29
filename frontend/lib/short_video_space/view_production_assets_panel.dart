part of 'view.dart';

class _ProductionAssetsOverviewSection extends StatelessWidget {
  const _ProductionAssetsOverviewSection({
    required this.dense,
    required this.ui,
  });

  final bool dense;
  final ShortVideoAssetsOverviewPanelUi ui;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final sectionSpacing =
        dense ? StudioSpacing.radiusComfort : StudioLayoutSpacing.cardInner;
    if (!ui.visible) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: sectionSpacing),
        _Panel(
          dense: dense,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shortVideoSpaceAssetsOverview,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: StudioSpacing.xs),
              _ShortVideoPanelFetchBody(
                loading: ui.loading,
                unavailable: ui.unavailable,
                statusLine: ui.headline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ui.headline,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    if (ui.typeLines.isNotEmpty) ...[
                      const SizedBox(height: StudioSpacing.radiusComfort),
                      for (final line in ui.typeLines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: StudioIconSize.xs,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: StudioSpacing.xs),
                              Expanded(
                                child: Text(
                                  line,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                ui.detail,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
