import 'package:flutter/material.dart';

import '../design_system/tokens.dart';

/// Pipeline navigation chip: icon + label inline (avoids FilterChip avatar hiding text).
class PipelineStepChip extends StatefulWidget {
  const PipelineStepChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.useStudioTokens = false,
    this.compact = false,
    this.iconOnly = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool enabled;
  final bool useStudioTokens;
  final bool compact;

  /// Handset / narrow pane: icon + tooltip only (saves horizontal space in pipeline rail).
  final bool iconOnly;

  @override
  State<PipelineStepChip> createState() => _PipelineStepChipState();
}

class _PipelineStepChipState extends State<PipelineStepChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = widget.useStudioTokens ? StudioTokens.of(context) : null;
    final hovered = _hovered && widget.enabled && !widget.selected;
    final selectedFg = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final iconColor = widget.selected
        ? (tokens?.primary ?? theme.colorScheme.primary)
        : (tokens?.textSecondary ?? theme.colorScheme.onSurfaceVariant);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: widget.selected
          ? selectedFg
          : (tokens?.textPrimary ?? theme.colorScheme.onSurface),
      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
    );
    final borderColor = widget.selected
        ? (tokens != null
              ? tokens.primary.withValues(alpha: 0.42)
              : theme.colorScheme.primary.withValues(alpha: 0.32))
        : hovered && tokens != null
        ? tokens.primary.withValues(alpha: 0.32)
        : (tokens?.borderSubtle ?? theme.colorScheme.outlineVariant);
    final background = widget.selected
        ? (tokens?.primarySoft ?? theme.colorScheme.primaryContainer)
        : hovered && tokens != null
        ? tokens.primarySoft.withValues(alpha: 0.45)
        : (tokens != null
              ? tokens.bgInset.withValues(alpha: 0.92)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.40,
                ));

    final chip = Opacity(
      opacity: widget.enabled ? 1 : 0.52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: widget.selected
                ? (tokens?.primary.withValues(alpha: 0.55) ?? borderColor)
                : borderColor,
            width: widget.selected ? 1.5 : (hovered && tokens != null ? 1.25 : 1),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled && widget.onSelected != null
                ? () => widget.onSelected!(true)
                : null,
            onHover: (value) {
              if (_hovered != value) {
                setState(() => _hovered = value);
              }
            },
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact
                    ? StudioSpacing.xs + 2
                    : StudioSpacing.sm,
                vertical: widget.compact
                    ? StudioSpacing.xs - 1
                    : StudioSpacing.xs + 1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? (tokens?.bgSurface.withValues(alpha: 0.55) ??
                                theme.colorScheme.surface.withValues(
                                  alpha: 0.55,
                                ))
                          : (tokens != null
                                ? tokens.bgSurface.withValues(
                                    alpha: hovered ? 0.96 : 0.88,
                                  )
                                : theme.colorScheme.surface.withValues(
                                    alpha: 0.78,
                                  )),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: widget.selected
                            ? (tokens?.primary.withValues(alpha: 0.28) ??
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.28,
                                  ))
                            : hovered && tokens != null
                            ? tokens.primary.withValues(alpha: 0.22)
                            : (tokens?.borderSubtle ??
                                  theme.colorScheme.outlineVariant),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.compact ? 6 : 8,
                        vertical: widget.compact ? 4 : 6,
                      ),
                      child: Icon(
                        widget.icon,
                        size: widget.compact ? 14 : 16,
                        color: iconColor,
                      ),
                    ),
                  ),
                  if (!widget.iconOnly) ...<Widget>[
                    SizedBox(
                      width: widget.compact
                          ? StudioSpacing.xs - 3
                          : StudioSpacing.xs,
                    ),
                    Text(
                      widget.label,
                      style: widget.compact
                          ? theme.textTheme.labelSmall?.copyWith(
                              color: labelStyle?.color,
                              fontWeight: labelStyle?.fontWeight,
                            )
                          : labelStyle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!widget.iconOnly) {
      return chip;
    }
    return Tooltip(message: widget.label, child: chip);
  }
}
