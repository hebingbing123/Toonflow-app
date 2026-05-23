import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:ui_audit/util/git_changed_files.dart';

void main() {
  group('GitChangedFiles', () {
    test('diffArguments supports revision ranges', () {
      expect(
        GitChangedFiles.diffArgumentsFor('origin/main...HEAD'),
        [
          'diff',
          '--name-only',
          '--diff-filter=ACMRT',
          'origin/main...HEAD',
        ],
      );
      expect(
        GitChangedFiles.diffArgumentsFor('HEAD'),
        ['diff', '--name-only', '--diff-filter=ACMRT', 'HEAD'],
      );
    });

    test('returns changed frontend dart files from repo root', () async {
      final repoRoot = await Process.run(
        'git',
        ['rev-parse', '--show-toplevel'],
        workingDirectory: Directory.current.path,
      );
      if (repoRoot.exitCode != 0) {
        markTestSkipped('Not a git repository');
        return;
      }

      final root = (repoRoot.stdout as String).trim();
      final frontend = p.normalize(p.join(root, 'frontend'));
      if (!Directory(frontend).existsSync()) {
        markTestSkipped('frontend/ not present');
        return;
      }

      final files = await GitChangedFiles.dartFilesUnderProject(
        projectPath: frontend,
      );

      for (final file in files) {
        expect(file.startsWith(frontend), isTrue);
        expect(File(file).existsSync(), isTrue);
      }
    });
  });
}
