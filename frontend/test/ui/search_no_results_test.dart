import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

import '../support/studio_golden_app.dart';

/// Visual contract for global search empty results (mirrors SearchResultsPage).
Widget buildSearchNoResultsIllustration(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.globalSearchNoResultsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.globalSearchNoResultsHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('search empty state shows localized no-results copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      studioGoldenApp(
        child: Builder(builder: buildSearchNoResultsIllustration),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('未找到匹配结果'), findsOneWidget);
    expect(find.text('请尝试其他关键词'), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
