import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/l10n/app_localizations_en.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';

import 'support/ignore_layout_overflow.dart';
import 'support/product_shell_overlay_harness.dart';

void main() {
  installLayoutOverflowIgnoreForTests();

  testWidgets(
    'home page can render storyboard overlay with injected auth seam',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(2560, 1440));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = productShellStoryboardOverlayRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        productShellOverlayTestApp(router, size: const Size(2560, 1440)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final l10n = AppLocalizationsEn();
      expect(find.text(l10n.studioStoryboardStudioTitle), findsOneWidget);
      expect(find.text(l10n.appTitle), findsOneWidget);
      expect(find.byKey(const Key('product-auth-submit')), findsNothing);
    },
  );

  testWidgets(
    'home page can render episode console overlay with injected auth seam',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(2560, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/projects/7/console/3',
        routes: <RouteBase>[
          GoRoute(
            path: '/projects/:projectNumericId/console/:scriptNumericId',
            builder: (context, state) => productShellOverlayHomePage(
              overlay: StudioOverlayMode.episodeConsole,
              projectNumericId: int.parse(
                state.pathParameters['projectNumericId']!,
              ),
              scriptNumericId: int.parse(
                state.pathParameters['scriptNumericId']!,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        productShellOverlayTestApp(
          router,
          size: const Size(2560, 2000),
        ),
      );
      await pumpIgnoringBenignLayoutOverflow(tester);
      await pumpIgnoringBenignLayoutOverflow(
        tester,
        const Duration(milliseconds: 500),
      );

      final l10n = AppLocalizationsEn();
      expect(find.text(l10n.studioEpisodeConsoleTitle(3)), findsOneWidget);
      expect(find.text(l10n.studioOpenFullStudio), findsOneWidget);
      expect(find.byKey(const Key('product-auth-submit')), findsNothing);
    },
  );

  testWidgets(
    'home page can render project studio overlay with injected auth seam',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(2560, 1440));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/projects/7/script',
        routes: <RouteBase>[
          GoRoute(
            path: '/projects/:projectNumericId/:stepSlug',
            builder: (context, state) => productShellOverlayHomePage(
              overlay: StudioOverlayMode.projectStudio,
              projectNumericId: int.parse(
                state.pathParameters['projectNumericId']!,
              ),
              stepSlug: state.pathParameters['stepSlug'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        productShellOverlayTestApp(router, size: const Size(2560, 1440)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Project Delta'), findsOneWidget);
      expect(find.byKey(const Key('product-auth-submit')), findsNothing);
    },
  );
}
