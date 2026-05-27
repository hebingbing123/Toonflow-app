import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../studio_typography.dart';
import '../theme.dart';
import '../tokens.dart';
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
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: enabled
                  ? Colors.white
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
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    if (icon != null) Icon(icon, size: 18),
                    Text(label, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          );

    final foregroundColor = enabled
        ? Colors.white
        : tokens.textSecondary.withValues(alpha: 0.88);

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
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
                      color: tokens.primary.withValues(alpha: 0.22),
                      blurRadius: 14,
                      spreadRadius: -8,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      spreadRadius: -10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: borderRadius,
            splashColor: tokens.accent.withValues(alpha: 0.12),
            highlightColor: tokens.primary.withValues(alpha: 0.10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: buttonHeight,
                minWidth: 96,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: StudioLayoutSpacing.insetDense + 2,
                  vertical: math
                      .max(6, (buttonHeight - 20) / 2)
                      .clamp(6.0, 8.0)
                      .toDouble(),
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(size: 18, color: foregroundColor),
                    child: DefaultTextStyle(
                      style: (studioControlLabelStyle(context) ??
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
    );
  }
}
