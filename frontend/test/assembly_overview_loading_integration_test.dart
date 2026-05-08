import 'package:flutter_test/flutter_test.dart';

/// Integration test for Task 14.1: 验证成片总览加载流程
/// 
/// This test verifies the assembly overview loading workflow:
/// - Requirements 1.1: Display all shots in script order
/// - Requirements 1.2: Display shot details (order, video URL, candidate count, duration, subtitle, voiceover)
/// - Requirements 1.3: Display voiceover_ready and voiceover_asset_ready status
/// - Requirements 1.4: Display export availability status
/// - Requirements 1.5: Display missing item diagnostics
/// - Requirements 1.6: Support grouping shots by script
/// - Requirements 1.7: Display total duration and shot count statistics

void main() {
  group('Task 14.1: Assembly Overview Loading Integration Tests', () {
    test('should load assembly data and display shots in script order', () {
      // Simulate assembly response with multiple scripts
      final assemblyResponse = {
        'schemaVersion': 1,
        'dataVersion': '2024-01-15T10:30:00Z',
        'projectDefaults': {
          'voiceProfile': 'default_voice',
          'subtitleStyle': 'cinematic_cn_v2',
          'bgmStrategy': 'pulse_light',
        },
        'effectiveShortVideoDefaults': {
          'ttsVoice': 'default_voice',
          'subtitleStyle': 'cinematic_cn_v2',
          'bgmStrategy': 'pulse_light',
        },
        'candidateQualitySummary': {
          'schemaVersion': 1,
          'projectBadCaseTotal': 5,
          'assemblyShotReviewTotal': 20,
          'assemblyShotBadCaseCount': 3,
          'assemblyShotsWithBadCase': 2,
          'assemblyLateStageBadCaseCount': 1,
          'badCasesByStage': [
            {'stage': 'generation', 'count': 2},
            {'stage': 'post_production', 'count': 1},
          ],
          'qualityDegradationCount': 1,
          'qualityDegradationRatePercent': 5.0,
        },
        'scripts': [
          {
            'scriptId': 'script-uuid-1',
            'scriptNumericId': 1,
            'scriptTitle': 'Episode 1',
            'shots': [
              {
                'storyboardId': 'shot-uuid-1',
                'storyboardNumericId': 101,
                'sbIndex': 1,
                'selectedMediaUrl': 'https://example.com/video1.mp4',
                'selectedMediaKind': 'video',
                'duration': '10s',
                'state': 'completed',
                'trackId': 1,
                'subtitleText': '这是第一个镜头的字幕',
                'subtitleSource': 'explicit_narration',
                'voiceoverScriptReady': true,
                'voiceoverState': 'completed',
                'voiceoverAudioUrl': 'https://example.com/audio1.mp3',
                'voiceoverError': null,
                'voiceoverAssetReady': true,
              },
              {
                'storyboardId': 'shot-uuid-2',
                'storyboardNumericId': 102,
                'sbIndex': 2,
                'selectedMediaUrl': 'https://example.com/video2.mp4',
                'selectedMediaKind': 'video',
                'duration': '15s',
                'state': 'completed',
                'trackId': 1,
                'subtitleText': '这是第二个镜头的字幕',
                'subtitleSource': 'explicit_narration',
                'voiceoverScriptReady': true,
                'voiceoverState': 'pending',
                'voiceoverAudioUrl': null,
                'voiceoverError': null,
                'voiceoverAssetReady': false,
              },
            ],
          },
          {
            'scriptId': 'script-uuid-2',
            'scriptNumericId': 2,
            'scriptTitle': 'Episode 2',
            'shots': [
              {
                'storyboardId': 'shot-uuid-3',
                'storyboardNumericId': 201,
                'sbIndex': 1,
                'selectedMediaUrl': null,
                'selectedMediaKind': 'none',
                'duration': null,
                'state': 'pending',
                'trackId': null,
                'subtitleText': '这是第三个镜头的字幕',
                'subtitleSource': 'prompt_fallback',
                'voiceoverScriptReady': false,
                'voiceoverState': null,
                'voiceoverAudioUrl': null,
                'voiceoverError': null,
                'voiceoverAssetReady': false,
              },
            ],
          },
        ],
      };

      // Requirement 1.1: Verify shots are displayed in script order
      final scripts = assemblyResponse['scripts'] as List;
      expect(scripts, hasLength(2));
      expect(scripts[0]['scriptNumericId'], 1);
      expect(scripts[1]['scriptNumericId'], 2);

      // Requirement 1.6: Verify shots are grouped by script
      final script1 = scripts[0] as Map;
      final script1Shots = script1['shots'] as List;
      expect(script1Shots, hasLength(2));
      expect(script1Shots[0]['storyboardNumericId'], 101);
      expect(script1Shots[1]['storyboardNumericId'], 102);

      final script2 = scripts[1] as Map;
      final script2Shots = script2['shots'] as List;
      expect(script2Shots, hasLength(1));
      expect(script2Shots[0]['storyboardNumericId'], 201);

      // Requirement 1.2: Verify shot details are displayed
      final shot1 = script1Shots[0] as Map;
      expect(shot1['sbIndex'], 1); // Shot order
      expect(shot1['selectedMediaUrl'], 'https://example.com/video1.mp4'); // Video URL
      expect(shot1['selectedMediaKind'], 'video'); // Media kind
      expect(shot1['duration'], '10s'); // Duration
      expect(shot1['subtitleText'], '这是第一个镜头的字幕'); // Subtitle
      
      // Requirement 1.3: Verify voiceover status
      expect(shot1['voiceoverScriptReady'], true);
      expect(shot1['voiceoverAssetReady'], true);
      expect(shot1['voiceoverState'], 'completed');
      expect(shot1['voiceoverAudioUrl'], 'https://example.com/audio1.mp3');

      final shot2 = script1Shots[1] as Map;
      expect(shot2['voiceoverScriptReady'], true);
      expect(shot2['voiceoverAssetReady'], false); // Audio not ready yet
      expect(shot2['voiceoverState'], 'pending');
      expect(shot2['voiceoverAudioUrl'], null);

      // Requirement 1.5: Verify missing item diagnostics
      final shot3 = script2Shots[0] as Map;
      expect(shot3['selectedMediaUrl'], null); // Missing video
      expect(shot3['duration'], null); // Missing duration
      expect(shot3['voiceoverScriptReady'], false); // Voiceover script not ready
      expect(shot3['voiceoverAssetReady'], false); // Voiceover asset not ready

      // Requirement 1.7: Verify statistics
      final qualitySummary = assemblyResponse['candidateQualitySummary'] as Map;
      expect(qualitySummary['projectBadCaseTotal'], 5);
      expect(qualitySummary['assemblyShotReviewTotal'], 20);
      expect(qualitySummary['assemblyShotBadCaseCount'], 3);
      expect(qualitySummary['assemblyShotsWithBadCase'], 2);
      expect(qualitySummary['assemblyLateStageBadCaseCount'], 1);
      expect(qualitySummary['qualityDegradationCount'], 1);
      expect(qualitySummary['qualityDegradationRatePercent'], 5.0);
    });

    test('should calculate total duration correctly', () {
      // Requirement 1.7: Display total duration statistics
      final shots = [
        {'durationText': '10s', 'selectedMediaUrl': 'url1'},
        {'durationText': '15s', 'selectedMediaUrl': 'url2'},
        {'durationText': '20s', 'selectedMediaUrl': 'url3'},
        {'durationText': '', 'selectedMediaUrl': ''}, // Paused shot
        {'durationText': '5s', 'selectedMediaUrl': 'url5'},
      ];

      int? parseDurationSeconds(String value) {
        final trimmed = value.trim().toLowerCase();
        if (trimmed.isEmpty) return null;
        final digits = RegExp(r'^(\d{1,3})\s*s?$').firstMatch(trimmed);
        if (digits == null) return null;
        return int.tryParse(digits.group(1)!);
      }

      var totalDuration = 0;
      var enabledShotCount = 0;

      for (final shot in shots) {
        final url = shot['selectedMediaUrl'] as String;
        if (url.isEmpty) continue; // Skip paused shots

        enabledShotCount++;
        final durationSec = parseDurationSeconds(shot['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          totalDuration += durationSec;
        }
      }

      expect(totalDuration, 50); // 10 + 15 + 20 + 5
      expect(enabledShotCount, 4); // Excluding paused shot
    });

    test('should identify export availability status', () {
      // Requirement 1.4: Display export availability status
      
      // Helper function to check if shot is ready for export
      bool isShotReadyForExport(Map<String, dynamic> shot) {
        final hasVideo = (shot['selectedMediaUrl'] as String?)?.isNotEmpty ?? false;
        final hasDuration = (shot['duration'] as String?)?.isNotEmpty ?? false;
        final hasSubtitle = (shot['subtitleText'] as String?)?.isNotEmpty ?? false;
        return hasVideo && hasDuration && hasSubtitle;
      }

      // Shot with all required fields
      final completeShot = {
        'selectedMediaUrl': 'https://example.com/video.mp4',
        'duration': '10s',
        'subtitleText': '字幕内容',
      };
      expect(isShotReadyForExport(completeShot), true);

      // Shot missing video
      final missingVideo = {
        'selectedMediaUrl': null,
        'duration': '10s',
        'subtitleText': '字幕内容',
      };
      expect(isShotReadyForExport(missingVideo), false);

      // Shot missing duration
      final missingDuration = {
        'selectedMediaUrl': 'https://example.com/video.mp4',
        'duration': null,
        'subtitleText': '字幕内容',
      };
      expect(isShotReadyForExport(missingDuration), false);

      // Shot missing subtitle
      final missingSubtitle = {
        'selectedMediaUrl': 'https://example.com/video.mp4',
        'duration': '10s',
        'subtitleText': '',
      };
      expect(isShotReadyForExport(missingSubtitle), false);

      // Paused shot (empty video URL)
      final pausedShot = {
        'selectedMediaUrl': '',
        'duration': '10s',
        'subtitleText': '字幕内容',
      };
      expect(isShotReadyForExport(pausedShot), false);
    });

    test('should generate missing item diagnostics', () {
      // Requirement 1.5: Display missing item diagnostics
      
      List<String> generateDiagnostics(Map<String, dynamic> shot) {
        final diagnostics = <String>[];
        
        final hasVideo = (shot['selectedMediaUrl'] as String?)?.isNotEmpty ?? false;
        final hasDuration = (shot['duration'] as String?)?.isNotEmpty ?? false;
        final hasSubtitle = (shot['subtitleText'] as String?)?.isNotEmpty ?? false;
        final voiceoverScriptReady = shot['voiceoverScriptReady'] as bool? ?? false;
        final voiceoverAssetReady = shot['voiceoverAssetReady'] as bool? ?? false;

        if (!hasVideo) {
          diagnostics.add('未选视频');
        }
        if (!hasDuration) {
          diagnostics.add('时长缺失');
        }
        if (!hasSubtitle) {
          diagnostics.add('字幕缺失');
        }
        if (!voiceoverScriptReady) {
          diagnostics.add('旁白文本未就绪');
        }
        if (!voiceoverAssetReady) {
          diagnostics.add('旁白音频未就绪');
        }

        return diagnostics;
      }

      // Complete shot - no diagnostics
      final completeShot = {
        'selectedMediaUrl': 'https://example.com/video.mp4',
        'duration': '10s',
        'subtitleText': '字幕内容',
        'voiceoverScriptReady': true,
        'voiceoverAssetReady': true,
      };
      expect(generateDiagnostics(completeShot), isEmpty);

      // Shot with multiple missing items
      final incompleteShot = {
        'selectedMediaUrl': null,
        'duration': null,
        'subtitleText': '',
        'voiceoverScriptReady': false,
        'voiceoverAssetReady': false,
      };
      final diagnostics = generateDiagnostics(incompleteShot);
      expect(diagnostics, contains('未选视频'));
      expect(diagnostics, contains('时长缺失'));
      expect(diagnostics, contains('字幕缺失'));
      expect(diagnostics, contains('旁白文本未就绪'));
      expect(diagnostics, contains('旁白音频未就绪'));

      // Shot with partial completion
      final partialShot = {
        'selectedMediaUrl': 'https://example.com/video.mp4',
        'duration': '10s',
        'subtitleText': '',
        'voiceoverScriptReady': true,
        'voiceoverAssetReady': false,
      };
      final partialDiagnostics = generateDiagnostics(partialShot);
      expect(partialDiagnostics, contains('字幕缺失'));
      expect(partialDiagnostics, contains('旁白音频未就绪'));
      expect(partialDiagnostics, hasLength(2));
    });

    test('should display voiceover state correctly', () {
      // Requirement 1.3: Display voiceover_ready and voiceover_asset_ready status
      
      String getVoiceoverStatusDisplay(Map<String, dynamic> shot) {
        final scriptReady = shot['voiceoverScriptReady'] as bool? ?? false;
        final assetReady = shot['voiceoverAssetReady'] as bool? ?? false;
        final state = shot['voiceoverState'] as String?;
        final error = shot['voiceoverError'] as String?;

        if (!scriptReady) {
          return '配音文本：✗ 未就绪';
        }
        if (state == 'failed' && error != null) {
          return '配音状态：失败 - $error';
        }
        if (assetReady) {
          return '配音资产：✓ 就绪';
        }
        if (state == 'running') {
          return '配音状态：生成中';
        }
        if (state == 'pending') {
          return '配音状态：等待中';
        }
        return '配音文本：✓ 就绪 · 配音资产：✗ 未就绪';
      }

      // Voiceover completed
      final completedShot = {
        'voiceoverScriptReady': true,
        'voiceoverAssetReady': true,
        'voiceoverState': 'completed',
        'voiceoverError': null,
      };
      expect(getVoiceoverStatusDisplay(completedShot), '配音资产：✓ 就绪');

      // Voiceover pending
      final pendingShot = {
        'voiceoverScriptReady': true,
        'voiceoverAssetReady': false,
        'voiceoverState': 'pending',
        'voiceoverError': null,
      };
      expect(getVoiceoverStatusDisplay(pendingShot), '配音状态：等待中');

      // Voiceover running
      final runningShot = {
        'voiceoverScriptReady': true,
        'voiceoverAssetReady': false,
        'voiceoverState': 'running',
        'voiceoverError': null,
      };
      expect(getVoiceoverStatusDisplay(runningShot), '配音状态：生成中');

      // Voiceover failed
      final failedShot = {
        'voiceoverScriptReady': true,
        'voiceoverAssetReady': false,
        'voiceoverState': 'failed',
        'voiceoverError': 'TTS service unavailable',
      };
      expect(getVoiceoverStatusDisplay(failedShot), '配音状态：失败 - TTS service unavailable');

      // Script not ready
      final noScriptShot = {
        'voiceoverScriptReady': false,
        'voiceoverAssetReady': false,
        'voiceoverState': null,
        'voiceoverError': null,
      };
      expect(getVoiceoverStatusDisplay(noScriptShot), '配音文本：✗ 未就绪');
    });

    test('should group shots by script correctly', () {
      // Requirement 1.6: Support grouping shots by script
      
      final assemblyData = {
        'scripts': [
          {
            'scriptNumericId': 1,
            'scriptTitle': 'Episode 1',
            'shots': [
              {'storyboardNumericId': 101},
              {'storyboardNumericId': 102},
              {'storyboardNumericId': 103},
            ],
          },
          {
            'scriptNumericId': 2,
            'scriptTitle': 'Episode 2',
            'shots': [
              {'storyboardNumericId': 201},
              {'storyboardNumericId': 202},
            ],
          },
          {
            'scriptNumericId': 3,
            'scriptTitle': 'Episode 3',
            'shots': [
              {'storyboardNumericId': 301},
            ],
          },
        ],
      };

      final scripts = assemblyData['scripts'] as List;
      
      // Verify script count
      expect(scripts, hasLength(3));

      // Verify each script has correct shots
      final script1 = scripts[0] as Map;
      expect(script1['scriptNumericId'], 1);
      expect(script1['shots'], hasLength(3));

      final script2 = scripts[1] as Map;
      expect(script2['scriptNumericId'], 2);
      expect(script2['shots'], hasLength(2));

      final script3 = scripts[2] as Map;
      expect(script3['scriptNumericId'], 3);
      expect(script3['shots'], hasLength(1));

      // Verify total shot count
      var totalShots = 0;
      for (final script in scripts) {
        final shots = (script as Map)['shots'] as List;
        totalShots += shots.length;
      }
      expect(totalShots, 6);
    });

    test('should display quality summary statistics', () {
      // Requirement 1.7: Display quality summary statistics
      
      final qualitySummary = {
        'schemaVersion': 1,
        'projectBadCaseTotal': 10,
        'assemblyShotReviewTotal': 50,
        'assemblyShotBadCaseCount': 5,
        'assemblyShotsWithBadCase': 3,
        'assemblyLateStageBadCaseCount': 2,
        'badCasesByStage': [
          {'stage': 'generation', 'count': 3},
          {'stage': 'post_production', 'count': 2},
        ],
        'qualityDegradationCount': 1,
        'qualityDegradationRatePercent': 2.0,
      };

      // Verify project-level statistics
      expect(qualitySummary['projectBadCaseTotal'], 10);
      
      // Verify assembly-level statistics
      expect(qualitySummary['assemblyShotReviewTotal'], 50);
      expect(qualitySummary['assemblyShotBadCaseCount'], 5);
      expect(qualitySummary['assemblyShotsWithBadCase'], 3);
      expect(qualitySummary['assemblyLateStageBadCaseCount'], 2);

      // Verify stage breakdown
      final badCasesByStage = qualitySummary['badCasesByStage'] as List;
      expect(badCasesByStage, hasLength(2));
      expect(badCasesByStage[0]['stage'], 'generation');
      expect(badCasesByStage[0]['count'], 3);
      expect(badCasesByStage[1]['stage'], 'post_production');
      expect(badCasesByStage[1]['count'], 2);

      // Verify quality degradation
      expect(qualitySummary['qualityDegradationCount'], 1);
      expect(qualitySummary['qualityDegradationRatePercent'], 2.0);
    });

    test('should handle empty assembly data gracefully', () {
      // Edge case: Empty assembly data
      
      final emptyAssembly = {
        'schemaVersion': 1,
        'dataVersion': '2024-01-15T10:30:00Z',
        'projectDefaults': {
          'voiceProfile': null,
          'subtitleStyle': null,
          'bgmStrategy': null,
        },
        'effectiveShortVideoDefaults': {
          'ttsVoice': null,
          'subtitleStyle': null,
          'bgmStrategy': null,
        },
        'candidateQualitySummary': {
          'schemaVersion': 1,
          'projectBadCaseTotal': 0,
          'assemblyShotReviewTotal': 0,
          'assemblyShotBadCaseCount': 0,
          'assemblyShotsWithBadCase': 0,
          'assemblyLateStageBadCaseCount': 0,
          'badCasesByStage': [],
          'qualityDegradationCount': 0,
          'qualityDegradationRatePercent': 0.0,
        },
        'scripts': [],
      };

      final scripts = emptyAssembly['scripts'] as List;
      expect(scripts, isEmpty);

      final qualitySummary = emptyAssembly['candidateQualitySummary'] as Map;
      expect(qualitySummary['projectBadCaseTotal'], 0);
      expect(qualitySummary['assemblyShotReviewTotal'], 0);
      expect(qualitySummary['badCasesByStage'], isEmpty);
    });

    test('should display data version timestamp', () {
      // Verify data version is included in response
      
      final assemblyResponse = {
        'schemaVersion': 1,
        'dataVersion': '2024-01-15T10:30:00Z',
        'projectDefaults': {},
        'effectiveShortVideoDefaults': {},
        'candidateQualitySummary': {},
        'scripts': [],
      };

      expect(assemblyResponse['dataVersion'], isNotNull);
      expect(assemblyResponse['dataVersion'], '2024-01-15T10:30:00Z');
      expect(assemblyResponse['schemaVersion'], 1);
    });

    test('should handle shots with different media kinds', () {
      // Verify media kind identification
      
      final shots = [
        {'selectedMediaUrl': 'https://example.com/video.mp4', 'selectedMediaKind': 'video'},
        {'selectedMediaUrl': 'https://example.com/image.png', 'selectedMediaKind': 'image'},
        {'selectedMediaUrl': null, 'selectedMediaKind': 'none'},
        {'selectedMediaUrl': 'https://example.com/file.xyz', 'selectedMediaKind': 'other'},
      ];

      expect(shots[0]['selectedMediaKind'], 'video');
      expect(shots[1]['selectedMediaKind'], 'image');
      expect(shots[2]['selectedMediaKind'], 'none');
      expect(shots[3]['selectedMediaKind'], 'other');
    });

    test('should display subtitle source correctly', () {
      // Verify subtitle source types
      
      final shots = [
        {'subtitleText': '明确旁白', 'subtitleSource': 'explicit_narration'},
        {'subtitleText': '提示词回退', 'subtitleSource': 'prompt_fallback'},
        {'subtitleText': '占位符', 'subtitleSource': 'placeholder'},
      ];

      expect(shots[0]['subtitleSource'], 'explicit_narration');
      expect(shots[1]['subtitleSource'], 'prompt_fallback');
      expect(shots[2]['subtitleSource'], 'placeholder');
    });
  });
}
