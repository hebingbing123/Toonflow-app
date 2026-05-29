import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../glass.dart';
import '../tokens.dart';
import 'studio_entrance_motion.dart';
import 'studio_surfaces.dart';
import 'studio_text_styles.dart';

/// First-run coach marks (Wave 0b).
class StudioOnboardingCoach extends StatefulWidget {
  const StudioOnboardingCoach({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// When false, coach marks are suppressed (e.g. login / non-projects panes).
  final bool enabled;

  static const _seenKey = 'studio_onboarding_seen_v1';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_seenKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<StudioOnboardingCoach> createState() => _StudioOnboardingCoachState();
}

class _OnboardingStepContent {
  const _OnboardingStepContent({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _StudioOnboardingCoachState extends State<StudioOnboardingCoach> {
  var _step = 0;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant StudioOnboardingCoach oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _visible) {
      setState(() => _visible = false);
    } else if (widget.enabled && !oldWidget.enabled) {
      unawaited(_init());
    }
  }

  Future<void> _init() async {
    if (!widget.enabled) {
      if (!mounted) return;
      setState(() => _visible = false);
      return;
    }
    final show = await StudioOnboardingCoach.shouldShow();
    if (!mounted) return;
    setState(() {
      _visible = show;
      _step = 0;
    });
  }

  Future<void> _dismiss() async {
    await StudioOnboardingCoach.markSeen();
    if (!mounted) return;
    setState(() => _visible = false);
  }

  List<_OnboardingStepContent> _steps(AppLocalizations l10n) =>
      <_OnboardingStepContent>[
        _OnboardingStepContent(
          icon: Icons.folder_open_outlined,
          title: l10n.studioOnboardingStep1Title,
          body: l10n.studioOnboardingStep1,
        ),
        _OnboardingStepContent(
          icon: Icons.linear_scale_rounded,
          title: l10n.studioOnboardingStep2Title,
          body: l10n.studioOnboardingStep2,
        ),
        _OnboardingStepContent(
          icon: Icons.keyboard_command_key_outlined,
          title: l10n.studioOnboardingStep3Title,
          body: l10n.studioOnboardingStep3,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context);
    final steps = _steps(l10n);
    final current = steps[_step.clamp(0, steps.length - 1)];
    final isLast = _step >= steps.length - 1;

    return Stack(
      children: <Widget>[
        widget.child,
        if (_visible)
          Positioned(
            right: StudioSpacing.md,
            bottom: StudioSpacing.md + MediaQuery.paddingOf(context).bottom,
            child: studioStaggeredItem(
              0,
              entranceKey: 'studio_onboarding_coach',
              child: Material(
              color: StudioPrimitives.transparent,
              elevation: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: StudioGlassPanel(
                  border: Border.all(color: tokens.surfaceHighlight),
                  padding: EdgeInsets.zero,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(StudioSpacing.radiusCard),
                      boxShadow: studioInsetElevationShadow(
                        context,
                        alpha: 0.16,
                        blurRadius: 24,
                        spreadRadius: -8,
                        offset: const Offset(0, 10),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(StudioSpacing.radiusCard),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Container(height: 3, color: tokens.primary),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              StudioSpacing.sm,
                              StudioSpacing.sm,
                              StudioSpacing.sm,
                              StudioSpacing.radiusComfort,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        l10n.studioOnboardingTitle,
                                        style: studioControlLabelStyle(context)
                                            ?.copyWith(
                                          color: tokens.textMuted,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _dismiss,
                                      style: studioFormTextButtonIconStyle(context),
                                      child: Text(l10n.studioOnboardingSkip),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: StudioSpacing.sm),
                                _OnboardingStepIndicator(
                                  stepCount: steps.length,
                                  currentIndex: _step,
                                ),
                                const SizedBox(height: StudioSpacing.sm),
                                _OnboardingStepVisual(
                                  stepIndex: _step,
                                ),
                                const SizedBox(height: StudioSpacing.sm),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: tokens.primarySoft
                                            .withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(
                                          StudioSpacing.radiusButton,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          StudioSpacing.xs,
                                        ),
                                        child: Icon(
                                          current.icon,
                                          size: StudioIconSize.lg,
                                          color: tokens.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: StudioSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            current.title,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: tokens.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: StudioSpacing.xs,
                                          ),
                                          Text(
                                            current.body,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              height: 1.45,
                                              color: tokens.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: StudioSpacing.sm),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      l10n.studioOnboardingStepCounter(
                                        _step + 1,
                                        steps.length,
                                      ),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: tokens.textMuted),
                                    ),
                                    const Spacer(),
                                    if (_step > 0)
                                      TextButton(
                                        onPressed: () =>
                                            setState(() => _step--),
                                        child: Text(l10n.studioOnboardingPrevious),
                                      ),
                                    FilledButton(
                                      style: studioFormPrimaryButtonStyle(
                                        context,
                                      ),
                                      onPressed: () {
                                        if (isLast) {
                                          _dismiss();
                                        } else {
                                          setState(() => _step++);
                                        }
                                      },
                                      child: Text(
                                        isLast
                                            ? l10n.studioOnboardingDone
                                            : l10n.studioOnboardingNext,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),
      ],
    );
  }
}

/// Segmented progress for the three-step coach.
class _OnboardingStepIndicator extends StatelessWidget {
  const _OnboardingStepIndicator({
    required this.stepCount,
    required this.currentIndex,
  });

  final int stepCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Row(
      children: List<Widget>.generate(stepCount, (index) {
        final active = index == currentIndex;
        final done = index < currentIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : StudioSpacing.xs / 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active
                    ? tokens.primary
                    : done
                    ? tokens.primary.withValues(alpha: 0.45)
                    : tokens.borderSubtle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Step-specific mini illustration (nav rail / pipeline / command palette).
class _OnboardingStepVisual extends StatelessWidget {
  const _OnboardingStepVisual({required this.stepIndex});

  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: switch (stepIndex) {
          0 => _NavRailHint(tokens: tokens, theme: theme),
          1 => _PipelineHint(tokens: tokens, theme: theme),
          _ => _CommandPaletteHint(tokens: tokens, theme: theme),
        },
      ),
    );
  }
}

class _NavRailHint extends StatelessWidget {
  const _NavRailHint({required this.tokens, required this.theme});

  final StudioTokens tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = <String>[
      l10n.productNavProjects,
      l10n.productNavTasks,
      l10n.productNavHelp,
    ];
    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.bgSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: StudioSpacing.xs,
              horizontal: StudioSpacing.xs / 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(labels.length, (index) {
                final active = index == 0;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == labels.length - 1 ? 0 : StudioSpacing.xs / 2,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: active
                          ? tokens.primarySoft.withValues(alpha: 0.72)
                          : StudioPrimitives.transparent,
                      borderRadius:
                          BorderRadius.circular(StudioSpacing.radiusDense),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: StudioSpacing.xs,
                        vertical: StudioSpacing.xs / 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            switch (index) {
                              0 => Icons.folder_open_outlined,
                              1 => Icons.checklist_rounded,
                              _ => Icons.help_outline_rounded,
                            },
                            size: StudioIconSize.sm,
                            color: active ? tokens.primary : tokens.textMuted,
                          ),
                          const SizedBox(width: StudioSpacing.xs / 2),
                          Text(
                            labels[index],
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: active
                                  ? tokens.textPrimary
                                  : tokens.textMuted,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: StudioSpacing.sm),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.bgSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: const SizedBox(height: 52),
          ),
        ),
      ],
    );
  }
}

class _PipelineHint extends StatelessWidget {
  const _PipelineHint({required this.tokens, required this.theme});

  final StudioTokens tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = <String>[
      l10n.studioStepScriptShort,
      l10n.studioStepArtShort,
      l10n.studioStepStoryboardShort,
      l10n.studioStepDeliverShort,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: StudioSpacing.xs / 2,
          runSpacing: StudioSpacing.xs / 2,
          children: List<Widget>.generate(steps.length, (index) {
            final active = index == 0;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: active
                    ? tokens.primarySoft.withValues(alpha: 0.65)
                    : tokens.bgSurface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
                border: Border.all(
                  color: active ? tokens.primary : tokens.borderSubtle,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StudioSpacing.sm,
                  vertical: StudioSpacing.xs / 2,
                ),
                child: Text(
                  steps[index],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: active ? tokens.primary : tokens.textSecondary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.studioOnboardingStep2,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tokens.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommandPaletteHint extends StatelessWidget {
  const _CommandPaletteHint({required this.tokens, required this.theme});

  final StudioTokens tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.bgSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StudioSpacing.sm,
              vertical: StudioSpacing.xs,
            ),
            child: Text(
              defaultTargetPlatform == TargetPlatform.macOS
                  ? l10n.studioCommandPaletteShortcutMac
                  : l10n.studioCommandPaletteShortcutWindows,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: StudioSpacing.sm),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.bgSurface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StudioSpacing.sm,
                vertical: StudioSpacing.xs,
              ),
              child: Text(
                l10n.studioOnboardingStep3,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tokens.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
