import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fills studio pane height inside scroll parents and pins [footer] bottom-center.
class StudioPaneScaffold extends StatelessWidget {
  const StudioPaneScaffold({
    super.key,
    required this.body,
    this.footer,
    this.chromeReserve = 300,
    this.minBodyHeight = 280,
    this.footerHeight = 40,
  });

  final Widget body;
  final Widget? footer;
  final double chromeReserve;
  final double minBodyHeight;
  final double footerHeight;

  @override
  Widget build(BuildContext context) {
    final paneHeight = math.max(
      minBodyHeight,
      MediaQuery.sizeOf(context).height - chromeReserve,
    );
    final bottomInset = footer == null ? 0.0 : footerHeight;
    return SizedBox(
      height: paneHeight,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: body,
          ),
          if (footer != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: footer!,
            ),
        ],
      ),
    );
  }
}
