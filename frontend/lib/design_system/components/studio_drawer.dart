import 'package:flutter/material.dart';

import '../ix/studio_focus_trap.dart';
import '../studio_motion.dart';
import '../tokens.dart';
import 'studio_surfaces.dart';

enum StudioDrawerSide { start, end }

/// Slide-over panel from the screen edge with overlay dismiss.
Future<T?> showStudioDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  StudioDrawerSide side = StudioDrawerSide.end,
  bool barrierDismissible = true,
  double widthFactor = 0.38,
  double maxWidth = 420,
}) {
  final tokens = StudioTokens.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: tokens.overlay,
    transitionDuration: StudioMotionDurations.drawerTransition,
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final width = MediaQuery.sizeOf(ctx).width;
      final panelWidth = (width * widthFactor).clamp(280.0, maxWidth);
      final align = side == StudioDrawerSide.end
          ? Alignment.centerRight
          : Alignment.centerLeft;
      return SafeArea(
        child: Align(
          alignment: align,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: Material(
              color: StudioPrimitives.transparent,
              child: StudioFocusTrap(
                child: DecoratedBox(
                  decoration: studioInsetPanelDecoration(ctx),
                  child: builder(ctx),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final offset = side == StudioDrawerSide.end
          ? Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          : Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero);
      return SlideTransition(
        position: offset.animate(
          CurvedAnimation(
            parent: animation,
            curve: studioAnimationCurve(ctx, StudioMotionCurves.drawerCurve),
          ),
        ),
        child: child,
      );
    },
  );
}
