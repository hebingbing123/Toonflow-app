import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Metrics collected from a rendered element subtree.
class WidgetTreeMetrics {
  final int elementCount;
  final int renderObjectCount;
  final List<Size> boxSizes;

  const WidgetTreeMetrics({
    required this.elementCount,
    required this.renderObjectCount,
    required this.boxSizes,
  });
}

/// Traverses the element tree and collects layout metrics.
class WidgetTreeInspector {
  WidgetTreeMetrics inspect(Element root) {
    var elementCount = 0;
    var renderObjectCount = 0;
    final boxSizes = <Size>[];

    void walk(Element element) {
      elementCount++;
      final renderObject = element.renderObject;
      if (renderObject != null) {
        renderObjectCount++;
        if (renderObject is RenderBox && renderObject.hasSize) {
          boxSizes.add(renderObject.size);
        }
      }
      element.visitChildren(walk);
    }

    walk(root);
    return WidgetTreeMetrics(
      elementCount: elementCount,
      renderObjectCount: renderObjectCount,
      boxSizes: boxSizes,
    );
  }
}
