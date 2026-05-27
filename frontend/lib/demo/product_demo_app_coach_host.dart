import 'dart:async';

import 'package:flutter/material.dart';

import 'product_demo_coach_overlay.dart';
import 'product_demo_mode.dart';
import 'product_demo_tour.dart';
import 'product_demo_tour_shell_navigator.dart';

/// Keeps the demo coach overlay above all [HomePage] route instances.
///
/// Without this, `go('/projects/…')` disposes the shell [HomePage] and the coach
/// layer vanishes mid-click so the next tap hits the journey strip instead.
class ProductDemoAppCoachHost extends StatelessWidget {
  const ProductDemoAppCoachHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        ProductDemoMode.instance,
        ProductDemoTour.instance,
      ]),
      builder: (context, _) {
        if (!ProductDemoMode.instance.isActive) {
          return child;
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            child,
            ProductDemoCoachOverlay(
              goRouter: ProductDemoTourShellNavigator.instance.router,
              onExit: () => unawaited(ProductDemoMode.instance.disable()),
            ),
          ],
        );
      },
    );
  }
}
