import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/episode_console/episode_console_page.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

Widget _appWithRouter(GoRouter router) {
  return MaterialApp.router(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

Widget _page(BuildContext context) {
  return EpisodeConsolePage(
    projectNumericId: 7,
    scriptNumericId: 1,
    deliverChild: const Center(child: Text('deliver-body')),
    onOpenFullStudio: () => context.go('/projects/7/script'),
  );
}

void main() {
  testWidgets('episode console preview shows deliver child and beta label', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EpisodeConsolePage(
            projectNumericId: 7,
            scriptNumericId: 1,
            deliverChild: const Center(child: Text('deliver-body')),
            onOpenFullStudio: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget); // studioEpisodeConsoleBetaLabel (en)
    expect(find.text('deliver-body'), findsOneWidget);
  });

  testWidgets('episode console back fallback and full studio action route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/7/console/1',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/7/console/1',
          builder: (context, state) => _page(context),
        ),
        GoRoute(
          path: '/projects/7/deliver',
          builder: (context, state) =>
              const Scaffold(body: Text('deliver-route')),
        ),
        GoRoute(
          path: '/projects/7/script',
          builder: (context, state) =>
              const Scaffold(body: Text('full-studio-route')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_appWithRouter(router));
    await tester.pumpAndSettle();

    expect(find.text('Episode 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('deliver-route'), findsOneWidget);

    router.go('/projects/7/console/1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full studio'));
    await tester.pumpAndSettle();
    expect(find.text('full-studio-route'), findsOneWidget);
  });
}
