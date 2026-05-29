import 'package:flutter/material.dart';

/// Highlights [query] matches inside [text] (case-insensitive).
TextSpan studioHighlightSearchMatches({
  required String text,
  required String query,
  required TextStyle baseStyle,
  TextStyle? highlightStyle,
}) {
  if (query.trim().isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: highlightStyle ??
            baseStyle.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    start = index + query.length;
  }
  return TextSpan(children: spans);
}
