import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/section.dart';

/// **Validates: Requirements 13, 14, 15, 16**
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
      expect(getFormatDisplayName('mp4'), 'MP4 (推荐)');
      expect(getFormatDisplayName('mov'), 'MOV (高质量)');
      expect(getFormatDisplayName('webm'), 'WebM (网络优化)');
      expect(getFormatDisplayName('unknown'), 'UNKNOWN');
    });

    test('maps resolutions to display names', () {
      expect(getResolutionDisplayName('1080p'), '1080p (1920×1080)');
      expect(getResolutionDisplayName('720p'), '720p (1280×720)');
      expect(getResolutionDisplayName('480p'), '480p (854×480)');
      expect(getResolutionDisplayName('360p'), '360p (640×360)');
      expect(getResolutionDisplayName('unknown'), 'unknown');
    });

    test('maps bitrates to display names and values', () {
      expect(getBitrateDisplayName('high'), '高 (8 Mbps)');
      expect(getBitrateDisplayName('medium'), '中 (4 Mbps)');
      expect(getBitrateDisplayName('low'), '低 (2 Mbps)');
      expect(getBitrateDisplayName('unknown'), 'unknown');

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
        const MaterialApp(
          home: Scaffold(
            body: ExportSettingsDialog(
              initialSettings: ExportSettings(
                format: 'mov',
                resolution: '720p',
                bitrate: 'high',
                framerate: 60,
              ),
              estimatedDurationSeconds: 120,
            ),
          ),
        ),
      );

      expect(find.text('导出设置'), findsOneWidget);
      expect(find.text('MOV (高质量)'), findsOneWidget);
      expect(find.text('720p (1280×720)'), findsOneWidget);
      expect(find.text('高 (8 Mbps)'), findsOneWidget);
      expect(find.text('60 FPS'), findsOneWidget);
      expect(find.text('预估文件大小'), findsOneWidget);
      expect(find.text('基于 120 秒视频时长'), findsOneWidget);
      expect(
        find.text('导出时间取决于视频长度和质量设置。高质量设置将需要更长的处理时间。'),
        findsOneWidget,
      );
    });

    testWidgets('calculates estimated file size correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportSettingsDialog(
              initialSettings: ExportSettings(
                bitrate: 'medium', // 4000 kbps
              ),
              estimatedDurationSeconds: 60,
            ),
          ),
        ),
      );

      // File size = (4000 kbps * 60 seconds) / (8 * 1024) = ~29.3 MB
      expect(find.textContaining('MB'), findsWidgets);
    });

    testWidgets('updates estimated file size when bitrate changes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportSettingsDialog(
              initialSettings: ExportSettings(
                bitrate: 'low',
              ),
              estimatedDurationSeconds: 60,
            ),
          ),
        ),
      );

      // Initial size with low bitrate (2000 kbps)
      await tester.pumpAndSettle();

      // Change to high bitrate
      await tester.tap(find.text('低 (2 Mbps)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('高 (8 Mbps)').last);
      await tester.pumpAndSettle();

      // File size should increase
      expect(find.text('高 (8 Mbps)'), findsOneWidget);
    });

    testWidgets('allows changing all export settings', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportSettingsDialog(
              initialSettings: ExportSettings(),
            ),
          ),
        ),
      );

      // Change format
      await tester.tap(find.text('MP4 (推荐)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WebM (网络优化)').last);
      await tester.pumpAndSettle();
      expect(find.text('WebM (网络优化)'), findsOneWidget);

      // Change resolution
      await tester.tap(find.text('1080p (1920×1080)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('480p (854×480)').last);
      await tester.pumpAndSettle();
      expect(find.text('480p (854×480)'), findsOneWidget);

      // Change bitrate
      await tester.tap(find.text('中 (4 Mbps)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('低 (2 Mbps)').last);
      await tester.pumpAndSettle();
      expect(find.text('低 (2 Mbps)'), findsOneWidget);

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
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    result = await showDialog<ExportSettings>(
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
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Change format to WebM
      await tester.tap(find.text('MP4 (推荐)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WebM (网络优化)').last);
      await tester.pumpAndSettle();

      // Change resolution to 720p
      await tester.tap(find.text('1080p (1920×1080)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('720p (1280×720)').last);
      await tester.pumpAndSettle();

      // Change bitrate to high
      await tester.tap(find.text('中 (4 Mbps)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('高 (8 Mbps)').last);
      await tester.pumpAndSettle();

      // Change framerate to 60
      await tester.tap(find.text('30 FPS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('60 FPS').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('开始导出'));
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
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    result = await showDialog<ExportSettings>(
                      context: context,
                      builder: (_) => const ExportSettingsDialog(),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('handles missing duration gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportSettingsDialog(
              initialSettings: ExportSettings(),
              // No estimatedDurationSeconds provided
            ),
          ),
        ),
      );

      expect(find.text('导出设置'), findsOneWidget);
      expect(find.text('预估文件大小'), findsOneWidget);
      // Should not show duration text when not provided
      expect(find.textContaining('基于'), findsNothing);
    });

    testWidgets('formats file size correctly for different ranges',
        (tester) async {
      // Test small file (< 1 MB)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportSettingsDialog(
              initialSettings: ExportSettings(bitrate: 'low'),
              estimatedDurationSeconds: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('KB'), findsOneWidget);

      // Test medium file (MB range)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportSettingsDialog(
              initialSettings: ExportSettings(bitrate: 'medium'),
              estimatedDurationSeconds: 60,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('MB'), findsWidgets);

      // Test large file (GB range)
      // 8000 kbps * 7200 seconds / (8 * 1024) = ~7031 MB = ~6.87 GB
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportSettingsDialog(
              initialSettings: ExportSettings(bitrate: 'high'),
              estimatedDurationSeconds: 7200, // 2 hours
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('GB'), findsOneWidget);
    });
  });
}
