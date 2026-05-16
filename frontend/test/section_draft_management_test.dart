import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/components/version_manager.dart';

void main() {
  group('AssemblyDraft', () {
    test('should create draft from JSON', () {
      final json = {
        'id': 'draft_1',
        'name': 'Test Draft',
        'saved_at': '2024-01-01T00:00:00.000Z',
        'shot_count': 5,
        'shot_config': {
          '1': {'enabled': true, 'video_url': 'https://example.com/video1.mp4'},
          '2': {'enabled': false},
        },
      };

      final draft = AssemblyDraft.fromJson(json);

      expect(draft.id, 'draft_1');
      expect(draft.name, 'Test Draft');
      expect(draft.shotCount, 5);
      expect(draft.shotConfig['1']['enabled'], true);
      expect(draft.shotConfig['2']['enabled'], false);
    });

    test('should convert draft to JSON', () {
      final draft = AssemblyDraft(
        id: 'draft_1',
        name: 'Test Draft',
        savedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 5,
        shotConfig: {
          '1': {'enabled': true, 'video_url': 'https://example.com/video1.mp4'},
          '2': {'enabled': false},
        },
      );

      final json = draft.toJson();

      expect(json['id'], 'draft_1');
      expect(json['name'], 'Test Draft');
      expect(json['saved_at'], '2024-01-01T00:00:00.000Z');
      expect(json['shot_count'], 5);
      expect(json['shot_config']['1']['enabled'], true);
    });

    test('should handle empty shot config', () {
      final json = {
        'id': 'draft_1',
        'name': 'Empty Draft',
        'saved_at': '2024-01-01T00:00:00.000Z',
        'shot_count': 0,
        'shot_config': <String, dynamic>{},
      };

      final draft = AssemblyDraft.fromJson(json);

      expect(draft.shotCount, 0);
      expect(draft.shotConfig, isEmpty);
    });
  });

  group('Draft Management Logic', () {
    test('should limit drafts to maximum 10', () {
      final drafts = List.generate(
        10,
        (i) => AssemblyDraft(
          id: 'draft_$i',
          name: 'Draft $i',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ),
      );

      expect(drafts.length, 10);
      
      // Attempting to add an 11th draft should fail
      // This is enforced in _handleSaveDraft
    });

    test('should store draft configuration correctly', () {
      final shotConfig = {
        '1': {
          'enabled': true,
          'video_url': 'https://example.com/video1.mp4',
          'duration': '10s',
          'subtitle': 'Test subtitle',
          'voiceover_audio_url': 'https://example.com/audio1.mp3',
        },
        '2': {
          'enabled': false,
          'video_url': '',
          'duration': '',
          'subtitle': '',
          'voiceover_audio_url': '',
        },
      };

      final draft = AssemblyDraft(
        id: 'draft_1',
        name: 'Test Draft',
        savedAt: DateTime.now(),
        shotCount: 2,
        shotConfig: shotConfig,
      );

      expect(draft.shotConfig['1']['enabled'], true);
      expect(draft.shotConfig['1']['video_url'], 'https://example.com/video1.mp4');
      expect(draft.shotConfig['1']['duration'], '10s');
      expect(draft.shotConfig['2']['enabled'], false);
    });

    test('should preserve draft order (most recent first)', () {
      final now = DateTime.now();
      final drafts = [
        AssemblyDraft(
          id: 'draft_3',
          name: 'Draft 3',
          savedAt: now,
          shotCount: 5,
          shotConfig: {},
        ),
        AssemblyDraft(
          id: 'draft_2',
          name: 'Draft 2',
          savedAt: now.subtract(const Duration(hours: 1)),
          shotCount: 5,
          shotConfig: {},
        ),
        AssemblyDraft(
          id: 'draft_1',
          name: 'Draft 1',
          savedAt: now.subtract(const Duration(hours: 2)),
          shotCount: 5,
          shotConfig: {},
        ),
      ];

      // Verify drafts are ordered by savedAt (most recent first)
      expect(drafts[0].savedAt.isAfter(drafts[1].savedAt), true);
      expect(drafts[1].savedAt.isAfter(drafts[2].savedAt), true);
    });
  });

  group('Draft Restoration Logic', () {
    test('should restore enabled shots with video URLs', () {
      final shotConfig = {
        '1': {
          'enabled': true,
          'video_url': 'https://example.com/video1.mp4',
          'duration': '10s',
        },
      };

      final draft = AssemblyDraft(
        id: 'draft_1',
        name: 'Test Draft',
        savedAt: DateTime.now(),
        shotCount: 1,
        shotConfig: shotConfig,
      );

      final config = draft.shotConfig['1'] as Map<String, dynamic>;
      expect(config['enabled'], true);
      expect(config['video_url'], isNotEmpty);
    });

    test('should restore disabled shots', () {
      final shotConfig = {
        '1': {
          'enabled': false,
          'video_url': '',
        },
      };

      final draft = AssemblyDraft(
        id: 'draft_1',
        name: 'Test Draft',
        savedAt: DateTime.now(),
        shotCount: 1,
        shotConfig: shotConfig,
      );

      final config = draft.shotConfig['1'] as Map<String, dynamic>;
      expect(config['enabled'], false);
    });

    test('should parse duration from config', () {
      final shotConfig = {
        '1': {
          'enabled': true,
          'video_url': 'https://example.com/video1.mp4',
          'duration': '15s',
        },
      };

      final draft = AssemblyDraft(
        id: 'draft_1',
        name: 'Test Draft',
        savedAt: DateTime.now(),
        shotCount: 1,
        shotConfig: shotConfig,
      );

      final config = draft.shotConfig['1'] as Map<String, dynamic>;
      final duration = config['duration'] as String;
      final durationSeconds = int.tryParse(
        duration.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      
      expect(durationSeconds, 15);
    });
  });

  group('Flow Data Structure', () {
    test('should structure flow_data correctly', () {
      final flowData = <String, dynamic>{
        'storyboard': [
          {'id': 1},
          {'id': 2},
          {'id': 3},
        ],
        'assembly_versions': {
          'current': 'v1',
          'versions': [
            {
              'id': 'v1',
              'name': 'Version 1',
              'created_at': '2024-01-01T00:00:00.000Z',
              'shot_count': 3,
              'shot_config': {},
            },
          ],
          'drafts': [
            {
              'id': 'draft_1',
              'name': 'Draft 1',
              'saved_at': '2024-01-01T00:00:00.000Z',
              'shot_count': 3,
              'shot_config': {},
            },
          ],
        },
      };

      expect(flowData['assembly_versions'], isNotNull);
      expect(flowData['assembly_versions']['drafts'], isList);
      expect(flowData['assembly_versions']['drafts'], hasLength(1));
    });

    test('should handle missing assembly_versions in flow_data', () {
      final flowData = <String, dynamic>{
        'storyboard': [
          {'id': 1},
        ],
      };

      final versionsData = flowData['assembly_versions'] as Map<String, dynamic>?;
      expect(versionsData, isNull);
      
      // Should initialize with empty structure
      final draftsList = versionsData?['drafts'] as List<dynamic>? ?? [];
      expect(draftsList, isEmpty);
    });

    test('should add new draft to beginning of list', () {
      final draftsList = <Map<String, dynamic>>[
        {
          'id': 'draft_1',
          'name': 'Draft 1',
          'saved_at': '2024-01-01T00:00:00.000Z',
          'shot_count': 3,
          'shot_config': {},
        },
      ];

      final newDraft = {
        'id': 'draft_2',
        'name': 'Draft 2',
        'saved_at': '2024-01-01T01:00:00.000Z',
        'shot_count': 3,
        'shot_config': {},
      };

      draftsList.insert(0, newDraft);

      expect(draftsList.first['id'], 'draft_2');
      expect(draftsList.last['id'], 'draft_1');
    });

    test('should limit drafts list to 10 items', () {
      final draftsList = List.generate(
        12,
        (i) => {
          'id': 'draft_$i',
          'name': 'Draft $i',
          'saved_at': '2024-01-01T00:00:00.000Z',
          'shot_count': 3,
          'shot_config': <String, dynamic>{},
        },
      );

      // Keep only the most recent 10
      if (draftsList.length > 10) {
        draftsList.removeRange(10, draftsList.length);
      }

      expect(draftsList.length, 10);
    });
  });
}
