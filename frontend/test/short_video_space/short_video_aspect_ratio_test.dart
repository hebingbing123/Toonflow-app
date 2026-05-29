import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/short_video_aspect_ratio.dart';

void main() {
  group('shortVideoAspectRatioFromLabel', () {
    test('maps portrait 9:16', () {
      expect(shortVideoAspectRatioFromLabel('9:16'), closeTo(9 / 16, 0.001));
    });

    test('maps landscape 16:9', () {
      expect(shortVideoAspectRatioFromLabel('16:9'), closeTo(16 / 9, 0.001));
    });

    test('maps square 1:1', () {
      expect(shortVideoAspectRatioFromLabel('1:1'), 1);
    });

    test('defaults unknown to portrait', () {
      expect(shortVideoAspectRatioFromLabel('4:3'), closeTo(9 / 16, 0.001));
    });
  });
}
