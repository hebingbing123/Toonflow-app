import 'package:json_annotation/json_annotation.dart';
import 'package:glob/glob.dart';
import '../models/enums.dart';

part 'ignore_rules.g.dart';

/// Configuration for ignoring specific issues or patterns
@JsonSerializable()
class IgnoreRules {
  /// File patterns to ignore (glob patterns)
  final List<String> ignoreFiles;
  
  /// Specific finding IDs to ignore
  final List<String> ignoreFindingIds;
  
  /// Categories to ignore globally
  final List<FindingCategory> ignoreCategories;
  
  /// Ignore rules by file pattern and category
  final List<IgnoreRule> rules;

  const IgnoreRules({
    this.ignoreFiles = const [],
    this.ignoreFindingIds = const [],
    this.ignoreCategories = const [],
    this.rules = const [],
  });

  factory IgnoreRules.fromJson(Map<String, dynamic> json) =>
      _$IgnoreRulesFromJson(json);

  Map<String, dynamic> toJson() => _$IgnoreRulesToJson(this);

  /// Creates ignore rules from YAML map
  factory IgnoreRules.fromYaml(Map<String, dynamic> yaml) {
    final ignoreConfig = yaml['ignore'] as Map<String, dynamic>? ?? {};
    
    return IgnoreRules(
      ignoreFiles: (ignoreConfig['files'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      ignoreFindingIds: (ignoreConfig['findingIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      ignoreCategories: (ignoreConfig['categories'] as List<dynamic>?)
              ?.map((e) => _parseFindingCategory(e.toString()))
              .toList() ??
          const [],
      rules: (ignoreConfig['rules'] as List<dynamic>?)
              ?.map((e) => IgnoreRule.fromYaml(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  static FindingCategory _parseFindingCategory(String value) {
    return FindingCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Invalid category: $value'),
    );
  }

  /// Checks if a file should be ignored
  bool shouldIgnoreFile(String filePath) {
    for (final pattern in ignoreFiles) {
      final glob = Glob(pattern);
      if (glob.matches(filePath)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a finding ID should be ignored
  bool shouldIgnoreFindingId(String findingId) {
    return ignoreFindingIds.contains(findingId);
  }

  /// Checks if a category should be ignored
  bool shouldIgnoreCategory(FindingCategory category) {
    return ignoreCategories.contains(category);
  }

  /// Checks if a finding should be ignored based on rules
  bool shouldIgnoreFinding({
    required String filePath,
    required FindingCategory category,
    required String findingId,
  }) {
    // Check global ignores first
    if (shouldIgnoreFile(filePath)) return true;
    if (shouldIgnoreFindingId(findingId)) return true;
    if (shouldIgnoreCategory(category)) return true;

    // Check specific rules
    for (final rule in rules) {
      if (rule.matches(filePath: filePath, category: category)) {
        return true;
      }
    }

    return false;
  }

  @override
  String toString() {
    return 'IgnoreRules('
        'files: ${ignoreFiles.length}, '
        'findingIds: ${ignoreFindingIds.length}, '
        'categories: ${ignoreCategories.length}, '
        'rules: ${rules.length})';
  }
}

/// A specific ignore rule combining file pattern and category
@JsonSerializable()
class IgnoreRule {
  /// File pattern (glob)
  final String filePattern;
  
  /// Categories to ignore for this pattern
  final List<FindingCategory> categories;
  
  /// Optional reason for ignoring
  final String? reason;

  const IgnoreRule({
    required this.filePattern,
    required this.categories,
    this.reason,
  });

  factory IgnoreRule.fromJson(Map<String, dynamic> json) =>
      _$IgnoreRuleFromJson(json);

  Map<String, dynamic> toJson() => _$IgnoreRuleToJson(this);

  factory IgnoreRule.fromYaml(Map<String, dynamic> yaml) {
    return IgnoreRule(
      filePattern: yaml['filePattern'] as String,
      categories: (yaml['categories'] as List<dynamic>)
          .map((e) => IgnoreRules._parseFindingCategory(e.toString()))
          .toList(),
      reason: yaml['reason'] as String?,
    );
  }

  /// Checks if this rule matches the given file and category
  bool matches({
    required String filePath,
    required FindingCategory category,
  }) {
    if (!categories.contains(category)) {
      return false;
    }

    final glob = Glob(filePattern);
    return glob.matches(filePath);
  }

  @override
  String toString() {
    return 'IgnoreRule($filePattern: ${categories.map((c) => c.name).join(", ")})';
  }
}
