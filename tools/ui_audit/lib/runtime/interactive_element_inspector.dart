import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/models.dart';

/// Validates touch targets and disabled-state opacity at runtime.
class InteractiveElementInspector {
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

      if (widget is Opacity && widget.opacity < 0.38) {
        _reportDisabledOpacity(
          findings,
          widget.opacity,
          '$fixtureName @ ${viewportWidth}px (Opacity)',
        );
      }

      final renderObject = element.renderObject;
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        element.visitChildren(walk);
        return;
      }

      final size = renderObject.size;
      final locationLabel =
          '$fixtureName @ ${viewportWidth}px (${element.widget.runtimeType})';

      if (widget is IconButton || widget is Icon) {
        _checkTouchTarget(
          findings,
          size: size,
          minimum: 36,
          label: 'icon button',
          locationLabel: locationLabel,
        );
      }

      if (widget is ElevatedButton ||
          widget is FilledButton ||
          widget is OutlinedButton ||
          widget is TextButton) {
        _checkTouchTarget(
          findings,
          size: size,
          minimum: 40,
          label: 'button',
          locationLabel: locationLabel,
        );
      }

      if (widget is NavigationRail || widget.toString().contains('Navigation')) {
        _checkTouchTarget(
          findings,
          size: size,
          minimum: 44,
          label: 'navigation item',
          locationLabel: locationLabel,
        );
      }

      _checkDisabledOpacity(findings, widget, locationLabel);

      element.visitChildren(walk);
    }

    walk(root);
    return findings;
  }

  void _reportDisabledOpacity(
    List<Finding> findings,
    double opacity,
    String locationLabel,
  ) {
    if (opacity >= 0.38 && opacity <= 0.5) {
      return;
    }
    findings.add(
      Finding(
        id: _nextId('IE'),
        category: FindingCategory.interactiveElements,
        severity: Severity.medium,
        title: 'Disabled state opacity out of range',
        description:
            'Disabled widget opacity $opacity should be between 0.38 and 0.5 ($locationLabel)',
        location: Location(file: locationLabel, line: 1, column: 1),
        recommendation: 'Use theme disabled opacity (0.38–0.5) for disabled controls',
        designSystemReference: 'ThemeData.disabledColor / opacity 0.38–0.5',
        effort: Effort.small,
      ),
    );
  }

  void _checkTouchTarget(
    List<Finding> findings, {
    required Size size,
    required double minimum,
    required String label,
    required String locationLabel,
  }) {
    if (size.width >= minimum && size.height >= minimum) {
      return;
    }

    findings.add(
      Finding(
        id: _nextId('IE'),
        category: FindingCategory.interactiveElements,
        severity: Severity.high,
        title: 'Touch target too small',
        description:
            '$label rendered at ${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}, below minimum ${minimum.toStringAsFixed(0)}px ($locationLabel)',
        location: Location(file: locationLabel, line: 1, column: 1),
        recommendation:
            'Increase to at least ${minimum.toStringAsFixed(0)}x${minimum.toStringAsFixed(0)} or use StudioSpacing.iconTouchTarget / navItemTouchTarget',
        designSystemReference: 'StudioSpacing.iconTouchTarget (36) / navItemTouchTarget (44)',
        effort: Effort.small,
      ),
    );
  }

  void _checkDisabledOpacity(
    List<Finding> findings,
    Widget widget,
    String locationLabel,
  ) {
    var isDisabled = false;
    double? opacity;

    if (widget is IconButton) {
      isDisabled = widget.onPressed == null;
    } else if (widget is ElevatedButton) {
      isDisabled = widget.onPressed == null;
    } else if (widget is TextButton) {
      isDisabled = widget.onPressed == null;
    } else if (widget is Opacity) {
      opacity = widget.opacity;
      isDisabled = opacity < 1;
    }

    if (!isDisabled || opacity == null) {
      return;
    }

    if (opacity < 0.38 || opacity > 0.5) {
      findings.add(
        Finding(
          id: _nextId('IE'),
          category: FindingCategory.interactiveElements,
          severity: Severity.medium,
          title: 'Disabled state opacity out of range',
          description:
              'Disabled widget opacity $opacity should be between 0.38 and 0.5 ($locationLabel)',
          location: Location(file: locationLabel, line: 1, column: 1),
          recommendation: 'Use theme disabled opacity (0.38–0.5) for disabled controls',
          designSystemReference: 'ThemeData.disabledColor / opacity 0.38–0.5',
          effort: Effort.small,
        ),
      );
    }
  }

  String _nextId(String prefix) {
    _findingCounter++;
    return '$prefix-${_findingCounter.toString().padLeft(3, '0')}';
  }
}
