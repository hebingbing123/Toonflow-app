import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'debug_error_overlay_controller.dart';
import 'debug_overlay_widget.dart';

/// Renders [DebugOverlayWidget] above [child] when the controller has a snapshot.
///
/// Only listens in non-release builds; release builds pass [child] through unchanged.
class DebugErrorOverlayHost extends StatelessWidget {
  const DebugErrorOverlayHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return child;
    }
    return ValueListenableBuilder<DebugErrorSnapshot?>(
      valueListenable: DebugErrorOverlayController.instance.snapshot,
      builder: (context, snapshot, _) {
        if (snapshot == null) {
          return child;
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            child,
            DebugOverlayWidget(snapshot: snapshot),
          ],
        );
      },
    );
  }
}
