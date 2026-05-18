import 'package:flutter/material.dart';

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
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool enabled;
  final bool useStudioTokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = useStudioTokens ? StudioTokens.of(context) : null;
    final iconColor = selected
        ? (tokens?.primary ?? theme.colorScheme.primary)
        : (tokens?.textSecondary ?? theme.colorScheme.onSurfaceVariant);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: selected
          ? (tokens?.primary ?? theme.colorScheme.primary)
          : (tokens?.textPrimary ?? theme.colorScheme.onSurface),
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );

    return FilterChip(
      showCheckmark: false,
      selected: selected,
      onSelected: enabled ? onSelected : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: labelStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
