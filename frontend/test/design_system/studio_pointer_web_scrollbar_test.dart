import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_pointer.dart';

void main() {
  testWidgets('handset layout hides scroll thumbs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 812)),
          child: Builder(
            builder: (context) {
              expect(studioScrollbarThumbVisible(context), isFalse);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  });

  testWidgets('landscape phone layout hides scroll thumbs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(844, 390)),
          child: Builder(
            builder: (context) {
              expect(studioScrollbarThumbVisible(context), isFalse);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  });
}
