import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/utils/search_highlight.dart';

void main() {
  test('studioHighlightSearchMatches wraps query substring', () {
    const base = TextStyle(fontSize: 14);
    final span = studioHighlightSearchMatches(
      text: 'Hello World',
      query: 'wor',
      baseStyle: base,
    );
    expect(span.children, isNotNull);
    expect(span.children!.length, greaterThan(1));
  });
}
