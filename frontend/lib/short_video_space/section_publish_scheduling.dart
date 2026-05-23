// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of 'section.dart';

/// Publish scheduling: draft scheduling, calendar, time picking.
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
    final l10n = resolveAppLocalizationsForErrors(context);
    if (_publishDrafts.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final draftId = _activePublishDraft?.id;
    if (draftId == null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.shortVideoPublishScheduleSelectDraftFirst),
          duration: const Duration(seconds: 4),
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
        SnackBar(content: Text(l10n.shortVideoPublishScheduleSingleSet(iso))),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishScheduleSingleFailed(describeUserVisibleApiErrorResolved(context, e)))),
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
        SnackBar(content: Text(l10n.shortVideoPublishBatchScheduledCount(res.updated, iso))),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishBatchScheduleFailed(describeUserVisibleApiErrorResolved(context, e)))),
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
    final proceed = await showStudioDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final dlgL10n = resolveAppLocalizationsForErrors(ctx);
            final dayLabel =
                '${dayLocal.year}-${dayLocal.month.toString().padLeft(2, '0')}-${dayLocal.day.toString().padLeft(2, '0')}';
            return StudioAlertDialog(
              title: Text(dlgL10n.shortVideoPublishScheduleCalendarTitle(dayLabel)),
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
                    title: Text(dlgL10n.shortVideoPublishScheduleCalendarIncludeScheduled),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  Text(
                    overrideExisting
                        ? dlgL10n.shortVideoPublishScheduleCalendarHintOverrideAll
                        : dlgL10n.shortVideoPublishScheduleCalendarHintNewOnly,
                    style: Theme.of(dialogCtx).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(dlgL10n.notificationsActionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: Text(dlgL10n.shortVideoPublishScheduleCalendarChooseTime),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final ids = _publishDrafts
        .where(
          (d) =>
              overrideExisting || (d.scheduledAt ?? '').trim().isEmpty,
        )
        .map((d) => d.id)
        .toList(growable: false);
    if (ids.isEmpty) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishScheduleCalendarNoDrafts)),
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
        SnackBar(content: Text(l10n.shortVideoPublishScheduleCalendarUpdated(res.updated, iso))),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishScheduleCalendarFailed(describeUserVisibleApiErrorResolved(context, e)))),
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
        SnackBar(content: Text(l10n.shortVideoPublishScheduleClearUpdated(res.updated))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shortVideoPublishScheduleClearFailed(describeUserVisibleApiErrorResolved(context, e)))),
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
