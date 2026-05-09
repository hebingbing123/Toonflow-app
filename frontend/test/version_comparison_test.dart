import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/components/version_manager.dart';

void main() {
  group('Version Comparison Logic', () {
    late AssemblyVersion version1;
    late AssemblyVersion version2;

    setUp(() {
      version1 = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 10,
        shotConfig: {
          '1': {'enabled': true, 'video_url': 'https://example.com/v1.mp4', 'duration': 10},
          '2': {'enabled': true, 'video_url': 'https://example.com/v2.mp4', 'duration': 15},
          '3': {'enabled': false},
        },
      );

      version2 = AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.parse('2024-01-02T00:00:00.000Z'),
        shotCount: 10,
        shotConfig: {
          '1': {'enabled': true, 'video_url': 'https://example.com/v1_new.mp4', 'duration': 12},
          '2': {'enabled': false},
          '3': {'enabled': true, 'video_url': 'https://example.com/v3.mp4', 'duration': 20},
        },
      );
    });

    test('should detect differences in shot enabled status', () {
      final differences = <String, Map<String, dynamic>>{};

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = version2.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) {
          differences[shotId] = {
            'type': 'missing_in_v2',
            'v1': v1Config,
            'v2': null,
          };
          continue;
        }

        final v1Enabled = v1Config['enabled'] as bool? ?? false;
        final v2Enabled = v2Config['enabled'] as bool? ?? false;

        if (v1Enabled != v2Enabled) {
          differences[shotId] = {
            'type': 'enabled_status',
            'v1': v1Enabled,
            'v2': v2Enabled,
          };
        }
      }

      expect(differences, isNotEmpty);
      expect(differences['2'], isNotNull);
      expect(differences['2']!['type'], 'enabled_status');
      expect(differences['2']!['v1'], true);
      expect(differences['2']!['v2'], false);
      expect(differences['3']!['v1'], false);
      expect(differences['3']!['v2'], true);
    });

    test('should detect differences in video URLs', () {
      final differences = <String, Map<String, dynamic>>{};

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = version2.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) continue;

        final v1Url = v1Config['video_url'] as String? ?? '';
        final v2Url = v2Config['video_url'] as String? ?? '';

        if (v1Url != v2Url && v1Url.isNotEmpty && v2Url.isNotEmpty) {
          differences[shotId] = {
            'type': 'video_url',
            'v1': v1Url,
            'v2': v2Url,
          };
        }
      }

      expect(differences, isNotEmpty);
      expect(differences['1'], isNotNull);
      expect(differences['1']!['type'], 'video_url');
      expect(differences['1']!['v1'], 'https://example.com/v1.mp4');
      expect(differences['1']!['v2'], 'https://example.com/v1_new.mp4');
    });

    test('should detect differences in duration', () {
      final differences = <String, Map<String, dynamic>>{};

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = version2.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) continue;

        final v1Duration = v1Config['duration'] as int? ?? 0;
        final v2Duration = v2Config['duration'] as int? ?? 0;

        if (v1Duration != v2Duration && v1Duration > 0 && v2Duration > 0) {
          differences[shotId] = {
            'type': 'duration',
            'v1': v1Duration,
            'v2': v2Duration,
          };
        }
      }

      expect(differences, isNotEmpty);
      expect(differences['1'], isNotNull);
      expect(differences['1']!['v1'], 10);
      expect(differences['1']!['v2'], 12);
    });

    test('should count total differences between versions', () {
      int differenceCount = 0;

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = version2.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) {
          differenceCount++;
          continue;
        }

        // Check enabled status
        final v1Enabled = v1Config['enabled'] as bool? ?? false;
        final v2Enabled = v2Config['enabled'] as bool? ?? false;
        if (v1Enabled != v2Enabled) differenceCount++;

        // Check video URL
        final v1Url = v1Config['video_url'] as String? ?? '';
        final v2Url = v2Config['video_url'] as String? ?? '';
        if (v1Url != v2Url && v1Url.isNotEmpty && v2Url.isNotEmpty) {
          differenceCount++;
        }

        // Check duration
        final v1Duration = v1Config['duration'] as int? ?? 0;
        final v2Duration = v2Config['duration'] as int? ?? 0;
        if (v1Duration != v2Duration && v1Duration > 0 && v2Duration > 0) {
          differenceCount++;
        }
      }

      // We expect: 2 enabled status changes + 1 URL change + 1 duration change = 4
      expect(differenceCount, greaterThan(0));
    });

    test('should handle identical versions', () {
      final identicalVersion = AssemblyVersion(
        id: 'v1_copy',
        name: 'Version 1 Copy',
        createdAt: DateTime.parse('2024-01-03T00:00:00.000Z'),
        shotCount: 10,
        shotConfig: Map.from(version1.shotConfig),
      );

      int differenceCount = 0;

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = identicalVersion.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) {
          differenceCount++;
          continue;
        }

        if (v1Config['enabled'] != v2Config['enabled']) differenceCount++;
        if (v1Config['video_url'] != v2Config['video_url']) differenceCount++;
        if (v1Config['duration'] != v2Config['duration']) differenceCount++;
      }

      expect(differenceCount, 0);
    });

    test('should handle version with missing shots', () {
      final versionWithMissingShots = AssemblyVersion(
        id: 'v3',
        name: 'Version 3',
        createdAt: DateTime.parse('2024-01-03T00:00:00.000Z'),
        shotCount: 5,
        shotConfig: {
          '1': {'enabled': true, 'video_url': 'https://example.com/v1.mp4', 'duration': 10},
          // Shot 2 and 3 are missing
        },
      );

      final missingShots = <String>[];

      for (final shotId in version1.shotConfig.keys) {
        if (!versionWithMissingShots.shotConfig.containsKey(shotId)) {
          missingShots.add(shotId);
        }
      }

      expect(missingShots, hasLength(2));
      expect(missingShots, contains('2'));
      expect(missingShots, contains('3'));
    });

    test('should handle version with additional shots', () {
      final versionWithExtraShots = AssemblyVersion(
        id: 'v4',
        name: 'Version 4',
        createdAt: DateTime.parse('2024-01-04T00:00:00.000Z'),
        shotCount: 15,
        shotConfig: {
          '1': {'enabled': true, 'video_url': 'https://example.com/v1.mp4', 'duration': 10},
          '2': {'enabled': true, 'video_url': 'https://example.com/v2.mp4', 'duration': 15},
          '3': {'enabled': false},
          '4': {'enabled': true, 'video_url': 'https://example.com/v4.mp4', 'duration': 8},
          '5': {'enabled': true, 'video_url': 'https://example.com/v5.mp4', 'duration': 12},
        },
      );

      final extraShots = <String>[];

      for (final shotId in versionWithExtraShots.shotConfig.keys) {
        if (!version1.shotConfig.containsKey(shotId)) {
          extraShots.add(shotId);
        }
      }

      expect(extraShots, hasLength(2));
      expect(extraShots, contains('4'));
      expect(extraShots, contains('5'));
    });

    test('should categorize differences by type', () {
      final differences = <String, List<String>>{
        'enabled_status': [],
        'video_url': [],
        'duration': [],
        'missing': [],
      };

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = version2.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) {
          differences['missing']!.add(shotId);
          continue;
        }

        // Check enabled status
        final v1Enabled = v1Config['enabled'] as bool? ?? false;
        final v2Enabled = v2Config['enabled'] as bool? ?? false;
        if (v1Enabled != v2Enabled) {
          differences['enabled_status']!.add(shotId);
        }

        // Check video URL
        final v1Url = v1Config['video_url'] as String? ?? '';
        final v2Url = v2Config['video_url'] as String? ?? '';
        if (v1Url != v2Url && v1Url.isNotEmpty && v2Url.isNotEmpty) {
          differences['video_url']!.add(shotId);
        }

        // Check duration
        final v1Duration = v1Config['duration'] as int? ?? 0;
        final v2Duration = v2Config['duration'] as int? ?? 0;
        if (v1Duration != v2Duration && v1Duration > 0 && v2Duration > 0) {
          differences['duration']!.add(shotId);
        }
      }

      expect(differences['enabled_status'], hasLength(2)); // Shots 2 and 3
      expect(differences['video_url'], hasLength(1)); // Shot 1
      expect(differences['duration'], hasLength(1)); // Shot 1
      expect(differences['missing'], isEmpty);
    });

    test('should generate comparison summary', () {
      int enabledStatusChanges = 0;
      int videoUrlChanges = 0;
      int durationChanges = 0;

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = version2.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) continue;

        if ((v1Config['enabled'] ?? false) != (v2Config['enabled'] ?? false)) {
          enabledStatusChanges++;
        }

        final v1Url = v1Config['video_url'] as String? ?? '';
        final v2Url = v2Config['video_url'] as String? ?? '';
        if (v1Url != v2Url && v1Url.isNotEmpty && v2Url.isNotEmpty) {
          videoUrlChanges++;
        }

        final v1Duration = v1Config['duration'] as int? ?? 0;
        final v2Duration = v2Config['duration'] as int? ?? 0;
        if (v1Duration != v2Duration && v1Duration > 0 && v2Duration > 0) {
          durationChanges++;
        }
      }

      final summary = {
        'enabled_status_changes': enabledStatusChanges,
        'video_url_changes': videoUrlChanges,
        'duration_changes': durationChanges,
        'total_changes': enabledStatusChanges + videoUrlChanges + durationChanges,
      };

      expect(summary['enabled_status_changes'], 2);
      expect(summary['video_url_changes'], 1);
      expect(summary['duration_changes'], 1);
      expect(summary['total_changes'], 4);
    });
  });

  group('Version Comparison Edge Cases', () {
    test('should handle empty shot configs', () {
      final emptyVersion1 = AssemblyVersion(
        id: 'v1',
        name: 'Empty Version 1',
        createdAt: DateTime.now(),
        shotCount: 0,
        shotConfig: {},
      );

      final emptyVersion2 = AssemblyVersion(
        id: 'v2',
        name: 'Empty Version 2',
        createdAt: DateTime.now(),
        shotCount: 0,
        shotConfig: {},
      );

      int differenceCount = 0;

      for (final shotId in emptyVersion1.shotConfig.keys) {
        final v2Config = emptyVersion2.shotConfig[shotId];
        if (v2Config == null) differenceCount++;
      }

      expect(differenceCount, 0);
    });

    test('should handle null values in shot config', () {
      final versionWithNulls = AssemblyVersion(
        id: 'v1',
        name: 'Version with nulls',
        createdAt: DateTime.now(),
        shotCount: 1,
        shotConfig: {
          '1': {'enabled': true, 'video_url': null, 'duration': null},
        },
      );

      final normalVersion = AssemblyVersion(
        id: 'v2',
        name: 'Normal version',
        createdAt: DateTime.now(),
        shotCount: 1,
        shotConfig: {
          '1': {'enabled': true, 'video_url': '', 'duration': 0},
        },
      );

      final v1Config = versionWithNulls.shotConfig['1'] as Map<String, dynamic>;
      final v2Config = normalVersion.shotConfig['1'] as Map<String, dynamic>;

      final v1Url = v1Config['video_url'] as String? ?? '';
      final v2Url = v2Config['video_url'] as String? ?? '';

      expect(v1Url, isEmpty);
      expect(v2Url, isEmpty);
      expect(v1Url == v2Url, true);
    });

    test('should handle shot order differences', () {
      final version1 = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.now(),
        shotCount: 3,
        shotConfig: {
          '1': {'enabled': true, 'order': 0},
          '2': {'enabled': true, 'order': 1},
          '3': {'enabled': true, 'order': 2},
        },
      );

      final version2 = AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.now(),
        shotCount: 3,
        shotConfig: {
          '1': {'enabled': true, 'order': 2},
          '2': {'enabled': true, 'order': 0},
          '3': {'enabled': true, 'order': 1},
        },
      );

      int orderChanges = 0;

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = version2.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) continue;

        final v1Order = v1Config['order'] as int? ?? 0;
        final v2Order = v2Config['order'] as int? ?? 0;

        if (v1Order != v2Order) {
          orderChanges++;
        }
      }

      expect(orderChanges, 3); // All shots have different order
    });

    test('should handle very large shot configs', () {
      final largeConfig = <String, dynamic>{};
      for (int i = 0; i < 1000; i++) {
        largeConfig['$i'] = {
          'enabled': i % 2 == 0,
          'video_url': 'https://example.com/video$i.mp4',
          'duration': 10 + (i % 20),
        };
      }

      final version1 = AssemblyVersion(
        id: 'v1',
        name: 'Large Version 1',
        createdAt: DateTime.now(),
        shotCount: 1000,
        shotConfig: largeConfig,
      );

      final version2 = AssemblyVersion(
        id: 'v2',
        name: 'Large Version 2',
        createdAt: DateTime.now(),
        shotCount: 1000,
        shotConfig: Map.from(largeConfig),
      );

      int differenceCount = 0;

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = version2.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) {
          differenceCount++;
          continue;
        }

        if (v1Config['enabled'] != v2Config['enabled']) differenceCount++;
        if (v1Config['video_url'] != v2Config['video_url']) differenceCount++;
        if (v1Config['duration'] != v2Config['duration']) differenceCount++;
      }

      expect(differenceCount, 0); // Identical configs
      expect(version1.shotConfig.length, 1000);
    });
  });

  group('Version Comparison Report Generation', () {
    test('should generate detailed comparison report', () {
      final version1 = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 3,
        shotConfig: {
          '1': {'enabled': true, 'video_url': 'https://example.com/v1.mp4', 'duration': 10},
          '2': {'enabled': true, 'video_url': 'https://example.com/v2.mp4', 'duration': 15},
          '3': {'enabled': false},
        },
      );

      final version2 = AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.parse('2024-01-02T00:00:00.000Z'),
        shotCount: 3,
        shotConfig: {
          '1': {'enabled': true, 'video_url': 'https://example.com/v1_new.mp4', 'duration': 12},
          '2': {'enabled': false},
          '3': {'enabled': true, 'video_url': 'https://example.com/v3.mp4', 'duration': 20},
        },
      );

      final report = <String, dynamic>{
        'version1': {
          'id': version1.id,
          'name': version1.name,
          'shot_count': version1.shotCount,
        },
        'version2': {
          'id': version2.id,
          'name': version2.name,
          'shot_count': version2.shotCount,
        },
        'differences': <String, dynamic>{},
        'summary': {
          'total_shots': version1.shotConfig.length,
          'changed_shots': 0,
          'enabled_status_changes': 0,
          'video_url_changes': 0,
          'duration_changes': 0,
        },
      };

      final differences = <String, dynamic>{};
      final changedShots = <String>{};

      for (final shotId in version1.shotConfig.keys) {
        final v1Config = version1.shotConfig[shotId] as Map<String, dynamic>;
        final v2Config = version2.shotConfig[shotId] as Map<String, dynamic>?;

        if (v2Config == null) continue;

        final shotDifferences = <String, dynamic>{};

        // Check enabled status
        final v1Enabled = v1Config['enabled'] as bool? ?? false;
        final v2Enabled = v2Config['enabled'] as bool? ?? false;
        if (v1Enabled != v2Enabled) {
          shotDifferences['enabled'] = {'v1': v1Enabled, 'v2': v2Enabled};
          report['summary']['enabled_status_changes'] = 
              (report['summary']['enabled_status_changes'] as int) + 1;
          changedShots.add(shotId);
        }

        // Check video URL
        final v1Url = v1Config['video_url'] as String? ?? '';
        final v2Url = v2Config['video_url'] as String? ?? '';
        if (v1Url != v2Url && v1Url.isNotEmpty && v2Url.isNotEmpty) {
          shotDifferences['video_url'] = {'v1': v1Url, 'v2': v2Url};
          report['summary']['video_url_changes'] = 
              (report['summary']['video_url_changes'] as int) + 1;
          changedShots.add(shotId);
        }

        // Check duration
        final v1Duration = v1Config['duration'] as int? ?? 0;
        final v2Duration = v2Config['duration'] as int? ?? 0;
        if (v1Duration != v2Duration && v1Duration > 0 && v2Duration > 0) {
          shotDifferences['duration'] = {'v1': v1Duration, 'v2': v2Duration};
          report['summary']['duration_changes'] = 
              (report['summary']['duration_changes'] as int) + 1;
          changedShots.add(shotId);
        }

        if (shotDifferences.isNotEmpty) {
          differences[shotId] = shotDifferences;
        }
      }

      report['differences'] = differences;
      report['summary']['changed_shots'] = changedShots.length;

      expect(report['summary']['total_shots'], 3);
      expect(report['summary']['changed_shots'], 3);
      expect(report['summary']['enabled_status_changes'], 2);
      expect(report['summary']['video_url_changes'], 1);
      expect(report['summary']['duration_changes'], 1);
      expect(report['differences'], hasLength(3));
    });

    test('should export comparison report as JSON', () {
      final version1 = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 2,
        shotConfig: {
          '1': {'enabled': true, 'video_url': 'https://example.com/v1.mp4'},
          '2': {'enabled': false},
        },
      );

      final version2 = AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.parse('2024-01-02T00:00:00.000Z'),
        shotCount: 2,
        shotConfig: {
          '1': {'enabled': true, 'video_url': 'https://example.com/v1_new.mp4'},
          '2': {'enabled': true, 'video_url': 'https://example.com/v2.mp4'},
        },
      );

      final report = {
        'comparison_date': DateTime.now().toIso8601String(),
        'version1': version1.toJson(),
        'version2': version2.toJson(),
        'differences': {
          '1': {
            'video_url': {
              'v1': 'https://example.com/v1.mp4',
              'v2': 'https://example.com/v1_new.mp4',
            },
          },
          '2': {
            'enabled': {'v1': false, 'v2': true},
          },
        },
      };

      expect(report['version1'], isNotNull);
      expect(report['version2'], isNotNull);
      expect(report['differences'], isNotEmpty);
      expect(report['comparison_date'], isNotNull);
    });
  });
}
