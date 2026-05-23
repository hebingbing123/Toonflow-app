import 'package:test/test.dart';
import 'package:ui_audit/remediation/spacing_fix.dart';

void main() {
  test('replaces SizedBox height with StudioSpacing', () {
    const content = 'const SizedBox(height: 6)';
    final finding = {
      'description': 'SizedBox.height uses hardcoded spacing 6',
      'codeSnippet': 'const SizedBox(height: 6)',
    };
    final result = applySpacingFix(content, finding);
    expect(result, contains('StudioSpacing.xs'));
  });

  test('returns null for unknown patterns', () {
    const content = 'padding: 6';
    final finding = {
      'description': 'spacing 6',
      'codeSnippet': 'padding: 6',
    };
    expect(applySpacingFix(content, finding), isNull);
  });
}
