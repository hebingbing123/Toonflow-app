import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/content_compliance/controller.dart';
import 'package:openflow_app/demo/product_demo_catalog.dart';
import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/rust_api/core.dart';
import 'package:openflow_app/jobs/controller.dart';
import 'package:openflow_app/l10n/app_localizations_en.dart';
import 'package:openflow_app/notifications/controller.dart';
import 'package:openflow_app/projects/controller.dart';
import 'package:openflow_app/quality_reviews/controller.dart';
import 'package:openflow_app/task_center/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProductDemoMode.instance.disable();
  });

  test('enable guest demo skips live project list loads', () async {
    await ProductDemoMode.instance.enable(guest: true);
    final l10n = AppLocalizationsEn();
    final controller = ProjectsController(
      accessTokenProvider: () => ProductDemoMode.guestAccessToken,
      onErrorChanged: (_) {},
      l10nProvider: () => l10n,
    );
    ProductDemoCatalog.buildDefault(l10n).applyTo(
      projectsController: controller,
      taskCenterController: TaskCenterController(
        accessTokenProvider: () => ProductDemoMode.guestAccessToken,
        onErrorChanged: (_) {},
        l10nProvider: () => l10n,
        projectIdTextProvider: () => '',
        projectUuidTextProvider: () => '',
      ),
      jobsController: JobsController(
        accessTokenProvider: () => ProductDemoMode.guestAccessToken,
        onErrorChanged: (_) {},
        l10nProvider: () => l10n,
      ),
      qualityReviewsController: QualityReviewsController(
        accessTokenProvider: () => ProductDemoMode.guestAccessToken,
        onErrorChanged: (_) {},
        l10nProvider: () => l10n,
      ),
      notificationsController: NotificationsController(
        accessTokenProvider: () => ProductDemoMode.guestAccessToken,
        onErrorChanged: (_) {},
        l10nProvider: () => l10n,
      ),
      contentComplianceController: ContentComplianceController(
        accessTokenProvider: () => ProductDemoMode.guestAccessToken,
        onErrorChanged: (_) {},
        l10nProvider: () => l10n,
      ),
    );

    expect(controller.projects, isNotNull);
    expect(controller.skipDemoApi, isTrue);

    await controller.loadProjects();

    expect(controller.loadingProjects, isFalse);
    expect(controller.projects, isNotEmpty);
  });

  test('suppresses JWT errors while demo mode is active', () async {
    await ProductDemoMode.instance.enable(guest: true);
    final jwtError = RustApiException(
      '{"code":"invalid_token","message":"JWT verification failed","status":401}',
      statusCode: 401,
    );
    expect(ProductDemoMode.shouldSuppressDemoApiError(jwtError), isTrue);
    await ProductDemoMode.instance.disable();
    expect(ProductDemoMode.shouldSuppressDemoApiError(jwtError), isFalse);
  });
}
