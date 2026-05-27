import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/platform/studio_load_state.dart';

void main() {
  group('resolveStudioPaneLoadState', () {
    test('error takes precedence', () {
      expect(
        resolveStudioPaneLoadState(
          reported: StudioLoadState.error,
          busy: true,
          hasData: false,
        ),
        StudioLoadState.error,
      );
    });

    test('busy or initial/loading maps to loading', () {
      expect(
        resolveStudioPaneLoadState(
          reported: StudioLoadState.success,
          busy: true,
          hasData: true,
        ),
        StudioLoadState.loading,
      );
      expect(
        resolveStudioPaneLoadState(
          reported: StudioLoadState.initial,
          hasData: false,
        ),
        StudioLoadState.loading,
      );
    });

    test('success without data maps to empty', () {
      expect(
        resolveStudioPaneLoadState(
          reported: StudioLoadState.success,
          hasData: false,
        ),
        StudioLoadState.empty,
      );
    });

    test('success with data stays success', () {
      expect(
        resolveStudioPaneLoadState(
          reported: StudioLoadState.success,
          hasData: true,
        ),
        StudioLoadState.success,
      );
    });
  });
}
