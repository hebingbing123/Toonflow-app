import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/product_shell/router.dart';

void main() {
  test('studio router exposes product entry routes', () {
    final router = createStudioRouter();

    expect(router.routeInformationProvider.value.uri.toString(), '/');
    expect(router.configuration.routes, isNotEmpty);

    router.dispose();
  });
}
