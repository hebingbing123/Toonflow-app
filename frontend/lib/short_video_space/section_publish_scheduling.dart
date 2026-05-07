// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of 'section.dart';

/// Extension containing publish scheduling operations for ShortVideoSpaceSection.
/// Includes draft scheduling, calendar operations, and time picking.
extension ShortVideoPublishScheduling on _ShortVideoSpaceSectionState {
  Future<DateTime?> _pickScheduleDateTime(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: today.subtract(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (!context.mounted) {
      return null;
    }
    if (pickedDate == null) {
      return null;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!context.mounted || pickedTime == null) {
      return null;
    }
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _scheduleFirstDraft(
    BuildContext context,
    ProjectRow project,
    String token,
  ) async {
    if (_publishDrafts.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final draftId = _activePublishDraft?.id;
    if (draftId == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('请先明确选择要定时的草稿。'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final dt = await _pickScheduleDateTime(context);
    if (dt == null || !context.mounted) {
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final iso = dt.toUtc().toIso8601String();
      await patchPublishDraft(token, project.id, draftId, <String, dynamic>{
        'scheduled_at': iso,
      });
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        SnackBar(content: Text('已设为定时：$iso（UTC）')),
      );
    } on RustApiException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('定时失败：${e.statusCode}')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('定时失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _scheduleAllDraftsSameTime(
    BuildContext context,
    ProjectRow project,
    String token,
  ) async {
    if (_publishDrafts.length < 2) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final dt = await _pickScheduleDateTime(context);
    if (dt == null || !context.mounted) {
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final iso = dt.toUtc().toIso8601String();
      final ids = _publishDrafts.map((d) => d.id).toList(growable: false);
      final res = await batchSchedulePublishDrafts(
        token,
        project.id,
        draftIds: ids,
        scheduledAtIso: iso,
      );
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        SnackBar(content: Text('已批量定时 ${res.updated} 张草稿：$iso（UTC）')),
      );
    } on RustApiException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('批量定时失败：${e.statusCode}')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('批量定时失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<DateTime?> _pickScheduleTimeForDay(
    BuildContext context,
    DateTime dayLocal,
  ) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (!context.mounted || pickedTime == null) {
      return null;
    }
    return DateTime(
      dayLocal.year,
      dayLocal.month,
      dayLocal.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _bulkScheduleDraftsForCalendarDay(
    BuildContext context,
    ProjectRow project,
    String token,
    DateTime dayLocal,
  ) async {
    if (_publishDrafts.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    var overrideExisting = false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final dayLabel =
                '${dayLocal.year}-${dayLocal.month.toString().padLeft(2, '0')}-${dayLocal.day.toString().padLeft(2, '0')}';
            return AlertDialog(
              title: Text('批量定时 · $dayLabel'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: overrideExisting,
                    onChanged: (v) {
                      setLocal(() {
                        overrideExisting = v ?? false;
                      });
                    },
                    title: const Text('包含已定时草稿并重写为该时刻'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    overrideExisting
                        ? '将对当前列表中的全部草稿写入同一发布时间。'
                        : '仅对尚未填写定时的草稿写入发布时间。',
                    style: Theme.of(dialogCtx).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('选择时间'),
                ),
              ],
            );
          },
        );
      },
    );
    if (proceed != true || !context.mounted) {
      return;
    }
    final dt = await _pickScheduleTimeForDay(context, dayLocal);
    if (dt == null || !context.mounted) {
      return;
    }
    final ids = _publishDrafts
        .where(
          (d) =>
              overrideExisting || (d.scheduledAt ?? '').trim().isEmpty,
        )
        .map((d) => d.id)
        .toList(growable: false);
    if (ids.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('没有符合条件的草稿（试勾选「包含已定时」）。')),
      );
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final iso = dt.toUtc().toIso8601String();
      final res = await batchSchedulePublishDrafts(
        token,
        project.id,
        draftIds: ids,
        scheduledAtIso: iso,
      );
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        SnackBar(content: Text('已更新 ${res.updated} 张草稿定时：$iso（UTC）')),
      );
    } on RustApiException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('日历批量定时失败：${e.statusCode}')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('日历批量定时失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _clearPublishSchedule() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_publishDrafts.isEmpty) {
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final ids = _publishDrafts.map((d) => d.id).toList(growable: false);
      final res = await batchSchedulePublishDrafts(
        token,
        project.id,
        draftIds: ids,
        scheduledAtIso: null,
      );
      await _refreshPublishSlice(project, token);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新 ${res.updated} 张草稿的定时字段（可为 worker 放行）。')),
      );
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除定时失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除定时失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }
}
