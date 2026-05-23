/// AST Parser for Flutter UI/UX Audit
///
/// This module parses Dart/Flutter source files to extract design system usage,
/// widget properties, and identify potential UI/UX violations.
///
/// Requirements: 1.2, 1.7, 2.1, 3.7, 4.1

import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;

/// Configuration for AST parsing
class AstParserConfig {
  /// Root directory to analyze
  final String projectPath;

  /// Glob patterns for files to include (e.g., 'lib/**/*.dart')
  final List<String> includePatterns;

  /// Glob patterns for files to exclude (e.g., '**/*.g.dart', '**/*.freezed.dart')
  final List<String> excludePatterns;

  const AstParserConfig({
    required this.projectPath,
    this.includePatterns = const ['lib/**/*.dart'],
    this.excludePatterns = const [
      '**/*.g.dart',
      '**/*.freezed.dart',
      '**/generated/**',
    ],
  });
}

/// Represents a widget found in the AST
class WidgetInfo {
  /// Widget class name (e.g., 'Text', 'Container', 'Card')
  final String className;

  /// File path where the widget is defined
  final String filePath;

  /// Line number in the file
  final int line;

  /// Column number in the file
  final int column;

  /// Properties extracted from the widget
  final Map<String, dynamic> properties;

  /// Parent widget path (e.g., 'Scaffold > Column > Card')
  final String? widgetPath;

  WidgetInfo({
    required this.className,
    required this.filePath,
    required this.line,
    required this.column,
    required this.properties,
    this.widgetPath,
  });

  @override
  String toString() {
    return 'WidgetInfo($className at $filePath:$line:$column)';
  }
}

/// Represents a color reference found in the code
class ColorReference {
  /// Type of color reference: 'token', 'hardcoded', 'literal'
  final String type;

  /// The actual color value or token name
  final String value;

  /// File path where the color is used
  final String filePath;

  /// Line number
  final int line;

  /// Column number
  final int column;

  /// Context (e.g., 'Text.style.color', 'Container.color')
  final String? context;

  ColorReference({
    required this.type,
    required this.value,
    required this.filePath,
    required this.line,
    required this.column,
    this.context,
  });

  @override
  String toString() {
    return 'ColorReference($type: $value at $filePath:$line:$column)';
  }
}

/// Represents a spacing value found in the code
class SpacingReference {
  /// Type: 'aligned', 'legacy', 'non-standard'
  final String type;

  /// The spacing value
  final double value;

  /// File path
  final String filePath;

  /// Line number
  final int line;

  /// Column number
  final int column;

  /// Context (e.g., 'Padding.padding', 'SizedBox.height')
  final String? context;

  SpacingReference({
    required this.type,
    required this.value,
    required this.filePath,
    required this.line,
    required this.column,
    this.context,
  });

  @override
  String toString() {
    return 'SpacingReference($type: $value at $filePath:$line:$column)';
  }
}

/// Represents a typography reference found in the code
class TypographyReference {
  /// Type: 'studio-typography', 'hardcoded', 'theme'
  final String type;

  /// Font size (if available)
  final double? fontSize;

  /// Font weight (if available)
  final String? fontWeight;

  /// Line height (if available)
  final double? lineHeight;

  /// Font family (if available)
  final String? fontFamily;

  /// File path
  final String filePath;

  /// Line number
  final int line;

  /// Column number
  final int column;

  /// Context (e.g., 'Text.style')
  final String? context;

  TypographyReference({
    required this.type,
    this.fontSize,
    this.fontWeight,
    this.lineHeight,
    this.fontFamily,
    required this.filePath,
    required this.line,
    required this.column,
    this.context,
  });

  @override
  String toString() {
    return 'TypographyReference($type at $filePath:$line:$column)';
  }
}

/// Symbol table containing all extracted information
class SymbolTable {
  /// All widgets found
  final List<WidgetInfo> widgets = [];

  /// All color references found
  final List<ColorReference> colors = [];

  /// All spacing references found
  final List<SpacingReference> spacing = [];

  /// All typography references found
  final List<TypographyReference> typography = [];

  /// Files analyzed
  final Set<String> analyzedFiles = {};

  /// Errors encountered during parsing
  final List<String> errors = [];

  void addWidget(WidgetInfo widget) => widgets.add(widget);
  void addColor(ColorReference color) => colors.add(color);
  void addSpacing(SpacingReference space) => spacing.add(space);
  void addTypography(TypographyReference typo) => typography.add(typo);
  void addError(String error) => errors.add(error);

  @override
  String toString() {
    return 'SymbolTable(widgets: ${widgets.length}, colors: ${colors.length}, '
        'spacing: ${spacing.length}, typography: ${typography.length}, '
        'files: ${analyzedFiles.length}, errors: ${errors.length})';
  }
}

/// AST Parser for Flutter UI/UX Audit
class AstParser {
  final AstParserConfig config;
  final SymbolTable symbolTable = SymbolTable();

  AstParser(this.config);

  /// Parse all files matching the configuration
  Future<SymbolTable> parse() async {
    final files = await _collectFiles();
    print('Found ${files.length} files to analyze');

    // Create analysis context
    final collection = AnalysisContextCollection(
      includedPaths: [config.projectPath],
    );

    for (final file in files) {
      try {
        await _parseFile(file, collection);
        symbolTable.analyzedFiles.add(file);
      } catch (e) {
        symbolTable.addError('Error parsing $file: $e');
        print('Error parsing $file: $e');
      }
    }

    return symbolTable;
  }

  /// Collect all files matching include/exclude patterns
  Future<List<String>> _collectFiles() async {
    final allFiles = <String>{};

    // Process include patterns
    for (final pattern in config.includePatterns) {
      final glob = Glob(pattern);
      final dir = Directory(config.projectPath);
      
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: config.projectPath);
          if (glob.matches(relativePath)) {
            allFiles.add(entity.path);
          }
        }
      }
    }

    // Filter out excluded patterns
    final filteredFiles = <String>[];
    for (final file in allFiles) {
      bool excluded = false;
      for (final pattern in config.excludePatterns) {
        final glob = Glob(pattern);
        final relativePath = path.relative(file, from: config.projectPath);
        if (glob.matches(relativePath)) {
          excluded = true;
          break;
        }
      }
      if (!excluded) {
        filteredFiles.add(file);
      }
    }

    return filteredFiles;
  }

  /// Parse a single file
  Future<void> _parseFile(
    String filePath,
    AnalysisContextCollection collection,
  ) async {
    final context = collection.contextFor(filePath);
    final result = await context.currentSession.getResolvedUnit(filePath);

    if (result is ResolvedUnitResult) {
      final visitor = _AstVisitor(filePath, symbolTable, result.lineInfo);
      result.unit.visitChildren(visitor);
    }
  }
}

/// AST Visitor to extract widget information
class _AstVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final SymbolTable symbolTable;
  final LineInfo lineInfo;
  final List<String> _widgetPath = [];

  _AstVisitor(this.filePath, this.symbolTable, this.lineInfo);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final className = node.constructorName.type.name2.toString();

    // Track widget hierarchy
    _widgetPath.add(className);

    // Extract widget properties
    final properties = <String, dynamic>{};
    if (node.argumentList.arguments.isNotEmpty) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          properties[name] = _extractValue(arg.expression);
        }
      }
    }

    // Get proper line and column numbers
    final location = lineInfo.getLocation(node.offset);

    // Create widget info
    final widgetInfo = WidgetInfo(
      className: className,
      filePath: filePath,
      line: location.lineNumber,
      column: location.columnNumber,
      properties: properties,
      widgetPath: _widgetPath.join(' > '),
    );
    symbolTable.addWidget(widgetInfo);

    // Extract specific property types
    _extractColorReferences(node, className);
    _extractSpacingReferences(node, className);
    _extractTypographyReferences(node, className);

    super.visitInstanceCreationExpression(node);

    _widgetPath.removeLast();
  }

  /// Extract color references from widget
  void _extractColorReferences(
    InstanceCreationExpression node,
    String className,
  ) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if (name == 'color' || name == 'backgroundColor') {
          final colorRef = _analyzeColorExpression(arg.expression, name);
          if (colorRef != null) {
            symbolTable.addColor(colorRef);
          }
        }
      }
    }
  }

  /// Analyze a color expression
  ColorReference? _analyzeColorExpression(Expression expr, String context) {
    String type;
    String value;

    final location = lineInfo.getLocation(expr.offset);

    if (expr is PropertyAccess) {
      // StudioTokens.of(context).primary pattern
      if (expr.target is MethodInvocation) {
        final target = expr.target as MethodInvocation;
        if (target.methodName.name == 'of' &&
            target.target.toString() == 'StudioTokens') {
          type = 'token';
          value = 'StudioTokens.${expr.propertyName.name}';
          return ColorReference(
            type: type,
            value: value,
            filePath: filePath,
            line: location.lineNumber,
            column: location.columnNumber,
            context: context,
          );
        }
      }
    } else if (expr is MethodInvocation) {
      // Check for StudioTokens.of(context).primary pattern (alternative form)
      if (expr.target is MethodInvocation) {
        final target = expr.target as MethodInvocation;
        if (target.methodName.name == 'of' &&
            target.target.toString() == 'StudioTokens') {
          type = 'token';
          value = 'StudioTokens.${expr.methodName.name}';
          return ColorReference(
            type: type,
            value: value,
            filePath: filePath,
            line: location.lineNumber,
            column: location.columnNumber,
            context: context,
          );
        }
      }
    } else if (expr is InstanceCreationExpression) {
      // Color(0xFF7C97FF) or Colors.blue
      final className = expr.constructorName.type.name2.toString();
      if (className == 'Color') {
        type = 'hardcoded';
        value = expr.toString();
        return ColorReference(
          type: type,
          value: value,
          filePath: filePath,
          line: location.lineNumber,
          column: location.columnNumber,
          context: context,
        );
      }
    } else if (expr is PrefixedIdentifier) {
      // Colors.blue pattern
      if (expr.prefix.name == 'Colors') {
        type = 'literal';
        value = expr.toString();
        return ColorReference(
          type: type,
          value: value,
          filePath: filePath,
          line: location.lineNumber,
          column: location.columnNumber,
          context: context,
        );
      }
    }

    return null;
  }

  /// Extract spacing references from widget
  void _extractSpacingReferences(
    InstanceCreationExpression node,
    String className,
  ) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if (name == 'padding' ||
            name == 'margin' ||
            name == 'height' ||
            name == 'width') {
          final spacingRef = _analyzeSpacingExpression(arg.expression, name);
          if (spacingRef != null) {
            symbolTable.addSpacing(spacingRef);
          }
        }
      }
    }
  }

  /// Analyze a spacing expression
  SpacingReference? _analyzeSpacingExpression(
    Expression expr,
    String context,
  ) {
    // Try to extract numeric value
    double? value;

    final location = lineInfo.getLocation(expr.offset);

    if (expr is IntegerLiteral) {
      value = expr.value?.toDouble();
    } else if (expr is DoubleLiteral) {
      value = expr.value;
    } else if (expr is PrefixedIdentifier) {
      // Check for StudioSpacing.xs, StudioLayoutSpacing.inlineGap, etc.
      if (expr.prefix.name == 'StudioSpacing' ||
          expr.prefix.name == 'StudioLayoutSpacing') {
        // This is a design system reference, mark as aligned
        return SpacingReference(
          type: 'aligned',
          value: 0, // Placeholder, actual value depends on constant
          filePath: filePath,
          line: location.lineNumber,
          column: location.columnNumber,
          context: '${expr.prefix.name}.${expr.identifier.name}',
        );
      }
    } else if (expr is PropertyAccess) {
      // Check for StudioSpacing.xs, StudioLayoutSpacing.inlineGap via property access
      final target = expr.target;
      if (target is SimpleIdentifier) {
        if (target.name == 'StudioSpacing' ||
            target.name == 'StudioLayoutSpacing') {
          return SpacingReference(
            type: 'aligned',
            value: 0, // Placeholder
            filePath: filePath,
            line: location.lineNumber,
            column: location.columnNumber,
            context: '${target.name}.${expr.propertyName.name}',
          );
        }
      }
    }

    if (value != null) {
      // Classify spacing
      String type;
      const studioSpacing = [8.0, 16.0, 24.0, 32.0];
      const layoutSpacing = [10.0, 12.0, 14.0, 18.0];

      if (studioSpacing.contains(value)) {
        type = 'aligned';
      } else if (layoutSpacing.contains(value)) {
        type = 'legacy';
      } else {
        type = 'non-standard';
      }

      return SpacingReference(
        type: type,
        value: value,
        filePath: filePath,
        line: location.lineNumber,
        column: location.columnNumber,
        context: context,
      );
    }

    return null;
  }

  /// Extract typography references from widget
  void _extractTypographyReferences(
    InstanceCreationExpression node,
    String className,
  ) {
    if (className == 'Text' || className == 'TextStyle') {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'style') {
          final typoRef = _analyzeTypographyExpression(arg.expression);
          if (typoRef != null) {
            symbolTable.addTypography(typoRef);
          }
        }
      }
    }
  }

  /// Analyze a typography expression
  TypographyReference? _analyzeTypographyExpression(Expression expr) {
    final location = lineInfo.getLocation(expr.offset);

    if (expr is InstanceCreationExpression) {
      final className = expr.constructorName.type.name2.toString();
      if (className == 'TextStyle') {
        double? fontSize;
        String? fontWeight;
        double? lineHeight;
        String? fontFamily;

        for (final arg in expr.argumentList.arguments) {
          if (arg is NamedExpression) {
            final name = arg.name.label.name;
            switch (name) {
              case 'fontSize':
                if (arg.expression is IntegerLiteral) {
                  fontSize =
                      (arg.expression as IntegerLiteral).value?.toDouble();
                } else if (arg.expression is DoubleLiteral) {
                  fontSize = (arg.expression as DoubleLiteral).value;
                }
                break;
              case 'fontWeight':
                fontWeight = arg.expression.toString();
                break;
              case 'height':
                if (arg.expression is DoubleLiteral) {
                  lineHeight = (arg.expression as DoubleLiteral).value;
                }
                break;
              case 'fontFamily':
                fontFamily = arg.expression.toString();
                break;
            }
          }
        }

        return TypographyReference(
          type: 'hardcoded',
          fontSize: fontSize,
          fontWeight: fontWeight,
          lineHeight: lineHeight,
          fontFamily: fontFamily,
          filePath: filePath,
          line: location.lineNumber,
          column: location.columnNumber,
          context: 'TextStyle',
        );
      }
    } else if (expr is PropertyAccess) {
      // Check for StudioTypography.of(context).body pattern
      if (expr.target is MethodInvocation) {
        final target = expr.target as MethodInvocation;
        if (target.methodName.name == 'of' &&
            target.target.toString() == 'StudioTypography') {
          return TypographyReference(
            type: 'studio-typography',
            filePath: filePath,
            line: location.lineNumber,
            column: location.columnNumber,
            context: 'StudioTypography.${expr.propertyName.name}',
          );
        }
      }
    } else if (expr is MethodInvocation) {
      // Check for StudioTypography.of(context).body pattern (alternative form)
      if (expr.target is MethodInvocation) {
        final target = expr.target as MethodInvocation;
        if (target.methodName.name == 'of' &&
            target.target.toString() == 'StudioTypography') {
          return TypographyReference(
            type: 'studio-typography',
            filePath: filePath,
            line: location.lineNumber,
            column: location.columnNumber,
            context: 'StudioTypography.${expr.methodName.name}',
          );
        }
      }
    }

    return null;
  }

  /// Extract value from expression (simplified)
  dynamic _extractValue(Expression expr) {
    if (expr is IntegerLiteral) {
      return expr.value;
    } else if (expr is DoubleLiteral) {
      return expr.value;
    } else if (expr is StringLiteral) {
      return expr.stringValue;
    } else if (expr is BooleanLiteral) {
      return expr.value;
    }
    return expr.toString();
  }
}
