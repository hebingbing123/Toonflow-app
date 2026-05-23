import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;

/// Parses design system definitions from Dart source files
class DesignSystemParser {
  final String projectPath;
  
  DesignSystemParser(this.projectPath);
  
  /// Parses StudioTokens color definitions
  Future<Map<String, String>> parseStudioTokens() async {
    final tokensPath = path.join(
      projectPath,
      'lib',
      'design_system',
      'tokens.dart',
    );
    
    final file = File(tokensPath);
    if (!await file.exists()) {
      throw Exception('StudioTokens file not found at $tokensPath');
    }
    
    final content = await file.readAsString();
    final parseResult = parseString(content: content);
    
    final visitor = _TokensVisitor();
    parseResult.unit.visitChildren(visitor);
    
    return visitor.tokens;
  }
  
  /// Parses StudioTypography font size definitions
  Future<Map<String, double>> parseStudioTypography() async {
    final typographyPath = path.join(
      projectPath,
      'lib',
      'design_system',
      'studio_typography.dart',
    );
    
    final file = File(typographyPath);
    if (!await file.exists()) {
      throw Exception('StudioTypography file not found at $typographyPath');
    }
    
    final content = await file.readAsString();
    final parseResult = parseString(content: content);
    
    final visitor = _TypographyVisitor();
    parseResult.unit.visitChildren(visitor);
    
    return visitor.fontSizes;
  }
  
  /// Parses StudioSpacing constant definitions
  Future<Map<String, double>> parseStudioSpacing() async {
    final tokensPath = path.join(
      projectPath,
      'lib',
      'design_system',
      'tokens.dart',
    );
    
    final file = File(tokensPath);
    if (!await file.exists()) {
      throw Exception('StudioSpacing file not found at $tokensPath');
    }
    
    final content = await file.readAsString();
    final parseResult = parseString(content: content);
    
    final visitor = _SpacingVisitor();
    parseResult.unit.visitChildren(visitor);
    
    return visitor.spacing;
  }
  
  /// Parses all design system definitions
  Future<DesignSystemDefinitions> parseAll() async {
    final tokens = await parseStudioTokens();
    final typography = await parseStudioTypography();
    final spacing = await parseStudioSpacing();
    
    return DesignSystemDefinitions(
      tokens: tokens,
      typography: typography,
      spacing: spacing,
    );
  }
}

/// Visitor to extract StudioTokens color definitions
class _TokensVisitor extends RecursiveAstVisitor<void> {
  final Map<String, String> tokens = {};
  
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.name.lexeme == 'StudioTokens') {
      // Look for the static const dark field
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            if (variable.name.lexeme == 'dark') {
              _extractTokensFromConstructor(variable.initializer);
            }
          }
        }
      }
    }
    super.visitClassDeclaration(node);
  }
  
  void _extractTokensFromConstructor(Expression? initializer) {
    if (initializer is InstanceCreationExpression) {
      for (final arg in initializer.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          final value = arg.expression;
          
          if (value is MethodInvocation && value.methodName.name == 'Color') {
            // Extract hex color value
            final hexArg = value.argumentList.arguments.first;
            if (hexArg is IntegerLiteral) {
              tokens[name] = '0x${hexArg.value!.toRadixString(16).padLeft(8, '0')}';
            }
          }
        }
      }
    }
  }
}

/// Visitor to extract StudioTypography font size definitions
class _TypographyVisitor extends RecursiveAstVisitor<void> {
  final Map<String, double> fontSizes = {};
  
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.name.lexeme == 'StudioTypography') {
      // Look for the static const regular field
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            if (variable.name.lexeme == 'regular') {
              _extractFontSizesFromConstructor(variable.initializer);
            }
          }
        }
      }
    }
    super.visitClassDeclaration(node);
  }
  
  void _extractFontSizesFromConstructor(Expression? initializer) {
    if (initializer is InstanceCreationExpression) {
      for (final arg in initializer.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          final value = arg.expression;
          
          // Skip non-font-size fields
          if (name.contains('Padding') || name.contains('Height')) {
            continue;
          }
          
          if (value is IntegerLiteral) {
            fontSizes[name] = value.value!.toDouble();
          } else if (value is DoubleLiteral) {
            fontSizes[name] = value.value;
          }
        }
      }
    }
  }
}

/// Visitor to extract StudioSpacing constant definitions
class _SpacingVisitor extends RecursiveAstVisitor<void> {
  final Map<String, double> spacing = {};
  
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.name.lexeme == 'StudioSpacing' || 
        node.name.lexeme == 'StudioLayoutSpacing') {
      for (final member in node.members) {
        if (member is FieldDeclaration && member.isStatic) {
          for (final variable in member.fields.variables) {
            final name = variable.name.lexeme;
            final initializer = variable.initializer;
            
            if (initializer is IntegerLiteral) {
              spacing[name] = initializer.value!.toDouble();
            } else if (initializer is DoubleLiteral) {
              spacing[name] = initializer.value;
            } else if (initializer is PrefixedIdentifier) {
              // Handle references like StudioSpacing.md
              // We'll resolve these in a second pass
              spacing[name] = 0.0; // Placeholder
            }
          }
        }
      }
    }
    super.visitClassDeclaration(node);
  }
}

/// Container for all design system definitions
class DesignSystemDefinitions {
  final Map<String, String> tokens;
  final Map<String, double> typography;
  final Map<String, double> spacing;
  
  const DesignSystemDefinitions({
    required this.tokens,
    required this.typography,
    required this.spacing,
  });
  
  /// Finds the closest spacing constant to a given value
  String? findClosestSpacing(double value) {
    if (spacing.isEmpty) return null;
    
    String? closest;
    double minDiff = double.infinity;
    
    for (final entry in spacing.entries) {
      final diff = (entry.value - value).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = entry.key;
      }
    }
    
    return closest;
  }
  
  /// Finds the closest typography size to a given value
  String? findClosestTypography(double value) {
    if (typography.isEmpty) return null;
    
    String? closest;
    double minDiff = double.infinity;
    
    for (final entry in typography.entries) {
      final diff = (entry.value - value).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = entry.key;
      }
    }
    
    return closest;
  }
  
  /// Checks if a color hex value exists in tokens
  bool hasColor(String hexValue) {
    return tokens.values.any((v) => v.toLowerCase() == hexValue.toLowerCase());
  }
  
  /// Finds token name for a given color hex value
  String? findColorToken(String hexValue) {
    for (final entry in tokens.entries) {
      if (entry.value.toLowerCase() == hexValue.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }
  
  @override
  String toString() {
    return 'DesignSystemDefinitions('
        'tokens: ${tokens.length}, '
        'typography: ${typography.length}, '
        'spacing: ${spacing.length})';
  }
}
