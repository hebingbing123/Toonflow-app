import 'dart:async';

import 'package:flutter/material.dart';

import '../ix/studio_mobile_affordances.dart';
import '../tokens.dart';
import 'studio_entrance_motion.dart';
import 'studio_surfaces.dart';
import 'studio_text_styles.dart';

/// Dense pane-toolbar action (not a full-bleed hero CTA).
class StudioToolbarButton extends StatelessWidget {
  const StudioToolbarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && onPressed != null;
    final child = StudioFadeSwitcher(
      transitionKey: busy,
      duration: studioMotionQuickDuration,
      slideOffset: Offset.zero,
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: StudioControlSize.progressStroke,
              ),
            )
          : (icon != null
                ? Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: StudioSpacing.xs,
                    runSpacing: StudioSpacing.chromeActionGap,
                    children: <Widget>[
                      Icon(icon, size: StudioIconSize.xs),
                      Text(label, softWrap: true),
                    ],
                  )
                : Text(label, softWrap: true)),
    );

    final style = primary
        ? studioToolbarPrimaryButtonStyle(context)
        : studioToolbarTonalButtonStyle(context);

    if (primary) {
      return FilledButton(
        style: style,
        onPressed: enabled
            ? () {
                unawaited(studioLightImpact());
                onPressed!();
              }
            : null,
        child: child,
      );
    }
    return FilledButton.tonal(
      style: style,
      onPressed: enabled
          ? () {
              unawaited(studioLightImpact());
              onPressed!();
            }
          : null,
      child: DefaultTextStyle(
        style: studioControlLabelStyle(context) ?? const TextStyle(),
        child: child,
      ),
    );
  }
}
