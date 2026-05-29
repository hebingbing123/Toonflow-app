import 'package:flutter/material.dart';

import 'studio_glass_shader.dart';
import 'tokens.dart';

/// Dark glass panel for sidebar/topbar chrome. Content previews should use solid [StudioTokens.bgSurface].
class StudioGlassPanel extends StatefulWidget {
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
  State<StudioGlassPanel> createState() => _StudioGlassPanelState();
}

class _StudioGlassPanelState extends State<StudioGlassPanel> {
  @override
  void initState() {
    super.initState();
    StudioGlassShader.scheduleWarmUp();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final content = Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: widget.child,
    );

    if (!StudioGlassPanel.glassEnabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgElevated,
          border: widget.border ??
              Border(bottom: BorderSide(color: tokens.borderSubtle)),
        ),
        child: content,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 800,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 600,
        );
        return ClipRect(
          child: BackdropFilter(
            filter: StudioGlassShader.blurFilter(
              sigma: widget.blur,
              textureSize: size,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.glass,
                border: widget.border ??
                    Border(
                      bottom: BorderSide(color: tokens.glassBorder),
                    ),
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }
}
