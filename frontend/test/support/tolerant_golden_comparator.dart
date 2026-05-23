import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// [LocalFileComparator] that allows sub-percent rendering drift (fonts, AA).
///
/// [precisionTolerance] is a fraction in \[0, 1\] (e.g. `0.001` ≈ 0.1% pixels).
class TolerantLocalFileComparator extends LocalFileComparator {
  TolerantLocalFileComparator(
    super.testFile, {
    this.precisionTolerance = 0.001,
  }) : assert(
         precisionTolerance >= 0 && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       );

  final double precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    final passed = result.passed || result.diffPercent <= precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
