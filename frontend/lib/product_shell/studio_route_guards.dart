import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';

/// Redirect when Supabase session is required but missing.
String? studioAuthRedirect(GoRouterState state) {
  if (!kSupabaseConfigured) {
    return null;
  }
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    return null;
  }
  final returnTo = Uri.encodeComponent(state.uri.toString());
  return '/?returnTo=$returnTo';
}

/// Unknown project step slugs → project root redirect (testable helper).
String? studioProjectStepRedirectLocation({
  required String? projectNumericId,
  required String? stepSlug,
  required Set<String> validSlugs,
}) {
  if (stepSlug == null || validSlugs.contains(stepSlug)) {
    return null;
  }
  if (projectNumericId == null) {
    return '/';
  }
  return '/projects/$projectNumericId';
}

/// Unknown project step slugs → project root redirect.
String? studioProjectStepRedirect(GoRouterState state, {required Set<String> validSlugs}) {
  return studioProjectStepRedirectLocation(
    projectNumericId: state.pathParameters['projectNumericId'],
    stepSlug: state.pathParameters['stepSlug'],
    validSlugs: validSlugs,
  );
}

/// Full-screen 404 for unmatched studio routes.
class StudioNotFoundPage extends StatelessWidget {
  const StudioNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.studioNotFoundPageTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: Text(l10n.studioNotFoundBackToHome),
            ),
          ],
        ),
      ),
    );
  }
}
