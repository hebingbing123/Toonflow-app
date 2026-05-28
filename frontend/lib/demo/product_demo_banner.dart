import 'package:flutter/material.dart';

import '../design_system/components/studio_dense_action_row.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import 'product_demo_tour.dart';

/// Sticky banner with per-step guidance while [ProductDemoMode] is active.
class ProductDemoModeBanner extends StatelessWidget {
  ProductDemoModeBanner({
    super.key,
    required this.onExit,
    ProductDemoTour? tour,
  }) : tour = tour ?? ProductDemoTour.instance;

  final VoidCallback onExit;
  final ProductDemoTour tour;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final title = tour.currentGuideTitle ?? l10n.productDemoModeBannerTitle;
    final body = tour.currentGuideBody ?? l10n.productDemoModeBannerBody;
    final stepCounter = tour.stepCount > 0
        ? l10n.productDemoGuideStepCounter(tour.stepIndex + 1, tour.stepCount)
        : null;
    return Material(
      color: tokens.warning.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.radiusComfort, StudioSpacing.sm, StudioSpacing.radiusComfort),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  tour.isAutoplaying && !tour.isAutoplayPaused
                      ? Icons.smart_display_outlined
                      : Icons.route_outlined,
                  color: tokens.warning,
                  size: StudioIconSize.xl,
                ),
                const SizedBox(width: StudioSpacing.radiusComfort),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              l10n.productDemoModeBannerTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (stepCounter != null)
                            Text(
                              stepCounter,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: tokens.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: StudioSpacing.chromeActionGap),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: StudioSpacing.radiusHairline),
                      Text(
                        body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onExit,
                  child: Text(l10n.productDemoModeExit),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.xs),
            StudioDenseActionRow(
              spacing: StudioSpacing.chromeActionGap,
              children: <Widget>[
                TextButton(
                  onPressed: tour.stepCount > 0
                      ? () => tour.goToPrevious()
                      : null,
                  child: Text(l10n.productDemoGuidePrevious),
                ),
                FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed: tour.stepCount > 0 ? () => tour.goToNext() : null,
                  child: Text(l10n.productDemoGuideNext),
                ),
                if (tour.isAutoplaying)
                  TextButton(
                    onPressed: tour.toggleAutoplayPaused,
                    child: Text(
                      tour.isAutoplayPaused
                          ? l10n.productDemoAutoplayResume
                          : l10n.productDemoAutoplayPause,
                    ),
                  )
                else
                  TextButton(
                    onPressed: tour.startAutoplay,
                    child: Text(l10n.productDemoGuideStartAutoplay),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
