import 'package:flutter/material.dart';

/// Marks an icon as decorative when adjacent copy or control labels carry meaning.
Widget studioDecorativeIcon(
  IconData icon, {
  Key? key,
  double? size,
  Color? color,
  String? semanticLabel,
}) {
  if (semanticLabel != null && semanticLabel.isNotEmpty) {
    return Icon(icon, key: key, size: size, color: color, semanticLabel: semanticLabel);
  }
  return ExcludeSemantics(
    child: Icon(icon, key: key, size: size, color: color),
  );
}
