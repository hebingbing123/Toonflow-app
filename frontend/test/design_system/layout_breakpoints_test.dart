import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/layout_breakpoints.dart';

void main() {
  group('StudioBreakpoint.fromWidth', () {
    test('maps Kiro width tiers', () {
      expect(StudioBreakpoint.fromWidth(400), StudioBreakpoint.mobile);
      expect(StudioBreakpoint.fromWidth(600), StudioBreakpoint.tablet);
      expect(StudioBreakpoint.fromWidth(800), StudioBreakpoint.tablet);
      expect(StudioBreakpoint.fromWidth(960), StudioBreakpoint.desktop);
      expect(StudioBreakpoint.fromWidth(1500), StudioBreakpoint.wide);
    });

    test('boolean helpers', () {
      expect(StudioBreakpoint.fromWidth(500).isMobile, isTrue);
      expect(StudioBreakpoint.fromWidth(1400).isWide, isTrue);
      expect(StudioBreakpoint.fromWidth(1100).isDesktop, isTrue);
    });
  });
}
