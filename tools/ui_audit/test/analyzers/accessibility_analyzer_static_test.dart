import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ui_audit/analyzers/accessibility_analyzer_static.dart';
import 'package:ui_audit/models/models.dart';

void main() {
  group('AccessibilityAnalyzerStatic', () {
    late AccessibilityAnalyzerStatic analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = AccessibilityAnalyzerStatic();
      tempDir = Directory.systemTemp.createTempSync('ui_audit_a11y_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('Property 16: flags Icon without semanticLabel', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  void m() => Icon(Icons.add);
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(
        findings.any((f) => f.title.contains('Icon missing semantic label')),
        isTrue,
      );
    });

    test('Property 17: flags TextField without label or hint', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  void m() => TextField();
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(
        findings.any((f) => f.title.contains('Form input missing')),
        isTrue,
      );
    });

    test('does not flag Icon inside IconButton with tooltip', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  Widget m() => IconButton(
    tooltip: 'Refresh',
    onPressed: () {},
    icon: Icon(Icons.refresh),
  );
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings.where((f) => f.title.contains('Icon missing')), isEmpty);
    });

    test('does not flag decorative Icon beside Text in Row', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  Widget m() => Row(children: [Icon(Icons.folder), Text('Projects')]);
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings.where((f) => f.title.contains('Icon missing')), isEmpty);
    });

    test('does not flag Icon inside FilledButton.tonalIcon with label', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  Widget m() => FilledButton.tonalIcon(
    onPressed: () {},
    icon: Icon(Icons.download_outlined),
    label: Text('Download'),
  );
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings.where((f) => f.title.contains('Icon missing')), isEmpty);
    });

    test('does not flag Icon inside ButtonSegment with label', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  Widget m() => ButtonSegment(
    value: 0,
    icon: Icon(Icons.auto_awesome_outlined),
    label: Text('Animated'),
  );
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings.where((f) => f.title.contains('Icon missing')), isEmpty);
    });

    test('does not flag AnimatedBuilder used as Listenable rebuild', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  Widget m() => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Text('x'),
  );
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(
        findings.where((f) => f.title.contains('reduced-motion')),
        isEmpty,
      );
    });

    test('does not flag AnimatedContainer with studioAnimationDuration', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  Widget m(BuildContext context) => AnimatedContainer(
    duration: studioAnimationDuration(context, const Duration(milliseconds: 220)),
    child: Text('x'),
  );
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(
        findings.where((f) => f.title.contains('reduced-motion')),
        isEmpty,
      );
    });

    test('does not flag Icon with semanticLabel', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  void m() => Icon(Icons.add, semanticLabel: 'Add item');
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isEmpty);
    });
  });
}
