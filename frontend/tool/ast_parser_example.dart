/// Example usage of the AST Parser
///
/// This demonstrates how to use the AST parser to analyze Flutter code
/// for UI/UX audit purposes.

import 'dart:io';
import 'ast_parser.dart';

Future<void> main() async {
  // Configure the parser
  final config = AstParserConfig(
    projectPath: Directory.current.path,
    includePatterns: ['lib/**/*.dart'],
    excludePatterns: [
      '**/*.g.dart',
      '**/*.freezed.dart',
      '**/generated/**',
      '**/rust_api/**', // Exclude generated Rust bridge code
    ],
  );

  print('Starting AST analysis...');
  print('Project path: ${config.projectPath}');
  print('Include patterns: ${config.includePatterns}');
  print('Exclude patterns: ${config.excludePatterns}');
  print('');

  // Create parser and run analysis
  final parser = AstParser(config);
  final symbolTable = await parser.parse();

  // Print summary
  print('Analysis complete!');
  print('');
  print('Summary:');
  print('  Files analyzed: ${symbolTable.analyzedFiles.length}');
  print('  Widgets found: ${symbolTable.widgets.length}');
  print('  Color references: ${symbolTable.colors.length}');
  print('  Spacing references: ${symbolTable.spacing.length}');
  print('  Typography references: ${symbolTable.typography.length}');
  print('  Errors: ${symbolTable.errors.length}');
  print('');

  // Analyze color usage
  final hardcodedColors =
      symbolTable.colors.where((c) => c.type == 'hardcoded').length;
  final literalColors =
      symbolTable.colors.where((c) => c.type == 'literal').length;
  final tokenColors = symbolTable.colors.where((c) => c.type == 'token').length;

  print('Color Analysis:');
  print('  StudioTokens references: $tokenColors');
  print('  Hardcoded Color() values: $hardcodedColors');
  print('  Colors.* literals: $literalColors');
  print('');

  // Analyze spacing usage
  final alignedSpacing =
      symbolTable.spacing.where((s) => s.type == 'aligned').length;
  final legacySpacing =
      symbolTable.spacing.where((s) => s.type == 'legacy').length;
  final nonStandardSpacing =
      symbolTable.spacing.where((s) => s.type == 'non-standard').length;

  print('Spacing Analysis:');
  print('  Aligned (8/16/24/32): $alignedSpacing');
  print('  Legacy (10/12/14/18): $legacySpacing');
  print('  Non-standard: $nonStandardSpacing');
  print('');

  // Analyze typography usage
  final studioTypography =
      symbolTable.typography.where((t) => t.type == 'studio-typography').length;
  final hardcodedTypography =
      symbolTable.typography.where((t) => t.type == 'hardcoded').length;

  print('Typography Analysis:');
  print('  StudioTypography references: $studioTypography');
  print('  Hardcoded TextStyle: $hardcodedTypography');
  print('');

  // Show some examples of violations
  if (hardcodedColors > 0) {
    print('Example hardcoded colors:');
    symbolTable.colors
        .where((c) => c.type == 'hardcoded')
        .take(5)
        .forEach((c) {
      print('  ${c.filePath}:${c.line}:${c.column} - ${c.value}');
    });
    print('');
  }

  if (nonStandardSpacing > 0) {
    print('Example non-standard spacing values:');
    symbolTable.spacing
        .where((s) => s.type == 'non-standard')
        .take(5)
        .forEach((s) {
      print('  ${s.filePath}:${s.line}:${s.column} - ${s.value}px');
    });
    print('');
  }

  if (hardcodedTypography > 0) {
    print('Example hardcoded typography:');
    symbolTable.typography
        .where((t) => t.type == 'hardcoded')
        .take(5)
        .forEach((t) {
      final details = <String>[];
      if (t.fontSize != null) details.add('fontSize: ${t.fontSize}');
      if (t.fontWeight != null) details.add('fontWeight: ${t.fontWeight}');
      if (t.lineHeight != null) details.add('lineHeight: ${t.lineHeight}');
      print('  ${t.filePath}:${t.line}:${t.column} - ${details.join(', ')}');
    });
    print('');
  }

  // Show errors if any
  if (symbolTable.errors.isNotEmpty) {
    print('Errors encountered:');
    symbolTable.errors.take(10).forEach((error) {
      print('  $error');
    });
    print('');
  }

  print('Analysis complete. Symbol table ready for further processing.');
}
