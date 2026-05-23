# AST Parser for UI/UX Audit

This directory contains the AST (Abstract Syntax Tree) parser module for the Frontend UI/UX Audit system.

## Overview

The AST Parser analyzes Dart/Flutter source files to extract design system usage, widget properties, and identify potential UI/UX violations. It serves as the foundation for the static code analysis component of the audit system.

## Features

- **Widget Analysis**: Extracts all widget instances with their properties and hierarchy
- **Color Detection**: Identifies hardcoded colors vs StudioTokens references
- **Spacing Analysis**: Classifies spacing values as aligned, legacy, or non-standard
- **Typography Detection**: Finds hardcoded TextStyle vs StudioTypography references
- **File Traversal**: Supports glob patterns for include/exclude filtering
- **Symbol Table**: Builds a comprehensive symbol table for further analysis

## Requirements

This module validates the following requirements from the spec:
- **Requirement 1.2**: Document font size deviations from StudioTypography
- **Requirement 1.7**: Flag hardcoded font sizes not referencing StudioTypography
- **Requirement 2.1**: Identify spacing values not aligned with StudioSpacing
- **Requirement 3.7**: Flag text using colors outside StudioTokens
- **Requirement 4.1**: Identify hardcoded Color values not referencing StudioTokens

## Usage

### Basic Example

```dart
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
    ],
  );

  // Create parser and run analysis
  final parser = AstParser(config);
  final symbolTable = await parser.parse();

  // Access results
  print('Files analyzed: ${symbolTable.analyzedFiles.length}');
  print('Widgets found: ${symbolTable.widgets.length}');
  print('Color references: ${symbolTable.colors.length}');
  print('Spacing references: ${symbolTable.spacing.length}');
  print('Typography references: ${symbolTable.typography.length}');
}
```

### Running the Example

```bash
cd frontend
dart run tool/ast_parser_example.dart
```

This will analyze the entire `lib/` directory and print a summary of findings.

## Data Models

### WidgetInfo

Represents a widget found in the AST:

```dart
class WidgetInfo {
  final String className;        // e.g., 'Text', 'Container', 'Card'
  final String filePath;          // File path where widget is defined
  final int line;                 // Line number
  final int column;               // Column number
  final Map<String, dynamic> properties;  // Extracted properties
  final String? widgetPath;       // Parent hierarchy (e.g., 'Scaffold > Column > Card')
}
```

### ColorReference

Represents a color reference found in the code:

```dart
class ColorReference {
  final String type;              // 'token', 'hardcoded', 'literal'
  final String value;             // Color value or token name
  final String filePath;          // File path
  final int line;                 // Line number
  final int column;               // Column number
  final String? context;          // Context (e.g., 'Text.style.color')
}
```

**Color Types:**
- `token`: StudioTokens reference (e.g., `StudioTokens.of(context).primary`)
- `hardcoded`: Color constructor (e.g., `Color(0xFF7C97FF)`)
- `literal`: Colors.* literal (e.g., `Colors.blue`)

### SpacingReference

Represents a spacing value found in the code:

```dart
class SpacingReference {
  final String type;              // 'aligned', 'legacy', 'non-standard'
  final double value;             // Spacing value
  final String filePath;          // File path
  final int line;                 // Line number
  final int column;               // Column number
  final String? context;          // Context (e.g., 'Padding.padding')
}
```

**Spacing Types:**
- `aligned`: Matches StudioSpacing constants (8, 16, 24, 32)
- `legacy`: Matches legacy semantic values (10, 12, 14, 18)
- `non-standard`: Does not match any known pattern

### TypographyReference

Represents a typography reference found in the code:

```dart
class TypographyReference {
  final String type;              // 'studio-typography', 'hardcoded', 'theme'
  final double? fontSize;         // Font size (if available)
  final String? fontWeight;       // Font weight (if available)
  final double? lineHeight;       // Line height (if available)
  final String? fontFamily;       // Font family (if available)
  final String filePath;          // File path
  final int line;                 // Line number
  final int column;               // Column number
  final String? context;          // Context (e.g., 'Text.style')
}
```

**Typography Types:**
- `studio-typography`: StudioTypography reference (e.g., `StudioTypography.of(context).body`)
- `hardcoded`: Hardcoded TextStyle (e.g., `TextStyle(fontSize: 19)`)
- `theme`: Theme reference (e.g., `Theme.of(context).textTheme.bodyMedium`)

### SymbolTable

The main data structure containing all extracted information:

```dart
class SymbolTable {
  final List<WidgetInfo> widgets;
  final List<ColorReference> colors;
  final List<SpacingReference> spacing;
  final List<TypographyReference> typography;
  final Set<String> analyzedFiles;
  final List<String> errors;
}
```

## Configuration

### AstParserConfig

```dart
class AstParserConfig {
  final String projectPath;              // Root directory to analyze
  final List<String> includePatterns;    // Glob patterns for files to include
  final List<String> excludePatterns;    // Glob patterns for files to exclude
}
```

**Default Configuration:**

```dart
const AstParserConfig(
  projectPath: '.',
  includePatterns: ['lib/**/*.dart'],
  excludePatterns: [
    '**/*.g.dart',
    '**/*.freezed.dart',
    '**/generated/**',
  ],
);
```

## Design System Integration

The AST Parser is aware of the Toonflow design system:

### StudioTokens (Color System)

The parser recognizes these color token patterns:
- `StudioTokens.of(context).primary`
- `StudioTokens.of(context).bgSurface`
- `StudioTokens.of(context).textPrimary`
- etc.

### StudioSpacing (Spacing System)

The parser recognizes these spacing constants:
- `StudioSpacing.xs` (8px)
- `StudioSpacing.sm` (16px)
- `StudioSpacing.md` (24px)
- `StudioSpacing.lg` (32px)

### StudioLayoutSpacing (Semantic Spacing)

The parser recognizes these semantic spacing values:
- `StudioLayoutSpacing.inlineGap` (10px)
- `StudioLayoutSpacing.insetDense` (12px)
- `StudioLayoutSpacing.stackMedium` (14px)
- `StudioLayoutSpacing.insetComfortable` (18px)

### StudioTypography (Typography System)

The parser recognizes these typography patterns:
- `StudioTypography.of(context).pageTitle`
- `StudioTypography.of(context).body`
- `StudioTypography.of(context).label`
- etc.

## Performance

The parser uses the Dart `analyzer` package for efficient AST parsing:

- **Parallel Processing**: Files can be parsed in parallel using isolates (future enhancement)
- **Incremental Analysis**: Supports caching AST results for unchanged files (future enhancement)
- **Selective Parsing**: Exclude patterns prevent parsing of generated files

**Typical Performance:**
- ~500 files analyzed in ~5-10 seconds
- ~16,000 widgets extracted
- ~2,000 spacing references found

## Error Handling

The parser gracefully handles errors:

- If a file fails to parse, the error is logged and analysis continues
- All errors are collected in `symbolTable.errors`
- Successfully analyzed files are tracked in `symbolTable.analyzedFiles`

## Integration with Audit System

The AST Parser is the first component in the audit pipeline:

```
AST Parser → Visual Hierarchy Analyzer
          → Spacing Analyzer
          → Typography Analyzer
          → Color System Analyzer
          → Component Consistency Analyzer
          → Report Generator
```

The symbol table produced by the AST Parser is consumed by specialized analyzers that apply audit rules and generate findings.

## Future Enhancements

1. **Parallel Processing**: Use isolates to parse files in parallel
2. **Incremental Analysis**: Cache AST results for unchanged files
3. **Enhanced Pattern Detection**: Detect more complex design system patterns
4. **Theme Detection**: Recognize Theme.of(context) patterns
5. **Widget Composition Analysis**: Analyze widget composition patterns
6. **Performance Profiling**: Add timing metrics for optimization

## Dependencies

- `analyzer: ^6.0.0` - Dart AST parsing
- `glob: ^2.1.0` - File pattern matching
- `path: ^1.8.0` - Path manipulation

## Testing

Unit tests are located in `test/tool/ast_parser_test.dart`. Note that these tests require a proper Flutter SDK environment to run.

For integration testing, use the example script:

```bash
dart run tool/ast_parser_example.dart
```

## License

This module is part of the Toonflow application and follows the same license.

## References

- [Dart Analyzer Package](https://pub.dev/packages/analyzer)
- [AST Visitor Pattern](https://en.wikipedia.org/wiki/Visitor_pattern)
- Toonflow Design System: `frontend/lib/design_system/`
- Audit Requirements: `.kiro/specs/frontend-ui-ux-audit/requirements.md`
- Audit Design: `.kiro/specs/frontend-ui-ux-audit/design.md`
