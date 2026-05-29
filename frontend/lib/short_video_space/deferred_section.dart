import 'package:flutter/material.dart';

import '../design_system/components/studio_loading_placeholders.dart';
import '../design_system/studio_scheduler.dart';
import '../design_system/tokens.dart';

/// Delays mounting heavy short-video subtree until after first frame (stage 14).
class ShortVideoDeferredBody extends StatefulWidget {
  const ShortVideoDeferredBody({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 32),
  });

  final Widget child;
  final Duration delay;

  @override
  State<ShortVideoDeferredBody> createState() => _ShortVideoDeferredBodyState();
}

class _ShortVideoDeferredBodyState extends State<ShortVideoDeferredBody> {
  var _ready = false;

  @override
  void initState() {
    super.initState();
    StudioScheduler.scheduleOnceUntil('short_video_deferred_body', () async {
      await Future<void>.delayed(widget.delay);
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Padding(
        padding: EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: StudioPaneLoadingSkeleton(),
      );
    }
    return widget.child;
  }
}
