// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of 'section.dart';

/// P8 multi-select and batch: scheduling, publishing, archiving, comparison.
extension ShortVideoPublishBatch on _ShortVideoSpaceSectionState {
  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) {
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      }
    });
  }

  void _toggleDraftSelection(String draftId) {
    setState(() {
      final next = Set<String>.from(_selectedDraftIds);
      if (next.contains(draftId)) {
        next.remove(draftId);
      } else {
        next.add(draftId);
      }
      _selectedDraftIds = next;
      _batchValidation = null;
    });
  }

  void _selectAllDrafts() {
    setState(() {
      _selectedDraftIds = _publishDrafts.map((d) => d.id).toSet();
      _batchValidation = null;
    });
  }

  void _clearDraftSelection() {
    setState(() {
      _selectedDraftIds = <String>{};
      _batchValidation = null;
    });
  }

  Future<void> _batchScheduleDrafts(BuildContext context) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_selectedDraftIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishBatchSelectDraftsToSchedule)),
      );
      return;
    }

    // Validate first
    setState(() {
      _publishBusy = true;
    });
    try {
      final validation = await batchValidatePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
      );

      if (!context.mounted) {
        return;
      }

      if (validation.blockedCount > 0) {
        final proceed = await showStudioDialog<bool>(
          context: context,
          builder: (ctx) {
            final dlgL10n = resolveAppLocalizationsForErrors(ctx);
            return StudioAlertDialog(
              title: Text(dlgL10n.shortVideoPublishBatchScheduleValidateTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dlgL10n.shortVideoPublishBatchReadyDraftsCount(validation.readyCount)),
                  Text(dlgL10n.shortVideoPublishBatchBlockedDraftsCount(validation.blockedCount)),
                  const SizedBox(height: 16),
                  Text(dlgL10n.shortVideoPublishBatchBlockedReasonsLabel),
                  ...validation.blockedDrafts.take(5).map((d) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text(
                          '${d.title.isEmpty ? d.draftId.substring(0, 8) : d.title}: ${d.blockingReasons.map((r) => r.message).join(", ")}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(dlgL10n.notificationsActionCancel),
                ),
                FilledButton(
                  style: studioFormPrimaryButtonStyle(ctx),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(dlgL10n.shortVideoPublishBatchContinueScheduleReady),
                ),
              ],
            );
          },
        );

        if (proceed != true || !context.mounted) {
          return;
        }
      }

      final dt = await _pickScheduleDateTime(context);
      if (dt == null || !context.mounted) {
        return;
      }

      final iso = dt.toUtc().toIso8601String();
      final res = await batchSchedulePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
        scheduledAtIso: iso,
      );

      await _refreshPublishSlice(project, token);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishBatchScheduledCount(res.updated, iso))),
      );

      setState(() {
        _multiSelectMode = false;
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shortVideoPublishBatchScheduleFailed(describeUserVisibleApiErrorResolved(context, e)))),
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

  Future<void> _batchPublishDrafts() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_selectedDraftIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishBatchSelectDraftsToPublish)),
      );
      return;
    }

    setState(() {
      _publishBusy = true;
    });
    try {
      // Validate first
      final validation = await batchValidatePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
      );

      setState(() {
        _batchValidation = validation;
      });

      if (!mounted) {
        return;
      }

      if (validation.blockedCount > 0) {
        final proceed = await showStudioDialog<bool>(
          context: context,
          builder: (ctx) {
            final dlgL10n = resolveAppLocalizationsForErrors(ctx);
            return StudioAlertDialog(
              title: Text(dlgL10n.shortVideoPublishBatchPublishValidateTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dlgL10n.shortVideoPublishBatchReadyDraftsCount(validation.readyCount)),
                  Text(dlgL10n.shortVideoPublishBatchBlockedDraftsCount(validation.blockedCount)),
                  const SizedBox(height: 16),
                  Text(dlgL10n.shortVideoPublishBatchBlockedReasonsLabel),
                  ...validation.blockedDrafts.take(5).map((d) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text(
                          '${d.title.isEmpty ? d.draftId.substring(0, 8) : d.title}: ${d.blockingReasons.map((r) => r.message).join(", ")}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(dlgL10n.notificationsActionCancel),
                ),
                FilledButton(
                  style: studioFormPrimaryButtonStyle(ctx),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(dlgL10n.shortVideoPublishBatchContinuePublishReady),
                ),
              ],
            );
          },
        );

        if (proceed != true || !mounted) {
          return;
        }
      }

      final res = await batchPublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
        immediate: true,
      );

      await _refreshPublishSlice(project, token);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishBatchPublishDone(res.successCount, res.failedCount))),
      );

      setState(() {
        _multiSelectMode = false;
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shortVideoPublishBatchPublishFailed(describeUserVisibleApiErrorResolved(context, e)))),
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

  Future<void> _batchArchiveDrafts() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_selectedDraftIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishBatchSelectDraftsToArchive)),
      );
      return;
    }

    final proceed = await showBatchArchivePublishConfirmation(
      context,
      draftCount: _selectedDraftIds.length,
      showDontShowAgain: true,
    );

    if (proceed != true || !mounted) {
      return;
    }

    setState(() {
      _publishBusy = true;
    });
    try {
      final res = await batchArchivePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
      );

      await _refreshPublishSlice(project, token);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishBatchArchivedCount(res.archivedCount))),
      );

      setState(() {
        _multiSelectMode = false;
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shortVideoPublishBatchArchiveFailed(describeUserVisibleApiErrorResolved(context, e)))),
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

  void _compareDrafts() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (_selectedDraftIds.length < 2 || _selectedDraftIds.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishBatchCompareSelectCount)),
      );
      return;
    }

    final order = _selectedDraftIds.toList();
    final selected = <PublishDraftRow>[];
    for (final id in order) {
      for (final d in _publishDrafts) {
        if (d.id == id) {
          selected.add(d);
          break;
        }
      }
    }
    if (selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishBatchCompareStaleSelection)),
      );
      return;
    }

    unawaited(showPublishDraftCompareDialog(context, drafts: selected));
  }

  // P11: Delivery mode handlers
  void _onDeliveryModeFilterChanged(String mode) {
    setState(() {
      _deliveryModeFilter = mode == _deliveryModeFilter ? null : mode;
    });
  }
}
