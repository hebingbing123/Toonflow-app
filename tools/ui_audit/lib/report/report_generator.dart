import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'html_formatter.dart';
import 'markdown_formatter.dart';

/// Writes audit reports to disk in configured formats.
class ReportGenerator {
  final MarkdownFormatter _markdown = MarkdownFormatter();
  final HtmlFormatter _html = HtmlFormatter();

  Future<List<String>> writeReports(
    AuditResult result,
    AuditConfiguration config,
  ) async {
    final outputDir = Directory(config.outputDirectory);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final timestamp =
        result.metadata.auditDate.toIso8601String().replaceAll(':', '-');
    final written = <String>[];

    for (final format in config.outputFormats) {
      switch (format.toLowerCase()) {
        case 'json':
          final path = '${outputDir.path}/audit-$timestamp.json';
          await File(path).writeAsString(
            const JsonEncoder.withIndent('  ').convert(result.toJson()),
          );
          written.add(path);
        case 'markdown':
        case 'md':
          final path = '${outputDir.path}/audit-$timestamp.md';
          await File(path).writeAsString(_markdown.format(result));
          written.add(path);
        case 'html':
          final path = '${outputDir.path}/audit-$timestamp.html';
          await File(path).writeAsString(_html.format(result));
          written.add(path);
      }
    }

    return written;
  }
}
