import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

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
    final enabled = !loading && onPressed != null;
    final borderRadius = BorderRadius.circular(StudioSpacing.radiusButton);
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
              constraints: const BoxConstraints(minHeight: 46, minWidth: 120),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StudioLayoutSpacing.insetComfortable,
                  vertical: 11,
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(size: 18, color: foregroundColor),
                    child: DefaultTextStyle(
                      style: (theme.textTheme.labelLarge ?? const TextStyle())
                          .copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w700,
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
