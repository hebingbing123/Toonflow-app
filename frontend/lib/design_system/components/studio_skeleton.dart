import 'package:flutter/material.dart';

import '../tokens.dart';
import '../studio_motion.dart';

class StudioSkeleton extends StatefulWidget {
  const StudioSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<StudioSkeleton> createState() => _StudioSkeletonState();
}

class _StudioSkeletonState extends State<StudioSkeleton>
    with SingleTickerProviderStateMixin {
  static const _pulseDuration = Duration(milliseconds: 1200);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _pulseDuration)
      ..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = studioAnimationDuration(context, _pulseDuration);
    if (_controller.duration != duration) {
      _controller.duration = duration;
      if (duration == Duration.zero) {
        _controller.stop();
        _controller.value = 0;
      } else if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: Color.lerp(
              tokens.bgInset,
              tokens.borderDefault,
              _controller.value,
            ),
          ),
        );
      },
    );
  }
}
