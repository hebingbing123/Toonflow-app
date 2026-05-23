import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/models.dart';

/// Runtime semantics and focus-order checks.
class AccessibilityInspectorRuntime {
  int _findingCounter = 0;

  List<Finding> inspect(
    WidgetController tester, {
    required String fixtureName,
  }) {
    final findings = <Finding>[];
    _findingCounter = 0;

    final handle = tester.ensureSemantics();
    final owner = tester.binding.pipelineOwner.semanticsOwner;
    if (owner == null) {
      handle.dispose();
      return findings;
    }

    final nodes = <SemanticsNode>[];
    void collect(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((child) {
        collect(child);
        return true;
      });
    }

    final rootNode = owner.rootSemanticsNode;
    if (rootNode != null) {
      collect(rootNode);
    }

    SemanticsNode? previous;
    for (final node in nodes) {
      final label = node.label.trim();
      final hint = node.hint.trim();

      final flags = node.getSemanticsData();
      if (flags.hasFlag(SemanticsFlag.isImage) && label.isEmpty && hint.isEmpty) {
        findings.add(
          Finding(
            id: _nextId('ACC'),
            category: FindingCategory.accessibility,
            severity: Severity.high,
            title: 'Image missing semantics label (runtime)',
            description: 'Semantics image node has no label in $fixtureName',
            location: Location(file: fixtureName, line: 1, column: 1),
            recommendation: 'Add semanticLabel to Image or mark as decorative',
            designSystemReference: 'Semantics',
            effort: Effort.small,
          ),
        );
      }

      if (previous != null &&
          node.rect.top < previous.rect.top - 200 &&
          node.rect.left < previous.rect.left) {
        findings.add(
          Finding(
            id: _nextId('ACC'),
            category: FindingCategory.accessibility,
            severity: Severity.medium,
            title: 'Possible illogical focus/visual order',
            description:
                'Semantics order may not follow top-to-bottom reading flow in $fixtureName',
            location: Location(file: fixtureName, line: 1, column: 1),
            recommendation: 'Verify Tab order matches visual layout',
            designSystemReference: 'FocusTraversalPolicy',
            effort: Effort.medium,
          ),
        );
      }

      previous = node;
    }

    handle.dispose();
    return findings;
  }

  String _nextId(String prefix) {
    _findingCounter++;
    return '$prefix-${_findingCounter.toString().padLeft(3, '0')}';
  }
}
