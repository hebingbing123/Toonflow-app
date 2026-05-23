import 'dart:io';

import '../config/config_parser.dart';

/// Validates modified Dart files via `flutter analyze`.
class FixValidator {
  final String projectPath;
  final Duration timeout;

  FixValidator({
    String projectPath = 'frontend',
    this.timeout = const Duration(minutes: 5),
  }) : projectPath = ConfigParser.resolveProjectDirectory(projectPath);

  /// Runs analyze on [relativePaths] under [projectPath]. Returns paths that failed.
  Future<List<String>> validatePaths(List<String> relativePaths) async {
    if (relativePaths.isEmpty) {
      return [];
    }

    final failures = <String>[];
    for (final rel in relativePaths) {
      final failed = await _analyzeFile(rel);
      if (failed) {
        failures.add(rel);
      }
    }
    return failures;
  }

  Future<bool> _analyzeFile(String relativePath) async {
    final result = await Process.run(
      'flutter',
      ['analyze', relativePath],
      workingDirectory: projectPath,
      runInShell: true,
    ).timeout(timeout);

    return result.exitCode != 0;
  }

  /// Runs project-wide analyze (used after batch fix).
  Future<bool> validateProject() async {
    final result = await Process.run(
      'flutter',
      ['analyze'],
      workingDirectory: projectPath,
      runInShell: true,
    ).timeout(timeout);

    return result.exitCode == 0;
  }
}
