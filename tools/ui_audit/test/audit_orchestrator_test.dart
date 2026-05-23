import 'dart:io';

import 'package:test/test.dart';
import 'package:ui_audit/analyzers/static_analysis_runner.dart';
import 'package:ui_audit/audit_orchestrator.dart';
import 'package:ui_audit/models/models.dart';
import 'package:ui_audit/runtime/runtime_inspector.dart';

void main() {
  group('AuditOrchestrator', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ui_audit_orch_');
      Directory('${tempDir.path}/lib').createSync();
      File('${tempDir.path}/lib/bad_spacing.dart').writeAsStringSync('''
class BadSpacing {
  void build() {
    final p = EdgeInsets.all(15);
    final t = Text('x', style: TextStyle(fontSize: 19));
  }
}
''');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('end-to-end static audit produces findings and reports', () async {
      final config = AuditConfiguration(
        projectPath: tempDir.path,
        includePaths: const ['lib/**/*.dart'],
        runRuntimeInspection: false,
        outputFormats: const ['json', 'markdown'],
        outputDirectory: '${tempDir.path}/reports',
        enabledCategories: const [
          FindingCategory.spacing,
          FindingCategory.visualHierarchy,
        ],
      );

      final run = await AuditOrchestrator(
        runtimeInspector: const _EmptyRuntime(),
      ).run(config);

      expect(run.result.summary.totalFindings, greaterThan(0));
      expect(run.reportPaths, isNotEmpty);
      for (final path in run.reportPaths) {
        expect(File(path).existsSync(), isTrue);
      }
    });
  });
}

class _EmptyRuntime implements RuntimeInspector {
  const _EmptyRuntime();

  @override
  Future<RuntimeInspectionResult> inspect(RuntimeInspectionContext context) async {
    return const RuntimeInspectionResult();
  }
}
