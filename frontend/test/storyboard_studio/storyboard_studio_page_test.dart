import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/storyboard_studio/storyboard_studio_page.dart';

Widget _wrapApp({required Widget child}) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  test('resolve storyboard studio project uuid keeps valid uuid', () async {
    final resolved = await resolveStoryboardStudioProjectUuid(
      accessToken: 'token',
      projectNumericId: 7,
      projectUuid: '00000000-0000-0000-0000-000000000099',
      resolveFromNumericId: (_, _) async => 'should-not-be-used',
    );

    expect(resolved, '00000000-0000-0000-0000-000000000099');
  });

  test(
    'resolve storyboard studio project uuid falls back from invalid scope',
    () async {
      final resolved = await resolveStoryboardStudioProjectUuid(
        accessToken: 'token',
        projectNumericId: 7,
        projectUuid: ':',
        resolveFromNumericId: (_, numericId) async =>
            '00000000-0000-0000-0000-0000000000$numericId',
      );

      expect(resolved, '00000000-0000-0000-0000-00000000007');
    },
  );

  testWidgets('storyboard studio renders chrome and grid action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapApp(
        child: StoryboardStudioPage(
          projectNumericId: 7,
          projectUuid: '00000000-0000-0000-0000-000000000099',
          accessToken: 'test-token',
          onOpenProductionWorkspace: ({required String projectUuid}) {},
          debugScripts: const [
            ScriptWorkbenchDetailRow(
              numericId: 1,
              name: 'Episode 1',
              relatedAssets: [],
            ),
          ],
          debugShots: const [
            ProductionStoryboardItemV1(
              id: 1,
              scriptId: 1,
              prompt: 'Shot prompt',
              state: 'draft',
              sbIndex: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Storyboard studio'), findsOneWidget);
    expect(find.text('Shots'), findsOneWidget);
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Grid mode'), findsOneWidget);
    expect(find.text('Open production'), findsWidgets);
    expect(find.textContaining('split into cells'), findsOneWidget);
  });

  testWidgets(
    'storyboard studio resolves invalid project uuid before opening production',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedProjectUuid;

      await tester.pumpWidget(
        _wrapApp(
          child: StoryboardStudioPage(
            projectNumericId: 7,
            projectUuid: ':',
            accessToken: 'test-token',
            projectUuidResolver: (_, _) async =>
                '00000000-0000-0000-0000-000000000007',
            onOpenProductionWorkspace: ({required String projectUuid}) {
              openedProjectUuid = projectUuid;
            },
            debugScripts: const [
              ScriptWorkbenchDetailRow(
                numericId: 1,
                name: 'Episode 1',
                relatedAssets: [],
              ),
            ],
            debugShots: const [
              ProductionStoryboardItemV1(
                id: 1,
                scriptId: 1,
                prompt: 'Shot prompt',
                state: 'draft',
                sbIndex: 1,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open production').first);
      await tester.pumpAndSettle();

      expect(openedProjectUuid, '00000000-0000-0000-0000-000000000007');
    },
  );

  testWidgets('storyboard studio empty shots shows one primary empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapApp(
        child: StoryboardStudioPage(
          projectNumericId: 7,
          projectUuid: '00000000-0000-0000-0000-000000000099',
          accessToken: 'test-token',
          onOpenProductionWorkspace: ({required String projectUuid}) {},
          debugScripts: const [
            ScriptWorkbenchDetailRow(
              numericId: 1,
              name: 'Episode 1',
              relatedAssets: [],
            ),
          ],
          debugShots: const <ProductionStoryboardItemV1>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No shots in this script yet. Add storyboards on the script step first.',
      ),
      findsOneWidget,
    );
    expect(find.text('No shots yet'), findsNothing);
    expect(find.text('Shots'), findsNothing);
    expect(find.text('Properties'), findsNothing);
    expect(find.text('Grid mode'), findsNothing);
    expect(find.text('Open Script'), findsWidgets);
  });

  testWidgets('storyboard studio close button uses explicit close action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var closeCount = 0;

    await tester.pumpWidget(
      _wrapApp(
        child: StoryboardStudioPage(
          projectNumericId: 7,
          projectUuid: '00000000-0000-0000-0000-000000000099',
          accessToken: 'test-token',
          onClose: () {
            closeCount += 1;
          },
          onOpenProductionWorkspace: ({required String projectUuid}) {},
          debugScripts: const [
            ScriptWorkbenchDetailRow(
              numericId: 1,
              name: 'Episode 1',
              relatedAssets: [],
            ),
          ],
          debugShots: const [
            ProductionStoryboardItemV1(
              id: 1,
              scriptId: 1,
              prompt: 'Shot prompt',
              state: 'draft',
              sbIndex: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(closeCount, 1);
  });
}
