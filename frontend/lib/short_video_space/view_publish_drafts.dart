part of 'view.dart';

/// Draft list and management widget
class _PublishDraftsPanel extends StatelessWidget {
  const _PublishDraftsPanel({
    required this.publishPanelUi,
  });

  final ShortVideoPublishPanelUi publishPanelUi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    
    if (!publishPanelUi.visible) {
      return const SizedBox.shrink();
    }
    
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('发布准备', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (publishPanelUi.exportGateHint.trim().isNotEmpty) ...[
            Text(
              publishPanelUi.exportGateHint,
              style: theme.textTheme.bodySmall?.copyWith(color: outline),
            ),
            const SizedBox(height: 8),
          ],
          if (publishPanelUi.loading)
            Text(
              publishPanelUi.headline,
              style: theme.textTheme.bodyMedium?.copyWith(color: outline),
            )
          else if (publishPanelUi.unavailable)
            Text(
              publishPanelUi.headline,
              style: theme.textTheme.bodyMedium?.copyWith(color: outline),
            )
          else ...[
            Text(
              publishPanelUi.headline,
              style: theme.textTheme.bodyMedium?.copyWith(color: outline),
            ),
            if (publishPanelUi.matrixDomesticLines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '国内平台矩阵（占位约束）',
                style: theme.textTheme.labelSmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 6),
              for (final line in publishPanelUi.matrixDomesticLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (publishPanelUi.matrixOverseasLines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '海外平台矩阵（占位约束）',
                style: theme.textTheme.labelSmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 6),
              for (final line in publishPanelUi.matrixOverseasLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (publishPanelUi.prepareLines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '发布准备校验',
                style: theme.textTheme.labelSmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 6),
              for (final line in publishPanelUi.prepareLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (publishPanelUi.draftLines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '发布单（草稿）',
                    style: theme.textTheme.labelSmall?.copyWith(color: outline),
                  ),
                  const Spacer(),
                  // P8: Multi-select toggle
                  if (publishPanelUi.onToggleMultiSelectMode != null)
                    TextButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onToggleMultiSelectMode,
                      icon: Icon(
                        publishPanelUi.multiSelectMode
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 18,
                      ),
                      label: Text(
                        publishPanelUi.multiSelectMode ? '退出多选' : '多选模式',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // P8: Multi-select toolbar
              if (publishPanelUi.multiSelectMode) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '已选择 ${publishPanelUi.selectedDraftIds.length} 张草稿',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onSelectAllDrafts,
                            child: const Text('全选'),
                          ),
                          TextButton(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onClearDraftSelection,
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                      if (publishPanelUi.selectedDraftIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (publishPanelUi.onBatchScheduleDrafts != null)
                              FilledButton.tonalIcon(
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : () => publishPanelUi.onBatchScheduleDrafts?.call(context),
                                icon: const Icon(Icons.schedule, size: 18),
                                label: const Text('批量定时'),
                              ),
                            if (publishPanelUi.onBatchPublishDrafts != null)
                              FilledButton.icon(
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : publishPanelUi.onBatchPublishDrafts,
                                icon: const Icon(Icons.publish, size: 18),
                                label: const Text('批量发布'),
                              ),
                            if (publishPanelUi.onBatchArchiveDrafts != null)
                              OutlinedButton.icon(
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : publishPanelUi.onBatchArchiveDrafts,
                                icon: const Icon(Icons.archive, size: 18),
                                label: const Text('批量归档'),
                              ),
                            if (publishPanelUi.onCompareDrafts != null)
                              OutlinedButton.icon(
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : publishPanelUi.onCompareDrafts,
                                icon: const Icon(Icons.compare, size: 18),
                                label: const Text('对比草稿'),
                              ),
                          ],
                        ),
                      ],
                      // P8: Batch validation summary
                      if (publishPanelUi.batchValidation != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '批量验证结果',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '就绪：${publishPanelUi.batchValidation!.readyCount} 张 · '
                                '阻塞：${publishPanelUi.batchValidation!.blockedCount} 张',
                                style: theme.textTheme.bodySmall,
                              ),
                              if (publishPanelUi.batchValidation!.blockedDrafts.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                ...publishPanelUi.batchValidation!.blockedDrafts.take(3).map(
                                  (d) => Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${d.title.isEmpty ? d.draftId.substring(0, 8) : d.title}: '
                                      '${d.blockingReasons.map((r) => r.message).join(", ")}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // P8: Draft list with checkboxes
              for (var i = 0; i < publishPanelUi.publishDraftOptions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: publishPanelUi.multiSelectMode
                      ? CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: publishPanelUi.selectedDraftIds.contains(
                            publishPanelUi.publishDraftOptions[i].id,
                          ),
                          onChanged: publishPanelUi.publishBusy
                              ? null
                              : (checked) {
                                  publishPanelUi.onToggleDraftSelection?.call(
                                    publishPanelUi.publishDraftOptions[i].id,
                                  );
                                },
                          title: Text(
                            publishPanelUi.draftLines[i],
                            style: theme.textTheme.bodySmall,
                          ),
                        )
                      : Text(
                          publishPanelUi.draftLines[i],
                          style: theme.textTheme.bodySmall,
                        ),
                ),
            ],
            if (publishPanelUi.publishDraftOptions.length > 1 &&
                publishPanelUi.onSelectPublishDraft != null) ...[
              const SizedBox(height: 10),
              Text(
                '当前操作草稿',
                style: theme.textTheme.labelSmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: publishPanelUi.selectedPublishDraftId,
                isExpanded: true,
                hint: publishPanelUi.selectedPublishDraftId == null ||
                        publishPanelUi.selectedPublishDraftId!.trim().isEmpty
                    ? const Text('请选择要操作的草稿')
                    : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: publishPanelUi.publishDraftOptions.map((d) {
                  final title = d.title.trim().isEmpty ? '（无标题）' : d.title.trim();
                  return DropdownMenuItem<String>(
                    value: d.id,
                    child: Text('$title · ${d.draftStatus}'),
                  );
                }).toList(growable: false),
                onChanged: publishPanelUi.publishBusy
                    ? null
                    : (v) {
                        if (v == null || v.trim().isEmpty) {
                          return;
                        }
                        publishPanelUi.onSelectPublishDraft?.call(v);
                      },
              ),
            ],
            if (!publishPanelUi.loading &&
                !publishPanelUi.unavailable &&
                publishPanelUi.publishPrimaryDraftId.isNotEmpty &&
                (publishPanelUi.publishDomesticTargetIds.isNotEmpty ||
                    publishPanelUi.publishOverseasTargetIds.isNotEmpty)) ...[
              const SizedBox(height: 12),
              PublishPlatformCopyEditor(
                key: ValueKey(
                  '${publishPanelUi.publishPrimaryDraftId}_${publishPanelUi.publishCopyEditorRevision}',
                ),
                draftId: publishPanelUi.publishPrimaryDraftId,
                domesticPlatformIds: publishPanelUi.publishDomesticTargetIds,
                overseasPlatformIds: publishPanelUi.publishOverseasTargetIds,
                platformLabels: publishPanelUi.publishPlatformLabels,
                platformCopy: publishPanelUi.publishPlatformCopySnapshot,
                busy: publishPanelUi.publishBusy,
                onCommit: publishPanelUi.onCommitPublishPlatformCopy,
              ),
            ],
            if (publishPanelUi.awaitingSemiAutoJobId != null &&
                publishPanelUi.onConfirmSemiAuto != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: publishPanelUi.publishBusy
                    ? null
                    : publishPanelUi.onConfirmSemiAuto,
                icon: publishPanelUi.publishBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: const Text('确认半自动发布（服务端闸门）'),
              ),
            ],
            if (publishPanelUi.publishAutomationModesByPlatform.isNotEmpty &&
                publishPanelUi.onChangePublishAutomationMode != null) ...[
              const SizedBox(height: 12),
              Text(
                '自动化模式（按平台）',
                style: theme.textTheme.labelSmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 6),
              for (final entry
                  in publishPanelUi.publishAutomationModesByPlatform.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          publishPanelUi.publishPlatformLabels[entry.key] ??
                              entry.key,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: entry.value,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'full_auto',
                              child: Text('full_auto'),
                            ),
                            DropdownMenuItem(
                              value: 'semi_auto',
                              child: Text('semi_auto'),
                            ),
                            DropdownMenuItem(
                              value: 'manual_assisted',
                              child: Text('manual_assisted'),
                            ),
                          ],
                          onChanged: publishPanelUi.publishBusy
                              ? null
                              : (next) {
                                  if (next == null || next == entry.value) {
                                    return;
                                  }
                                  publishPanelUi.onChangePublishAutomationMode
                                      ?.call(entry.key, next);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (publishPanelUi.onBootstrapPublishDraft != null ||
                publishPanelUi.onEnqueuePublishJob != null ||
                publishPanelUi.onEnqueueAllDrafts != null ||
                publishPanelUi.onRetryFailedPublishJobs != null ||
                publishPanelUi.onRefreshPublish != null ||
                publishPanelUi.onSuggestPublishCopy != null ||
                publishPanelUi.onClearPublishSchedule != null ||
                publishPanelUi.onScheduleFirstDraft != null ||
                publishPanelUi.onScheduleAllDraftsSameTime != null ||
                publishPanelUi.onOpenPublishTroubleshooting != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (publishPanelUi.onRefreshPublish != null)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onRefreshPublish,
                      icon: const Icon(Icons.refresh),
                      label: const Text('刷新发布数据'),
                    ),
                  if (publishPanelUi.onBootstrapPublishDraft != null)
                    FilledButton.tonalIcon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onBootstrapPublishDraft,
                      icon: publishPanelUi.publishBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.note_add_outlined),
                      label: const Text('创建发布草稿并写入平台目标'),
                    ),
                  if (publishPanelUi.onEnqueuePublishJob != null)
                    FilledButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onEnqueuePublishJob,
                      icon: publishPanelUi.publishBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: const Text('投递发布作业'),
                    ),
                  if (publishPanelUi.onEnqueueAllDrafts != null)
                    FilledButton.tonal(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onEnqueueAllDrafts,
                      child: const Text('批量投递全部草稿'),
                    ),
                  if (publishPanelUi.onRetryFailedPublishJobs != null)
                    FilledButton.tonal(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onRetryFailedPublishJobs,
                      child: const Text('批量重试失败作业'),
                    ),
                  if (publishPanelUi.onSuggestPublishCopy != null)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onSuggestPublishCopy,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('生成差异化文案'),
                    ),
                  if (publishPanelUi.onClearPublishSchedule != null)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onClearPublishSchedule,
                      icon: const Icon(Icons.schedule_outlined),
                      label: const Text('清除定时（允许入队）'),
                    ),
                  if (publishPanelUi.onScheduleFirstDraft != null &&
                      publishPanelUi.publishPrimaryDraftId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : () => publishPanelUi.onScheduleFirstDraft?.call(context),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('定时当前草稿…'),
                    ),
                  if (publishPanelUi.onScheduleAllDraftsSameTime != null &&
                      publishPanelUi.draftLines.length > 1)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : () => publishPanelUi.onScheduleAllDraftsSameTime?.call(context),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('批量定时全部草稿…'),
                    ),
                  if (publishPanelUi.onOpenPublishTroubleshooting != null)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onOpenPublishTroubleshooting,
                      icon: const Icon(Icons.bug_report_outlined),
                      label: const Text('打开发布排障入口'),
                    ),
                ],
              ),
            ],
            if (publishPanelUi.publishBatchResultLines.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '批量结果摘要',
                style: theme.textTheme.labelSmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 6),
              ...publishPanelUi.publishBatchResultLines.take(8).map(
                    (line) => Text(
                      '• $line',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
            ],
          ],
          const SizedBox(height: 8),
          Text(
            publishPanelUi.detail,
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
        ],
      ),
    );
  }
}
