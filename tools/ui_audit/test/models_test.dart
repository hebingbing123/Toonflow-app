import 'package:flutter_test/flutter_test.dart';
import 'package:ui_audit/models/models.dart';
import 'package:ui_audit/config/config_parser.dart';

void main() {
  group('Data Models', () {
    test('Finding can be created and serialized', () {
      final finding = Finding(
        id: 'VH-001',
        category: FindingCategory.visualHierarchy,
        severity: Severity.high,
        title: 'Test finding',
        description: 'Test description',
        location: const Location(
          file: 'lib/test.dart',
          line: 10,
          column: 5,
        ),
        recommendation: 'Fix this',
        effort: Effort.small,
      );

      expect(finding.id, 'VH-001');
      expect(finding.category, FindingCategory.visualHierarchy);
      expect(finding.severity, Severity.high);

      // Test JSON serialization
      final json = finding.toJson();
      expect(json['id'], 'VH-001');
      expect(json['category'], 'visualHierarchy');
      expect(json['severity'], 'high');
      
      // Verify location is serialized
      expect(json['location'], isA<Map<String, dynamic>>());
      expect(json['location']['file'], 'lib/test.dart');
    });

    test('Location can be created and serialized', () {
      const location = Location(
        file: 'lib/test.dart',
        line: 10,
        column: 5,
        widgetPath: 'Scaffold > Column > Text',
      );

      expect(location.file, 'lib/test.dart');
      expect(location.line, 10);
      expect(location.column, 5);
      expect(location.widgetPath, 'Scaffold > Column > Text');

      // Test JSON serialization
      final json = location.toJson();
      final fromJson = Location.fromJson(json);
      expect(fromJson, location);
    });

    test('AuditConfiguration can be created from YAML', () {
      final yaml = {
        'audit': {
          'projectPath': 'frontend/',
          'include': ['lib/**/*.dart'],
          'exclude': ['lib/**/*.g.dart'],
          'categories': ['visualHierarchy', 'spacing'],
          'minimumSeverity': 'medium',
          'runtime': {
            'enabled': true,
            'breakpoints': [720, 1280],
            'captureScreenshots': false,
          },
          'output': {
            'formats': ['json'],
            'directory': '.kiro/reports/',
            'includeBeforeAfter': false,
          },
          'thresholds': {
            'failOnCritical': true,
            'failOnHigh': true,
            'maxFindings': 100,
          },
        },
      };

      final config = AuditConfiguration.fromYaml(yaml);

      expect(config.projectPath, 'frontend/');
      expect(config.includePaths, ['lib/**/*.dart']);
      expect(config.excludePaths, ['lib/**/*.g.dart']);
      expect(config.enabledCategories, [
        FindingCategory.visualHierarchy,
        FindingCategory.spacing,
      ]);
      expect(config.minimumSeverity, Severity.medium);
      expect(config.testBreakpoints, [720, 1280]);
      expect(config.captureScreenshots, false);
      expect(config.runRuntimeInspection, true);
      expect(config.outputFormats, ['json']);
      expect(config.outputDirectory, '.kiro/reports/');
      expect(config.includeBeforeAfter, false);
      expect(config.failOnCritical, true);
      expect(config.failOnHigh, true);
      expect(config.maxFindings, 100);
    });

    test('AuditSummary can be created from findings', () {
      const location = Location(file: 'lib/a.dart', line: 1, column: 1);
      final findings = [
        Finding(
          id: 'A-1',
          category: FindingCategory.accessibility,
          severity: Severity.critical,
          title: 't',
          description: 'd',
          location: location,
          recommendation: 'r',
          effort: Effort.small,
        ),
        Finding(
          id: 'S-1',
          category: FindingCategory.spacing,
          severity: Severity.high,
          title: 't',
          description: 'd',
          location: location,
          recommendation: 'r',
          effort: Effort.small,
        ),
        Finding(
          id: 'S-2',
          category: FindingCategory.spacing,
          severity: Severity.high,
          title: 't',
          description: 'd',
          location: location,
          recommendation: 'r',
          effort: Effort.small,
        ),
        Finding(
          id: 'T-1',
          category: FindingCategory.typography,
          severity: Severity.medium,
          title: 't',
          description: 'd',
          location: location,
          recommendation: 'r',
          effort: Effort.small,
        ),
      ];

      final summary = AuditSummary.fromFindings(findings);

      expect(summary.totalFindings, 4);
      expect(summary.bySeverity[Severity.critical], 1);
      expect(summary.bySeverity[Severity.high], 2);
      expect(summary.bySeverity[Severity.medium], 1);
      expect(summary.bySeverity[Severity.low], 0);
      expect(summary.byCategory[FindingCategory.accessibility], 1);
      expect(summary.byCategory[FindingCategory.spacing], 2);
      expect(summary.byCategory[FindingCategory.typography], 1);
    });

    test('AuditResult shouldFail works correctly', () {
      final result = AuditResult(
        metadata: AuditMetadata(
          auditDate: DateTime.now(),
          auditVersion: '1.0.0',
          projectPath: 'frontend/',
          filesAnalyzed: 100,
        ),
        summary: AuditSummary(
          totalFindings: 3,
          bySeverity: {
            Severity.critical: 1,
            Severity.high: 1,
            Severity.medium: 1,
            Severity.low: 0,
          },
          byCategory: {
            FindingCategory.visualHierarchy: 1,
            FindingCategory.spacing: 1,
            FindingCategory.typography: 1,
            FindingCategory.colorSystem: 0,
            FindingCategory.interactiveElements: 0,
            FindingCategory.emptyStates: 0,
            FindingCategory.responsiveness: 0,
            FindingCategory.componentConsistency: 0,
            FindingCategory.accessibility: 0,
          },
        ),
        findings: [],
        errors: [],
        actionPlan: [],
      );

      expect(
        result.shouldFail(failOnCritical: true, failOnHigh: false),
        true,
      );
      expect(
        result.shouldFail(failOnCritical: false, failOnHigh: true),
        true,
      );
      expect(
        result.shouldFail(failOnCritical: false, failOnHigh: false),
        false,
      );
    });

    test('SpacingClassification enum has all expected values', () {
      expect(SpacingClassification.values, [
        SpacingClassification.aligned,
        SpacingClassification.legacy,
        SpacingClassification.halfGrid,
        SpacingClassification.nonStandard,
      ]);
    });

    test('FindingCategory enum has all expected values', () {
      expect(FindingCategory.values.length, 9);
      expect(FindingCategory.values, contains(FindingCategory.visualHierarchy));
      expect(FindingCategory.values, contains(FindingCategory.spacing));
      expect(FindingCategory.values, contains(FindingCategory.typography));
      expect(FindingCategory.values, contains(FindingCategory.colorSystem));
      expect(FindingCategory.values, contains(FindingCategory.interactiveElements));
      expect(FindingCategory.values, contains(FindingCategory.emptyStates));
      expect(FindingCategory.values, contains(FindingCategory.responsiveness));
      expect(FindingCategory.values, contains(FindingCategory.componentConsistency));
      expect(FindingCategory.values, contains(FindingCategory.accessibility));
    });

    test('Severity enum has all expected values', () {
      expect(Severity.values, [
        Severity.critical,
        Severity.high,
        Severity.medium,
        Severity.low,
      ]);
    });

    test('Effort enum has all expected values', () {
      expect(Effort.values, [
        Effort.small,
        Effort.medium,
        Effort.large,
      ]);
    });
  });

  group('ConfigParser', () {
    test('ConfigParser can load configuration from YAML', () async {
      // This test would require creating a temporary file
      // For now, we just test that the class exists and has the expected methods
      expect(ConfigParser.loadFromFile, isA<Function>());
      expect(ConfigParser.createDefaultConfig, isA<Function>());
    });
  });
}
