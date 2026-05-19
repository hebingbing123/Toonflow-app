import 'dart:ffi' as ffi;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:openflow_app/native_bridge/generated/api.dart';
import 'package:openflow_app/native_bridge/generated/frb_generated.dart';
import 'package:openflow_app/native_bridge/openflow_native_bridge.dart';

void main() {
  final bridge = OpenflowNativeBridge.instance;

  tearDown(() {
    bridge.resetForTest();
  });

  test('facade returns mock bridge health and timeline summary', () async {
    bridge.initializeMock(api: _FakeBridgeApi());

    final health = await bridge.bridgeHealth();
    final timeline = await bridge.createEmptyTimelineSummary();

    expect(health, isNotNull);
    expect(health!.desktopSupported, isTrue);
    expect(health.bridgeApiVersion, 1);
    expect(timeline, isNotNull);
    expect(timeline!.videoTrackCount, BigInt.zero);
    expect(timeline.audioTrackCount, BigInt.zero);
    expect(timeline.subtitleCount, BigInt.zero);
  });
}

class _FakeBridgeApi extends OpenflowCoreBridgeApiApi {
  static const _documentId = '00000000-0000-0000-0000-000000000001';

  @override
  Future<CoreBridgeHealth> crateApiBridgeHealth() async =>
      const CoreBridgeHealth(
        bridgeApiVersion: 1,
        rustCoreVersion: 'mock',
        desktopSupported: true,
      );

  @override
  Future<ImageDocument> crateApiNewImageDocument({
    required int width,
    required int height,
  }) async => _FakeImageDocument();

  @override
  Future<TimelineDocument> crateApiNewTimelineDocument() async =>
      _FakeTimelineDocument();

  @override
  Future<WorkflowDocument> crateApiNewWorkflowDocument() async =>
      _FakeWorkflowDocument();

  @override
  Future<ImageDocumentSummary> crateApiSummarizeImageDocument({
    required ImageDocument document,
  }) async => ImageDocumentSummary(
    documentId: _documentId,
    width: 1920,
    height: 1080,
    layerCount: BigInt.zero,
  );

  @override
  Future<TimelineSummary> crateApiSummarizeTimelineDocument({
    required TimelineDocument document,
  }) async => TimelineSummary(
    documentId: _documentId,
    revision: 0,
    videoTrackCount: BigInt.zero,
    audioTrackCount: BigInt.zero,
    subtitleCount: BigInt.zero,
  );

  @override
  Future<WorkflowSummary> crateApiSummarizeWorkflowDocument({
    required WorkflowDocument document,
  }) async => WorkflowSummary(
    documentId: _documentId,
    nodeCount: BigInt.zero,
    edgeCount: BigInt.zero,
  );

  @override
  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_ImageDocument => (_) {};

  @override
  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_ImageDocument => (_) {};

  @override
  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_ImageDocumentPtr => ffi.nullptr.cast();

  @override
  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_TimelineDocument => (_) {};

  @override
  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_TimelineDocument => (_) {};

  @override
  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_TimelineDocumentPtr => ffi.nullptr.cast();

  @override
  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_WorkflowDocument => (_) {};

  @override
  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_WorkflowDocument => (_) {};

  @override
  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_WorkflowDocumentPtr => ffi.nullptr.cast();
}

class _FakeImageDocument implements ImageDocument {
  @override
  bool get isDisposed => false;

  @override
  void dispose() {}
}

class _FakeTimelineDocument implements TimelineDocument {
  @override
  bool get isDisposed => false;

  @override
  void dispose() {}
}

class _FakeWorkflowDocument implements WorkflowDocument {
  @override
  bool get isDisposed => false;

  @override
  void dispose() {}
}
