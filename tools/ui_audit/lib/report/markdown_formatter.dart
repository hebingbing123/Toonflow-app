import '../models/models.dart';

/// Formats [AuditResult] as human-readable Markdown.
class MarkdownFormatter {
  String format(AuditResult result) {
    final buffer = StringBuffer()
      ..writeln('# UI/UX Audit Report')
      ..writeln()
      ..writeln('**Date:** ${result.metadata.auditDate.toIso8601String()}')
      ..writeln('**Project:** `${result.metadata.projectPath}`')
      ..writeln('**Files analyzed:** ${result.metadata.filesAnalyzed}')
      ..writeln('**Tool version:** ${result.metadata.auditVersion}')
      ..writeln()
      ..writeln('## Summary')
      ..writeln()
      ..writeln('| Severity | Count |')
      ..writeln('|----------|------:|');

    for (final severity in Severity.values) {
      final count = result.summary.bySeverity[severity] ?? 0;
      if (count > 0) {
        buffer.writeln('| ${severity.name} | $count |');
      }
    }

    buffer
      ..writeln()
      ..writeln('## Findings')
      ..writeln();

    for (final finding in result.findings) {
      buffer
        ..writeln('### ${finding.id}: ${finding.title}')
        ..writeln()
        ..writeln('- **Severity:** ${finding.severity.name}')
        ..writeln('- **Category:** ${finding.category.name}')
        ..writeln(
          '- **Location:** `${finding.location.file}:${finding.location.line}`',
        )
        ..writeln()
        ..writeln(finding.description)
        ..writeln()
        ..writeln('**Recommendation:** ${finding.recommendation}');
      if (finding.designSystemReference != null) {
        buffer.writeln(
          '**Design system:** `${finding.designSystemReference}`',
        );
      }
      if (finding.codeSnippet != null) {
        buffer
          ..writeln()
          ..writeln('```dart')
          ..writeln(finding.codeSnippet)
          ..writeln('```');
      }
      if (finding.beforeAfter != null) {
        buffer
          ..writeln()
          ..writeln('**Before:**')
          ..writeln('```dart')
          ..writeln(finding.beforeAfter!.before)
          ..writeln('```')
          ..writeln('**After:**')
          ..writeln('```dart')
          ..writeln(finding.beforeAfter!.after)
          ..writeln('```');
      }
      buffer.writeln();
    }

    if (result.actionPlan.isNotEmpty) {
      buffer.writeln('## Action Plan');
      buffer.writeln();
      for (final item in result.actionPlan) {
        buffer
          ..writeln(
            '${item.priority}. **${item.category.name}** (${item.estimatedEffort})',
          )
          ..writeln('   ${item.rationale}')
          ..writeln('   Findings: ${item.findingIds.join(', ')}')
          ..writeln();
      }
    }

    if (result.errors.isNotEmpty) {
      buffer.writeln('## Errors');
      buffer.writeln();
      for (final error in result.errors) {
        buffer.writeln('- `${error.phase}` ${error.file}: ${error.message}');
      }
    }

    return buffer.toString();
  }
}
