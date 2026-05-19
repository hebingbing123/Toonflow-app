// Canonical quality_stale golden: test/ui/quality_stale_golden_test.dart
// Desktop layout goldens: test/ui/desktop_layout_widget_gallery_test.dart
// Integration PNG gallery: integration_test/desktop_layout_gallery_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('golden gallery moved to widget tests', () {
    // Keeps workflow_dispatch job hook stable until CI references are updated.
  });
}
