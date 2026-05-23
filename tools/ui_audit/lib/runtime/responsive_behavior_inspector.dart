import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/models.dart';

/// Detects overflow and fixed layouts at runtime viewports.
class ResponsiveBehaviorInspector {
  int _findingCounter = 0;

  List<Finding> inspect(
    WidgetController tester, {
    required String fixtureName,
    required int viewportWidth,
  }) {
    final findings = <Finding>[];
    _findingCounter = 0;

    final root = tester.binding.rootElement;
    if (root == null) {
      return findings;
    }

    void walk(Element element) {
      final widget = element.widget;

      if (widget is SizedBox && widget.width != null && widget.width! > viewportWidth) {
        findings.add(
          Finding(
            id: _nextId('RS'),
            category: FindingCategory.responsiveness,
            severity: Severity.high,
            title: 'Fixed-width element may block responsive layout',
            description:
                'SizedBox width ${widget.width!.toStringAsFixed(0)} exceeds viewport $viewportWidth ($fixtureName)',
            location: Location(file: fixtureName, line: 1, column: 1),
            recommendation: 'Use responsive constraints instead of fixed width',
            designSystemReference: 'layout_breakpoints.dart',
            effort: Effort.medium,
          ),
        );
        return;
      }

      final renderObject = element.renderObject;
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        element.visitChildren(walk);
        return;
      }

      final width = renderObject.size.width;
      if (width > viewportWidth + 1) {
        findings.add(
          Finding(
            id: _nextId('RS'),
            category: FindingCategory.responsiveness,
            severity: Severity.high,
            title: 'Child wider than viewport',
            description:
                '${element.widget.runtimeType} width ${width.toStringAsFixed(0)} exceeds viewport $viewportWidth ($fixtureName)',
            location: Location(file: fixtureName, line: 1, column: 1),
            recommendation: 'Use responsive constraints instead of fixed width',
            designSystemReference: 'layout_breakpoints.dart',
            effort: Effort.medium,
          ),
        );
        return;
      }

      element.visitChildren(walk);
    }

    walk(root);
    return findings;
  }

  String _nextId(String prefix) {
    _findingCounter++;
    return '$prefix-${_findingCounter.toString().padLeft(3, '0')}';
  }
}
