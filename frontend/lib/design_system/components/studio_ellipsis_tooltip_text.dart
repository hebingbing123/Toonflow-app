import 'package:flutter/material.dart';

/// Truncated copy that shows the full [text] in a [Tooltip] when ellipsized.
class StudioEllipsisTooltipText extends StatefulWidget {
  const StudioEllipsisTooltipText({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 1,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  State<StudioEllipsisTooltipText> createState() =>
      _StudioEllipsisTooltipTextState();
}

class _StudioEllipsisTooltipTextState extends State<StudioEllipsisTooltipText> {
  bool _overflows = false;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final text = Text(
      widget.text,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: widget.textAlign,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _scheduleOverflowCheck(constraints.maxWidth, textDirection);
        if (!_overflows) {
          return text;
        }
        return Tooltip(
          message: widget.text,
          waitDuration: const Duration(milliseconds: 350),
          child: text,
        );
      },
    );
  }

  void _scheduleOverflowCheck(double maxWidth, TextDirection textDirection) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final next = _isOverflowing(maxWidth, textDirection);
      if (next != _overflows) {
        setState(() => _overflows = next);
      }
    });
  }

  bool _isOverflowing(double maxWidth, TextDirection textDirection) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return false;
    }
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: widget.maxLines,
      textDirection: textDirection,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}
