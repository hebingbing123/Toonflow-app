import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures a widget subtree to a [ui.Image] for golden comparison.
Future<ui.Image> captureWidgetToImage(
  WidgetTester tester,
  Widget widget, {
  required Size size,
}) async {
  final repaintKey = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Center(
        child: RepaintBoundary(
          key: repaintKey,
          child: SizedBox(width: size.width, height: size.height, child: widget),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(repaintKey),
  );
  return boundary.toImage(pixelRatio: 1.0);
}

String goldenPathForScenario(String scenarioId) {
  return '../goldens/ui_gallery/$scenarioId.png';
}

/// PR-checkable desktop layout goldens (parity with integration gallery names).
String goldenPathForDesktopLayout(String layoutName) {
  return '../goldens/desktop_layouts/$layoutName.png';
}
