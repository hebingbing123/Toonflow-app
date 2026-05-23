/// Typography auto-fix helpers (limited safe replacements).
String? applyTypographyFix(String content, Map<String, dynamic> finding) {
  final title = finding['title'] as String?;
  final codeSnippet = finding['codeSnippet'] as String?;
  if (codeSnippet == null || title == null) {
    return null;
  }

  // Hardcoded fontSize -> typography scale when snippet is a simple TextStyle.
  if (title.contains('hardcoded typography') ||
      title.contains('TextStyle without StudioTypography')) {
    final match = RegExp(r'fontSize:\s*(\d+\.?\d*)').firstMatch(codeSnippet);
    if (match != null) {
      final fixed = codeSnippet.replaceFirst(
        RegExp(r'fontSize:\s*\d+\.?\d*'),
        'fontSize: StudioTypography.of(context).body',
      );
      if (fixed != codeSnippet && content.contains(codeSnippet)) {
        return content.replaceFirst(codeSnippet, fixed);
      }
    }
  }

  return null;
}
