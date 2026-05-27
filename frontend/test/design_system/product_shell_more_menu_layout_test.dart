import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/layout_breakpoints.dart';

void main() {
  test('productShellMoreMenuPanelWidth caps desktop overlay width', () {
    expect(productShellMoreMenuPanelWidth(1920), 360);
    expect(productShellMoreMenuPanelWidth(1280), 340);
    expect(productShellMoreMenuPanelWidth(960), 320);
  });

  test('productShellMoreMenuUsesBottomSheet at compact shell widths', () {
    expect(productShellMoreMenuUsesBottomSheet(860), isTrue);
    expect(productShellMoreMenuUsesBottomSheet(375), isTrue);
    expect(productShellMoreMenuUsesBottomSheet(861), isFalse);
  });

  test('productShellMoreMenuPanelWidth on handset uses viewport minus margin', () {
    expect(productShellMoreMenuPanelWidth(375, horizontalMargin: 12), 351);
  });
}
