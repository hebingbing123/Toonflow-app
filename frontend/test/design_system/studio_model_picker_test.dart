import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_model_picker.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  testWidgets('studio model picker lists catalog entries', (tester) async {
    const models = <ModelListEntry>[
      ModelListEntry(
        id: 1,
        label: 'GPT-4o mini',
        value: 'gpt-4o-mini',
        type: 'text',
        name: 'OpenAI',
        modelId: '1:gpt-4o-mini',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioModelPicker(
            models: models,
            selectedModelId: '1:gpt-4o-mini',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Model'), findsOneWidget);
    expect(find.textContaining('GPT-4o mini'), findsWidgets);
  });
}
