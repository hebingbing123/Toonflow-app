import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('report command exits 0 with empty history message', () async {
    final dir = await Directory.systemTemp.createTemp('ui_audit_cli_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = '${dir.path}/empty.jsonl';

    final result = await Process.run(
      'dart',
      [
        'run',
        'ui_audit:ui_audit',
        'report',
        '--history=$history',
        '--no-trend',
      ],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0);
    expect(result.stdout, contains('No metrics'));
  });
}
