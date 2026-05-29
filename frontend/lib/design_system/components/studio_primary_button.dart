import 'dart:async';

import 'package:flutter/material.dart';

import '../ix/studio_mobile_affordances.dart';
import '../ix/studio_pointer.dart';
import '../studio_typography.dart';
import '../theme.dart';
import '../tokens.dart';
import 'studio_debounced_action.dart';
import 'studio_entrance_motion.dart';
import 'studio_text_styles.dart';

class StudioPrimaryButton extends StatelessWidget {
  const StudioPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final studio = StudioColors.of(context);
    final theme = Theme.of(context);
    final typography = StudioTypography.of(context);
    final enabled = !loading && onPressed != null;
    final borderRadius = BorderRadius.circular(StudioSpacing.radiusButton);
    final buttonHeight = typography.buttonHeight;
    final child = StudioFadeSwitcher(
      transitionKey: loading,
      duration: studioMotionQuickDuration,
      slideOffset: Offset.zero,
      child: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: StudioControlSize.progressStroke,
                color: enabled
                    ? theme.colorScheme.onPrimary
                    : tokens.textSecondary.withValues(alpha: 0.9),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: StudioSpacing.xs,
                    runSpacing: StudioSpacing.chromeActionGap,
                    children: <Widget>[
                      if (icon != null) Icon(icon, size: StudioIconSize.sm),
                      Text(label, textAlign: TextAlign.center, softWrap: true),
                    ],
                  ),
                ),
              ],
            ),
    );

    final foregroundColor = enabled
        ? theme.colorScheme.onPrimary
        : tokens.textSecondary.withValues(alpha: 0.88);

    Widget buildButton(VoidCallback? tap) {
      return Semantics(
        button: true,
        enabled: enabled,
        child: studioWrapClickCursor(
          enabled: enabled,
          child: Material(
            color: StudioPrimitives.transparent,
            borderRadius: borderRadius,
            child: Ink(
              decoration: BoxDecoration(
                gradient: enabled
                    ? studio.primaryGradient
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          tokens.bgElevated,
                          tokens.bgSurface.withValues(alpha: 0.94),
                        ],
                      ),
                borderRadius: borderRadius,
                border: Border.all(
                  color: enabled
                      ? tokens.primary.withValues(alpha: 0.58)
                      : tokens.borderSubtle.withValues(alpha: 0.92),
                ),
                boxShadow: enabled
                    ? <BoxShadow>[
                        BoxShadow(
                          color: tokens.primary.withValues(alpha: 0.14),
                          blurRadius: 10,
                          spreadRadius: -10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: InkWell(
                onTap: tap,
                borderRadius: borderRadius,
                splashColor: tokens.accent.withValues(alpha: 0.12),
                highlightColor: tokens.primary.withValues(alpha: 0.10),
                hoverColor: studioPointerChromeEnabled(context)
                    ? tokens.primary.withValues(alpha: 0.12)
                    : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: buttonHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: StudioLayoutSpacing.insetDense,
                      vertical: StudioSpacing.xs,
                    ),
                    child: Center(
                      child: IconTheme(
                        data: IconThemeData(
                          size: StudioIconSize.sm,
                          color: foregroundColor,
                        ),
                        child: DefaultTextStyle(
                          style:
                              (studioControlLabelStyle(context) ??
                                      theme.textTheme.labelLarge ??
                                      const TextStyle())
                                  .copyWith(
                                    color: foregroundColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!enabled || onPressed == null) {
      return buildButton(null);
    }

    return StudioDebouncedAction(
      enabled: true,
      onPressed: () async {
        unawaited(studioLightImpact());
        onPressed!();
      },
      builder: (context, debouncedOnPressed) {
        return buildButton(debouncedOnPressed);
      },
    );
  }
}
