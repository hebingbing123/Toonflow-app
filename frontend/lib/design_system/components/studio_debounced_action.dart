import 'dart:async';

import 'package:flutter/material.dart';

import '../studio_interaction_timing.dart';

/// Debounces rapid taps on primary actions (submit, purchase, save).
///
/// Default [duration] is [StudioInteractionTiming.submitDebounce].
class StudioDebouncedAction extends StatefulWidget {
  const StudioDebouncedAction({
    super.key,
    required this.onPressed,
    required this.builder,
    this.duration = StudioInteractionTiming.submitDebounce,
    this.enabled = true,
  });

  final Future<void> Function()? onPressed;
  final bool enabled;
  final Duration duration;
  final Widget Function(BuildContext context, VoidCallback? onPressed) builder;

  @override
  State<StudioDebouncedAction> createState() => _StudioDebouncedActionState();
}

class _StudioDebouncedActionState extends State<StudioDebouncedAction> {
  bool _locked = false;
  Timer? _unlockTimer;

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  void _scheduleUnlock() {
    _unlockTimer?.cancel();
    _unlockTimer = Timer(widget.duration, () {
      if (!mounted) return;
      setState(() => _locked = false);
    });
  }

  Future<void> _handlePress() async {
    final action = widget.onPressed;
    if (!widget.enabled || action == null || _locked) return;
    setState(() => _locked = true);
    try {
      await action();
    } finally {
      if (mounted) {
        _scheduleUnlock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPress = widget.enabled && widget.onPressed != null && !_locked;
    return widget.builder(
      context,
      canPress ? () => unawaited(_handlePress()) : null,
    );
  }
}
