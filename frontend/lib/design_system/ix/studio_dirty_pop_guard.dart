import 'dart:async';

import 'package:flutter/material.dart';

/// Blocks back / route pop while [isDirty], prompting via [onConfirmDiscard].
///
/// Set [allowPop] to true before programmatic `Navigator.pop` after save/create.
/// Set [popBlocked] while async work must not be interrupted (e.g. saving).
class StudioDirtyPopGuard extends StatefulWidget {
  const StudioDirtyPopGuard({
    super.key,
    required this.isDirty,
    required this.onConfirmDiscard,
    required this.child,
    this.enabled = true,
    this.allowPop = false,
    this.popBlocked = false,
  });

  final bool isDirty;
  final bool enabled;
  final bool allowPop;
  final bool popBlocked;
  final Future<bool> Function() onConfirmDiscard;
  final Widget child;

  @override
  State<StudioDirtyPopGuard> createState() => _StudioDirtyPopGuardState();
}

class _StudioDirtyPopGuardState extends State<StudioDirtyPopGuard> {
  var _allowPopOnce = false;
  var _handlingPop = false;

  @override
  void didUpdateWidget(covariant StudioDirtyPopGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allowPop && !oldWidget.allowPop) {
      _allowPopOnce = true;
    }
  }

  bool get _canPop =>
      !widget.enabled ||
      widget.allowPop ||
      _allowPopOnce ||
      widget.popBlocked ||
      !widget.isDirty;

  Future<void> _handlePopInvoked(bool didPop) async {
    if (didPop || _handlingPop || widget.popBlocked || !widget.enabled) {
      return;
    }
    if (!widget.isDirty) {
      setState(() => _allowPopOnce = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
      return;
    }

    _handlingPop = true;
    try {
      final discard = await widget.onConfirmDiscard();
      if (!mounted || discard != true) {
        return;
      }
      setState(() => _allowPopOnce = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
    } finally {
      _handlingPop = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        unawaited(_handlePopInvoked(didPop));
      },
      child: widget.child,
    );
  }
}
