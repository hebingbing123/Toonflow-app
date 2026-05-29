part of 'view.dart';

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child, this.dense = false});

  final Widget child;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Container(
      padding: EdgeInsets.all(
        dense ? StudioSpacing.radiusComfort : StudioLayoutSpacing.cardInner,
      ),
      decoration: BoxDecoration(
        color: tokens.bgSurface.withValues(alpha: 0.96),
        border: Border.all(color: tokens.borderSubtle),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
      ),
      child: child,
    );
  }
}

/// Loading / unavailable / loaded body for short-video data panels.
class _ShortVideoPanelFetchBody extends StatelessWidget {
  const _ShortVideoPanelFetchBody({
    required this.loading,
    required this.unavailable,
    this.statusLine,
    this.onRetry,
    required this.child,
  });

  final bool loading;
  final bool unavailable;
  final String? statusLine;
  final VoidCallback? onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const StudioPaneLoadingSkeleton();
    }
    if (unavailable) {
      final line = (statusLine ?? '').trim();
      if (line.isEmpty) {
        return const SizedBox.shrink();
      }
      if (onRetry != null) {
        return StudioApiErrorCallout(
          error: line,
          onRetry: onRetry,
          emphasis: StudioApiErrorCalloutEmphasis.subtle,
        );
      }
      return Text(
        line,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: studioPanelMutedColor(context),
        ),
      );
    }
    return child;
  }
}

Future<void> Function()? shortVideoDebouncedVoid(
  bool blocked,
  VoidCallback? action,
) {
  if (blocked || action == null) {
    return null;
  }
  return () async => action();
}

class _ModeSegmentedButton extends StatelessWidget {
  const _ModeSegmentedButton({required this.mode, required this.onChanged});

  final ShortVideoMode mode;
  final ValueChanged<ShortVideoMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<ShortVideoMode>(
        segments: [
          ButtonSegment(
            value: ShortVideoMode.animated,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.shortVideoSpaceModeTitleAnimated),
          ),
          ButtonSegment(
            value: ShortVideoMode.liveAction,
            icon: const Icon(Icons.person_outline),
            label: Text(l10n.shortVideoSpaceModeTitleLive),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) {
          if (selection.isEmpty) {
            return;
          }
          onChanged(selection.first);
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.xs,
        vertical: StudioSpacing.chromeActionGap,
      ),
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.72),
        border: Border.all(color: tokens.borderSubtle),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
      ),
      child: StudioMetricSwitch(
        transitionKey: value,
        child: Text(
          resolveAppLocalizationsForErrors(
            context,
          ).shortVideoMetricChipLine(label, value),
          style: studioMetricTextStyle(context)?.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _WritebackStatusChip extends StatelessWidget {
  const _WritebackStatusChip({
    required this.line,
    required this.indicatesProblem,
  });

  final String line;
  final bool indicatesProblem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incomplete = indicatesProblem;
    final color = incomplete
        ? theme.colorScheme.errorContainer
        : StudioTokens.of(context).accentSoft;
    final onColor = incomplete
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.xs,
        vertical: StudioSpacing.chromeActionGap,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            incomplete ? Icons.sync_problem : Icons.check_circle_outline,
            size: StudioIconSize.xxs,
            color: onColor,
          ),
          const SizedBox(width: StudioSpacing.xs),
          Flexible(
            child: Text(
              line,
              style: theme.textTheme.labelSmall?.copyWith(color: onColor),
            ),
          ),
        ],
      ),
    );
  }
}
