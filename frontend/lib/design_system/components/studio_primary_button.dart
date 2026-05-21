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
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final foregroundColor = enabled
        ? Colors.white
        : tokens.textSecondary.withValues(alpha: 0.88);

    return Material(
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
                ? tokens.primary.withValues(alpha: 0.48)
                : tokens.borderSubtle,
          ),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: tokens.primary.withValues(alpha: 0.18),
                    blurRadius: 10,
                    spreadRadius: -4,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(size: 18, color: foregroundColor),
                  child: DefaultTextStyle(
                    style: (theme.textTheme.labelLarge ?? const TextStyle())
                        .copyWith(color: foregroundColor),
                    child: child,
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
