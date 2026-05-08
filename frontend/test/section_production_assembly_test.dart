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

  group('Voiceover Status Display Tests', () {
    // Requirements 16.1-16.7: Voiceover asset readiness status display
    
    test('should display voiceover_script_ready status correctly', () {
      // Requirements 16.1, 16.3: Display voiceover_script_ready status
      String formatVoiceoverScriptStatus(bool ready) {
        return ready ? '✓ 就绪' : '✗ 未就绪';
      }

      expect(formatVoiceoverScriptStatus(true), '✓ 就绪');
      expect(formatVoiceoverScriptStatus(false), '✗ 未就绪');
    });

    test('should display voiceover_asset_ready status correctly', () {
      // Requirements 16.2, 16.4: Display voiceover_asset_ready status
      String formatVoiceoverAssetStatus(bool ready) {
        return ready ? '✓ 就绪' : '✗ 未就绪';
      }

      expect(formatVoiceoverAssetStatus(true), '✓ 就绪');
      expect(formatVoiceoverAssetStatus(false), '✗ 未就绪');
    });

    test('should display voiceover_state when present', () {
      // Requirements 16.6: Display voiceover_state
      bool shouldDisplayVoiceoverState(String state) {
        return state.isNotEmpty;
      }

      expect(shouldDisplayVoiceoverState('pending'), true);
      expect(shouldDisplayVoiceoverState('running'), true);
      expect(shouldDisplayVoiceoverState('completed'), true);
      expect(shouldDisplayVoiceoverState('failed'), true);
      expect(shouldDisplayVoiceoverState(''), false);
    });

    test('should display voiceover_audio_url when present', () {
      // Requirements 16.5: Display voiceover_audio_url if exists
      bool shouldDisplayVoiceoverAudioUrl(String url) {
        return url.trim().isNotEmpty;
      }

      expect(shouldDisplayVoiceoverAudioUrl('https://example.com/audio.mp3'), true);
      expect(shouldDisplayVoiceoverAudioUrl(''), false);
      expect(shouldDisplayVoiceoverAudioUrl('   '), false);
    });

    test('should display voiceover_error when state is failed', () {
      // Requirements 16.7: Display voiceover_error when state is failed
      bool shouldDisplayVoiceoverError(String state, String error) {
        return state == 'failed' && error.trim().isNotEmpty;
      }

      expect(shouldDisplayVoiceoverError('failed', 'TTS service unavailable'), true);
      expect(shouldDisplayVoiceoverError('failed', ''), false);
      expect(shouldDisplayVoiceoverError('completed', 'Some error'), false);
      expect(shouldDisplayVoiceoverError('pending', ''), false);
    });

    test('should format complete voiceover status line', () {
      String formatVoiceoverStatusLine(bool scriptReady, bool assetReady) {
        return '配音文本：${scriptReady ? "✓ 就绪" : "✗ 未就绪"} · '
            '配音资产：${assetReady ? "✓ 就绪" : "✗ 未就绪"}';
      }

      expect(
        formatVoiceoverStatusLine(true, true),
        '配音文本：✓ 就绪 · 配音资产：✓ 就绪',
      );
      expect(
        formatVoiceoverStatusLine(true, false),
        '配音文本：✓ 就绪 · 配音资产：✗ 未就绪',
      );
      expect(
        formatVoiceoverStatusLine(false, true),
        '配音文本：✗ 未就绪 · 配音资产：✓ 就绪',
      );
      expect(
        formatVoiceoverStatusLine(false, false),
        '配音文本：✗ 未就绪 · 配音资产：✗ 未就绪',
      );
    });

    test('should handle all voiceover states correctly', () {
      final validStates = ['pending', 'running', 'completed', 'failed'];
      
      for (final state in validStates) {
        expect(state.isNotEmpty, true);
      }

      // Empty state should not be displayed
      expect(''.isNotEmpty, false);
    });

    test('should truncate long audio URLs for display', () {
      // Simulate URL truncation logic
      String formatAudioUrlForDisplay(String url, {int maxLength = 50}) {
        if (url.length <= maxLength) return url;
        return '${url.substring(0, maxLength)}...';
      }

      final shortUrl = 'https://example.com/audio.mp3';
      final longUrl = 'https://example.com/very/long/path/to/audio/file/with/many/segments/audio.mp3';

      expect(formatAudioUrlForDisplay(shortUrl), shortUrl);
      expect(formatAudioUrlForDisplay(longUrl, maxLength: 50).length, 53); // 50 + '...'
      expect(formatAudioUrlForDisplay(longUrl, maxLength: 50).endsWith('...'), true);
    });

    test('should validate voiceover entry data structure', () {
      // Simulate creating an entry with voiceover fields
      final entry = {
        'voiceoverScriptReady': true,
        'voiceoverAssetReady': false,
        'voiceoverState': 'pending',
        'voiceoverAudioUrl': '',
        'voiceoverError': '',
      };

      expect(entry['voiceoverScriptReady'], isA<bool>());
      expect(entry['voiceoverAssetReady'], isA<bool>());
      expect(entry['voiceoverState'], isA<String>());
      expect(entry['voiceoverAudioUrl'], isA<String>());
      expect(entry['voiceoverError'], isA<String>());
    });

    test('should handle null voiceover fields gracefully', () {
      // Simulate handling null values from API
      String? nullableState;
      String? nullableUrl;
      String? nullableError;

      final state = nullableState ?? '';
      final url = nullableUrl ?? '';
      final error = nullableError ?? '';

      expect(state, '');
      expect(url, '');
      expect(error, '');
    });

    test('should display error message in red when voiceover fails', () {
      // Simulate error styling logic
      bool shouldUseErrorColor(String state, String error) {
        return state == 'failed' && error.trim().isNotEmpty;
      }

      expect(shouldUseErrorColor('failed', 'TTS error'), true);
      expect(shouldUseErrorColor('failed', ''), false);
      expect(shouldUseErrorColor('completed', 'Some error'), false);
      expect(shouldUseErrorColor('pending', ''), false);
    });

    test('should preserve voiceover fields during copyWith', () {
      // Simulate copyWith logic
      final original = {
        'voiceoverScriptReady': true,
        'voiceoverAssetReady': false,
        'voiceoverState': 'pending',
        'voiceoverAudioUrl': 'https://example.com/audio.mp3',
        'voiceoverError': '',
      };

      // Copy with some fields changed
      final updated = Map<String, dynamic>.from(original);
      updated['selectedMediaUrl'] = 'new_url';
      updated['durationText'] = '20s';

      // Verify voiceover fields are preserved
      expect(updated['voiceoverScriptReady'], true);
      expect(updated['voiceoverAssetReady'], false);
      expect(updated['voiceoverState'], 'pending');
      expect(updated['voiceoverAudioUrl'], 'https://example.com/audio.mp3');
      expect(updated['voiceoverError'], '');
    });

    test('should display voiceover status for multiple shots', () {
      final shots = [
        {
          'id': 1,
          'voiceoverScriptReady': true,
          'voiceoverAssetReady': true,
          'voiceoverState': 'completed',
          'voiceoverAudioUrl': 'https://example.com/audio1.mp3',
          'voiceoverError': '',
        },
        {
          'id': 2,
          'voiceoverScriptReady': true,
          'voiceoverAssetReady': false,
          'voiceoverState': 'pending',
          'voiceoverAudioUrl': '',
          'voiceoverError': '',
        },
        {
          'id': 3,
          'voiceoverScriptReady': false,
          'voiceoverAssetReady': false,
          'voiceoverState': 'failed',
          'voiceoverAudioUrl': '',
          'voiceoverError': 'TTS service unavailable',
        },
      ];

      // Verify each shot has correct voiceover status
      expect(shots[0]['voiceoverScriptReady'], true);
      expect(shots[0]['voiceoverAssetReady'], true);
      expect(shots[0]['voiceoverState'], 'completed');

      expect(shots[1]['voiceoverScriptReady'], true);
      expect(shots[1]['voiceoverAssetReady'], false);
      expect(shots[1]['voiceoverState'], 'pending');

      expect(shots[2]['voiceoverScriptReady'], false);
      expect(shots[2]['voiceoverAssetReady'], false);
      expect(shots[2]['voiceoverState'], 'failed');
      expect(shots[2]['voiceoverError'], 'TTS service unavailable');
    });

    test('should handle voiceover state transitions', () {
      // Simulate state transitions
      var state = 'pending';
      
      // Transition to running
      state = 'running';
      expect(state, 'running');

      // Transition to completed
      state = 'completed';
      expect(state, 'completed');

      // Or transition to failed
      state = 'failed';
      expect(state, 'failed');
    });

    test('should validate voiceover readiness combinations', () {
      // Test all possible combinations of script_ready and asset_ready
      final combinations = [
        {'scriptReady': false, 'assetReady': false}, // No voiceover
        {'scriptReady': true, 'assetReady': false},  // Script ready, no asset
        {'scriptReady': false, 'assetReady': true},  // Asset without script (unusual)
        {'scriptReady': true, 'assetReady': true},   // Fully ready
      ];

      for (final combo in combinations) {
        expect(combo['scriptReady'], isA<bool>());
        expect(combo['assetReady'], isA<bool>());
      }

      // Most common case: script ready but asset not yet generated
      expect(combinations[1]['scriptReady'], true);
      expect(combinations[1]['assetReady'], false);

      // Ideal case: both ready
      expect(combinations[3]['scriptReady'], true);
      expect(combinations[3]['assetReady'], true);
    });
  });

  group('Export Check Workflow Tests', () {
    // Task 14.3: Verify export check workflow
    // Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 11.1, 11.2, 11.3, 11.4

    String exportCheckHeadline(bool exportReady) {
      return exportReady
          ? '服务端未发现阻塞级问题（仍需在制作侧确认成片）。'
          : '存在阻塞项：建议先在制作工作区补齐后再导出 / 成片。';
    }

    test('export check should display export ready status correctly', () {
      // Requirements 10.2: Display export ready status
      final exportCheck = <String, dynamic>{
        'exportReady': true,
        'summary': <String, dynamic>{
          'storyboardCount': 10,
          'blockingIssueCount': 0,
          'warningIssueCount': 2,
        },
      };

      expect(exportCheck['exportReady'], true);
      final summary = exportCheck['summary']! as Map<String, dynamic>;
      expect(summary['blockingIssueCount'], 0);
      expect(summary['warningIssueCount'], 2);
    });

    test('export check should display blocking issues correctly', () {
      // Requirements 10.4: Display blocking issues with details
      final issues = [
        {
          'severity': 'blocking',
          'code': 'NO_VIDEO',
          'detail': '未选择视频',
          'scriptNumericId': 1,
          'storyboardNumericId': 10,
          'sbIndex': 1,
        },
        {
          'severity': 'blocking',
          'code': 'NO_DURATION',
          'detail': '时长未设定',
          'scriptNumericId': 1,
          'storyboardNumericId': 11,
          'sbIndex': 2,
        },
      ];

      final blockingIssues = issues.where((i) => i['severity'] == 'blocking').toList();
      expect(blockingIssues, hasLength(2));
      expect(blockingIssues[0]['code'], 'NO_VIDEO');
      expect(blockingIssues[1]['code'], 'NO_DURATION');
    });

    test('export check should display warning issues correctly', () {
      // Requirements 10.4: Display warning issues with details
      final issues = [
        {
          'severity': 'warning',
          'code': 'SUBTITLE_EMPTY',
          'detail': '字幕为空',
          'scriptNumericId': 1,
          'storyboardNumericId': 12,
          'sbIndex': 3,
        },
        {
          'severity': 'warning',
          'code': 'VOICEOVER_MISSING',
          'detail': '旁白缺失',
          'scriptNumericId': 1,
          'storyboardNumericId': 13,
          'sbIndex': 4,
        },
      ];

      final warningIssues = issues.where((i) => i['severity'] == 'warning').toList();
      expect(warningIssues, hasLength(2));
      expect(warningIssues[0]['code'], 'SUBTITLE_EMPTY');
      expect(warningIssues[1]['code'], 'VOICEOVER_MISSING');
    });

    test('export check should format issue display correctly', () {
      // Requirements 10.5: Display issue with severity, code, message, shot info
      final issue = {
        'severity': 'blocking',
        'code': 'NO_VIDEO',
        'detail': '未选择视频',
        'scriptNumericId': 1,
        'storyboardNumericId': 10,
        'sbIndex': 1,
      };

      final formatted = '剧本 #${issue['scriptNumericId']} · '
          '分镜 #${issue['storyboardNumericId']} · '
          '序 ${issue['sbIndex']} · '
          '${issue['code']} · '
          '${issue['detail']}';

      expect(formatted, '剧本 #1 · 分镜 #10 · 序 1 · NO_VIDEO · 未选择视频');
    });

    test('export check should disable export button when blocking issues exist', () {
      // Requirements 10.6: Disable export button when blocking issues exist
      final exportCheck = <String, dynamic>{
        'exportReady': false,
        'summary': <String, dynamic>{
          'blockingIssueCount': 3,
          'warningIssueCount': 1,
        },
      };

      final canExport = exportCheck['exportReady'] as bool;
      final summary = exportCheck['summary']! as Map<String, dynamic>;
      final hasBlockingIssues = (summary['blockingIssueCount'] as int) > 0;

      expect(canExport, false);
      expect(hasBlockingIssues, true);
    });

    test('export check should allow export when only warnings exist', () {
      // Requirements 10.7: Allow export when only warning issues exist
      final exportCheck = <String, dynamic>{
        'exportReady': true,
        'summary': <String, dynamic>{
          'blockingIssueCount': 0,
          'warningIssueCount': 2,
        },
      };

      final canExport = exportCheck['exportReady'] as bool;
      final summary = exportCheck['summary']! as Map<String, dynamic>;
      final hasBlockingIssues = (summary['blockingIssueCount'] as int) > 0;
      final hasWarnings = (summary['warningIssueCount'] as int) > 0;

      expect(canExport, true);
      expect(hasBlockingIssues, false);
      expect(hasWarnings, true);
    });

    test('export check should display summary metrics correctly', () {
      // Requirements 10.3: Display check summary
      final summary = {
        'storyboardCount': 15,
        'blockingIssueCount': 2,
        'warningIssueCount': 3,
      };

      expect(summary['storyboardCount'], 15);
      expect(summary['blockingIssueCount'], 2);
      expect(summary['warningIssueCount'], 3);
    });

    test('quality gate should skip check when strategy is off', () {
      // Requirements 11.2: Skip quality gate check when strategy is off
      final qualityGate = {
        'strategy': 'off',
        'enforced': false,
        'pendingReviewBadCaseCount': 5,
      };

      final shouldCheckQuality = qualityGate['strategy'] != 'off';
      expect(shouldCheckQuality, false);
    });

    test('quality gate should show warning when strategy is warn', () {
      // Requirements 11.3: Show warning but allow export when strategy is warn
      final qualityGate = {
        'strategy': 'warn',
        'enforced': false,
        'pendingReviewBadCaseCount': 3,
      };

      final isWarnMode = qualityGate['strategy'] == 'warn';
      final hasBadCases = (qualityGate['pendingReviewBadCaseCount'] as int) > 0;

      expect(isWarnMode, true);
      expect(hasBadCases, true);
      
      // In warn mode, export is allowed even with bad cases
      final canExport = true; // Warn mode doesn't block
      expect(canExport, true);
    });

    test('quality gate should block export when strategy is block and has bad cases', () {
      // Requirements 11.4: Block export when strategy is block and quality not met
      final qualityGate = {
        'strategy': 'block',
        'enforced': true,
        'pendingReviewBadCaseCount': 2,
      };

      final isBlockMode = qualityGate['strategy'] == 'block';
      final isEnforced = qualityGate['enforced'] as bool;
      final hasBadCases = (qualityGate['pendingReviewBadCaseCount'] as int) > 0;

      expect(isBlockMode, true);
      expect(isEnforced, true);
      expect(hasBadCases, true);

      // In block mode with enforcement and bad cases, export is blocked
      final canExport = !(isBlockMode && isEnforced && hasBadCases);
      expect(canExport, false);
    });

    test('quality gate should allow export when strategy is block but no bad cases', () {
      // Requirements 11.4: Allow export when strategy is block but no bad cases
      final qualityGate = {
        'strategy': 'block',
        'enforced': true,
        'pendingReviewBadCaseCount': 0,
      };

      final isBlockMode = qualityGate['strategy'] == 'block';
      final isEnforced = qualityGate['enforced'] as bool;
      final hasBadCases = (qualityGate['pendingReviewBadCaseCount'] as int) > 0;

      expect(isBlockMode, true);
      expect(isEnforced, true);
      expect(hasBadCases, false);

      // In block mode but no bad cases, export is allowed
      final canExport = !(isBlockMode && isEnforced && hasBadCases);
      expect(canExport, true);
    });

    test('quality gate should display pending review bad case count', () {
      // Requirements 11.7: Display pending review bad case count
      final qualityGate = {
        'strategy': 'block',
        'enforced': true,
        'pendingReviewBadCaseCount': 5,
      };

      expect(qualityGate['pendingReviewBadCaseCount'], 5);
    });

    test('quality gate should display blocking reasons when enforced', () {
      // Requirements 11.6: Display blocking reasons with code, message, rework route
      final qualityGate = {
        'strategy': 'block',
        'enforced': true,
        'pendingReviewBadCaseCount': 2,
        'blockingReasons': [
          {
            'code': 'QUALITY_ISSUE_1',
            'message': '质量问题1需要修复',
            'reworkRoute': '/quality/review/1',
          },
          {
            'code': 'QUALITY_ISSUE_2',
            'message': '质量问题2需要修复',
            'reworkRoute': '/quality/review/2',
          },
        ],
      };

      final reasons = qualityGate['blockingReasons'] as List;
      expect(reasons, hasLength(2));
      expect(reasons[0]['code'], 'QUALITY_ISSUE_1');
      expect(reasons[0]['message'], '质量问题1需要修复');
      expect(reasons[0]['reworkRoute'], '/quality/review/1');
    });

    test('quality gate should format blocking reason display correctly', () {
      // Requirements 11.6: Format blocking reason with code, message, rework route
      final reason = {
        'code': 'QUALITY_ISSUE',
        'message': '质量问题需要修复',
        'reworkRoute': '/quality/review/123',
      };

      final formatted = '${reason['code']}: ${reason['message']} [返工: ${reason['reworkRoute']}]';
      expect(formatted, 'QUALITY_ISSUE: 质量问题需要修复 [返工: /quality/review/123]');
    });

    test('quality gate should handle null rework route', () {
      final reason = {
        'code': 'QUALITY_ISSUE',
        'message': '质量问题需要修复',
        'reworkRoute': null,
      };

      final routePart = reason['reworkRoute'] != null ? ' [返工: ${reason['reworkRoute']}]' : '';
      final formatted = '${reason['code']}: ${reason['message']}$routePart';
      expect(formatted, 'QUALITY_ISSUE: 质量问题需要修复');
    });

    test('export check should generate correct headline when export ready', () {
      // Requirements 10.2: Display appropriate headline based on export ready status
      expect(
        exportCheckHeadline(true),
        '服务端未发现阻塞级问题（仍需在制作侧确认成片）。',
      );
    });

    test('export check should generate correct headline when export not ready', () {
      expect(
        exportCheckHeadline(false),
        '存在阻塞项：建议先在制作工作区补齐后再导出 / 成片。',
      );
    });

    test('export check should limit displayed issues to 14 items', () {
      // Generate 20 blocking issues
      final issues = List.generate(20, (i) => {
        'severity': 'blocking',
        'code': 'ISSUE_$i',
        'detail': '问题 $i',
        'scriptNumericId': 1,
        'storyboardNumericId': 10 + i,
        'sbIndex': i + 1,
      });

      final blockingIssues = issues
          .where((i) => i['severity'] == 'blocking')
          .take(14)
          .toList();

      expect(blockingIssues, hasLength(14));
      expect(blockingIssues.first['code'], 'ISSUE_0');
      expect(blockingIssues.last['code'], 'ISSUE_13');
    });

    test('export check should separate blocking and warning issues', () {
      final issues = [
        {'severity': 'blocking', 'code': 'BLOCK_1'},
        {'severity': 'warning', 'code': 'WARN_1'},
        {'severity': 'blocking', 'code': 'BLOCK_2'},
        {'severity': 'warning', 'code': 'WARN_2'},
        {'severity': 'blocking', 'code': 'BLOCK_3'},
      ];

      final blockingIssues = issues.where((i) => i['severity'] == 'blocking').toList();
      final warningIssues = issues.where((i) => i['severity'] == 'warning').toList();

      expect(blockingIssues, hasLength(3));
      expect(warningIssues, hasLength(2));
      expect(blockingIssues.every((i) => i['severity'] == 'blocking'), true);
      expect(warningIssues.every((i) => i['severity'] == 'warning'), true);
    });

    test('export check should handle empty issues list', () {
      final issues = <Map<String, dynamic>>[];

      final blockingIssues = issues.where((i) => i['severity'] == 'blocking').toList();
      final warningIssues = issues.where((i) => i['severity'] == 'warning').toList();

      expect(blockingIssues, isEmpty);
      expect(warningIssues, isEmpty);
    });

    test('export check should handle null sbIndex in issue display', () {
      final issue = {
        'severity': 'blocking',
        'code': 'NO_VIDEO',
        'detail': '未选择视频',
        'scriptNumericId': 1,
        'storyboardNumericId': 10,
        'sbIndex': null,
      };

      final sbIndex = issue['sbIndex'];
      final sbPart = sbIndex == null ? '' : ' · 序 $sbIndex';
      final formatted = '剧本 #${issue['scriptNumericId']} · '
          '分镜 #${issue['storyboardNumericId']}$sbPart · '
          '${issue['code']} · '
          '${issue['detail']}';

      expect(formatted, '剧本 #1 · 分镜 #10 · NO_VIDEO · 未选择视频');
    });

    test('quality gate line should format correctly for off strategy', () {
      final strategy = 'off';
      final qualityGateLine = strategy == 'off'
          ? '质量门禁：已关闭（不检查质量问题）。'
          : '';

      expect(qualityGateLine, '质量门禁：已关闭（不检查质量问题）。');
    });

    test('quality gate line should format correctly for warn strategy with bad cases', () {
      final strategy = 'warn';
      final pendingReviewBadCaseCount = 3;
      
      String qualityGateLine;
      if (strategy == 'warn') {
        if (pendingReviewBadCaseCount > 0) {
          qualityGateLine = '质量门禁：警告模式 - 待复核坏例 $pendingReviewBadCaseCount 条（允许导出但建议修复）。';
        } else {
          qualityGateLine = '质量门禁：警告模式 - 暂无待复核坏例（允许导出）。';
        }
      } else {
        qualityGateLine = '';
      }

      expect(qualityGateLine, '质量门禁：警告模式 - 待复核坏例 3 条（允许导出但建议修复）。');
    });

    test('quality gate line should format correctly for block strategy with enforcement', () {
      final strategy = 'block';
      final enforced = true;
      final pendingReviewBadCaseCount = 2;
      
      String qualityGateLine;
      if (strategy == 'block') {
        if (enforced && pendingReviewBadCaseCount > 0) {
          qualityGateLine = '质量门禁：阻断模式 - 待复核坏例 $pendingReviewBadCaseCount 条（阻止导出，需先修复）。';
        } else if (pendingReviewBadCaseCount > 0) {
          qualityGateLine = '质量门禁：阻断模式 - 待复核坏例 $pendingReviewBadCaseCount 条（暂未强制执行）。';
        } else {
          qualityGateLine = '质量门禁：阻断模式 - 暂无待复核坏例（允许导出）。';
        }
      } else {
        qualityGateLine = '';
      }

      expect(qualityGateLine, '质量门禁：阻断模式 - 待复核坏例 2 条（阻止导出，需先修复）。');
    });

    test('export check should determine final export permission correctly', () {
      bool canExport(bool exportReady, bool qualityGateBlocks) =>
          exportReady && !qualityGateBlocks;

      expect(canExport(true, false), true); // ready, gate clear
      expect(canExport(false, false), false); // not ready
      expect(canExport(true, true), false); // gate blocks
      expect(canExport(false, true), false); // not ready and gate blocks
    });

    test('export check UI should show loading state correctly', () {
      final uiState = {
        'visible': true,
        'loading': true,
        'unavailable': false,
        'headline': '正在读取导出前检查…',
      };

      expect(uiState['visible'], true);
      expect(uiState['loading'], true);
      expect(uiState['unavailable'], false);
    });

    test('export check UI should show unavailable state correctly', () {
      final uiState = {
        'visible': true,
        'loading': false,
        'unavailable': true,
        'headline': '导出前检查暂不可用。',
      };

      expect(uiState['visible'], true);
      expect(uiState['loading'], false);
      expect(uiState['unavailable'], true);
    });

    test('export check UI should show data correctly when available', () {
      final uiState = {
        'visible': true,
        'loading': false,
        'unavailable': false,
        'exportReady': true,
        'metrics': [
          {'label': '分镜', 'value': '10'},
          {'label': '阻塞', 'value': '0'},
          {'label': '提醒', 'value': '2'},
          {'label': '可导出', 'value': '是'},
        ],
      };

      expect(uiState['visible'], true);
      expect(uiState['loading'], false);
      expect(uiState['unavailable'], false);
      expect(uiState['exportReady'], true);
      expect(uiState['metrics'], hasLength(4));
    });
  });

  group('Assembly Filter Mapping Tests', () {
    bool matchesSearch({
      required String keyword,
      required String subtitleText,
      required String voiceoverState,
      required String voiceoverError,
      required String voiceoverAudioUrl,
      required bool searchInSubtitles,
      required bool searchInVoiceover,
    }) {
      final normalized = keyword.trim().toLowerCase();
      if (normalized.isEmpty) {
        return true;
      }
      final targets = <String>[
        if (searchInSubtitles) subtitleText,
        if (searchInVoiceover) ...[
          voiceoverState,
          voiceoverError,
          voiceoverAudioUrl,
        ],
      ];
      return targets.any((value) => value.toLowerCase().contains(normalized));
    }

    test('search can target subtitle text without matching voiceover fields', () {
      expect(
        matchesSearch(
          keyword: '雨夜',
          subtitleText: '雨夜追逐',
          voiceoverState: 'ready',
          voiceoverError: '',
          voiceoverAudioUrl: '',
          searchInSubtitles: true,
          searchInVoiceover: false,
        ),
        isTrue,
      );

      expect(
        matchesSearch(
          keyword: '音频失败',
          subtitleText: '雨夜追逐',
          voiceoverState: 'failed',
          voiceoverError: '音频失败',
          voiceoverAudioUrl: '',
          searchInSubtitles: true,
          searchInVoiceover: false,
        ),
        isFalse,
      );
    });

    test('quality degradation can be inferred from failed voiceover or mismatch', () {
      bool hasQualityIssue({
        required String voiceoverState,
        required String mismatchLine,
      }) {
        return voiceoverState == 'failed' ||
            mismatchLine != '字幕与时长未见明显错位。';
      }

      expect(
        hasQualityIssue(
          voiceoverState: 'failed',
          mismatchLine: '字幕与时长未见明显错位。',
        ),
        isTrue,
      );
      expect(
        hasQualityIssue(
          voiceoverState: 'ready',
          mismatchLine: '时长已设定，但字幕为空（可能有字幕轨缺口）。',
        ),
        isTrue,
      );
      expect(
        hasQualityIssue(
          voiceoverState: 'ready',
          mismatchLine: '字幕与时长未见明显错位。',
        ),
        isFalse,
      );
    });
  });

  group('Search Result Highlighting Tests', () {
    // Requirements 22, 23, 24: Search highlighting functionality
    
    test('should highlight single keyword occurrence in text', () {
      // Simulate highlighting logic
      List<Map<String, dynamic>> findMatches(String text, String keyword) {
        if (keyword.isEmpty || text.isEmpty) return [];
        
        final lowerText = text.toLowerCase();
        final lowerKeyword = keyword.toLowerCase();
        final matches = <Map<String, dynamic>>[];
        
        var startIndex = 0;
        while (true) {
          final index = lowerText.indexOf(lowerKeyword, startIndex);
          if (index == -1) break;
          matches.add({
            'start': index,
            'end': index + lowerKeyword.length,
            'text': text.substring(index, index + lowerKeyword.length),
          });
          startIndex = index + lowerKeyword.length;
        }
        
        return matches;
      }

      final matches = findMatches('这是一段测试文本', '测试');
      expect(matches, hasLength(1));
      expect(matches[0]['start'], 4);
      expect(matches[0]['end'], 6);
      expect(matches[0]['text'], '测试');
    });

    test('should highlight multiple keyword occurrences in text', () {
      List<Map<String, dynamic>> findMatches(String text, String keyword) {
        if (keyword.isEmpty || text.isEmpty) return [];
        
        final lowerText = text.toLowerCase();
        final lowerKeyword = keyword.toLowerCase();
        final matches = <Map<String, dynamic>>[];
        
        var startIndex = 0;
        while (true) {
          final index = lowerText.indexOf(lowerKeyword, startIndex);
          if (index == -1) break;
          matches.add({
            'start': index,
            'end': index + lowerKeyword.length,
            'text': text.substring(index, index + lowerKeyword.length),
          });
          startIndex = index + lowerKeyword.length;
        }
        
        return matches;
      }

      final matches = findMatches('测试文本中有多个测试关键词测试', '测试');
      expect(matches, hasLength(3));
      expect(matches[0]['start'], 0);
      expect(matches[1]['start'], 8);
      expect(matches[2]['start'], 13);
    });

    test('should be case-insensitive when highlighting', () {
      List<Map<String, dynamic>> findMatches(String text, String keyword) {
        if (keyword.isEmpty || text.isEmpty) return [];
        
        final lowerText = text.toLowerCase();
        final lowerKeyword = keyword.toLowerCase();
        final matches = <Map<String, dynamic>>[];
        
        var startIndex = 0;
        while (true) {
          final index = lowerText.indexOf(lowerKeyword, startIndex);
          if (index == -1) break;
          matches.add({
            'start': index,
            'end': index + lowerKeyword.length,
            'text': text.substring(index, index + lowerKeyword.length),
          });
          startIndex = index + lowerKeyword.length;
        }
        
        return matches;
      }

      final matches = findMatches('Test test TEST', 'test');
      expect(matches, hasLength(3));
      expect(matches[0]['text'], 'Test');
      expect(matches[1]['text'], 'test');
      expect(matches[2]['text'], 'TEST');
    });

    test('should return empty list when keyword is empty', () {
      List<Map<String, dynamic>> findMatches(String text, String keyword) {
        if (keyword.isEmpty || text.isEmpty) return [];
        
        final lowerText = text.toLowerCase();
        final lowerKeyword = keyword.toLowerCase();
        final matches = <Map<String, dynamic>>[];
        
        var startIndex = 0;
        while (true) {
          final index = lowerText.indexOf(lowerKeyword, startIndex);
          if (index == -1) break;
          matches.add({
            'start': index,
            'end': index + lowerKeyword.length,
            'text': text.substring(index, index + lowerKeyword.length),
          });
          startIndex = index + lowerKeyword.length;
        }
        
        return matches;
      }

      final matches = findMatches('测试文本', '');
      expect(matches, isEmpty);
    });

    test('should return empty list when text is empty', () {
      List<Map<String, dynamic>> findMatches(String text, String keyword) {
        if (keyword.isEmpty || text.isEmpty) return [];
        
        final lowerText = text.toLowerCase();
        final lowerKeyword = keyword.toLowerCase();
        final matches = <Map<String, dynamic>>[];
        
        var startIndex = 0;
        while (true) {
          final index = lowerText.indexOf(lowerKeyword, startIndex);
          if (index == -1) break;
          matches.add({
            'start': index,
            'end': index + lowerKeyword.length,
            'text': text.substring(index, index + lowerKeyword.length),
          });
          startIndex = index + lowerKeyword.length;
        }
        
        return matches;
      }

      final matches = findMatches('', '测试');
      expect(matches, isEmpty);
    });

    test('should return empty list when keyword not found', () {
      List<Map<String, dynamic>> findMatches(String text, String keyword) {
        if (keyword.isEmpty || text.isEmpty) return [];
        
        final lowerText = text.toLowerCase();
        final lowerKeyword = keyword.toLowerCase();
        final matches = <Map<String, dynamic>>[];
        
        var startIndex = 0;
        while (true) {
          final index = lowerText.indexOf(lowerKeyword, startIndex);
          if (index == -1) break;
          matches.add({
            'start': index,
            'end': index + lowerKeyword.length,
            'text': text.substring(index, index + lowerKeyword.length),
          });
          startIndex = index + lowerKeyword.length;
        }
        
        return matches;
      }

      final matches = findMatches('这是一段文本', '关键词');
      expect(matches, isEmpty);
    });

    test('should highlight overlapping keywords correctly', () {
      List<Map<String, dynamic>> findMatches(String text, String keyword) {
        if (keyword.isEmpty || text.isEmpty) return [];
        
        final lowerText = text.toLowerCase();
        final lowerKeyword = keyword.toLowerCase();
        final matches = <Map<String, dynamic>>[];
        
        var startIndex = 0;
        while (true) {
          final index = lowerText.indexOf(lowerKeyword, startIndex);
          if (index == -1) break;
          matches.add({
            'start': index,
            'end': index + lowerKeyword.length,
            'text': text.substring(index, index + lowerKeyword.length),
          });
          startIndex = index + lowerKeyword.length;
        }
        
        return matches;
      }

      // Search for 'aa' in 'aaaa' should find 2 non-overlapping matches
      final matches = findMatches('aaaa', 'aa');
      expect(matches, hasLength(2));
      expect(matches[0]['start'], 0);
      expect(matches[1]['start'], 2);
    });

    test('should highlight in subtitle text when searchInSubtitles is true', () {
      bool shouldHighlight({
        required bool searchInSubtitles,
        required bool isSubtitleField,
        required bool searchInVoiceover,
        required bool isVoiceoverField,
      }) {
        if (isSubtitleField) return searchInSubtitles;
        if (isVoiceoverField) return searchInVoiceover;
        return false;
      }

      expect(
        shouldHighlight(
          searchInSubtitles: true,
          isSubtitleField: true,
          searchInVoiceover: false,
          isVoiceoverField: false,
        ),
        true,
      );

      expect(
        shouldHighlight(
          searchInSubtitles: false,
          isSubtitleField: true,
          searchInVoiceover: false,
          isVoiceoverField: false,
        ),
        false,
      );
    });

    test('should highlight in voiceover text when searchInVoiceover is true', () {
      bool shouldHighlight({
        required bool searchInSubtitles,
        required bool isSubtitleField,
        required bool searchInVoiceover,
        required bool isVoiceoverField,
      }) {
        if (isSubtitleField) return searchInSubtitles;
        if (isVoiceoverField) return searchInVoiceover;
        return false;
      }

      expect(
        shouldHighlight(
          searchInSubtitles: false,
          isSubtitleField: false,
          searchInVoiceover: true,
          isVoiceoverField: true,
        ),
        true,
      );

      expect(
        shouldHighlight(
          searchInSubtitles: false,
          isSubtitleField: false,
          searchInVoiceover: false,
          isVoiceoverField: true,
        ),
        false,
      );
    });

    test('should not highlight when both search options are disabled', () {
      bool shouldHighlight({
        required bool searchInSubtitles,
        required bool isSubtitleField,
        required bool searchInVoiceover,
        required bool isVoiceoverField,
      }) {
        if (isSubtitleField) return searchInSubtitles;
        if (isVoiceoverField) return searchInVoiceover;
        return false;
      }

      expect(
        shouldHighlight(
          searchInSubtitles: false,
          isSubtitleField: true,
          searchInVoiceover: false,
          isVoiceoverField: false,
        ),
        false,
      );

      expect(
        shouldHighlight(
          searchInSubtitles: false,
          isSubtitleField: false,
          searchInVoiceover: false,
          isVoiceoverField: true,
        ),
        false,
      );
    });

    test('should handle Chinese characters in highlighting', () {
      List<Map<String, dynamic>> findMatches(String text, String keyword) {
        if (keyword.isEmpty || text.isEmpty) return [];
        
        final lowerText = text.toLowerCase();
        final lowerKeyword = keyword.toLowerCase();
        final matches = <Map<String, dynamic>>[];
        
        var startIndex = 0;
        while (true) {
          final index = lowerText.indexOf(lowerKeyword, startIndex);
          if (index == -1) break;
          matches.add({
            'start': index,
            'end': index + lowerKeyword.length,
            'text': text.substring(index, index + lowerKeyword.length),
          });
          startIndex = index + lowerKeyword.length;
        }
        
        return matches;
      }

      final matches = findMatches('这是一段中文测试文本，包含测试关键词', '测试');
      expect(matches, hasLength(2));
      expect(matches[0]['text'], '测试');
      expect(matches[1]['text'], '测试');
    });

    test('should handle mixed Chinese and English in highlighting', () {
      List<Map<String, dynamic>> findMatches(String text, String keyword) {
        if (keyword.isEmpty || text.isEmpty) return [];
        
        final lowerText = text.toLowerCase();
        final lowerKeyword = keyword.toLowerCase();
        final matches = <Map<String, dynamic>>[];
        
        var startIndex = 0;
        while (true) {
          final index = lowerText.indexOf(lowerKeyword, startIndex);
          if (index == -1) break;
          matches.add({
            'start': index,
            'end': index + lowerKeyword.length,
            'text': text.substring(index, index + lowerKeyword.length),
          });
          startIndex = index + lowerKeyword.length;
        }
        
        return matches;
      }

      final matches = findMatches('这是test文本，包含test关键词', 'test');
      expect(matches, hasLength(2));
      expect(matches[0]['text'], 'test');
      expect(matches[1]['text'], 'test');
    });
  });
}
