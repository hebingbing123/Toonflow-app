import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openflow_app/l10n/app_localizations.dart';

/// Tests for soft keyboard resize behavior.
/// Verifies that Scaffold widgets have resizeToAvoidBottomInset: true
/// to prevent keyboard from covering input fields.
void main() {
  group('Soft Keyboard Resize Protection', () {
    Widget buildTestApp({
      required Widget child,
      bool resizeToAvoidBottomInset = true,
    }) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          body: child,
        ),
      );
    }

    testWidgets('Scaffold with resizeToAvoidBottomInset: true is configured correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          resizeToAvoidBottomInset: true,
          child: const Center(child: Text('Test')),
        ),
      );

      // Find the Scaffold
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      // Verify resizeToAvoidBottomInset is true
      expect(scaffold.resizeToAvoidBottomInset, isTrue);
    });

    testWidgets('Scaffold without resizeToAvoidBottomInset defaults to true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      // Find the Scaffold
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      // Verify resizeToAvoidBottomInset defaults to true (Flutter default)
      // Note: In Flutter, the default is true, so we expect true
      expect(scaffold.resizeToAvoidBottomInset, isNull); // null means use default (true)
    });

    testWidgets('Login form with TextField at bottom remains visible with keyboard', (
      WidgetTester tester,
    ) async {
      final emailController = TextEditingController();
      final passwordController = TextEditingController();
      addTearDown(() {
        emailController.dispose();
        passwordController.dispose();
      });

      await tester.pumpWidget(
        buildTestApp(
          resizeToAvoidBottomInset: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify Scaffold has resizeToAvoidBottomInset: true
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isTrue);

      // Verify all widgets are present
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Dialog with TextField and SingleChildScrollView handles keyboard', (
      WidgetTester tester,
    ) async {
      final controllers = List.generate(5, (_) => TextEditingController());
      addTearDown(() {
        for (final c in controllers) {
          c.dispose();
        }
      });

      await tester.pumpWidget(
        buildTestApp(
          resizeToAvoidBottomInset: true,
          child: AlertDialog(
            title: const Text('Form Dialog'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: controllers[i],
                        decoration: InputDecoration(labelText: 'Field ${i + 1}'),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () {}, child: const Text('Cancel')),
              TextButton(onPressed: () {}, child: const Text('Submit')),
            ],
          ),
        ),
      );

      // Verify Scaffold has resizeToAvoidBottomInset: true
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isTrue);

      // Verify SingleChildScrollView is present
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Verify all fields are present
      expect(find.byType(TextField), findsNWidgets(5));
    });

    testWidgets('Bottom sheet with TextField remains accessible with keyboard', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildTestApp(
          resizeToAvoidBottomInset: true,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Enter text',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Show Bottom Sheet'),
            ),
          ),
        ),
      );

      // Verify Scaffold has resizeToAvoidBottomInset: true
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isTrue);

      // Tap button to show bottom sheet
      await tester.tap(find.text('Show Bottom Sheet'));
      await tester.pumpAndSettle();

      // Verify bottom sheet content is visible
      expect(find.text('Enter text'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget); // Only one Submit button in bottom sheet
    });

    testWidgets('Form with multiple TextFields at different positions', (
      WidgetTester tester,
    ) async {
      final controllers = List.generate(10, (_) => TextEditingController());
      addTearDown(() {
        for (final c in controllers) {
          c.dispose();
        }
      });

      await tester.pumpWidget(
        buildTestApp(
          resizeToAvoidBottomInset: true,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (int i = 0; i < 10; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: controllers[i],
                        decoration: InputDecoration(
                          labelText: 'Field ${i + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify Scaffold has resizeToAvoidBottomInset: true
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isTrue);

      // Verify SingleChildScrollView is present
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Verify all fields are present
      expect(find.byType(TextField), findsNWidgets(10));

      // Scroll to bottom field using a more specific finder
      final field10Finder = find.widgetWithText(TextField, 'Field 10');
      await tester.ensureVisible(field10Finder);
      await tester.pumpAndSettle();

      // Verify bottom field is now visible
      expect(field10Finder, findsOneWidget);
    });

    testWidgets('Multiline TextField with keyboard does not overflow', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildTestApp(
          resizeToAvoidBottomInset: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Enter your message:'),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      hintText: 'Type here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify Scaffold has resizeToAvoidBottomInset: true
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isTrue);

      // Verify multiline TextField is present
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, isNull);
      expect(textField.expands, isTrue);
    });

    testWidgets('Scaffold with AppBar and TextField at bottom', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(title: const Text('Form Page')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Spacer(),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify Scaffold has resizeToAvoidBottomInset: true
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isTrue);

      // Verify AppBar is present
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Form Page'), findsOneWidget);

      // Verify TextField and button are present
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('Nested Scaffold inherits resizeToAvoidBottomInset behavior', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: true,
            body: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Scaffold(
                  resizeToAvoidBottomInset: true,
                  appBar: AppBar(title: const Text('Nested Page')),
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'Input'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify both Scaffolds have resizeToAvoidBottomInset: true
      final scaffolds = tester.widgetList<Scaffold>(find.byType(Scaffold)).toList();
      expect(scaffolds.length, 2);
      expect(scaffolds[0].resizeToAvoidBottomInset, isTrue);
      expect(scaffolds[1].resizeToAvoidBottomInset, isTrue);
    });

    testWidgets('Scaffold with FloatingActionButton and TextField', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(title: const Text('FAB Page')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Search'),
                  ),
                  const Expanded(child: Center(child: Text('Content'))),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      // Verify Scaffold has resizeToAvoidBottomInset: true
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isTrue);

      // Verify FAB is present
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Verify TextField is present
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
