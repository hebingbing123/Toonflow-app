import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/utils/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('should be a singleton', () {
      final logger1 = appLogger;
      final logger2 = appLogger;
      expect(identical(logger1, logger2), isTrue);
    });

    test('should log debug messages without error', () {
      expect(() => appLogger.debug('Debug message'), returnsNormally);
    });

    test('should log info messages without error', () {
      expect(() => appLogger.info('Info message'), returnsNormally);
    });

    test('should log warning messages without error', () {
      expect(() => appLogger.warning('Warning message'), returnsNormally);
    });

    test('should log error messages without error', () {
      expect(() => appLogger.error('Error message'), returnsNormally);
    });

    test('should log fatal messages without error', () {
      expect(() => appLogger.fatal('Fatal message'), returnsNormally);
    });

    test('should log user actions without metadata', () {
      expect(
        () => appLogger.logUserAction('button_click'),
        returnsNormally,
      );
    });

    test('should log user actions with metadata', () {
      expect(
        () => appLogger.logUserAction(
          'button_click',
          metadata: {'button_id': 'submit', 'screen': 'login'},
        ),
        returnsNormally,
      );
    });

    test('should log API calls with minimal info', () {
      expect(
        () => appLogger.logApiCall('/api/v1/test', 'GET'),
        returnsNormally,
      );
    });

    test('should log API calls with full info', () {
      expect(
        () => appLogger.logApiCall(
          '/api/v1/test',
          'POST',
          statusCode: 200,
          duration: const Duration(milliseconds: 150),
        ),
        returnsNormally,
      );
    });

    test('should log performance metrics without metadata', () {
      expect(
        () => appLogger.logPerformance(
          'render_frame',
          const Duration(milliseconds: 16),
        ),
        returnsNormally,
      );
    });

    test('should log performance metrics with metadata', () {
      expect(
        () => appLogger.logPerformance(
          'render_frame',
          const Duration(milliseconds: 16),
          metadata: {'frame_count': 60, 'dropped_frames': 2},
        ),
        returnsNormally,
      );
    });

    test('should handle errors with stack traces', () {
      try {
        throw Exception('Test exception');
      } catch (e, stackTrace) {
        expect(
          () => appLogger.error('Caught exception', e, stackTrace),
          returnsNormally,
        );
      }
    });
  });
}
