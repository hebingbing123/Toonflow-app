import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/tokens.dart';
import '../design_system/components/studio_surfaces.dart';
import '../l10n/app_localizations.dart';
import 'product_demo_coach_keys.dart';
import 'product_demo_coach_theme.dart';
import 'product_demo_mode.dart';
import 'product_demo_tour.dart';
import 'product_demo_tour_anchors.dart';
import 'product_demo_tour_guide.dart';

/// Visual treatment for a demo coach step (spotlight vs floating card, etc.).
enum ProductDemoCoachStyle {
  spotlight,
  calloutAbove,
  calloutBeside,
  floatingCard,
  edgeHint,
}

/// Full-screen coach layer: floating card + optional target ring (no dim scrim).
class ProductDemoCoachOverlay extends StatefulWidget {
  ProductDemoCoachOverlay({
    super.key,
    required this.onExit,
    this.goRouter,
    ProductDemoTour? tour,
  }) : tour = tour ?? ProductDemoTour.instance;

  final VoidCallback onExit;
  final GoRouter? goRouter;
  final ProductDemoTour tour;

  @override
  State<ProductDemoCoachOverlay> createState() => _ProductDemoCoachOverlayState();
}

class _ProductDemoCoachOverlayState extends State<ProductDemoCoachOverlay> {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    widget.tour.addListener(_onTourChanged);
    _scheduleMeasure();
  }

  @override
  void dispose() {
    widget.tour.removeListener(_onTourChanged);
    super.dispose();
  }

  void _onTourChanged() {
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    ProductDemoTourAnchors.instance.scheduleRemeasure(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _targetRect = ProductDemoTourAnchors.instance.rectOnScreen(
          widget.tour.currentStop?.anchorId,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ProductDemoMode.instance.isActive) {
      return const SizedBox.shrink();
    }
    final stop = widget.tour.currentStop;
    if (stop == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final style = stop.coachStyle;
    final media = MediaQuery.of(context);
    final screen = Offset.zero & media.size;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: SizedBox.expand(),
          ),
        ),
        if (_targetRect != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DemoTargetRingPainter(
                  targetRect: _targetRect!,
                  color: tokens.primary,
                ),
              ),
            ),
          ),
        _CoachCalloutCard(
          tour: widget.tour,
          goRouter: widget.goRouter,
          l10n: l10n,
          tokens: tokens,
          style: style,
          targetRect: _targetRect,
          screen: screen,
          onExit: widget.onExit,
        ),
        Positioned(
          top: media.padding.top + 8,
          right: 12,
          child: _DemoModePill(
            l10n: l10n,
            tokens: tokens,
            onExit: widget.onExit,
          ),
        ),
      ],
    );
  }
}

/// Soft ring around the anchored control — no fullscreen dim.
class _DemoTargetRingPainter extends CustomPainter {
  _DemoTargetRingPainter({
    required this.targetRect,
    required this.color,
  });

  final Rect targetRect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      targetRect.inflate(6),
      const Radius.circular(10),
    );
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _DemoTargetRingPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.color != color;
  }
}

class _CoachCalloutCard extends StatelessWidget {
  const _CoachCalloutCard({
    required this.tour,
    this.goRouter,
    required this.l10n,
    required this.tokens,
    required this.style,
    required this.targetRect,
    required this.screen,
    required this.onExit,
  });

  final ProductDemoTour tour;
  final GoRouter? goRouter;
  final AppLocalizations l10n;
  final StudioTokens tokens;
  final ProductDemoCoachStyle style;
  final Rect? targetRect;
  final Rect screen;
  final VoidCallback onExit;

  static const double _cardMaxWidth = 360;
  static const double _cardBodyMaxHeight = 188;
  static const double _margin = 16;
  static const double _dockBottom = 16;

  double _cardWidth() {
    return _cardMaxWidth.clamp(260.0, screen.width - _margin * 2);
  }

  @override
  Widget build(BuildContext context) {
    final stop = tour.currentStop;
    final title = tour.currentGuideTitle ?? l10n.productDemoModeBannerTitle;
    final body = tour.currentGuideBody ?? l10n.productDemoModeBannerBody;
    final counter = tour.stepCount > 0
        ? l10n.productDemoGuideStepCounter(tour.stepIndex + 1, tour.stepCount)
        : null;

    final width = _cardWidth();
    final bottom = _dockBottom + MediaQuery.paddingOf(context).bottom;

    final card = Semantics(
      label: 'product-demo-coach-overlay',
      container: true,
      explicitChildNodes: true,
      child: Material(
        color: StudioPrimitives.transparent,
        child: _CalloutBody(
          tokens: tokens,
          title: title,
          body: body,
          counter: counter,
          stop: stop,
          languageCode: tour.languageCode,
          tour: tour,
          goRouter: goRouter,
          l10n: l10n,
        ),
      ),
    );

    return Positioned(
      right: _margin,
      bottom: bottom,
      width: width,
      child: card,
    );
  }
}

class _CalloutBody extends StatefulWidget {
  const _CalloutBody({
    required this.tokens,
    required this.title,
    required this.body,
    required this.counter,
    required this.stop,
    required this.languageCode,
    required this.tour,
    this.goRouter,
    required this.l10n,
  });

  final StudioTokens tokens;
  final String title;
  final String body;
  final String? counter;
  final ProductDemoTourStop? stop;
  final String languageCode;
  final ProductDemoTour tour;
  final GoRouter? goRouter;
  final AppLocalizations l10n;

  @override
  State<_CalloutBody> createState() => _CalloutBodyState();
}

class _CalloutBodyState extends State<_CalloutBody> {
  bool _detailsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final title = widget.title;
    final body = widget.body;
    final counter = widget.counter;
    final stop = widget.stop;
    final languageCode = widget.languageCode;
    final tour = widget.tour;
    final goRouter = widget.goRouter;
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final coachTheme = ProductDemoCoachTheme.of(
      tokens,
      isOptionalUtility: stop?.isOptionalUtility == true,
    );
    final accent = coachTheme.accent;

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: tokens.textPrimary,
    );
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      height: 1.45,
      color: tokens.textSecondary,
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: tokens.textPrimary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    final counterStyle = theme.textTheme.labelSmall?.copyWith(
      color: tokens.textMuted,
      fontWeight: FontWeight.w500,
    );

    final sections = stop?.sections;
    final badgeLabels = <String>[];
    final mainlineStep = stop?.mainlineStep;
    final launchPart = stop?.launchPart;
    final launchPartTotal = stop?.launchPartTotal;
    if (mainlineStep != null) {
      badgeLabels.add(l10n.productDemoGuideMainlineCounter(mainlineStep, 6));
    } else if (launchPart != null && launchPartTotal != null) {
      badgeLabels.add(
        l10n.productDemoGuideLaunchCounter(launchPart, launchPartTotal),
      );
    }
    if (stop?.isOptionalUtility == true) {
      badgeLabels.add(l10n.productDemoGuideOptionalTag);
    }

    final radius = BorderRadius.circular(StudioSpacing.radiusCard);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.bgElevated.withValues(alpha: 0.28),
            borderRadius: radius,
            border: Border.all(
              color: tokens.borderDefault.withValues(alpha: 0.38),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: studioShadowColor(context, alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
            Container(
              height: 3,
              color: accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                StudioSpacing.radiusComfort,
                StudioSpacing.radiusComfort,
                StudioSpacing.radiusComfort,
                StudioSpacing.radiusComfort,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.route_outlined,
                        size: StudioIconSize.sm,
                        color: accent,
                      ),
                      const SizedBox(width: StudioSpacing.xs),
                      Expanded(
                        child: Text(title, style: titleStyle),
                      ),
                      if (counter != null)
                        Padding(
                          padding: const EdgeInsets.only(left: StudioSpacing.xs),
                          child: Semantics(
                            label: 'Demo tour step counter $counter',
                            child: Text(counter, style: counterStyle),
                          ),
                        ),
                    ],
                  ),
                  if (_detailsExpanded) ...<Widget>[
                    if (badgeLabels.isNotEmpty) ...<Widget>[
                      const SizedBox(height: StudioSpacing.xs),
                      Wrap(
                        spacing: StudioSpacing.xs,
                        runSpacing: StudioSpacing.chromeActionGap,
                        children: badgeLabels.map((label) {
                          final isOptional =
                              label == l10n.productDemoGuideOptionalTag;
                          final badgeColor =
                              isOptional ? coachTheme.optionalAccent : accent;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: StudioSpacing.xs,
                              vertical: StudioSpacing.chromeActionGap,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                StudioSpacing.radiusDense,
                              ),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.38),
                              ),
                            ),
                            child: Text(
                              label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: badgeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                    if (tour.isAutoplaying) ...<Widget>[
                      const SizedBox(height: StudioLayoutSpacing.titleTight),
                      Text(
                        l10n.productDemoAutoplayStepBody(
                          tour.currentStepLabel ?? title,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: StudioSpacing.xs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: _CoachCalloutCard._cardBodyMaxHeight,
                      ),
                      child: SingleChildScrollView(
                        child: sections != null
                            ? ProductDemoTourGuideBody(
                                sections: sections,
                                languageCode: languageCode,
                                l10n: l10n,
                                textStyle: bodyStyle,
                                labelStyle: labelStyle,
                              )
                            : Text(body, style: bodyStyle),
                      ),
                    ),
                  ],
                  SizedBox(height: _detailsExpanded ? 12 : 8),
                  Row(
                    children: <Widget>[
                      Semantics(
                        label: ProductDemoCoachKeys.semanticsPrevious,
                        button: true,
                        child: TextButton(
                          key: ProductDemoCoachKeys.tourPrevious,
                          style: coachTheme.secondaryButton(theme, tokens),
                          onPressed: tour.stepCount > 0
                              ? () => unawaited(tour.goToPrevious())
                              : null,
                          child: Text(l10n.productDemoGuidePrevious),
                        ),
                      ),
                      const SizedBox(width: StudioSpacing.xs),
                      Expanded(
                        child: Semantics(
                          label: ProductDemoCoachKeys.semanticsNext,
                          button: true,
                          container: true,
                          onTap: tour.stepCount > 0
                              ? () => unawaited(tour.goToNext())
                              : null,
                          child: FilledButton(
                            key: ProductDemoCoachKeys.tourNext,
                            style: coachTheme.primaryButton(theme, tokens),
                            onPressed: tour.stepCount > 0
                                ? () => unawaited(tour.goToNext())
                                : null,
                            child: Text(l10n.productDemoGuideNext),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _CoachSecondaryActionsRow(
                    detailsExpanded: _detailsExpanded,
                    coachTheme: coachTheme,
                    theme: theme,
                    tokens: tokens,
                    l10n: l10n,
                    tour: tour,
                    goRouter: goRouter,
                    onToggleDetails: () {
                      setState(() => _detailsExpanded = !_detailsExpanded);
                    },
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachSecondaryActionsRow extends StatelessWidget {
  const _CoachSecondaryActionsRow({
    required this.detailsExpanded,
    required this.coachTheme,
    required this.theme,
    required this.tokens,
    required this.l10n,
    required this.tour,
    this.goRouter,
    required this.onToggleDetails,
  });

  final bool detailsExpanded;
  final ProductDemoCoachTheme coachTheme;
  final ThemeData theme;
  final StudioTokens tokens;
  final AppLocalizations l10n;
  final ProductDemoTour tour;
  final GoRouter? goRouter;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final expandLabel = detailsExpanded
        ? l10n.productDemoGuideCollapseDetails
        : l10n.productDemoGuideExpandDetails;
    final expandSemantics = detailsExpanded
        ? ProductDemoCoachKeys.semanticsCollapseDetails
        : ProductDemoCoachKeys.semanticsExpandDetails;

    return Padding(
      padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
      child: Row(
        children: <Widget>[
          Semantics(
            label: expandSemantics,
            button: true,
            onTap: onToggleDetails,
            child: TextButton.icon(
              key: ProductDemoCoachKeys.tourToggleDetails,
              style: coachTheme.tertiaryButton(theme, tokens),
              onPressed: onToggleDetails,
              icon: Icon(
                detailsExpanded
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                size: StudioIconSize.sm,
              ),
              label: Text(expandLabel),
            ),
          ),
          const Spacer(),
          if (!tour.isAutoplaying)
            Semantics(
              label: ProductDemoCoachKeys.semanticsAutoplay,
              button: true,
              child: TextButton(
                key: ProductDemoCoachKeys.tourAutoplay,
                style: coachTheme.tertiaryButton(theme, tokens),
                onPressed: () => _startAutoplayFromContext(
                  context,
                  tour,
                  goRouter: goRouter,
                ),
                child: Text(l10n.productDemoGuideStartAutoplay),
              ),
            )
          else
            TextButton(
              style: coachTheme.tertiaryButton(theme, tokens),
              onPressed: tour.toggleAutoplayPaused,
              child: Text(
                tour.isAutoplayPaused
                    ? l10n.productDemoAutoplayResume
                    : l10n.productDemoAutoplayPause,
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoModePill extends StatelessWidget {
  const _DemoModePill({
    required this.l10n,
    required this.tokens,
    required this.onExit,
  });

  final AppLocalizations l10n;
  final StudioTokens tokens;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: tokens.bgElevated.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
      elevation: 4,
      shadowColor: studioShadowColor(context, alpha: 0.2),
      child: Semantics(
        label: ProductDemoCoachKeys.semanticsExit,
        button: true,
        child: InkWell(
          key: ProductDemoCoachKeys.tourExit,
          onTap: onExit,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StudioSpacing.radiusComfort,
              vertical: StudioSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.play_lesson_outlined,
                  size: StudioIconSize.xs,
                  color: tokens.warning,
                ),
                const SizedBox(width: StudioSpacing.xs),
                Text(
                  l10n.productDemoModeBannerTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(width: StudioSpacing.chromeActionGap),
                Text(
                  '·',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
                const SizedBox(width: StudioSpacing.chromeActionGap),
                Text(
                  l10n.productDemoModeExit,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _startAutoplayFromContext(
  BuildContext context,
  ProductDemoTour tour, {
  GoRouter? goRouter,
}) {
  final router = goRouter ?? GoRouter.maybeOf(context);
  final languageCode = Localizations.localeOf(context).languageCode;
  tour.startAutoplay(languageCode: languageCode, router: router);
}
