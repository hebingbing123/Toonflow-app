import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Registers active [BuildContext]s for demo coach spotlight targets.
class ProductDemoTourAnchors {
  ProductDemoTourAnchors._();

  static final ProductDemoTourAnchors instance = ProductDemoTourAnchors._();

  final Map<String, BuildContext> _contexts = <String, BuildContext>{};

  void register(String anchorId, BuildContext context) {
    _contexts[anchorId] = context;
  }

  void unregister(String anchorId, BuildContext context) {
    if (_contexts[anchorId] == context) {
      _contexts.remove(anchorId);
    }
  }

  /// Screen-space bounds for [anchorId], or null if not laid out yet.
  Rect? rectOnScreen(String? anchorId) {
    if (anchorId == null || anchorId.isEmpty) {
      return null;
    }
    final context = _contexts[anchorId];
    if (context == null || !context.mounted) {
      return null;
    }
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return null;
      }
      final offset = box.localToGlobal(Offset.zero);
      return offset & box.size;
    } catch (_) {
      return null;
    }
  }

  void scheduleRemeasure(VoidCallback onMeasured) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      onMeasured();
    });
  }
}

/// Marks a subtree as a demo tour spotlight target.
class ProductDemoTourAnchor extends StatefulWidget {
  const ProductDemoTourAnchor({
    super.key,
    required this.anchorId,
    required this.child,
  });

  final String anchorId;
  final Widget child;

  @override
  State<ProductDemoTourAnchor> createState() => _ProductDemoTourAnchorState();
}

class _ProductDemoTourAnchorState extends State<ProductDemoTourAnchor> {
  @override
  void didUpdateWidget(ProductDemoTourAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorId != widget.anchorId) {
      ProductDemoTourAnchors.instance.unregister(oldWidget.anchorId, context);
    }
  }

  @override
  void dispose() {
    ProductDemoTourAnchors.instance.unregister(widget.anchorId, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ProductDemoTourAnchors.instance.register(widget.anchorId, context);
      }
    });
    return widget.child;
  }
}

/// Known anchor ids used by [ProductDemoTour.buildDefaultStops].
abstract final class ProductDemoTourAnchorIds {
  static const projectsGrid = 'demo.projects.grid';
  static const studioJourney = 'demo.studio.journey';
  static const shellPipeline = 'demo.shell.pipeline';
  static const shellContent = 'demo.shell.content';
  static const shellAppBar = 'demo.shell.appbar';
}

