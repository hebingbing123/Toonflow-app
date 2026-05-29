import 'package:flutter/material.dart';

/// Keys and semantics labels for demo coach automation (CDP / integration_test).
abstract final class ProductDemoCoachKeys {
  static const exploreGuestLogin = Key('product-login-explore-demo');
  static const tourNext = Key('product-demo-tour-next');
  static const tourPrevious = Key('product-demo-tour-previous');
  static const tourAutoplay = Key('product-demo-tour-autoplay');
  static const tourToggleDetails = Key('product-demo-tour-toggle-details');
  static const tourExit = Key('product-demo-tour-exit');

  /// Stable English semantics aliases (Flutter web CDP aria-label).
  static const semanticsExploreGuest = 'Try demo first';
  static const semanticsAutoplay = 'Auto tour';
  static const semanticsExpandDetails = 'Demo tour expand details';
  static const semanticsCollapseDetails = 'Demo tour collapse details';
  static const semanticsNext = 'Demo tour next step';
  static const semanticsPrevious = 'Demo tour previous step';
  static const semanticsExit = 'Exit demo';
  static const semanticsOverlay = 'product-demo-coach-overlay';
}
