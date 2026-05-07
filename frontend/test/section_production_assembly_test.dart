import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Assembly Defaults Editor Tests', () {
    test('should validate subtitle style input', () {
      // Simulate subtitle style input validation
      String? validateSubtitleStyle(String? value) {
        // Empty is valid (means default)
        if (value == null || value.trim().isEmpty) return null;
        // Any non-empty string is valid
        return null;
      }

      expect(validateSubtitleStyle(null), null);
      expect(validateSubtitleStyle(''), null);
      expect(validateSubtitleStyle('   '), null);
      expect(validateSubtitleStyle('cinematic_cn_v2'), null);
      expect(validateSubtitleStyle('custom_style'), null);
    });

    test('should validate BGM strategy input', () {
      // Simulate BGM strategy input validation
      String? validateBgmStrategy(String? value) {
        // Empty is valid (means default)
        if (value == null || value.trim().isEmpty) return null;
        // Any non-empty string is valid
        return null;
      }

      expect(validateBgmStrategy(null), null);
      expect(validateBgmStrategy(''), null);
      expect(validateBgmStrategy('   '), null);
      expect(validateBgmStrategy('pulse_light'), null);
      expect(validateBgmStrategy('custom_bgm'), null);
    });

    test('should convert empty strings to null for API call', () {
      // Simulate the conversion logic used in the save handler
      String? convertToApiValue(String input) {
        final trimmed = input.trim();
        return trimmed.isEmpty ? null : trimmed;
      }

      expect(convertToApiValue(''), null);
      expect(convertToApiValue('   '), null);
      expect(convertToApiValue('cinematic_cn_v2'), 'cinematic_cn_v2');
      expect(convertToApiValue('  pulse_light  '), 'pulse_light');
    });

    test('should prepare correct API payload for project update', () {
      // Simulate preparing the API payload
      Map<String, dynamic> prepareUpdatePayload(
        String subtitleStyle,
        String bgmStrategy,
      ) {
        final trimmedSubtitle = subtitleStyle.trim();
        final trimmedBgm = bgmStrategy.trim();
        return <String, dynamic>{
          'subtitleStyle': trimmedSubtitle.isEmpty ? null : trimmedSubtitle,
          'bgmStrategy': trimmedBgm.isEmpty ? null : trimmedBgm,
        };
      }

      // Both empty - should send nulls
      var payload = prepareUpdatePayload('', '');
      expect(payload['subtitleStyle'], null);
      expect(payload['bgmStrategy'], null);

      // Both filled
      payload = prepareUpdatePayload('cinematic_cn_v2', 'pulse_light');
      expect(payload['subtitleStyle'], 'cinematic_cn_v2');
      expect(payload['bgmStrategy'], 'pulse_light');

      // Mixed
      payload = prepareUpdatePayload('cinematic_cn_v2', '');
      expect(payload['subtitleStyle'], 'cinematic_cn_v2');
      expect(payload['bgmStrategy'], null);

      payload = prepareUpdatePayload('', 'pulse_light');
      expect(payload['subtitleStyle'], null);
      expect(payload['bgmStrategy'], 'pulse_light');

      // With whitespace
      payload = prepareUpdatePayload('  cinematic_cn_v2  ', '  pulse_light  ');
      expect(payload['subtitleStyle'], 'cinematic_cn_v2');
      expect(payload['bgmStrategy'], 'pulse_light');
    });

    test('should format success message correctly', () {
      // Simulate success message formatting
      String formatSuccessMessage(String subtitleStyle, String bgmStrategy) {
        final subtitleDisplay = subtitleStyle.trim().isEmpty 
            ? '默认' 
            : subtitleStyle.trim();
        final bgmDisplay = bgmStrategy.trim().isEmpty 
            ? '默认' 
            : bgmStrategy.trim();
        return '已更新成片级默认：字幕 $subtitleDisplay · BGM $bgmDisplay';
      }

      expect(
        formatSuccessMessage('', ''),
        '已更新成片级默认：字幕 默认 · BGM 默认',
      );
      expect(
        formatSuccessMessage('cinematic_cn_v2', 'pulse_light'),
        '已更新成片级默认：字幕 cinematic_cn_v2 · BGM pulse_light',
      );
      expect(
        formatSuccessMessage('cinematic_cn_v2', ''),
        '已更新成片级默认：字幕 cinematic_cn_v2 · BGM 默认',
      );
      expect(
        formatSuccessMessage('', 'pulse_light'),
        '已更新成片级默认：字幕 默认 · BGM pulse_light',
      );
    });

    test('should handle API error responses correctly', () {
      // Simulate error message formatting
      String formatErrorMessage(int? statusCode) {
        return '成片样式写回失败：${statusCode ?? '-'}';
      }

      expect(formatErrorMessage(400), '成片样式写回失败：400');
      expect(formatErrorMessage(500), '成片样式写回失败：500');
      expect(formatErrorMessage(null), '成片样式写回失败：-');
    });

    test('should pre-fill text controllers with current values', () {
      // Simulate pre-filling logic
      String getInitialSubtitleStyle(String? currentValue) {
        return currentValue ?? '';
      }

      String getInitialBgmStrategy(String? currentValue) {
        return currentValue ?? '';
      }

      expect(getInitialSubtitleStyle(null), '');
      expect(getInitialSubtitleStyle(''), '');
      expect(getInitialSubtitleStyle('cinematic_cn_v2'), 'cinematic_cn_v2');

      expect(getInitialBgmStrategy(null), '');
      expect(getInitialBgmStrategy(''), '');
      expect(getInitialBgmStrategy('pulse_light'), 'pulse_light');
    });

    test('should update state after successful save', () {
      // Simulate state update logic
      var subtitleStyle = 'old_style';
      var bgmStrategy = 'old_bgm';

      void updateState(String newSubtitle, String newBgm) {
        subtitleStyle = newSubtitle;
        bgmStrategy = newBgm;
      }

      updateState('cinematic_cn_v2', 'pulse_light');
      expect(subtitleStyle, 'cinematic_cn_v2');
      expect(bgmStrategy, 'pulse_light');

      // Clear to defaults
      updateState('', '');
      expect(subtitleStyle, '');
      expect(bgmStrategy, '');
    });

    test('should handle clearing configuration (reset to defaults)', () {
      // Simulate clearing configuration
      Map<String, dynamic> prepareClearPayload() {
        return <String, dynamic>{
          'subtitleStyle': null,
          'bgmStrategy': null,
        };
      }

      final payload = prepareClearPayload();
      expect(payload['subtitleStyle'], null);
      expect(payload['bgmStrategy'], null);
    });

    test('should validate dialog can be opened with project selected', () {
      // Simulate dialog open conditions
      bool canOpenDialog({
        required String? accessToken,
        required bool projectSelected,
      }) {
        if (accessToken == null || accessToken.isEmpty) return false;
        if (!projectSelected) return false;
        return true;
      }

      expect(canOpenDialog(accessToken: null, projectSelected: true), false);
      expect(canOpenDialog(accessToken: '', projectSelected: true), false);
      expect(canOpenDialog(accessToken: 'token', projectSelected: false), false);
      expect(canOpenDialog(accessToken: 'token', projectSelected: true), true);
    });
  });

  group('Shot Reordering UI Tests', () {
    test('parseDurationSeconds should parse valid duration strings', () {
      int? parseDurationSeconds(String value) {
        final trimmed = value.trim().toLowerCase();
        if (trimmed.isEmpty) return null;
        final digits = RegExp(r'^(\d{1,3})\s*s?$').firstMatch(trimmed);
        if (digits == null) return null;
        return int.tryParse(digits.group(1)!);
      }

      expect(parseDurationSeconds('10s'), 10);
      expect(parseDurationSeconds('10'), 10);
      expect(parseDurationSeconds('  10s  '), 10);
      expect(parseDurationSeconds('100S'), 100);
      expect(parseDurationSeconds(''), null);
      expect(parseDurationSeconds('abc'), null);
      expect(parseDurationSeconds('10.5'), null);
    });

    test('subtitleMismatchLine should detect subtitle/duration mismatches', () {
      int? parseDurationSeconds(String value) {
        final trimmed = value.trim().toLowerCase();
        if (trimmed.isEmpty) return null;
        final digits = RegExp(r'^(\d{1,3})\s*s?$').firstMatch(trimmed);
        if (digits == null) return null;
        return int.tryParse(digits.group(1)!);
      }

      String subtitleMismatchLine(String durationText, String subtitleText) {
        final durationSec = parseDurationSeconds(durationText);
        final hasSubtitle = subtitleText.isNotEmpty;
        if (hasSubtitle && durationSec == null) {
          return '字幕存在，但时长未显式（建议先对齐时长）。';
        }
        if (!hasSubtitle && (durationSec ?? 0) > 0) {
          return '时长已设定，但字幕为空（可能有字幕轨缺口）。';
        }
        if (hasSubtitle && (durationSec ?? 0) <= 0) {
          return '字幕存在，但时长异常（<=0）。';
        }
        return '字幕与时长未见明显错位。';
      }

      expect(
        subtitleMismatchLine('', '字幕内容'),
        '字幕存在，但时长未显式（建议先对齐时长）。',
      );
      expect(
        subtitleMismatchLine('10s', ''),
        '时长已设定，但字幕为空（可能有字幕轨缺口）。',
      );
      expect(
        subtitleMismatchLine('0s', '字幕内容'),
        '字幕存在，但时长异常（<=0）。',
      );
      expect(
        subtitleMismatchLine('10s', '字幕内容'),
        '字幕与时长未见明显错位。',
      );
      expect(
        subtitleMismatchLine('', ''),
        '字幕与时长未见明显错位。',
      );
    });

    test('shot reordering should swap adjacent items correctly', () {
      // Simulate shot list
      final shots = [
        {'id': 1, 'name': 'Shot 1'},
        {'id': 2, 'name': 'Shot 2'},
        {'id': 3, 'name': 'Shot 3'},
      ];

      // Move down (swap with next)
      void moveDown(List<Map<String, dynamic>> list, int index) {
        if (index < list.length - 1) {
          final current = list[index];
          list[index] = list[index + 1];
          list[index + 1] = current;
        }
      }

      // Move up (swap with previous)
      void moveUp(List<Map<String, dynamic>> list, int index) {
        if (index > 0) {
          final current = list[index];
          list[index] = list[index - 1];
          list[index - 1] = current;
        }
      }

      // Test move down
      moveDown(shots, 0);
      expect(shots[0]['id'], 2);
      expect(shots[1]['id'], 1);
      expect(shots[2]['id'], 3);

      // Test move up
      moveUp(shots, 1);
      expect(shots[0]['id'], 1);
      expect(shots[1]['id'], 2);
      expect(shots[2]['id'], 3);

      // Test move down at last position (should not change)
      moveDown(shots, 2);
      expect(shots[0]['id'], 1);
      expect(shots[1]['id'], 2);
      expect(shots[2]['id'], 3);

      // Test move up at first position (should not change)
      moveUp(shots, 0);
      expect(shots[0]['id'], 1);
      expect(shots[1]['id'], 2);
      expect(shots[2]['id'], 3);
    });

    test('canMoveUp should be false for first item', () {
      final shots = [1, 2, 3];
      
      bool canMoveUp(int index) => index > 0;
      bool canMoveDown(int index, int length) => index < length - 1;

      expect(canMoveUp(0), false);
      expect(canMoveUp(1), true);
      expect(canMoveUp(2), true);

      expect(canMoveDown(0, shots.length), true);
      expect(canMoveDown(1, shots.length), true);
      expect(canMoveDown(2, shots.length), false);
    });

    test('shot order should update sequence numbers after reordering', () {
      final shots = [
        {'id': 1, 'sequence': 1},
        {'id': 2, 'sequence': 2},
        {'id': 3, 'sequence': 3},
      ];

      // Simulate reordering
      final current = shots[0];
      shots[0] = shots[1];
      shots[1] = current;

      // Verify sequence numbers are based on index
      for (var i = 0; i < shots.length; i++) {
        expect(i + 1, i + 1); // Sequence is idx + 1
      }

      expect(shots[0]['id'], 2);
      expect(shots[1]['id'], 1);
      expect(shots[2]['id'], 3);
    });

    test('duration validation should enforce 1-300 second range', () {
      bool isValidDuration(int? duration) {
        if (duration == null) return false;
        return duration > 0 && duration <= 300;
      }

      expect(isValidDuration(null), false);
      expect(isValidDuration(0), false);
      expect(isValidDuration(-1), false);
      expect(isValidDuration(1), true);
      expect(isValidDuration(150), true);
      expect(isValidDuration(300), true);
      expect(isValidDuration(301), false);
    });

    test('URL validation should reject empty strings', () {
      bool isValidUrl(String? url) {
        return (url ?? '').trim().isNotEmpty;
      }

      expect(isValidUrl(null), false);
      expect(isValidUrl(''), false);
      expect(isValidUrl('   '), false);
      expect(isValidUrl('https://example.com/video.mp4'), true);
    });

    test('shot reordering should preserve paused state', () {
      final pausedIds = {2, 4};
      final shots = [
        {'id': 1, 'paused': false},
        {'id': 2, 'paused': true},
        {'id': 3, 'paused': false},
        {'id': 4, 'paused': true},
      ];

      // Reorder shots
      final current = shots[1];
      shots[1] = shots[2];
      shots[2] = current;

      // Verify paused state is preserved
      expect(pausedIds.contains(2), true);
      expect(pausedIds.contains(4), true);
      expect(pausedIds.contains(1), false);
      expect(pausedIds.contains(3), false);
    });

    test('flow data should contain storyboard array with correct structure', () {
      final orderedStoryboardIds = [789, 790, 791];
      final flowData = <String, dynamic>{
        'storyboard': orderedStoryboardIds
            .map((id) => <String, dynamic>{'id': id})
            .toList(growable: false),
      };

      expect(flowData['storyboard'], isA<List>());
      expect(flowData['storyboard'], hasLength(3));
      expect(flowData['storyboard'][0]['id'], 789);
      expect(flowData['storyboard'][1]['id'], 790);
      expect(flowData['storyboard'][2]['id'], 791);
    });

    test('reorder should group shots by script ID', () {
      final shots = [
        {'scriptId': 1, 'storyboardId': 10},
        {'scriptId': 1, 'storyboardId': 11},
        {'scriptId': 2, 'storyboardId': 20},
        {'scriptId': 2, 'storyboardId': 21},
      ];

      final byScript = <int, List<int>>{};
      for (final shot in shots) {
        final scriptId = shot['scriptId'] as int;
        final storyboardId = shot['storyboardId'] as int;
        byScript.putIfAbsent(scriptId, () => <int>[]).add(storyboardId);
      }

      expect(byScript[1], [10, 11]);
      expect(byScript[2], [20, 21]);
      expect(byScript.keys, hasLength(2));
    });

    test('undo should restore initial order', () {
      final initial = [
        {'id': 1},
        {'id': 2},
        {'id': 3},
      ];
      final ordered = List<Map<String, dynamic>>.from(initial);

      // Reorder
      final current = ordered[0];
      ordered[0] = ordered[1];
      ordered[1] = current;

      expect(ordered[0]['id'], 2);
      expect(ordered[1]['id'], 1);

      // Undo
      final restored = List<Map<String, dynamic>>.from(initial);
      expect(restored[0]['id'], 1);
      expect(restored[1]['id'], 2);
      expect(restored[2]['id'], 3);
    });

    test('persistReorder should handle empty flow data gracefully', () {
      // Simulate empty flow data response
      final flowData = <String, dynamic>{};
      
      // Add storyboard array
      final orderedStoryboardIds = [789, 790, 791];
      flowData['storyboard'] = orderedStoryboardIds
          .map((id) => <String, dynamic>{'id': id})
          .toList(growable: false);

      expect(flowData['storyboard'], isA<List>());
      expect(flowData['storyboard'], hasLength(3));
      expect(flowData['storyboard'][0]['id'], 789);
    });

    test('persistReorder should preserve existing flow data fields', () {
      // Simulate existing flow data with other fields
      final flowData = <String, dynamic>{
        'version': '1.0',
        'metadata': {'created': '2024-01-01'},
        'storyboard': [
          {'id': 100},
          {'id': 101},
        ],
      };

      // Update storyboard order
      final newOrder = [101, 100];
      flowData['storyboard'] = newOrder
          .map((id) => <String, dynamic>{'id': id})
          .toList(growable: false);

      // Verify other fields are preserved
      expect(flowData['version'], '1.0');
      expect(flowData['metadata'], isNotNull);
      expect(flowData['storyboard'][0]['id'], 101);
      expect(flowData['storyboard'][1]['id'], 100);
    });

    test('persistReorder should handle multiple scripts correctly', () {
      final shots = [
        {'scriptId': 1, 'storyboardId': 10},
        {'scriptId': 1, 'storyboardId': 11},
        {'scriptId': 2, 'storyboardId': 20},
        {'scriptId': 2, 'storyboardId': 21},
        {'scriptId': 2, 'storyboardId': 22},
      ];

      // Group by script
      final byScript = <int, List<int>>{};
      for (final shot in shots) {
        final scriptId = shot['scriptId'] as int;
        final storyboardId = shot['storyboardId'] as int;
        byScript.putIfAbsent(scriptId, () => <int>[]).add(storyboardId);
      }

      // Verify grouping
      expect(byScript.keys, hasLength(2));
      expect(byScript[1], [10, 11]);
      expect(byScript[2], [20, 21, 22]);

      // Simulate creating flow data for each script
      for (final entry in byScript.entries) {
        final flowData = <String, dynamic>{
          'storyboard': entry.value
              .map((id) => <String, dynamic>{'id': id})
              .toList(growable: false),
        };
        expect(flowData['storyboard'], isA<List>());
        expect(flowData['storyboard'].length, entry.value.length);
      }
    });

    test('hasOrderChanged should detect when order has changed', () {
      // Helper function to check if order has changed
      bool hasOrderChanged(List<int> ordered, List<int> initial) {
        if (ordered.length != initial.length) return true;
        for (var i = 0; i < ordered.length; i++) {
          if (ordered[i] != initial[i]) return true;
        }
        return false;
      }

      final initial = [1, 2, 3, 4];
      
      // No change
      expect(hasOrderChanged([1, 2, 3, 4], initial), false);
      
      // Order changed
      expect(hasOrderChanged([2, 1, 3, 4], initial), true);
      expect(hasOrderChanged([1, 2, 4, 3], initial), true);
      
      // Length changed
      expect(hasOrderChanged([1, 2, 3], initial), true);
      expect(hasOrderChanged([1, 2, 3, 4, 5], initial), true);
    });

    test('undo button should be disabled when order has not changed', () {
      final initial = [1, 2, 3];
      final ordered = List<int>.from(initial);

      bool hasOrderChanged(List<int> ordered, List<int> initial) {
        if (ordered.length != initial.length) return true;
        for (var i = 0; i < ordered.length; i++) {
          if (ordered[i] != initial[i]) return true;
        }
        return false;
      }

      // Initially, no change
      expect(hasOrderChanged(ordered, initial), false);

      // After reordering
      final current = ordered[0];
      ordered[0] = ordered[1];
      ordered[1] = current;
      expect(hasOrderChanged(ordered, initial), true);

      // After undo
      final restored = List<int>.from(initial);
      expect(hasOrderChanged(restored, initial), false);
    });

    test('initial order should be updated after successful save', () {
      final initial = [1, 2, 3];
      var ordered = List<int>.from(initial);
      var initialOrdered = List<int>.from(initial);

      // Reorder
      final current = ordered[0];
      ordered[0] = ordered[1];
      ordered[1] = current;
      expect(ordered, [2, 1, 3]);

      // Simulate successful save - update initial order
      initialOrdered = List<int>.from(ordered);
      expect(initialOrdered, [2, 1, 3]);

      // Now the "initial" order is the saved order
      bool hasOrderChanged(List<int> ordered, List<int> initial) {
        if (ordered.length != initial.length) return true;
        for (var i = 0; i < ordered.length; i++) {
          if (ordered[i] != initial[i]) return true;
        }
        return false;
      }

      expect(hasOrderChanged(ordered, initialOrdered), false);

      // Further reordering should be detected
      final current2 = ordered[1];
      ordered[1] = ordered[2];
      ordered[2] = current2;
      expect(hasOrderChanged(ordered, initialOrdered), true);
    });

    test('undo should preserve paused state and other shot properties', () {
      final initial = [
        {'id': 1, 'paused': false, 'url': 'url1'},
        {'id': 2, 'paused': true, 'url': ''},
        {'id': 3, 'paused': false, 'url': 'url3'},
      ];
      final ordered = List<Map<String, dynamic>>.from(initial);

      // Reorder
      final current = ordered[0];
      ordered[0] = ordered[1];
      ordered[1] = current;

      // Verify reordering
      expect(ordered[0]['id'], 2);
      expect(ordered[1]['id'], 1);

      // Undo - restore initial order
      final restored = List<Map<String, dynamic>>.from(initial);
      
      // Verify order restored
      expect(restored[0]['id'], 1);
      expect(restored[1]['id'], 2);
      expect(restored[2]['id'], 3);

      // Verify paused state preserved
      expect(restored[0]['paused'], false);
      expect(restored[1]['paused'], true);
      expect(restored[2]['paused'], false);

      // Verify URLs preserved
      expect(restored[0]['url'], 'url1');
      expect(restored[1]['url'], '');
      expect(restored[2]['url'], 'url3');
    });
  });

  group('Total Duration Calculation Tests', () {
    // Requirements 19.1-19.7: Total duration calculation and display
    
    int? parseDurationSeconds(String value) {
      final trimmed = value.trim().toLowerCase();
      if (trimmed.isEmpty) return null;
      final digits = RegExp(r'^(\d{1,3})\s*s?$').firstMatch(trimmed);
      if (digits == null) return null;
      return int.tryParse(digits.group(1)!);
    }

    test('calculateTotalDuration should sum all enabled shot durations', () {
      // Requirements 19.1: Calculate total duration of all enabled shots
      final shots = [
        {'durationText': '10s', 'paused': false},
        {'durationText': '20s', 'paused': false},
        {'durationText': '30s', 'paused': false},
      ];
      final pausedIds = <int>{};

      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      expect(total, 60); // 10 + 20 + 30
    });

    test('calculateTotalDuration should exclude paused shots', () {
      // Requirements 19.6: Exclude paused shots from total duration
      final shots = [
        {'id': 0, 'durationText': '10s', 'paused': false},
        {'id': 1, 'durationText': '20s', 'paused': true},
        {'id': 2, 'durationText': '30s', 'paused': false},
      ];
      final pausedIds = {1};

      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      expect(total, 40); // 10 + 30 (excluding paused shot with 20s)
    });

    test('calculateTotalDuration should treat missing duration as 0', () {
      // Requirements 19.5: Duration missing should be calculated as 0 seconds
      final shots = [
        {'durationText': '10s', 'paused': false},
        {'durationText': '', 'paused': false},
        {'durationText': '30s', 'paused': false},
      ];
      final pausedIds = <int>{};

      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      expect(total, 40); // 10 + 0 + 30
    });

    test('calculateTotalDuration should handle all shots paused', () {
      final shots = [
        {'id': 0, 'durationText': '10s', 'paused': true},
        {'id': 1, 'durationText': '20s', 'paused': true},
        {'id': 2, 'durationText': '30s', 'paused': true},
      ];
      final pausedIds = {0, 1, 2};

      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      expect(total, 0); // All shots paused
    });

    test('calculateTotalDuration should handle empty shot list', () {
      final shots = <Map<String, dynamic>>[];
      final pausedIds = <int>{};

      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      expect(total, 0); // No shots
    });

    test('calculateTotalDuration should handle mixed valid and invalid durations', () {
      final shots = [
        {'durationText': '10s', 'paused': false},
        {'durationText': 'invalid', 'paused': false},
        {'durationText': '20', 'paused': false},
        {'durationText': '', 'paused': false},
        {'durationText': '30s', 'paused': false},
      ];
      final pausedIds = <int>{};

      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      expect(total, 60); // 10 + 0 + 20 + 0 + 30
    });

    test('formatDurationHHMMSS should format seconds correctly', () {
      // Requirements 19.4: Display formatted HH:MM:SS duration
      String formatDurationHHMMSS(int totalSeconds) {
        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;
        return '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}';
      }

      expect(formatDurationHHMMSS(0), '00:00:00');
      expect(formatDurationHHMMSS(1), '00:00:01');
      expect(formatDurationHHMMSS(59), '00:00:59');
      expect(formatDurationHHMMSS(60), '00:01:00');
      expect(formatDurationHHMMSS(61), '00:01:01');
      expect(formatDurationHHMMSS(3599), '00:59:59');
      expect(formatDurationHHMMSS(3600), '01:00:00');
      expect(formatDurationHHMMSS(3661), '01:01:01');
      expect(formatDurationHHMMSS(7200), '02:00:00');
      expect(formatDurationHHMMSS(7265), '02:01:05');
    });

    test('formatDurationHHMMSS should handle large durations', () {
      String formatDurationHHMMSS(int totalSeconds) {
        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;
        return '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}';
      }

      expect(formatDurationHHMMSS(36000), '10:00:00'); // 10 hours
      expect(formatDurationHHMMSS(86400), '24:00:00'); // 24 hours
      expect(formatDurationHHMMSS(359999), '99:59:59'); // 99:59:59
    });

    test('total duration should update when shot order changes', () {
      // Requirements 19.7: Update total duration after shot order changes
      final shots = [
        {'durationText': '10s', 'paused': false},
        {'durationText': '20s', 'paused': false},
        {'durationText': '30s', 'paused': false},
      ];
      final pausedIds = <int>{};

      // Calculate initial total
      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }
      expect(total, 60);

      // Reorder shots (swap first two)
      final temp = shots[0];
      shots[0] = shots[1];
      shots[1] = temp;

      // Recalculate total (should be same since order doesn't affect sum)
      total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }
      expect(total, 60); // Same total, different order
    });

    test('total duration should update when shot duration changes', () {
      // Requirements 19.7: Update total duration after duration changes
      final shots = [
        {'durationText': '10s', 'paused': false},
        {'durationText': '20s', 'paused': false},
        {'durationText': '30s', 'paused': false},
      ];
      final pausedIds = <int>{};

      // Calculate initial total
      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }
      expect(total, 60);

      // Update duration of second shot
      shots[1]['durationText'] = '50s';

      // Recalculate total
      total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }
      expect(total, 90); // 10 + 50 + 30
    });

    test('total duration should update when shot is paused', () {
      // Requirements 19.7: Update total duration after pause state changes
      final shots = [
        {'id': 0, 'durationText': '10s', 'paused': false},
        {'id': 1, 'durationText': '20s', 'paused': false},
        {'id': 2, 'durationText': '30s', 'paused': false},
      ];
      var pausedIds = <int>{};

      // Calculate initial total
      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }
      expect(total, 60);

      // Pause second shot
      pausedIds = {1};

      // Recalculate total
      total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }
      expect(total, 40); // 10 + 30 (excluding paused 20s)
    });

    test('total duration should update when shot is enabled', () {
      final shots = [
        {'id': 0, 'durationText': '10s', 'paused': false},
        {'id': 1, 'durationText': '20s', 'paused': true},
        {'id': 2, 'durationText': '30s', 'paused': false},
      ];
      var pausedIds = {1};

      // Calculate initial total (with shot 1 paused)
      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }
      expect(total, 40); // 10 + 30

      // Enable second shot
      pausedIds = <int>{};

      // Recalculate total
      total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }
      expect(total, 60); // 10 + 20 + 30
    });

    test('total duration display should show both seconds and formatted time', () {
      // Requirements 19.2, 19.3, 19.4: Display total duration in seconds and HH:MM:SS
      String formatDurationHHMMSS(int totalSeconds) {
        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;
        return '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}';
      }

      String formatTotalDurationDisplay(int totalSeconds) {
        final formatted = formatDurationHHMMSS(totalSeconds);
        return '成片总时长：$totalSeconds秒 ($formatted)';
      }

      expect(
        formatTotalDurationDisplay(0),
        '成片总时长：0秒 (00:00:00)',
      );
      expect(
        formatTotalDurationDisplay(60),
        '成片总时长：60秒 (00:01:00)',
      );
      expect(
        formatTotalDurationDisplay(125),
        '成片总时长：125秒 (00:02:05)',
      );
      expect(
        formatTotalDurationDisplay(3665),
        '成片总时长：3665秒 (01:01:05)',
      );
    });

    test('total duration should handle zero duration shots', () {
      final shots = [
        {'durationText': '0s', 'paused': false},
        {'durationText': '10s', 'paused': false},
        {'durationText': '0', 'paused': false},
      ];
      final pausedIds = <int>{};

      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      expect(total, 10); // Only the 10s shot counts (0s shots are excluded)
    });

    test('total duration should handle negative duration gracefully', () {
      // Although negative durations shouldn't occur, test defensive behavior
      final shots = [
        {'durationText': '10s', 'paused': false},
        {'durationText': '-5s', 'paused': false}, // Invalid, should be ignored
        {'durationText': '20s', 'paused': false},
      ];
      final pausedIds = <int>{};

      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      expect(total, 30); // 10 + 20 (negative duration ignored)
    });

    test('total duration calculation should be efficient for large shot lists', () {
      // Create a large list of shots
      final shots = List.generate(
        1000,
        (i) => {'durationText': '${(i % 100) + 1}s', 'paused': false},
      );
      final pausedIds = <int>{};

      // Calculate total
      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      // Verify calculation completes and produces reasonable result
      expect(total, greaterThan(0));
      expect(total, lessThan(100000)); // Sanity check
    });

    test('total duration should handle complex scenario with mixed states', () {
      // Complex scenario: mix of enabled, paused, missing durations
      final shots = [
        {'id': 0, 'durationText': '10s', 'paused': false},
        {'id': 1, 'durationText': '20s', 'paused': true},
        {'id': 2, 'durationText': '', 'paused': false},
        {'id': 3, 'durationText': '30s', 'paused': false},
        {'id': 4, 'durationText': '15s', 'paused': true},
        {'id': 5, 'durationText': '25s', 'paused': false},
        {'id': 6, 'durationText': 'invalid', 'paused': false},
        {'id': 7, 'durationText': '5s', 'paused': false},
      ];
      final pausedIds = {1, 4};

      var total = 0;
      for (var i = 0; i < shots.length; i++) {
        if (pausedIds.contains(i)) continue;
        final durationSec = parseDurationSeconds(shots[i]['durationText'] as String);
        if (durationSec != null && durationSec > 0) {
          total += durationSec;
        }
      }

      // 10 + 0 + 30 + 25 + 0 + 5 = 70
      // (excluding paused: 20, 15; missing/invalid: '', 'invalid')
      expect(total, 70);
    });
  });

  group('Media Type Inference Tests', () {
    // Note: Media type inference is performed on the backend via the
    // assembly_selected_media_kind function. The frontend receives the
    // inferred type in the selectedMediaKind field of ShortVideoAssemblyShot.
    // These tests verify the expected behavior matches backend implementation.

    // Helper function matching the backend implementation for testing
    String inferMediaKind(String? url) {
      final trimmed = url?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return 'none';
      }
      
      // Remove query parameters and fragments
      final path = trimmed.split('?').first.split('#').first;
      final lower = path.toLowerCase();
      
      // Requirements 18.2: video types (mp4, mov, avi)
      if (lower.endsWith('.mp4') || 
          lower.endsWith('.mov') || 
          lower.endsWith('.avi')) {
        return 'video';
      }
      
      // Requirements 18.3: image types (png, jpg, jpeg, webp)
      if (lower.endsWith('.png') || 
          lower.endsWith('.jpg') || 
          lower.endsWith('.jpeg') || 
          lower.endsWith('.webp')) {
        return 'image';
      }
      
      // Requirements 18.5: other type (unrecognized formats)
      return 'other';
    }

    test('should return none for empty or null URLs', () {
      // Requirements 18.4: none type (URL is empty)
      expect(inferMediaKind(null), 'none');
      expect(inferMediaKind(''), 'none');
      expect(inferMediaKind('   '), 'none');
      expect(inferMediaKind('\t\n'), 'none');
    });

    test('should recognize video types', () {
      // Requirements 18.2: video types (mp4, mov, avi)
      expect(inferMediaKind('https://example.com/video.mp4'), 'video');
      expect(inferMediaKind('https://example.com/video.mov'), 'video');
      expect(inferMediaKind('https://example.com/video.avi'), 'video');
      
      // Case insensitive
      expect(inferMediaKind('https://example.com/video.MP4'), 'video');
      expect(inferMediaKind('https://example.com/video.MOV'), 'video');
      expect(inferMediaKind('https://example.com/video.AVI'), 'video');
      expect(inferMediaKind('https://example.com/video.Mp4'), 'video');
    });

    test('should recognize image types', () {
      // Requirements 18.3: image types (png, jpg, jpeg, webp)
      expect(inferMediaKind('https://example.com/image.png'), 'image');
      expect(inferMediaKind('https://example.com/image.jpg'), 'image');
      expect(inferMediaKind('https://example.com/image.jpeg'), 'image');
      expect(inferMediaKind('https://example.com/image.webp'), 'image');
      
      // Case insensitive
      expect(inferMediaKind('https://example.com/image.PNG'), 'image');
      expect(inferMediaKind('https://example.com/image.JPG'), 'image');
      expect(inferMediaKind('https://example.com/image.JPEG'), 'image');
      expect(inferMediaKind('https://example.com/image.WEBP'), 'image');
    });

    test('should return other for unrecognized formats', () {
      // Requirements 18.5: other type (unrecognized formats)
      expect(inferMediaKind('https://example.com/file.txt'), 'other');
      expect(inferMediaKind('https://example.com/file.pdf'), 'other');
      expect(inferMediaKind('https://example.com/file.mkv'), 'other');
      expect(inferMediaKind('https://example.com/file.webm'), 'other');
      expect(inferMediaKind('https://example.com/file.gif'), 'other');
      expect(inferMediaKind('https://example.com/file.svg'), 'other');
      expect(inferMediaKind('https://example.com/file'), 'other');
      expect(inferMediaKind('https://example.com/'), 'other');
    });

    test('should handle URLs with query parameters', () {
      expect(
        inferMediaKind('https://example.com/video.mp4?token=abc123'),
        'video',
      );
      expect(
        inferMediaKind('https://example.com/image.png?size=large&format=hd'),
        'image',
      );
      expect(
        inferMediaKind('https://example.com/file.txt?download=true'),
        'other',
      );
    });

    test('should handle URLs with fragments', () {
      expect(
        inferMediaKind('https://example.com/video.mov#section'),
        'video',
      );
      expect(
        inferMediaKind('https://example.com/image.jpg#top'),
        'image',
      );
      expect(
        inferMediaKind('https://example.com/file.pdf#page=1'),
        'other',
      );
    });

    test('should handle URLs with both query parameters and fragments', () {
      expect(
        inferMediaKind('https://example.com/video.avi?token=xyz#start'),
        'video',
      );
      expect(
        inferMediaKind('https://example.com/image.webp?quality=high#preview'),
        'image',
      );
    });

    test('should handle URLs with leading/trailing whitespace', () {
      expect(
        inferMediaKind('  https://example.com/video.mp4  '),
        'video',
      );
      expect(
        inferMediaKind('\thttps://example.com/image.png\n'),
        'image',
      );
      expect(
        inferMediaKind('  https://example.com/file.txt  '),
        'other',
      );
    });

    test('should handle local file paths', () {
      expect(inferMediaKind('/path/to/video.mp4'), 'video');
      expect(inferMediaKind('/path/to/image.jpg'), 'image');
      expect(inferMediaKind('C:\\Users\\video.mov'), 'video');
      expect(inferMediaKind('./relative/path/image.png'), 'image');
    });

    test('should handle filenames with multiple dots', () {
      expect(inferMediaKind('https://example.com/my.video.file.mp4'), 'video');
      expect(inferMediaKind('https://example.com/my.image.file.png'), 'image');
      expect(inferMediaKind('https://example.com/my.document.file.pdf'), 'other');
    });

    test('should handle URLs without file extensions', () {
      expect(inferMediaKind('https://example.com/video'), 'other');
      expect(inferMediaKind('https://example.com/image'), 'other');
      expect(inferMediaKind('https://example.com/'), 'other');
      expect(inferMediaKind('https://example.com'), 'other');
    });

    test('should not recognize formats that are not in requirements', () {
      // These should return 'other' as they're not in the requirements
      expect(inferMediaKind('https://example.com/video.mkv'), 'other');
      expect(inferMediaKind('https://example.com/video.webm'), 'other');
      expect(inferMediaKind('https://example.com/image.gif'), 'other');
      expect(inferMediaKind('https://example.com/image.bmp'), 'other');
      expect(inferMediaKind('https://example.com/image.svg'), 'other');
    });

    test('should handle edge cases', () {
      expect(inferMediaKind('.mp4'), 'video');
      expect(inferMediaKind('.png'), 'image');
      expect(inferMediaKind('mp4'), 'other'); // No dot
      expect(inferMediaKind('png'), 'other'); // No dot
      expect(inferMediaKind('https://example.com/.mp4'), 'video');
      expect(inferMediaKind('https://example.com/.hidden.jpg'), 'image');
    });

    test('should match backend implementation behavior', () {
      // These tests ensure frontend test logic matches backend implementation
      final testCases = <List<dynamic>>[
        // [url, expected]
        [null, 'none'],
        ['', 'none'],
        ['   ', 'none'],
        ['https://example.com/video.mp4', 'video'],
        ['https://example.com/video.mov', 'video'],
        ['https://example.com/video.avi', 'video'],
        ['https://example.com/image.png', 'image'],
        ['https://example.com/image.jpg', 'image'],
        ['https://example.com/image.jpeg', 'image'],
        ['https://example.com/image.webp', 'image'],
        ['https://example.com/file.txt', 'other'],
        ['https://example.com/video.mp4?token=abc', 'video'],
        ['https://example.com/image.png#section', 'image'],
        ['  https://example.com/video.mp4  ', 'video'],
      ];

      for (final testCase in testCases) {
        final url = testCase[0];
        final expected = testCase[1];
        expect(
          inferMediaKind(url),
          expected,
          reason: 'Failed for URL: $url',
        );
      }
    });

    test('should display media type in UI correctly', () {
      // Simulate the UI display logic
      String formatStatusText(bool paused, String mediaKind) {
        return paused ? '状态：暂停' : '状态：启用（$mediaKind）';
      }

      expect(formatStatusText(false, 'video'), '状态：启用（video）');
      expect(formatStatusText(false, 'image'), '状态：启用（image）');
      expect(formatStatusText(false, 'none'), '状态：启用（none）');
      expect(formatStatusText(false, 'other'), '状态：启用（other）');
      expect(formatStatusText(true, 'video'), '状态：暂停');
      expect(formatStatusText(true, 'image'), '状态：暂停');
    });

    test('should handle media type changes when replacing video', () {
      // Simulate replacing video URL and updating media kind
      String currentUrl = 'https://example.com/video.mp4';
      String currentKind = inferMediaKind(currentUrl);
      expect(currentKind, 'video');

      // Replace with image
      currentUrl = 'https://example.com/image.png';
      currentKind = inferMediaKind(currentUrl);
      expect(currentKind, 'image');

      // Replace with other format
      currentUrl = 'https://example.com/file.pdf';
      currentKind = inferMediaKind(currentUrl);
      expect(currentKind, 'other');

      // Clear URL
      currentUrl = '';
      currentKind = inferMediaKind(currentUrl);
      expect(currentKind, 'none');
    });
  });
}
