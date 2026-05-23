import 'dart:io';
import 'package:ui_audit/analyzers/visual_hierarchy_analyzer.dart';

void main() async {
  final analyzer = VisualHierarchyAnalyzer();
  final tempDir = Directory.systemTemp.createTempSync('ui_audit_debug_');
  
  final testFile = File('${tempDir.path}/test_widget.dart');
  testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Hello',
      style: TextStyle(fontSize: 19),
    );
  }
}
''');

  print('Test file: ${testFile.path}');
  print('Content:\n${testFile.readAsStringSync()}');
  
  final findings = await analyzer.analyze(testFile.path);
  
  print('\nFindings: ${findings.length}');
  for (final finding in findings) {
    print('  - ${finding.title}');
    print('    ${finding.description}');
  }
  
  tempDir.deleteSync(recursive: true);
}
