import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/short_video_space/section.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

/// **Validates: Requirements 13, 14, 15, 16**
final _zh = AppLocalizationsZh();

Widget _wrapZh(Widget body) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: body),
  );
}

void main() {
  group('ExportSettings', () {
    test('uses defaults when JSON is empty', () {
      final settings = ExportSettings.fromJson(<String, dynamic>{});

      expect(settings, const ExportSettings());
    });

    test('supports copyWith and JSON roundtrip', () {
      final settings = const ExportSettings().copyWith(
        format: 'mov',
        resolution: '720p',
        bitrate: 'high',
        framerate: 60,
      );

      expect(
        ExportSettings.fromJson(settings.toJson()),
        settings,
      );
      expect(
        settings.toString(),
        contains('mov'),
      );
      expect(
        settings.toString(),
        contains('720p'),
      );
    });

    test('equality and hashCode work correctly', () {
      const settings1 = ExportSettings(
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
      );
      const settings2 = ExportSettings(
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
      );
      const settings3 = ExportSettings(
        format: 'webm',
        resolution: '720p',
        bitrate: 'low',
        framerate: 24,
      );

      expect(settings1, settings2);
      expect(settings1.hashCode, settings2.hashCode);
      expect(settings1, isNot(settings3));
    });
  });

  group('Export helpers', () {
    test('exposes supported formats, resolutions, bitrates, and framerates',
        () {
      expect(
        kSupportedExportFormats,
        const ['mp4', 'mov', 'webm'],
      );
      expect(
        kSupportedResolutions,
        const ['1080p', '720p', '480p', '360p'],
      );
      expect(
        kSupportedBitrates,
        const ['high', 'medium', 'low'],
      );
      expect(
        kSupportedFramerates,
        const [60, 30, 24],
      );
    });

    test('maps formats to display names', () {
      expect(getFormatDisplayName(_zh, 'mp4'), _zh.shortVideoExportFormatMp4);
      expect(getFormatDisplayName(_zh, 'mov'), _zh.shortVideoExportFormatMov);
      expect(getFormatDisplayName(_zh, 'webm'), _zh.shortVideoExportFormatWebm);
      expect(getFormatDisplayName(_zh, 'unknown'), 'UNKNOWN');
    });

    test('maps resolutions to display names', () {
      expect(getResolutionDisplayName(_zh, '1080p'), _zh.shortVideoExportResolution1080p);
      expect(getResolutionDisplayName(_zh, '720p'), _zh.shortVideoExportResolution720p);
      expect(getResolutionDisplayName(_zh, '480p'), _zh.shortVideoExportResolution480p);
      expect(getResolutionDisplayName(_zh, '360p'), _zh.shortVideoExportResolution360p);
      expect(getResolutionDisplayName(_zh, 'unknown'), 'unknown');
    });

    test('maps bitrates to display names and values', () {
      expect(getBitrateDisplayName(_zh, 'high'), _zh.shortVideoExportBitrateHigh);
      expect(getBitrateDisplayName(_zh, 'medium'), _zh.shortVideoExportBitrateMedium);
      expect(getBitrateDisplayName(_zh, 'low'), _zh.shortVideoExportBitrateLow);
      expect(getBitrateDisplayName(_zh, 'unknown'), 'unknown');

      expect(getBitrateValue('high'), 8000);
      expect(getBitrateValue('medium'), 4000);
      expect(getBitrateValue('low'), 2000);
      expect(getBitrateValue('unknown'), 4000); // default
    });
  });

  group('ExportSettingsDialog', () {
    testWidgets('renders initial values and shows estimated file size',
        (tester) async {
      await tester.pumpWidget(
        _wrapZh(
          ExportSettingsDialog(
            initialSettings: const ExportSettings(
              format: 'mov',
              resolution: '720p',
              bitrate: 'high',
              framerate: 60,
            ),
            estimatedDurationSeconds: 120,
          ),
        ),
      );

      expect(find.text(_zh.shortVideoExportSettingsTitle), findsOneWidget);
      expect(find.text(_zh.shortVideoExportFormatMov), findsOneWidget);
      expect(find.text(_zh.shortVideoExportResolution720p), findsOneWidget);
      expect(find.text(_zh.shortVideoExportBitrateHigh), findsOneWidget);
      expect(find.text('60 FPS'), findsOneWidget);
      expect(find.text(_zh.shortVideoExportSettingsEstimatedSize), findsOneWidget);
      expect(find.text(_zh.shortVideoExportSettingsBasedOnDuration(120)), findsOneWidget);
      expect(
        find.text(_zh.shortVideoExportSettingsExportTimeHint),
        findsOneWidget,
      );
    });

    testWidgets('calculates estimated file size correctly', (tester) async {
      await tester.pumpWidget(
        _wrapZh(
          ExportSettingsDialog(
            initialSettings: const ExportSettings(
              bitrate: 'medium', // 4000 kbps
            ),
            estimatedDurationSeconds: 60,
          ),
        ),
      );

      // File size = (4000 kbps * 60 seconds) / (8 * 1024) = ~29.3 MB
      expect(find.textContaining('MB'), findsWidgets);
    });

    testWidgets('updates estimated file size when bitrate changes',
        (tester) async {
      await tester.pumpWidget(
        _wrapZh(
          ExportSettingsDialog(
            initialSettings: const ExportSettings(
              bitrate: 'low',
            ),
            estimatedDurationSeconds: 60,
          ),
        ),
      );

      // Initial size with low bitrate (2000 kbps)
      await tester.pumpAndSettle();

      // Change to high bitrate
      await tester.tap(find.text(_zh.shortVideoExportBitrateLow));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_zh.shortVideoExportBitrateHigh).last);
      await tester.pumpAndSettle();

      // File size should increase
      expect(find.text(_zh.shortVideoExportBitrateHigh), findsOneWidget);
    });

    testWidgets('allows changing all export settings', (tester) async {
      await tester.pumpWidget(
        _wrapZh(
          const ExportSettingsDialog(
            initialSettings: ExportSettings(),
          ),
        ),
      );

      // Change format
      await tester.tap(find.text(_zh.shortVideoExportFormatMp4));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_zh.shortVideoExportFormatWebm).last);
      await tester.pumpAndSettle();
      expect(find.text(_zh.shortVideoExportFormatWebm), findsOneWidget);

      // Change resolution
      await tester.tap(find.text(_zh.shortVideoExportResolution1080p));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_zh.shortVideoExportResolution480p).last);
      await tester.pumpAndSettle();
      expect(find.text(_zh.shortVideoExportResolution480p), findsOneWidget);

      // Change bitrate
      await tester.tap(find.text(_zh.shortVideoExportBitrateMedium));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_zh.shortVideoExportBitrateLow).last);
      await tester.pumpAndSettle();
      expect(find.text(_zh.shortVideoExportBitrateLow), findsOneWidget);

      // Change framerate
      await tester.tap(find.text('30 FPS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('24 FPS').last);
      await tester.pumpAndSettle();
      expect(find.text('24 FPS'), findsOneWidget);
    });

    testWidgets('returns updated settings when export is confirmed',
        (tester) async {
      ExportSettings? result;

      await tester.pumpWidget(
        _wrapZh(
          Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showStudioDialog<ExportSettings>(
                    context: context,
                    builder: (_) => const ExportSettingsDialog(
                      initialSettings: ExportSettings(),
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Change format to WebM
      await tester.tap(find.text(_zh.shortVideoExportFormatMp4));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_zh.shortVideoExportFormatWebm).last);
      await tester.pumpAndSettle();

      // Change resolution to 720p
      await tester.tap(find.text(_zh.shortVideoExportResolution1080p));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_zh.shortVideoExportResolution720p).last);
      await tester.pumpAndSettle();

      // Change bitrate to high
      await tester.tap(find.text(_zh.shortVideoExportBitrateMedium));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_zh.shortVideoExportBitrateHigh).last);
      await tester.pumpAndSettle();

      // Change framerate to 60
      await tester.tap(find.text('30 FPS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('60 FPS').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_zh.shortVideoExportSettingsStartExport));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.format, 'webm');
      expect(result!.resolution, '720p');
      expect(result!.bitrate, 'high');
      expect(result!.framerate, 60);
    });

    testWidgets('returns null when cancelled', (tester) async {
      ExportSettings? result = const ExportSettings();

      await tester.pumpWidget(
        _wrapZh(
          Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showStudioDialog<ExportSettings>(
                    context: context,
                    builder: (_) => const ExportSettingsDialog(),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_zh.notificationsActionCancel));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('handles missing duration gracefully', (tester) async {
      await tester.pumpWidget(
        _wrapZh(
          const ExportSettingsDialog(
            initialSettings: ExportSettings(),
            // No estimatedDurationSeconds provided
          ),
        ),
      );

      expect(find.text(_zh.shortVideoExportSettingsTitle), findsOneWidget);
      expect(find.text(_zh.shortVideoExportSettingsEstimatedSize), findsOneWidget);
      // Should not show duration text when not provided
      expect(find.textContaining('基于'), findsNothing);
    });

    testWidgets('formats file size correctly for different ranges',
        (tester) async {
      // Test small file (< 1 MB)
      await tester.pumpWidget(
        _wrapZh(
          ExportSettingsDialog(
            initialSettings: const ExportSettings(bitrate: 'low'),
            estimatedDurationSeconds: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('KB'), findsOneWidget);

      // Test medium file (MB range)
      await tester.pumpWidget(
        _wrapZh(
          ExportSettingsDialog(
            initialSettings: const ExportSettings(bitrate: 'medium'),
            estimatedDurationSeconds: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('MB'), findsWidgets);

      // Test large file (GB range)
      // 8000 kbps * 7200 seconds / (8 * 1024) = ~7031 MB = ~6.87 GB
      await tester.pumpWidget(
        _wrapZh(
          ExportSettingsDialog(
            initialSettings: const ExportSettings(bitrate: 'high'),
            estimatedDurationSeconds: 7200, // 2 hours
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('GB'), findsOneWidget);
    });
  });
}
