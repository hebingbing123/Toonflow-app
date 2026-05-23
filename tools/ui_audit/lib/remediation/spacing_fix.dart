/// Spacing auto-fix helpers (string-based, from audit findings).
String? applySpacingFix(String content, Map<String, dynamic> finding) {
  final description = finding['description'] as String?;
  final codeSnippet = finding['codeSnippet'] as String?;
  if (description == null || codeSnippet == null) {
    return null;
  }

  final spacingMatch = RegExp(r'spacing (\d+\.?\d*)').firstMatch(description);
  if (spacingMatch == null) {
    return null;
  }

  final spacingValue = double.parse(spacingMatch.group(1)!);
  final replacement = _replacementForSpacing(spacingValue);

  var fixedSnippet = codeSnippet;

  if (codeSnippet.contains('SizedBox(width:')) {
    fixedSnippet = codeSnippet.replaceFirst(
      RegExp(r'width:\s*\d+\.?\d*'),
      'width: $replacement',
    );
  } else if (codeSnippet.contains('SizedBox(height:')) {
    fixedSnippet = codeSnippet.replaceFirst(
      RegExp(r'height:\s*\d+\.?\d*'),
      'height: $replacement',
    );
  } else if (codeSnippet.contains('EdgeInsets.all(')) {
    fixedSnippet = codeSnippet.replaceFirst(
      RegExp(r'EdgeInsets\.all\(\s*\d+\.?\d*\s*\)'),
      'EdgeInsets.all($replacement)',
    );
  } else if (codeSnippet.contains('EdgeInsets.symmetric(')) {
    if (codeSnippet.contains('horizontal:')) {
      fixedSnippet = fixedSnippet.replaceFirst(
        RegExp(r'horizontal:\s*\d+\.?\d*'),
        'horizontal: $replacement',
      );
    }
    if (codeSnippet.contains('vertical:')) {
      fixedSnippet = fixedSnippet.replaceFirst(
        RegExp(r'vertical:\s*\d+\.?\d*'),
        'vertical: $replacement',
      );
    }
  } else if (codeSnippet.contains('EdgeInsets.only(')) {
    fixedSnippet = fixedSnippet
        .replaceFirst(RegExp(r'left:\s*\d+\.?\d*'), 'left: $replacement')
        .replaceFirst(RegExp(r'right:\s*\d+\.?\d*'), 'right: $replacement')
        .replaceFirst(RegExp(r'top:\s*\d+\.?\d*'), 'top: $replacement')
        .replaceFirst(RegExp(r'bottom:\s*\d+\.?\d*'), 'bottom: $replacement');
  } else if (codeSnippet.contains('Padding(')) {
    fixedSnippet = codeSnippet.replaceFirst(
      RegExp(r'padding:\s*EdgeInsets\.\w+\([^)]*\)'),
      'padding: EdgeInsets.all($replacement)',
    );
  } else {
    return null;
  }

  if (fixedSnippet == codeSnippet) {
    return null;
  }
  return content.replaceFirst(codeSnippet, fixedSnippet);
}

String _replacementForSpacing(double spacingValue) {
  if (spacingValue <= 4) {
    if (spacingValue == 2) {
      return '4';
    }
    return 'StudioSpacing.xs';
  }
  if (spacingValue <= 6) {
    return 'StudioSpacing.xs';
  }
  if (spacingValue <= 12) {
    return spacingValue < 10 ? 'StudioSpacing.xs' : 'StudioSpacing.sm';
  }
  if (spacingValue <= 20) {
    return 'StudioSpacing.sm';
  }
  if (spacingValue <= 28) {
    return 'StudioSpacing.md';
  }
  return 'StudioSpacing.lg';
}
