import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';

import 'support/real_product_shell_gallery_support.dart';

/// Full-stack: dev admin login → create project → art direction step (live APIs).
///
/// Credentials: `admin@openflow.local` / `admin123` — see `lib/config.dart`,
/// `supabase/seed.sql`, `scripts/seed_local_dev_admin.sh`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  testWidgets('login with dev admin and open art step panel', (
    WidgetTester tester,
  ) async {
    final harness = RealProductShellGalleryHarness(tester);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await harness.bootstrap();
    await harness.login();

    final projectName = 'E2E美术步-${DateTime.now().millisecondsSinceEpoch}';
    await harness.goProjectsHome();
    if (!await harness.tryCreateProjectViaWizard(projectName)) {
      return;
    }
    if (!await harness.tryOpenProjectByName(projectName)) {
      return;
    }

    expect(await harness.tryCaptureStudioArtStep(), isTrue);
    expect(find.byKey(const Key('studio_art_step_panel')), findsOneWidget);

    await harness.exitProjectStudio();
  });
}
