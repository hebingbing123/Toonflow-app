import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/models.dart';
import 'ast_parser.dart';
import 'static_analyzer.dart';

/// Detects hardcoded colors and misuse of StudioTokens (including glass).
class ColorSystemAnalyzer extends StaticAnalyzer {
  int _findingCounter = 0;
  final AstParser _parser;

  ColorSystemAnalyzer({AstParser? parser}) : _parser = parser ?? AstParser();

  @override
  FindingCategory get category => FindingCategory.colorSystem;

  @override
  Future<List<Finding>> analyze(String filePath) async {
    if (filePath.endsWith('design_system/theme.dart') ||
        filePath.endsWith('design_system/tokens.dart')) {
      return [];
    }

    final parsed = await _parser.parseFile(filePath);
    if (parsed == null) {
      return [];
    }

    final visitor = _ColorVisitor(parsed, this);
    parsed.unit.accept(visitor);
    return visitor.findings;
  }

  String _generateFindingId() {
    _findingCounter++;
    return 'CS-${_findingCounter.toString().padLeft(3, '0')}';
  }
}

class _ColorVisitor extends RecursiveAstVisitor<void> {
  final ParsedDartFile parsed;
  final ColorSystemAnalyzer analyzer;
  final List<Finding> findings = [];
  final Set<String> _reported = {};
  String? _enclosingClassName;

  _ColorVisitor(this.parsed, this.analyzer);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previous = _enclosingClassName;
    _enclosingClassName = node.name.lexeme;
    super.visitClassDeclaration(node);
    _enclosingClassName = previous;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toSource();
    if (typeName == 'Color') {
      _reportHardcodedColor(node, node.toSource());
    }
    _checkGlassUsage(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = constructionNameFromMethodInvocation(node);
    if (name == 'Color') {
      _reportHardcodedColor(node, node.toSource());
    }
    _checkGlassUsage(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final source = node.toSource();
    if (source.startsWith('Colors.')) {
      _reportHardcodedColor(node, source);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final property = node.propertyName.name;
    if (property == 'glass' || property == 'glassBorder') {
      _checkGlassUsage(node);
    }
    super.visitPropertyAccess(node);
  }

  void _reportHardcodedColor(AstNode node, String source) {
    if (source.contains('StudioTokens') ||
        source == 'Colors.transparent' ||
        source.startsWith('studioShadowColor') ||
        source.startsWith('studioInsetElevationShadow')) {
      return;
    }

    if (parsed.filePath.contains('design_system/')) {
      if (source == 'Colors.black' ||
          source == 'Colors.white' ||
          RegExp(r'Colors\.(black|white)\.withValues').hasMatch(source)) {
        return;
      }
    }

    if (parsed.filePath.endsWith('product_shell/login_page.dart') ||
        parsed.filePath.endsWith('main_harness.dart')) {
      return;
    }

    if (parsed.filePath.endsWith('preview_player.dart') &&
        source == 'Colors.black') {
      return;
    }

    if (source == 'Color(0x00000000)' || source == 'Color(0x00000000)') {
      return;
    }

    final key = '${node.offset}:$source';
    if (_reported.contains(key)) {
      return;
    }
    _reported.add(key);

    findings.add(
      Finding(
        id: analyzer._generateFindingId(),
        category: FindingCategory.colorSystem,
        severity: Severity.high,
        title: 'Hardcoded color value',
        description: 'Color does not reference StudioTokens: $source',
        location: parsed.atOffset(node.offset),
        codeSnippet: source.length > 100 ? '${source.substring(0, 100)}...' : source,
        recommendation:
            'Replace with StudioTokens.of(context) semantic color (bgSurface, primary, textPrimary, etc.)',
        designSystemReference: 'StudioTokens',
        effort: Effort.small,
        beforeAfter: BeforeAfter(
          before: source,
          after: 'StudioTokens.of(context).<token>',
        ),
      ),
    );
  }

  void _checkGlassUsage(AstNode node) {
    final source = node.toSource();
    if (!source.contains('glass') && !source.contains('glassBorder')) {
      return;
    }

    if (!source.contains('StudioTokens') && !source.contains('tokens.')) {
      return;
    }

    const overlayHints = [
      'Overlay',
      'Toast',
      'Dialog',
      'Modal',
      'Palette',
      'Banner',
      'GlassPanel',
      'glass.dart',
      'ReviewPack',
      'review_pack',
    ];

    final className = _enclosingClassName ?? '';
    final isLikelyOverlay =
        overlayHints.any((hint) => source.contains(hint) || className.contains(hint));
    if (isLikelyOverlay) {
      return;
    }

    final key = 'glass:${node.offset}';
    if (_reported.contains(key)) {
      return;
    }
    _reported.add(key);

    findings.add(
      Finding(
        id: analyzer._generateFindingId(),
        category: FindingCategory.colorSystem,
        severity: Severity.medium,
        title: 'Glass token on non-overlay surface',
        description:
            'glass/glassBorder tokens should only be used for overlay chrome (sidebar, toast, modal)',
        location: parsed.atOffset(node.offset),
        codeSnippet: source.length > 120 ? '${source.substring(0, 120)}...' : source,
        recommendation:
            'Use bgSurface or bgElevated for content panels; reserve glass tokens for overlay shells',
        designSystemReference: 'StudioTokens.glass (overlay only)',
        effort: Effort.medium,
      ),
    );
  }
}
