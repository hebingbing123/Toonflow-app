import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loadFromPrefs does not notify when demo flags unchanged', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'product_demo_mode_enabled_v1': true,
      'product_demo_mode_guest_v1': true,
    });
    var notifyCount = 0;
    void onChanged() => notifyCount++;
    ProductDemoMode.instance.addListener(onChanged);
    await ProductDemoMode.instance.loadFromPrefs();
    expect(notifyCount, 1);
    await ProductDemoMode.instance.loadFromPrefs();
    expect(notifyCount, 1);
    ProductDemoMode.instance.removeListener(onChanged);
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
  });
}
