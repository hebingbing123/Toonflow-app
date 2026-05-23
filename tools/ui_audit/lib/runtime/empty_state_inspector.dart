import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/models.dart';

/// Runtime checks for empty list/grid treatment.
class EmptyStateInspector {
  int _findingCounter = 0;

  List<Finding> inspect(
    WidgetController tester, {
    required String fixtureName,
  }) {
    final findings = <Finding>[];
    _findingCounter = 0;

    final listViews = find.byType(ListView);
    final gridViews = find.byType(GridView);
    final emptyStateWidgets = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().contains('StudioEmptyState'),
    );

    if ((listViews.evaluate().isNotEmpty || gridViews.evaluate().isNotEmpty) &&
        emptyStateWidgets.evaluate().isEmpty) {
      final hasEmptyText = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.isNotEmpty ?? false),
      );

      if (hasEmptyText.evaluate().isEmpty) {
        findings.add(
          Finding(
            id: _nextId('ES'),
            category: FindingCategory.emptyStates,
            severity: Severity.high,
            title: 'Empty state treatment missing',
            description:
                'List/grid rendered without StudioEmptyState or descriptive text ($fixtureName)',
            location: Location(file: fixtureName, line: 1, column: 1),
            recommendation:
                'Use StudioEmptyState with descriptive copy and optional primary action',
            designSystemReference: 'StudioEmptyState',
            effort: Effort.medium,
          ),
        );
      }
    }

    return findings;
  }

  String _nextId(String prefix) {
    _findingCounter++;
    return '$prefix-${_findingCounter.toString().padLeft(3, '0')}';
  }
}
