import 'dart:ffi';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:openflow_app/native_bridge/generated/api.dart';
import 'package:openflow_app/native_bridge/generated/frb_generated.dart';
import 'package:openflow_app/native_bridge/openflow_native_bridge.dart';

class _FakeTimelineDocument implements TimelineDocument {
  @override
  void dispose() {}

  @override
  bool get isDisposed => false;
}

class _FakeImageDocument implements ImageDocument {
  @override
  void dispose() {}

  @override
  bool get isDisposed => false;
}

class _FakeWorkflowDocument implements WorkflowDocument {
  @override
  void dispose() {}

  @override
  bool get isDisposed => false;
}

void _noopArc(PlatformPointer _) {}

/// Minimal [OpenflowCoreBridgeApiApi] for [OpenflowNativeBridge.initializeMock].
class FakeBridgeApi implements OpenflowCoreBridgeApiApi {
  static final TimelineDocument _timeline = _FakeTimelineDocument();
  static final ImageDocument _image = _FakeImageDocument();
  static final WorkflowDocument _workflow = _FakeWorkflowDocument();

  static final Pointer<NativeFinalizerFunction> _noopPtr =
      Pointer<NativeFinalizerFunction>.fromAddress(0);

  @override
  Future<CoreBridgeHealth> crateApiBridgeHealth() async {
    return const CoreBridgeHealth(
      bridgeApiVersion: kExpectedBridgeApiVersion,
      rustCoreVersion: 'test',
      desktopSupported: true,
    );
  }

  @override
  Future<TimelineDocument> crateApiNewTimelineDocument() async => _timeline;

  @override
  Future<TimelineSummary> crateApiSummarizeTimelineDocument({
    required TimelineDocument document,
  }) async {
    return TimelineSummary(
      documentId: 'fake-timeline',
      revision: 0,
      videoTrackCount: BigInt.zero,
      audioTrackCount: BigInt.zero,
      subtitleCount: BigInt.zero,
    );
  }

  @override
  Future<ImageDocument> crateApiNewImageDocument({
    required int width,
    required int height,
  }) async =>
      _image;

  @override
  Future<ImageDocumentSummary> crateApiSummarizeImageDocument({
    required ImageDocument document,
  }) async {
    return ImageDocumentSummary(
      documentId: 'fake-image',
      width: 1920,
      height: 1080,
      layerCount: BigInt.zero,
    );
  }

  @override
  Future<WorkflowDocument> crateApiNewWorkflowDocument() async => _workflow;

  @override
  Future<WorkflowSummary> crateApiSummarizeWorkflowDocument({
    required WorkflowDocument document,
  }) async {
    return WorkflowSummary(
      documentId: 'fake-workflow',
      nodeCount: BigInt.zero,
      edgeCount: BigInt.zero,
    );
  }

  @override
  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_ImageDocument => _noopArc;

  @override
  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_ImageDocument => _noopArc;

  @override
  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_ImageDocumentPtr =>
      _noopPtr;

  @override
  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_TimelineDocument => _noopArc;

  @override
  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_TimelineDocument => _noopArc;

  @override
  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_TimelineDocumentPtr => _noopPtr;

  @override
  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_WorkflowDocument => _noopArc;

  @override
  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_WorkflowDocument => _noopArc;

  @override
  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_WorkflowDocumentPtr => _noopPtr;
}
