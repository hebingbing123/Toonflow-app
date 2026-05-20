import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/native_bridge/openflow_native_bridge.dart';

import 'bridge_api_test_fakes.dart';

void main() {
  final bridge = OpenflowNativeBridge.instance;

  tearDown(() {
    bridge.resetForTest();
  });

  test('facade returns mock bridge health and timeline summary', () async {
    bridge.initializeMock(api: FakeBridgeApi());

    final health = await bridge.bridgeHealth();
    final timeline = await bridge.createEmptyTimelineSummary();

    expect(health, isNotNull);
    expect(health!.desktopSupported, isTrue);
    expect(health.bridgeApiVersion, kExpectedBridgeApiVersion);
    expect(timeline, isNotNull);
    expect(timeline!.videoTrackCount, BigInt.zero);
    expect(timeline.audioTrackCount, BigInt.zero);
    expect(timeline.subtitleCount, BigInt.zero);

    expect(
      () => bridge.createImageDocumentSummary(width: 0, height: 1080),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => bridge.createImageDocumentSummary(width: 1920, height: 0),
      throwsA(isA<ArgumentError>()),
    );
  });
}
