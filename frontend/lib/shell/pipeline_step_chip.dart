import 'package:flutter/material.dart';

import '../design_system/theme.dart';
import '../design_system/tokens.dart';

/// Pipeline navigation chip: icon + label inline (avoids FilterChip avatar hiding text).
class PipelineStepChip extends StatelessWidget {
  const PipelineStepChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.useStudioTokens = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool enabled;
  final bool useStudioTokens;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = useStudioTokens ? StudioTokens.of(context) : null;
    final studio = useStudioTokens ? StudioColors.of(context) : null;
    final iconColor = selected
        ? Colors.white
        : (tokens?.textSecondary ?? theme.colorScheme.onSurfaceVariant);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: selected
          ? Colors.white
          : (tokens?.textPrimary ?? theme.colorScheme.onSurface),
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    final borderColor = selected
        ? (tokens != null
              ? tokens.primary.withValues(alpha: 0.42)
              : theme.colorScheme.primary.withValues(alpha: 0.32))
        : (tokens?.surfaceHighlight ?? theme.colorScheme.outlineVariant);
    final background = selected
        ? null
        : (tokens != null
              ? tokens.bgInset.withValues(alpha: 0.92)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.40,
                ));

    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: selected ? studio?.signalGradient : null,
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          boxShadow: selected && tokens != null
              ? <BoxShadow>[
                  BoxShadow(
                    color: tokens.panelGlow.withValues(alpha: 0.18),
                    blurRadius: 16,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled && onSelected != null
                ? () => onSelected!(true)
                : null,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 9 : 12,
                vertical: compact ? 5 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.14)
                          : (tokens != null
                                ? tokens.bgSurface.withValues(alpha: 0.88)
                                : theme.colorScheme.surface.withValues(
                                    alpha: 0.78,
                                  )),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.18)
                            : (tokens?.surfaceHighlight ??
                                  theme.colorScheme.outlineVariant),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 8,
                        vertical: compact ? 4 : 6,
                      ),
                      child: Icon(
                        icon,
                        size: compact ? 14 : 16,
                        color: iconColor,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 5 : 8),
                  Text(
                    label,
                    style: compact
                        ? theme.textTheme.labelSmall?.copyWith(
                            color: labelStyle?.color,
                            fontWeight: labelStyle?.fontWeight,
                          )
                        : labelStyle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
