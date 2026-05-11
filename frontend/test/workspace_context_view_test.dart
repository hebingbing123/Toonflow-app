import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/shell/workspace_context_view.dart';

Widget _l10nApp(Widget body, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: body),
  );
}

void main() {
  testWidgets('workspace context view renders workspace and project scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      _l10nApp(
        const WorkspaceContextView(
          loading: false,
          workspaceName: 'Personal Workspace',
          workspaceType: 'personal',
          projectLabel: 'Project #12 · Palace Episode',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal Workspace'), findsOneWidget);
    expect(find.text('personal'), findsOneWidget);
    expect(find.text('Project #12 · Palace Episode'), findsOneWidget);
  });

  testWidgets(
    'workspace context view displays workspace billing when billing_scope=workspace',
    (tester) async {
      await tester.pumpWidget(
        _l10nApp(
          const WorkspaceContextView(
            loading: false,
            workspaceName: 'Enterprise Workspace',
            workspaceType: 'enterprise',
            projectLabel: 'Project #42 · Test Project',
            billingScope: 'workspace',
            workspacePlanTier: 'enterprise',
            workspaceDailyJobQuota: 1000,
            workspaceJobsToday: 250,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace billing'), findsOneWidget);
      expect(find.text('Plan: enterprise'), findsOneWidget);
      expect(find.text('Daily quota: 1000'), findsOneWidget);
      expect(find.text('250 / 1000'), findsOneWidget);
      expect(find.text('25% used'), findsOneWidget);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'workspace context view hides billing when billing_scope=user',
    (tester) async {
      await tester.pumpWidget(
        _l10nApp(
          const WorkspaceContextView(
            loading: false,
            workspaceName: 'Personal Workspace',
            workspaceType: 'personal',
            projectLabel: 'Project #12 · Test',
            billingScope: 'user',
            workspacePlanTier: 'pro',
            workspaceDailyJobQuota: 100,
            workspaceJobsToday: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace billing'), findsNothing);
      expect(find.text('Plan: pro'), findsNothing);
    },
  );

  testWidgets(
    'workspace context view hides billing when billingScope is null',
    (tester) async {
      await tester.pumpWidget(
        _l10nApp(
          const WorkspaceContextView(
            loading: false,
            workspaceName: 'Personal Workspace',
            workspaceType: 'personal',
            projectLabel: 'Project #12 · Test',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace billing'), findsNothing);
    },
  );

  testWidgets(
    'workspace context view displays unlimited quota correctly',
    (tester) async {
      await tester.pumpWidget(
        _l10nApp(
          const WorkspaceContextView(
            loading: false,
            workspaceName: 'Enterprise Workspace',
            workspaceType: 'enterprise',
            projectLabel: 'Project #42 · Test Project',
            billingScope: 'workspace',
            workspacePlanTier: 'enterprise',
            workspaceDailyJobQuota: null,
            workspaceJobsToday: 500,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace billing'), findsOneWidget);
      expect(find.text('Plan: enterprise'), findsOneWidget);
      expect(find.text('Daily quota: Unlimited'), findsOneWidget);
      expect(find.text('500 / Unlimited'), findsOneWidget);

      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'workspace context view shows error color when quota exceeded',
    (tester) async {
      await tester.pumpWidget(
        _l10nApp(
          const WorkspaceContextView(
            loading: false,
            workspaceName: 'Enterprise Workspace',
            workspaceType: 'enterprise',
            projectLabel: 'Project #42 · Test Project',
            billingScope: 'workspace',
            workspacePlanTier: 'enterprise',
            workspaceDailyJobQuota: 100,
            workspaceJobsToday: 150,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace billing'), findsOneWidget);
      expect(find.text('150 / 100'), findsOneWidget);
      expect(find.text('100% used'), findsOneWidget);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('workspace context billing title in zh locale', (tester) async {
    await tester.pumpWidget(
      _l10nApp(
        const WorkspaceContextView(
          loading: false,
          workspaceName: 'W',
          workspaceType: 'enterprise',
          projectLabel: 'P',
          billingScope: 'workspace',
          workspacePlanTier: 'pro',
          workspaceDailyJobQuota: 10,
          workspaceJobsToday: 1,
        ),
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('工作区计费'), findsOneWidget);
  });
}
