import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves Dart files changed in git that live under [projectPath].
class GitChangedFiles {
  static Future<List<String>> dartFilesUnderProject({
    required String projectPath,
    String diffRef = 'HEAD',
  }) async {
    final projectRoot = p.normalize(Directory(projectPath).absolute.path);
    final repoRoot = await _gitRepoRoot(projectRoot);

    final diffArgs = _diffArguments(diffRef);
    final result = await Process.run(
      'git',
      diffArgs,
      workingDirectory: repoRoot,
    );
    if (result.exitCode != 0) {
      return [];
    }

    return (result.stdout as String)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.endsWith('.dart'))
        .map((line) => p.normalize(p.join(repoRoot, line)))
        .where(
          (path) =>
              isUnderProject(path, projectRoot) && File(path).existsSync(),
        )
        .toList();
  }

  /// Builds git diff arguments for [diffRef].
  ///
  /// Supports:
  /// - `HEAD` — working tree vs last commit (local dev)
  /// - `A..B` / `A...B` — explicit revision range (CI pull requests)
  static List<String> _diffArguments(String diffRef) => diffArgumentsFor(diffRef);

  /// Exposed for unit tests.
  static List<String> diffArgumentsFor(String diffRef) {
    const prefix = ['diff', '--name-only', '--diff-filter=ACMRT'];
    if (diffRef.contains('..')) {
      return [...prefix, diffRef];
    }
    return [...prefix, diffRef];
  }

  static bool isUnderProject(String filePath, String projectRoot) {
    final normalized = p.normalize(filePath);
    if (normalized == projectRoot) {
      return true;
    }
    final prefix = projectRoot.endsWith(p.separator)
        ? projectRoot
        : '$projectRoot${p.separator}';
    return normalized.startsWith(prefix);
  }

  static Future<String> _gitRepoRoot(String fromPath) async {
    final result = await Process.run(
      'git',
      ['rev-parse', '--show-toplevel'],
      workingDirectory: fromPath,
    );
    if (result.exitCode != 0) {
      return p.normalize(Directory(fromPath).absolute.path);
    }
    return p.normalize((result.stdout as String).trim());
  }
}
