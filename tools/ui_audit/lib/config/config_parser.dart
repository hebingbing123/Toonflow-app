import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../models/models.dart';

/// Parses audit configuration from YAML files
class ConfigParser {
  /// Loads configuration from a YAML file
  static Future<AuditConfiguration> loadFromFile(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw ConfigParserException('Configuration file not found: $path');
    }

    try {
      final contents = await file.readAsString();
      final yaml = loadYaml(contents);

      if (yaml is! Map) {
        throw ConfigParserException('Invalid YAML format: expected a map');
      }

      final config = AuditConfiguration.fromYaml(
        _yamlToMap(yaml),
      );
      return _resolvePaths(config, path);
    } on YamlException catch (e) {
      throw ConfigParserException('Failed to parse YAML: ${e.message}');
    } catch (e) {
      throw ConfigParserException('Failed to load configuration: $e');
    }
  }

  static Map<String, dynamic> _yamlToMap(Map yaml) {
    return yaml.map(
      (key, value) => MapEntry(key.toString(), _yamlValue(value)),
    );
  }

  static dynamic _yamlValue(dynamic value) {
    if (value is Map) {
      return _yamlToMap(value);
    }
    if (value is List) {
      return value.map(_yamlValue).toList();
    }
    return value;
  }

  static AuditConfiguration _resolvePaths(
    AuditConfiguration config,
    String configPath,
  ) {
    final configDir = p.dirname(p.absolute(configPath));
    final repoRoot = p.normalize(p.join(configDir, '..'));

    final projectPath = _resolveDirectory(
      config.projectPath,
      cwd: Directory.current.path,
      configDir: configDir,
      repoRoot: repoRoot,
    );
    final outputDirectory = _resolveDirectory(
      config.outputDirectory,
      cwd: Directory.current.path,
      configDir: configDir,
      repoRoot: repoRoot,
    );

    return AuditConfiguration(
      projectPath: projectPath,
      includePaths: config.includePaths,
      excludePaths: config.excludePaths,
      enabledCategories: config.enabledCategories,
      minimumSeverity: config.minimumSeverity,
      testBreakpoints: config.testBreakpoints,
      captureScreenshots: config.captureScreenshots,
      runRuntimeInspection: config.runRuntimeInspection,
      outputFormats: config.outputFormats,
      outputDirectory: outputDirectory,
      includeBeforeAfter: config.includeBeforeAfter,
      failOnCritical: config.failOnCritical,
      failOnHigh: config.failOnHigh,
      maxFindings: config.maxFindings,
    );
  }

  static String _resolveDirectory(
    String configuredPath, {
    required String cwd,
    required String configDir,
    required String repoRoot,
  }) {
    if (p.isAbsolute(configuredPath)) {
      return configuredPath;
    }

    final candidates = [
      p.normalize(p.join(cwd, configuredPath)),
      p.normalize(p.join(configDir, configuredPath)),
      p.normalize(p.join(repoRoot, configuredPath)),
    ];

    for (final candidate in candidates) {
      if (Directory(candidate).existsSync()) {
        return candidate;
      }
    }

    return p.normalize(p.join(repoRoot, configuredPath));
  }

  /// Creates a default configuration file at the specified path
  static Future<void> createDefaultConfig(String path) async {
    final file = File(path);
    
    if (await file.exists()) {
      throw ConfigParserException('Configuration file already exists: $path');
    }

    await file.create(recursive: true);
    await file.writeAsString(_defaultConfigYaml);
  }

  static const String _defaultConfigYaml = '''
# UI/UX Audit Configuration
audit:
  projectPath: frontend/
  
  include:
    - lib/**/*.dart
  
  exclude:
    - lib/generated/**
    - lib/**/*.g.dart
    - lib/**/*.freezed.dart
  
  categories:
    - visualHierarchy
    - spacing
    - typography
    - colorSystem
    - interactiveElements
    - emptyStates
    - responsiveness
    - componentConsistency
    - accessibility
  
  minimumSeverity: low
  
  runtime:
    enabled: true
    breakpoints: [520, 720, 760, 1100, 1280, 1720]
    captureScreenshots: true
    screenshotFormat: png
    screenshotQuality: 80
  
  output:
    formats: [json, markdown, html]
    directory: .kiro/audit-reports/
    includeBeforeAfter: true
    includeScreenshots: true
  
  thresholds:
    failOnCritical: true
    failOnHigh: false
    maxFindings: 200
''';
}

/// Exception thrown when configuration parsing fails
class ConfigParserException implements Exception {
  final String message;

  ConfigParserException(this.message);

  @override
  String toString() => 'ConfigParserException: $message';
}
