part of 'version_comparison.dart';

/// 统计项组件
class _StatisticItem extends StatelessWidget {
  const _StatisticItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          value,
          style: studioStatHeroValueStyle(context, color),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          label,
          style: studioAccentBannerBodyStyle(
            context,
            StudioTokens.of(context).textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 差异列表项组件
class _DifferenceListItem extends StatelessWidget {
  const _DifferenceListItem({required this.difference});

  final ShotDifference difference;

  Color _getTypeColor(BuildContext context) {
    final tokens = StudioTokens.of(context);
    switch (difference.type) {
      case DifferenceType.added:
        return tokens.success;
      case DifferenceType.removed:
        return tokens.danger;
      case DifferenceType.modified:
        return tokens.warning;
      case DifferenceType.unchanged:
        return tokens.textMuted;
    }
  }

  IconData _getTypeIcon() {
    switch (difference.type) {
      case DifferenceType.added:
        return Icons.add_circle;
      case DifferenceType.removed:
        return Icons.remove_circle;
      case DifferenceType.modified:
        return Icons.edit;
      case DifferenceType.unchanged:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final typeColor = _getTypeColor(context);

    return StudioListRow(
      leading: Icon(_getTypeIcon(), color: typeColor),
      title: Row(
        children: [
          Text(
            l10n.shortVideoVersionComparisonShotTitle(difference.shotId),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: StudioSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs, vertical: StudioSpacing.radiusHairline),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
              border: Border.all(color: typeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              difference.localizedDescription(l10n),
              style: studioAccentBannerBodyStyle(context, typeColor).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle:
          difference.type == DifferenceType.modified &&
              difference.fieldName != null
          ? Padding(
              padding: const EdgeInsets.only(top: StudioSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                        ),
                        child: Text(
                          l10n.shortVideoVersionComparisonBadgeOld,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: StudioTypography.of(context).meta,
                            color: tokens.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: StudioSpacing.xs),
                      Expanded(
                        child: Text(
                          _formatVersionComparisonValue(
                            l10n,
                            difference.oldValue,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.danger,
                            decoration: TextDecoration.lineThrough,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                        ),
                        child: Text(
                          l10n.shortVideoVersionComparisonBadgeNew,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: StudioTypography.of(context).meta,
                            color: tokens.success,
                          ),
                        ),
                      ),
                      const SizedBox(width: StudioSpacing.xs),
                      Expanded(
                        child: Text(
                          _formatVersionComparisonValue(
                            l10n,
                            difference.newValue,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.success,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
