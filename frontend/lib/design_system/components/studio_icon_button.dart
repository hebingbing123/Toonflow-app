import 'dart:async';

import 'package:flutter/material.dart';

import '../ix/studio_pointer.dart';
import '../ix/studio_mobile_affordances.dart';
import '../tokens.dart';

/// Accessible icon button with built-in Semantics and Tooltip.
///
/// Use this instead of raw [IconButton] for icon-only buttons to ensure
/// screen reader accessibility. The [label] is used for both the tooltip
/// (visible on hover) and semantic label (announced by screen readers).
///
/// Example:
/// ```dart
/// StudioIconButton(
///   icon: Icons.close,
///   label: 'Close dialog',
///   onPressed: () => Navigator.pop(context),
/// )
/// ```
class StudioIconButton extends StatelessWidget {
  const StudioIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size,
    this.color,
    this.style,
    this.tooltip,
  });

  /// The icon to display.
  final IconData icon;

  /// Semantic label for screen readers and default tooltip text.
  /// This should describe the button's action (e.g., "Close dialog", "Edit item").
  final String label;

  /// Callback when button is pressed. If null, button is disabled.
  final VoidCallback? onPressed;

  /// Icon size. Defaults to theme's icon size.
  final double? size;

  /// Icon color. Defaults to theme's icon color.
  final Color? color;

  /// Button style. If provided, overrides default styling.
  final ButtonStyle? style;

  /// Optional custom tooltip text. If null, uses [label].
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tooltipMessage = tooltip ?? label;

    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: Tooltip(
        message: tooltipMessage,
        waitDuration: const Duration(milliseconds: 350),
        child: IconButton(
          style: style,
          icon: Icon(icon, size: size, color: color, semanticLabel: label),
          onPressed: onPressed == null
              ? null
              : () {
                  unawaited(studioLightImpact());
                  onPressed!();
                },
        ),
      ),
    );
  }
}

/// Accessible icon button with custom styling for utility chrome (app bar, toolbars).
///
/// Provides consistent styling for icon buttons in top-bar actions, side panels, etc.
/// Includes proper semantics, tooltips, and optional badge support.
class StudioUtilityIconButton extends StatelessWidget {
  const StudioUtilityIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.dense = false,
    this.badge,
  });

  /// The icon to display.
  final IconData icon;

  /// Semantic label for screen readers and tooltip.
  final String label;

  /// Callback when button is pressed.
  final VoidCallback onPressed;

  /// Whether this button represents a selected state.
  final bool selected;

  /// Whether to use dense styling (smaller, for title bars).
  final bool dense;

  /// Optional badge count to display.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final borderRadius = BorderRadius.circular(dense ? 4 : 12);
    final iconSize = dense ? 17.0 : 21.0;
    final boxSize = dense ? 28.0 : StudioSpacing.iconTouchTarget + 8.0;

    final iconWidget = Icon(
      icon,
      size: iconSize,
      fill: dense ? 0.35 : 0.0,
      weight: dense ? 500 : 400,
      semanticLabel: label,
      color: selected
          ? tokens.primary
          : tokens.textSecondary.withValues(alpha: dense ? 0.86 : 1.0),
    );

    return Semantics(
      button: true,
      label: badge != null ? '$label ($badge unread)' : label,
      selected: selected,
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 350),
        child: studioWrapClickCursor(
          enabled: true,
          child: Material(
            color: StudioPrimitives.transparent,
            borderRadius: borderRadius,
            child: Ink(
              width: boxSize,
              height: boxSize,
              decoration: dense
                  ? null
                  : BoxDecoration(
                      color: selected
                          ? tokens.primarySoft.withValues(alpha: 0.92)
                          : tokens.bgSurface.withValues(alpha: 0.72),
                      borderRadius: borderRadius,
                      border: selected
                          ? Border.all(
                              color: tokens.primary.withValues(alpha: 0.45),
                            )
                          : null,
                    ),
              child: InkWell(
                onTap: () {
                  unawaited(studioLightImpact());
                  onPressed();
                },
                borderRadius: borderRadius,
                hoverColor: dense
                    ? tokens.bgInset.withValues(alpha: 0.65)
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Center(child: iconWidget),
                    if (badge != null)
                      Positioned(
                        top: dense ? 2 : 7,
                        right: dense ? 2 : 6,
                        child: _Badge(value: badge!, dense: dense),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.value, this.dense = false});

  final int value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final size = dense ? 14.0 : 18.0;
    final fontSize = dense ? 9.0 : 10.0;

    return ExcludeSemantics(
      child: Container(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 3 : 4,
          vertical: dense ? 1 : 2,
        ),
        decoration: BoxDecoration(
          color: tokens.signal,
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: tokens.bgSurface, width: dense ? 1 : 1.5),
        ),
        child: Text(
          value > 99 ? '99+' : value.toString(),
          style: TextStyle(
            color: StudioPrimitives.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
