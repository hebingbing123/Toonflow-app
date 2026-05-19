import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/short_video_space/section.dart';

import '../support/studio_golden_app.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

void main() {
  testWidgets('voiceover settings dialog renders provider controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      studioGoldenApp(
        child: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                onPressed: () {
                  showStudioDialog<void>(
                    context: context,
                    builder: (_) => const VoiceoverSettingsDialog(),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(StudioAlertDialog), findsOneWidget);
    expect(find.byType(StudioDropdownButtonFormField<String>), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voiceover settings dialog shows preview action when enabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      studioGoldenApp(
        child: const Scaffold(
          body: VoiceoverSettingsDialog(
            onPreviewRequested: _previewStub,
            onPreviewAudioReady: _previewPlayStub,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}

Future<Uint8List> _previewStub(VoiceoverSettings settings) async {
  return Uint8List.fromList(<int>[1, 2, 3, 4]);
}

Future<void> _previewPlayStub(Uint8List bytes) async {}
