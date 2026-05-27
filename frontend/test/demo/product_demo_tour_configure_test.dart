import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';
import 'package:openflow_app/demo/product_demo_tour_shell_navigator.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

void main() {
  test('updateRouter preserves app-level navigateStop', () {
    final tour = ProductDemoTour.instance;
    tour.stop();
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
    final shellNav = ShellNavigationController();
    ProductDemoTourShellNavigator.instance.attach(
      router: router,
      shellNavigation: shellNav,
    );
    expect(tour.debugHasNavigateStop, isTrue);

    ProductDemoTourShellNavigator.instance.updateRouter(router);
    expect(tour.debugHasNavigateStop, isTrue);

    tour.configure(router, clearNavigateStop: true);
    expect(tour.debugHasNavigateStop, isFalse);
    tour.stop();
    shellNav.dispose();
  });
}
