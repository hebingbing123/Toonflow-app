import 'dart:convert';
import 'dart:io';

import 'fix_result.dart';
import 'fix_validator.dart';
import 'spacing_fix.dart';
import 'typography_fix.dart';

/// Applies automated fixes from a JSON audit report.
class AutoFixApplicator {
  final bool dryRun;
  final bool validateAfterApply;
  final String frontendProjectPath;
  final FixValidator? validator;

  AutoFixApplicator({
    this.dryRun = false,
    this.validateAfterApply = true,
    this.frontendProjectPath = 'frontend',
    FixValidator? validator,
  }) : validator = validateAfterApply
            ? (validator ?? FixValidator(projectPath: frontendProjectPath))
            : null;

  /// Applies fixes from [reportPath] or in-memory [reportJson].
  Future<FixRunResult> applyFromReportPath(String reportPath) async {
    final file = File(reportPath);
    if (!file.existsSync()) {
      throw StateError('Report file not found: $reportPath');
    }
    final json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return applyFromJson(json);
  }

  Future<FixRunResult> applyFromJson(Map<String, dynamic> reportJson) async {
    final findings = reportJson['findings'] as List<dynamic>? ?? [];
    final findingsByFile = <String, List<Map<String, dynamic>>>{};

    for (final raw in findings) {
      final finding = raw as Map<String, dynamic>;
      final location = finding['location'] as Map<String, dynamic>?;
      final file = location?['file'] as String?;
      if (file == null) {
        continue;
      }
      findingsByFile.putIfAbsent(file, () => []).add(finding);
    }

    var fixedCount = 0;
    var skippedCount = 0;
    final modifiedFiles = <String>[];
    final snapshots = <String, String>{};

    for (final entry in findingsByFile.entries) {
      final filePath = entry.key;
      final fileFindings = List<Map<String, dynamic>>.from(entry.value);

      final file = File(filePath);
      if (!file.existsSync()) {
        skippedCount += fileFindings.length;
        continue;
      }

      fileFindings.sort((a, b) {
        final lineA = (a['location'] as Map)['line'] as int;
        final lineB = (b['location'] as Map)['line'] as int;
        return lineB.compareTo(lineA);
      });

      var content = await file.readAsString();
      final originalContent = content;

      for (final finding in fileFindings) {
        final category = finding['category'] as String?;
        String? updated;
        if (category == 'spacing') {
          updated = applySpacingFix(content, finding);
        } else if (category == 'typography') {
          updated = applyTypographyFix(content, finding);
        }
        if (updated != null) {
          content = updated;
          fixedCount++;
        } else {
          skippedCount++;
        }
      }

      if (content != originalContent) {
        snapshots[filePath] = originalContent;
        if (!dryRun) {
          await file.writeAsString(content);
        }
        modifiedFiles.add(filePath);
      }
    }

    final validationFailures = <String>[];
    if (!dryRun && validateAfterApply && validator != null && modifiedFiles.isNotEmpty) {
      final relPaths = modifiedFiles
          .map((p) => _relativeToFrontend(p))
          .where((p) => p.isNotEmpty)
          .toList();
      final failed = await validator!.validatePaths(relPaths);
      validationFailures.addAll(failed);

      // Roll back files that failed validation.
      for (final rel in failed) {
        final abs = modifiedFiles.firstWhere(
          (p) => _relativeToFrontend(p) == rel,
          orElse: () => '',
        );
        if (abs.isNotEmpty && snapshots.containsKey(abs)) {
          await File(abs).writeAsString(snapshots[abs]!);
          modifiedFiles.remove(abs);
        }
      }
    }

    return FixRunResult(
      fixedCount: fixedCount,
      skippedCount: skippedCount,
      filesModified: modifiedFiles.length,
      modifiedFiles: modifiedFiles,
      validationFailures: validationFailures,
    );
  }

  String _relativeToFrontend(String absolutePath) {
    const marker = '/frontend/';
    final idx = absolutePath.indexOf(marker);
    if (idx >= 0) {
      return absolutePath.substring(idx + marker.length);
    }
    if (absolutePath.startsWith('frontend/')) {
      return absolutePath.substring('frontend/'.length);
    }
    return absolutePath;
  }
}
