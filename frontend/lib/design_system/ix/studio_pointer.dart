import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../layout_breakpoints.dart';
import '../tokens.dart';

/// Whether hover highlights and pointer cursors should apply.
///
/// Enabled on desktop embed targets and tablet/desktop-width layouts (incl. web).
bool studioPointerChromeEnabled(BuildContext context) {
  final mq = MediaQuery.maybeOf(context);
  if (mq == null) return false;

  if (kIsWeb && mq.size.width > kStudioHandsetMaxWidth) {
    return true;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => mq.size.width > kStudioHandsetMaxWidth,
    TargetPlatform.android || TargetPlatform.iOS =>
      mq.size.width >= kStudioGridDesktopMinWidth,
    _ => mq.size.width >= kStudioGridDesktopMinWidth,
  };
}

/// Whether scrollbars should stay visible (tablet / desktop / pointer layouts).
bool studioScrollbarThumbVisible(BuildContext context) {
  final mq = MediaQuery.maybeOf(context);
  if (mq == null) return false;
  if (mq.size.width <= kStudioHandsetMaxWidth) return false;
  if (studioPointerChromeEnabled(context)) return true;
  return mq.size.shortestSide > kStudioHandsetMaxWidth;
}

MouseCursor studioInteractiveMouseCursor({required bool enabled}) {
  return enabled ? SystemMouseCursors.click : SystemMouseCursors.basic;
}

/// Applies the standard click cursor when [enabled].
Widget studioWrapClickCursor({
  required Widget child,
  required bool enabled,
}) {
  if (!enabled) return child;
  return MouseRegion(
    cursor: studioInteractiveMouseCursor(enabled: true),
    child: child,
  );
}

/// Shared [ButtonStyle] mouse cursor for theme-level button variants.
ButtonStyle studioInteractiveButtonMouseCursor(ButtonStyle style) {
  return style.copyWith(
    mouseCursor: WidgetStateProperty.resolveWith<MouseCursor?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return SystemMouseCursors.basic;
      }
      return SystemMouseCursors.click;
    }),
  );
}

/// Hover overlay for Material buttons (theme + custom controls).
WidgetStateProperty<Color?> studioButtonHoverOverlay(StudioTokens tokens) {
  return WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) return null;
    if (states.contains(WidgetState.pressed)) {
      return tokens.primary.withValues(alpha: 0.14);
    }
    if (states.contains(WidgetState.hovered)) {
      return tokens.primary.withValues(alpha: 0.12);
    }
    return null;
  });
}

/// Pointer hover lift + surface tint for cards and custom tappables.
class StudioPointerHover extends StatefulWidget {
  const StudioPointerHover({
    super.key,
    required this.builder,
    this.enabled = true,
    this.borderRadius,
    this.liftShadow = true,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final bool enabled;
  final BorderRadius? borderRadius;
  final bool liftShadow;

  @override
  State<StudioPointerHover> createState() => _StudioPointerHoverState();
}

class _StudioPointerHoverState extends State<StudioPointerHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final pointer = widget.enabled && studioPointerChromeEnabled(context);
    final radius = widget.borderRadius ??
        BorderRadius.circular(StudioSpacing.radiusDense);

    return MouseRegion(
      onEnter: pointer ? (_) => setState(() => _hovered = true) : null,
      onExit: pointer ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: pointer && _hovered && widget.liftShadow
            ? BoxDecoration(
                borderRadius: radius,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: StudioPrimitives.black.withValues(alpha: 0.28),
                    blurRadius: 18,
                    spreadRadius: -6,
                    offset: const Offset(0, 8),
                  ),
                ],
              )
            : null,
        child: widget.builder(context, pointer && _hovered),
      ),
    );
  }
}
