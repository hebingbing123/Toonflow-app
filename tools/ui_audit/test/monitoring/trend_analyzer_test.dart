import 'package:test/test.dart';
import 'package:ui_audit/monitoring/trend_analyzer.dart';

void main() {
  test('detects total findings regression', () {
    final analyzer = TrendAnalyzer();
    final report = analyzer.analyze([
      {'totalFindings': 10, 'bySeverity': {}, 'byCategory': {}},
      {'totalFindings': 15, 'bySeverity': {}, 'byCategory': {}},
    ]);
    expect(report.totalDelta, 5);
    expect(report.regressions, isNotEmpty);
  });

  test('improvement has negative delta', () {
    final analyzer = TrendAnalyzer();
    final report = analyzer.analyze([
      {'totalFindings': 20, 'bySeverity': {}, 'byCategory': {}},
      {'totalFindings': 12, 'bySeverity': {}, 'byCategory': {}},
    ]);
    expect(report.totalDelta, -8);
    expect(report.regressions, isEmpty);
  });
}
