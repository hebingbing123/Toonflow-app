// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

/// Batch operations for ShortVideoSpaceSection
extension _ShortVideoSpaceSectionProductionBatchOperationsExtension on _ShortVideoSpaceSectionState {
  /// Batch enable selected shots
  Future<void> _batchEnableShots({
    required Set<int> selectedStoryboardIds,
    required List<_AssemblyClipDeskOpEntry> allEntries,
    required int projectId,
    required int scriptId,
    required String token,
    required Function(String message, {required bool isSuccess}) showFeedback,
    required Future<void> Function() refreshData,
  }) async {
    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要启用的镜头', isSuccess: false);
      return;
    }

    // Build operations list - only include shots that have video URLs
    final operations = <Map<String, dynamic>>[];
    for (final storyboardId in selectedStoryboardIds) {
      final entry = allEntries.firstWhere(
        (e) => e.storyboardNumericId == storyboardId,
        orElse: () => throw Exception('Shot not found: $storyboardId'),
      );
      
      if (entry.selectedMediaUrl.trim().isEmpty) {
        // Skip shots without video URLs
        continue;
      }
      
      operations.add({
        'storyboardId': storyboardId,
        'videoUrl': entry.selectedMediaUrl,
      });
    }

    if (operations.isEmpty) {
      showFeedback('所选镜头都没有可用的视频 URL', isSuccess: false);
      return;
    }

    try {
      final response = await postProductionWorkbenchBatchSelectVideoV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        operations: operations,
      );

      showFeedback(
        '批量启用完成：成功 ${response.success} 个，失败 ${response.failed} 个',
        isSuccess: response.failed == 0,
      );

      await refreshData();
    } on RustApiException catch (e) {
      showFeedback(
        '批量启用失败：${e.statusCode ?? '-'}',
        isSuccess: false,
      );
    } catch (e) {
      showFeedback(
        '批量启用失败：$e',
        isSuccess: false,
      );
    }
  }

  /// Batch disable selected shots
  Future<void> _batchDisableShots({
    required Set<int> selectedStoryboardIds,
    required int projectId,
    required int scriptId,
    required String token,
    required Function(String message, {required bool isSuccess}) showFeedback,
    required Future<void> Function() refreshData,
  }) async {
    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要禁用的镜头', isSuccess: false);
      return;
    }

    try {
      final response = await postProductionWorkbenchBatchDeleteVideoV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        storyboardIds: selectedStoryboardIds.toList(),
      );

      showFeedback(
        '批量禁用完成：成功 ${response.success} 个，失败 ${response.failed} 个',
        isSuccess: response.failed == 0,
      );

      await refreshData();
    } on RustApiException catch (e) {
      showFeedback(
        '批量禁用失败：${e.statusCode ?? '-'}',
        isSuccess: false,
      );
    } catch (e) {
      showFeedback(
        '批量禁用失败：$e',
        isSuccess: false,
      );
    }
  }

  /// Batch update duration for selected shots
  Future<void> _batchUpdateDuration({
    required Set<int> selectedStoryboardIds,
    required int projectId,
    required int scriptId,
    required String token,
    required BuildContext context,
    required Function(String message, {required bool isSuccess}) showFeedback,
    required Future<void> Function() refreshData,
  }) async {
    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要对齐时长的镜头', isSuccess: false);
      return;
    }

    // Prompt for duration
    final ctrl = TextEditingController();
    final duration = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量时长对齐'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '时长（秒）',
            hintText: '输入 1~300',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final sec = int.tryParse(ctrl.text.trim());
              Navigator.of(ctx).pop(sec);
            },
            child: const Text('对齐并写回'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (duration == null || duration <= 0 || duration > 300) {
      return;
    }

    // Build operations list
    final operations = selectedStoryboardIds
        .map((id) => {
              'storyboardId': id,
              'duration': duration,
            })
        .toList();

    try {
      final response = await postProductionWorkbenchBatchUpdateDurationV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        operations: operations,
      );

      showFeedback(
        '批量时长对齐完成：成功 ${response.success} 个，失败 ${response.failed} 个',
        isSuccess: response.failed == 0,
      );

      await refreshData();
    } on RustApiException catch (e) {
      showFeedback(
        '批量时长对齐失败：${e.statusCode ?? '-'}',
        isSuccess: false,
      );
    } catch (e) {
      showFeedback(
        '批量时长对齐失败：$e',
        isSuccess: false,
      );
    }
  }

  /// Batch replace videos for selected shots
  Future<void> _batchReplaceVideos({
    required Set<int> selectedStoryboardIds,
    required List<_AssemblyClipDeskOpEntry> allEntries,
    required int projectId,
    required int scriptId,
    required String token,
    required BuildContext context,
    required Function(String message, {required bool isSuccess}) showFeedback,
    required Future<void> Function() refreshData,
  }) async {
    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要替换的镜头', isSuccess: false);
      return;
    }

    // Prompt for replacement pattern
    final patternCtrl = TextEditingController();
    final replacementCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量替换视频 URL'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: patternCtrl,
                decoration: const InputDecoration(
                  labelText: '查找模式（支持正则表达式）',
                  hintText: '例如：/v1/',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replacementCtrl,
                decoration: const InputDecoration(
                  labelText: '替换为',
                  hintText: '例如：/v2/',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '将对所选镜头的视频 URL 执行查找替换操作',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop({
                'pattern': patternCtrl.text.trim(),
                'replacement': replacementCtrl.text.trim(),
              });
            },
            child: const Text('执行替换'),
          ),
        ],
      ),
    );
    patternCtrl.dispose();
    replacementCtrl.dispose();

    if (result == null || result['pattern']!.isEmpty) {
      return;
    }

    final pattern = result['pattern']!;
    final replacement = result['replacement']!;

    // Build operations list
    final operations = <Map<String, dynamic>>[];
    for (final storyboardId in selectedStoryboardIds) {
      final entry = allEntries.firstWhere(
        (e) => e.storyboardNumericId == storyboardId,
        orElse: () => throw Exception('Shot not found: $storyboardId'),
      );

      if (entry.selectedMediaUrl.trim().isEmpty) {
        continue;
      }

      // Apply replacement
      String newUrl;
      try {
        final regex = RegExp(pattern);
        newUrl = entry.selectedMediaUrl.replaceAll(regex, replacement);
      } catch (e) {
        // If regex fails, try simple string replacement
        newUrl = entry.selectedMediaUrl.replaceAll(pattern, replacement);
      }

      if (newUrl != entry.selectedMediaUrl) {
        operations.add({
          'storyboardId': storyboardId,
          'videoUrl': newUrl,
        });
      }
    }

    if (operations.isEmpty) {
      showFeedback('没有镜头需要替换（未匹配到模式）', isSuccess: false);
      return;
    }

    try {
      final response = await postProductionWorkbenchBatchSelectVideoV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        operations: operations,
      );

      showFeedback(
        '批量替换完成：成功 ${response.success} 个，失败 ${response.failed} 个',
        isSuccess: response.failed == 0,
      );

      await refreshData();
    } on RustApiException catch (e) {
      showFeedback(
        '批量替换失败：${e.statusCode ?? '-'}',
        isSuccess: false,
      );
    } catch (e) {
      showFeedback(
        '批量替换失败：$e',
        isSuccess: false,
      );
    }
  }

  /// Batch generate voiceover for selected shots
  Future<void> _batchGenerateVoiceover({
    required Set<int> selectedStoryboardIds,
    required List<_AssemblyClipDeskOpEntry> allEntries,
    required BuildContext context,
    required Function(String message, {required bool isSuccess}) showFeedback,
  }) async {
    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要生成配音的镜头', isSuccess: false);
      return;
    }

    // Filter shots that have voiceover script ready
    final eligibleShots = allEntries
        .where((e) =>
            selectedStoryboardIds.contains(e.storyboardNumericId) &&
            e.voiceoverScriptReady)
        .toList();

    if (eligibleShots.isEmpty) {
      showFeedback('所选镜头都没有可用的配音文本', isSuccess: false);
      return;
    }

    showFeedback(
      '批量配音生成功能即将推出（已选择 ${eligibleShots.length} 个有配音文本的镜头）',
      isSuccess: true,
    );

    // TODO: Implement TTS batch generation when backend API is ready
    // This will call the TTS service for each selected shot
  }
}
