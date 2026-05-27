// Back-compat facade — implementation lives in [ProductDemoTour].
import 'product_demo_tour.dart';

export 'product_demo_tour.dart'
    show ProductDemoTour, ProductDemoTourStop;

typedef ProductDemoAutoplayStop = ProductDemoTourStop;

/// Legacy name for [ProductDemoTour].
abstract final class ProductDemoAutoplay {
  static ProductDemoTour get instance => ProductDemoTour.instance;

  static List<ProductDemoTourStop> buildDefaultStops() =>
      ProductDemoTour.buildDefaultStops();
}
