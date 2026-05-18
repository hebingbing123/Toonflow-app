import 'dart:ui';

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Dark glass panel for sidebar/topbar chrome. Content previews should use solid [StudioTokens.bgSurface].
class StudioGlassPanel extends StatelessWidget {
  const StudioGlassPanel({
    super.key,
    required this.child,
    this.border,
    this.padding,
    this.blur = 16,
  });

  final Widget child;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final double blur;

  static bool get glassEnabled {
    return const bool.fromEnvironment('STUDIO_GLASS', defaultValue: true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (!glassEnabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgElevated,
          border: border ?? Border(bottom: BorderSide(color: tokens.borderSubtle)),
        ),
        child: content,
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.glass,
            border: border ??
                Border(
                  bottom: BorderSide(color: tokens.glassBorder),
                ),
          ),
          child: content,
        ),
      ),
    );
  }
}
