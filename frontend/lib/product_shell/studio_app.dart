import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/debug/debug.dart';
import '../design_system/ix/studio_scaffold_messenger.dart';
import '../design_system/ix/studio_mobile_affordances.dart';
import '../design_system/ix/studio_scroll_behavior.dart';
import '../design_system/ix/studio_toast_overlay.dart';
import '../design_system/studio_adaptive_theme.dart';
import '../design_system/studio_motion.dart';
import '../design_system/theme.dart';
import '../l10n/app_localizations.dart';
import '../locale/app_locale_notifier.dart';
import '../platform/rust_api_feedback.dart';
import '../demo/product_demo_app_coach_host.dart';
import '../demo/product_demo_tour_shell_navigator.dart';
import '../shell/navigation_controller.dart';
import 'router.dart';
import 'studio_shell_navigation_scope.dart';

/// MaterialApp.router for Studio product shell.
class StudioProductApp extends StatefulWidget {
  const StudioProductApp({super.key});

  @override
  State<StudioProductApp> createState() => _StudioProductAppState();
}

class _StudioProductAppState extends State<StudioProductApp> {
  late final GoRouter _router = createStudioRouter();
  late final ShellNavigationController _shellNavigation =
      ShellNavigationController();

  @override
  void initState() {
    super.initState();
    ProductDemoTourShellNavigator.instance.attach(
      router: _router,
      shellNavigation: _shellNavigation,
    );
  }

  @override
  void dispose() {
    _shellNavigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudioShellNavigationScope(
      navigation: _shellNavigation,
      child: ListenableBuilder(
        listenable: AppLocaleNotifier.instance,
        builder: (context, _) {
          return StudioScaffoldMessenger(
            key: kRustApiRootScaffoldMessengerKey,
            child: MaterialApp.router(
              scrollBehavior: const StudioScrollBehavior(),
              debugShowCheckedModeBanner: false,
              theme: buildStudioLightTheme(),
              darkTheme: buildStudioDarkTheme(),
              themeMode: ThemeMode.system,
              onGenerateTitle: (ctx) =>
                  AppLocalizations.of(ctx)?.appTitle ??
                  lookupAppLocalizations(const Locale('en')).appTitle,
              locale: AppLocaleNotifier.instance.localeOrNull,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              localeResolutionCallback: (locale, supportedLocales) {
                if (locale == null) {
                  return supportedLocales.first;
                }
                for (final supported in supportedLocales) {
                  if (supported.languageCode == locale.languageCode) {
                    return supported;
                  }
                }
                return supportedLocales.first;
              },
              routerConfig: _router,
              builder: (context, child) {
                final adaptiveTheme = studioAdaptiveDesktopTheme(context);
                return StudioSystemUiSurface(
                  child: AnimatedTheme(
                    data: adaptiveTheme,
                    duration: studioAnimationDuration(
                      context,
                      const Duration(milliseconds: 240),
                    ),
                    curve: studioAnimationCurve(
                      context,
                      Curves.easeInOutCubicEmphasized,
                    ),
                    child: DebugErrorOverlayHost(
                      child: ProductDemoAppCoachHost(
                        child: StudioToastHost(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
