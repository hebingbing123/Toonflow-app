import 'package:flutter/material.dart';

import '../tokens.dart';
import '../studio_motion.dart';

class StudioSkeleton extends StatefulWidget {
  const StudioSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = StudioSpacing.radiusDense,
    this.shimmer = true,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final bool shimmer;

  @override
  State<StudioSkeleton> createState() => _StudioSkeletonState();
}

class _StudioSkeletonState extends State<StudioSkeleton>
    with SingleTickerProviderStateMixin {
  static const _pulseDuration = Duration(milliseconds: 1400);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _pulseDuration)
      ..repeat();
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
        _controller.repeat();
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
        final base = Color.lerp(
          tokens.bgInset,
          tokens.borderDefault,
          0.35 + 0.25 * (0.5 - (0.5 - _controller.value).abs() * 2),
        )!;
        final highlight = Color.lerp(
          tokens.borderDefault,
          tokens.surfaceHighlight,
          widget.shimmer ? _controller.value : 0,
        )!;

        Widget box = Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: base,
          ),
        );

        if (widget.shimmer) {
          box = ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final slide = -1.2 + 2.4 * _controller.value;
              return LinearGradient(
                begin: Alignment(slide - 0.6, 0),
                end: Alignment(slide + 0.6, 0),
                colors: <Color>[
                  base,
                  highlight.withValues(alpha: 0.85),
                  base,
                ],
                stops: const <double>[0.25, 0.5, 0.75],
              ).createShader(bounds);
            },
            child: box,
          );
        }

        return box;
      },
    );
  }
}
