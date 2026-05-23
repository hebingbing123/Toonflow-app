import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import '../../tool/ast_parser.dart';

@Skip('Legacy frontend/tool AST prototype; canonical analyzer is tools/ui_audit/')
void main() {
  group('AstParser', () {
    late Directory tempDir;
    late String testFilePath;

    setUp(() async {
      // Create a temporary directory for test files
      tempDir = await Directory.systemTemp.createTemp('ast_parser_test_');
      testFilePath = path.join(tempDir.path, 'test_widget.dart');
    });

    tearDown(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should parse hardcoded color values', () async {
      // Create a test file with hardcoded colors
      final testCode = '''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF7C97FF),
      child: Text('Hello', style: TextStyle(color: Colors.blue)),
    );
  }
}
''';
      await File(testFilePath).writeAsString(testCode);

      // Parse the file
      final config = AstParserConfig(
        projectPath: tempDir.path,
        includePatterns: ['*.dart'],
        excludePatterns: [],
      );
      final parser = AstParser(config);
      final symbolTable = await parser.parse();

      // Verify color references were found
      expect(symbolTable.colors.length, greaterThan(0));
      expect(
        symbolTable.colors.any((c) => c.type == 'hardcoded'),
        isTrue,
        reason: 'Should find hardcoded Color(0xFF7C97FF)',
      );
      expect(
        symbolTable.colors.any((c) => c.type == 'literal'),
        isTrue,
        reason: 'Should find Colors.blue literal',
      );
    });

    test('should parse hardcoded spacing values', () async {
      final testCode = '''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SizedBox(height: 24, width: 100),
    );
  }
}
''';
      await File(testFilePath).writeAsString(testCode);

      final config = AstParserConfig(
        projectPath: tempDir.path,
        includePatterns: ['*.dart'],
        excludePatterns: [],
      );
      final parser = AstParser(config);
      final symbolTable = await parser.parse();

      // Verify spacing references were found
      expect(symbolTable.spacing.length, greaterThan(0));
      expect(
        symbolTable.spacing.any((s) => s.value == 16.0 && s.type == 'aligned'),
        isTrue,
        reason: 'Should find aligned spacing value 16',
      );
      expect(
        symbolTable.spacing.any((s) => s.value == 24.0 && s.type == 'aligned'),
        isTrue,
        reason: 'Should find aligned spacing value 24',
      );
    });

    test('should parse hardcoded typography', () async {
      final testCode = '''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Hello',
      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
    );
  }
}
''';
      await File(testFilePath).writeAsString(testCode);

      final config = AstParserConfig(
        projectPath: tempDir.path,
        includePatterns: ['*.dart'],
        excludePatterns: [],
      );
      final parser = AstParser(config);
      final symbolTable = await parser.parse();

      // Verify typography references were found
      expect(symbolTable.typography.length, greaterThan(0));
      expect(
        symbolTable.typography.any(
          (t) => t.type == 'hardcoded' && t.fontSize == 19.0,
        ),
        isTrue,
        reason: 'Should find hardcoded fontSize 19',
      );
    });

    test('should classify legacy spacing values', () async {
      final testCode = '''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: SizedBox(height: 12),
    );
  }
}
''';
      await File(testFilePath).writeAsString(testCode);

      final config = AstParserConfig(
        projectPath: tempDir.path,
        includePatterns: ['*.dart'],
        excludePatterns: [],
      );
      final parser = AstParser(config);
      final symbolTable = await parser.parse();

      // Verify legacy spacing values are classified correctly
      expect(
        symbolTable.spacing.any((s) => s.value == 10.0 && s.type == 'legacy'),
        isTrue,
        reason: 'Should classify 10 as legacy spacing',
      );
      expect(
        symbolTable.spacing.any((s) => s.value == 12.0 && s.type == 'legacy'),
        isTrue,
        reason: 'Should classify 12 as legacy spacing',
      );
    });

    test('should identify non-standard spacing values', () async {
      final testCode = '''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(7),
      child: SizedBox(height: 33),
    );
  }
}
''';
      await File(testFilePath).writeAsString(testCode);

      final config = AstParserConfig(
        projectPath: tempDir.path,
        includePatterns: ['*.dart'],
        excludePatterns: [],
      );
      final parser = AstParser(config);
      final symbolTable = await parser.parse();

      // Verify non-standard spacing values are identified
      expect(
        symbolTable.spacing
            .any((s) => s.value == 7.0 && s.type == 'non-standard'),
        isTrue,
        reason: 'Should classify 7 as non-standard spacing',
      );
      expect(
        symbolTable.spacing
            .any((s) => s.value == 33.0 && s.type == 'non-standard'),
        isTrue,
        reason: 'Should classify 33 as non-standard spacing',
      );
    });

    test('should build widget hierarchy path', () async {
      final testCode = '''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Card(
            child: Text('Hello'),
          ),
        ],
      ),
    );
  }
}
''';
      await File(testFilePath).writeAsString(testCode);

      final config = AstParserConfig(
        projectPath: tempDir.path,
        includePatterns: ['*.dart'],
        excludePatterns: [],
      );
      final parser = AstParser(config);
      final symbolTable = await parser.parse();

      // Verify widget hierarchy is tracked
      expect(symbolTable.widgets.length, greaterThan(0));
      expect(
        symbolTable.widgets.any((w) => w.widgetPath?.contains('Scaffold') ?? false),
        isTrue,
        reason: 'Should track Scaffold in widget path',
      );
      expect(
        symbolTable.widgets.any((w) => w.widgetPath?.contains('Column') ?? false),
        isTrue,
        reason: 'Should track Column in widget path',
      );
      expect(
        symbolTable.widgets.any((w) => w.widgetPath?.contains('Card') ?? false),
        isTrue,
        reason: 'Should track Card in widget path',
      );
    });

    test('should respect include/exclude patterns', () async {
      // Create multiple test files
      final includedFile = path.join(tempDir.path, 'lib', 'included.dart');
      final excludedFile = path.join(tempDir.path, 'lib', 'excluded.g.dart');

      await Directory(path.join(tempDir.path, 'lib')).create(recursive: true);

      final testCode = '''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
''';

      await File(includedFile).writeAsString(testCode);
      await File(excludedFile).writeAsString(testCode);

      final config = AstParserConfig(
        projectPath: tempDir.path,
        includePatterns: ['lib/**/*.dart'],
        excludePatterns: ['**/*.g.dart'],
      );
      final parser = AstParser(config);
      final symbolTable = await parser.parse();

      // Verify only included file was parsed
      expect(symbolTable.analyzedFiles.contains(includedFile), isTrue);
      expect(symbolTable.analyzedFiles.contains(excludedFile), isFalse);
    });
  }, skip: 'Legacy frontend/tool AST prototype; canonical analyzer is tools/ui_audit/');
}
