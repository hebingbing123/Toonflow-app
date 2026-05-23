import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

import '../models/location.dart';

/// Result of parsing a single Dart source file.
class ParsedDartFile {
  final String filePath;
  final String content;
  final CompilationUnit unit;
  final LineInfo lineInfo;

  const ParsedDartFile({
    required this.filePath,
    required this.content,
    required this.unit,
    required this.lineInfo,
  });

  Location atOffset(int offset, {String? widgetPath}) {
    final location = lineInfo.getLocation(offset);
    return Location(
      file: filePath,
      line: location.lineNumber,
      column: location.columnNumber,
      widgetPath: widgetPath,
    );
  }
}

/// Lightweight symbol table built while walking the AST.
class SymbolTable {
  final Set<String> designSystemReferences = {};
  final List<WidgetSymbol> widgets = [];

  void recordDesignSystemReference(String reference) {
    designSystemReferences.add(reference);
  }

  void recordWidget(WidgetSymbol symbol) {
    widgets.add(symbol);
  }
}

/// Metadata for a widget instantiation discovered in source.
class WidgetSymbol {
  final String typeName;
  final int offset;
  final Map<String, String> properties;

  const WidgetSymbol({
    required this.typeName,
    required this.offset,
    this.properties = const {},
  });
}

/// Parses Dart files and traverses project directories with include/exclude globs.
class AstParser {
  final Map<String, _ParseCacheEntry> _cache = {};

  /// Clears in-memory AST cache (useful between audit runs in long-lived processes).
  void clearCache() => _cache.clear();

  /// Parses [filePath] into a [ParsedDartFile], or null if unreadable or invalid.
  Future<ParsedDartFile?> parseFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final stat = await file.stat();
      final cached = _cache[filePath];
      if (cached != null && cached.modifiedMs == stat.modified.millisecondsSinceEpoch) {
        return cached.parsed;
      }

      final content = await file.readAsString();
      final parseResult = parseString(content: content, path: filePath);
      final unit = parseResult.unit;

      if (unit == null) {
        return null;
      }

      final lineInfo = parseResult.lineInfo ?? LineInfo.fromContent(content);

      final parsed = ParsedDartFile(
        filePath: filePath,
        content: content,
        unit: unit,
        lineInfo: lineInfo,
      );
      _cache[filePath] = _ParseCacheEntry(
        modifiedMs: stat.modified.millisecondsSinceEpoch,
        parsed: parsed,
      );
      return parsed;
    } catch (_) {
      return null;
    }
  }

  /// Collects Dart files under [projectPath] matching [includePaths] and not [excludePaths].
  ///
  /// Patterns are relative to [projectPath] (e.g. `lib/**/*.dart`).
  Future<List<String>> collectDartFiles({
    required String projectPath,
    List<String> includePaths = const ['lib/**/*.dart'],
    List<String> excludePaths = const [
      'lib/generated/**',
      'lib/**/*.g.dart',
      'lib/**/*.freezed.dart',
    ],
  }) async {
    final root = Directory(projectPath);
    if (!await root.exists()) {
      return [];
    }

    final results = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final relative = p.relative(entity.path, from: p.normalize(projectPath));
      final normalized = relative.replaceAll(r'\', '/');

      if (!_matchesAny(normalized, includePaths)) {
        continue;
      }
      if (_matchesAny(normalized, excludePaths)) {
        continue;
      }

      results.add(entity.path);
    }

    results.sort();
    return results;
  }

  /// Builds a [SymbolTable] by scanning design-system references and widget nodes.
  SymbolTable buildSymbolTable(ParsedDartFile parsed) {
    final table = SymbolTable();
    parsed.unit.accept(_SymbolTableVisitor(table));
    return table;
  }

  static bool _matchesAny(String relativePath, List<String> patterns) {
    for (final pattern in patterns) {
      if (_matchesGlob(relativePath, pattern)) {
        return true;
      }
    }
    return false;
  }

  static bool _matchesGlob(String relativePath, String pattern) {
    final normalizedPattern = pattern.replaceAll(r'\', '/');
    final normalizedPath = relativePath.replaceAll(r'\', '/');

    const dartGlobSuffix = '/**/*.dart';
    if (normalizedPattern.endsWith(dartGlobSuffix)) {
      final prefix = normalizedPattern.substring(
        0,
        normalizedPattern.length - dartGlobSuffix.length,
      );
      return normalizedPath.startsWith('$prefix/') &&
          normalizedPath.endsWith('.dart');
    }

    const generatedSuffix = '/generated/**';
    if (normalizedPattern.endsWith(generatedSuffix)) {
      final prefix = normalizedPattern.substring(
        0,
        normalizedPattern.length - generatedSuffix.length,
      );
      return normalizedPath.startsWith('$prefix/generated/');
    }

    const gDartSuffix = '/**/*.g.dart';
    if (normalizedPattern.endsWith(gDartSuffix)) {
      final prefix = normalizedPattern.substring(
        0,
        normalizedPattern.length - gDartSuffix.length,
      );
      return normalizedPath.startsWith('$prefix/') &&
          normalizedPath.endsWith('.g.dart');
    }

    if (normalizedPattern.contains('**')) {
      final regexPattern = normalizedPattern
          .replaceAll('.', r'\.')
          .replaceAll('**', '.*')
          .replaceAll('*', '[^/]*');
      return RegExp('^$regexPattern\$').hasMatch(normalizedPath);
    }

    final regexPattern = normalizedPattern
        .replaceAll('.', r'\.')
        .replaceAll('*', '[^/]*');
    return RegExp('^$regexPattern\$').hasMatch(normalizedPath);
  }
}

class _SymbolTableVisitor extends RecursiveAstVisitor<void> {
  final SymbolTable table;

  _SymbolTableVisitor(this.table);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _recordWidget(
      node.constructorName.type.toSource(),
      node.offset,
      node.argumentList.arguments,
      node.toSource(),
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = constructionNameFromMethodInvocation(node);
    if (name != null) {
      _recordWidget(
        name,
        node.offset,
        node.argumentList.arguments,
        node.toSource(),
      );
    }
    super.visitMethodInvocation(node);
  }

  void _recordWidget(
    String typeName,
    int offset,
    NodeList<Expression> arguments,
    String source,
  ) {
    final properties = <String, String>{};
    for (final arg in arguments) {
      if (arg is NamedExpression) {
        properties[arg.name.label.name] = arg.expression.toSource();
      }
    }

    table.recordWidget(
      WidgetSymbol(
        typeName: typeName,
        offset: offset,
        properties: properties,
      ),
    );
    _recordDesignSystemRefs(source);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _recordDesignSystemRefs(node.toSource());
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _recordDesignSystemRefs(node.toSource());
    super.visitPropertyAccess(node);
  }

  void _recordDesignSystemRefs(String source) {
    for (final prefix in const [
      'StudioTypography',
      'StudioSpacing',
      'StudioLayoutSpacing',
      'StudioTokens',
    ]) {
      if (source.contains(prefix)) {
        table.recordDesignSystemReference(prefix);
      }
    }
  }
}

/// Extracts a numeric literal from an [Expression], if possible.
double? extractNumericLiteral(Expression? expression) {
  if (expression == null) {
    return null;
  }
  if (expression is IntegerLiteral) {
    return expression.value?.toDouble();
  }
  if (expression is DoubleLiteral) {
    return expression.value;
  }
  if (expression is PrefixExpression &&
      expression.operator.lexeme == '-' &&
      expression.operand is IntegerLiteral) {
    final value = (expression.operand as IntegerLiteral).value;
    return value == null ? null : -value.toDouble();
  }
  return null;
}

/// Resolves widget-style construction name from a [MethodInvocation].
///
/// Unresolved Flutter types (no SDK context) parse as method calls, e.g.
/// `Text(...)` and `EdgeInsets.all(...)`.
String? constructionNameFromMethodInvocation(MethodInvocation node) {
  final method = node.methodName.name;
  if (node.target == null) {
    const topLevel = {
      'Text',
      'RichText',
      'TextStyle',
      'SizedBox',
      'Color',
      'Icon',
      'Image',
      'TextField',
      'TextFormField',
      'ListView',
      'GridView',
      'Container',
      'Card',
      'Chip',
      'Dialog',
    };
    if (topLevel.contains(method)) {
      return method;
    }
    return null;
  }

  if (node.target is SimpleIdentifier) {
    final target = (node.target! as SimpleIdentifier).name;
    if (target == 'EdgeInsets' || target == 'BorderRadius') {
      return '$target.$method';
    }
  }

  if (node.target is PrefixedIdentifier) {
    final target = node.target! as PrefixedIdentifier;
    return '${target.prefix.name}.${target.identifier.name}.$method';
  }

  return null;
}

class _ParseCacheEntry {
  final int modifiedMs;
  final ParsedDartFile parsed;

  const _ParseCacheEntry({
    required this.modifiedMs,
    required this.parsed,
  });
}

/// Returns true when [expression] references the design-system spacing APIs.
bool referencesDesignSystemSpacing(Expression? expression) {
  final source = expression?.toSource() ?? '';
  return source.contains('StudioSpacing') ||
      source.contains('StudioLayoutSpacing');
}
