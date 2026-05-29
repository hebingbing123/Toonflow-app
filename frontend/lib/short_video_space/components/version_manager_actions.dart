part of 'version_manager.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _VersionManagerStateActions on _VersionManagerState {
  /// 显示创建版本对话框
  Future<void> _showCreateVersionDialog() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final result = await showStudioDialog<String>(
      context: context,
      builder: (context) {
        var draftName = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => StudioAlertDialog(
            title: Text(l10n.shortVideoVersionManagerCreateVersionDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.shortVideoVersionManagerCreateVersionDialogBody),
                  const SizedBox(height: StudioSpacing.sm),
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.shortVideoVersionManagerVersionNameLabel,
                      hintText: l10n.shortVideoVersionManagerVersionNameHint,
                      border: const OutlineInputBorder(),
                    ),
                    autofocus: true,
                    maxLength: 50,
                    onChanged: (value) {
                      setDialogState(() {
                        draftName = value;
                      });
                    },
                    onSubmitted: (value) {
                      final name = value.trim();
                      if (name.isNotEmpty) {
                        Navigator.of(dialogContext).pop(name);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.notificationsActionCancel),
              ),
              FilledButton(
                style: studioFormPrimaryButtonStyle(dialogContext),
                onPressed: () {
                  final name = draftName.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(dialogContext).pop(name);
                  }
                },
                child: Text(l10n.shortVideoVersionManagerCreateAction),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _handleCreateVersion(result);
    }
  }

  /// 处理创建版本
  Future<void> _handleCreateVersion(String name) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onCreateVersion(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolveAppLocalizationsForErrors(
                context,
              ).shortVideoVersionManagerSnackbarVersionCreated(name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorVersionCreate(
            describeUserVisibleApiErrorResolved(context, e),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 处理切换版本
  Future<void> _handleSwitchVersion(String versionId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSwitchVersion(versionId);
      if (mounted) {
        final version = widget.versions.firstWhere((v) => v.id == versionId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolveAppLocalizationsForErrors(
                context,
              ).shortVideoVersionManagerSnackbarVersionSwitched(version.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorVersionSwitch(
            describeUserVisibleApiErrorResolved(context, e),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 处理删除版本
  Future<void> _handleDeleteVersion(AssemblyVersion version) async {
    // 显示确认对话框
    final confirmed = await showDeleteVersionConfirmation(
      context,
      versionName: version.name,
      showDontShowAgain: true,
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onDeleteVersion(version.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolveAppLocalizationsForErrors(
                context,
              ).shortVideoVersionManagerSnackbarVersionDeleted(version.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorVersionDelete(
            describeUserVisibleApiErrorResolved(context, e),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  /// 显示保存草稿对话框
  Future<void> _showSaveDraftDialog() async {
    // 检查草稿数量限制
    if (widget.drafts.length >= 10) {
      if (mounted) {
        final l10n = resolveAppLocalizationsForErrors(context);
        showStudioDialog<void>(
          context: context,
          builder: (context) {
            return StudioAlertDialog(
              title: Text(l10n.shortVideoVersionManagerDraftLimitTitle),
              content: Text(l10n.shortVideoVersionManagerDraftLimitBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.shortVideoVersionManagerGotIt),
                ),
                FilledButton(
                  style: studioFormPrimaryButtonStyle(context),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDraftsDialog();
                  },
                  child: Text(l10n.shortVideoVersionManagerViewDraftsList),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    final l10n = resolveAppLocalizationsForErrors(context);
    final result = await showStudioDialog<String>(
      context: context,
      builder: (context) {
        var draftName = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => StudioAlertDialog(
            title: Text(l10n.shortVideoVersionManagerSaveDraftDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.shortVideoVersionManagerSaveDraftDialogBody),
                  const SizedBox(height: StudioSpacing.sm),
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.shortVideoVersionManagerDraftNameLabel,
                      hintText: l10n.shortVideoVersionManagerDraftNameHint,
                      border: const OutlineInputBorder(),
                    ),
                    autofocus: true,
                    maxLength: 50,
                    onChanged: (value) {
                      setDialogState(() {
                        draftName = value;
                      });
                    },
                    onSubmitted: (value) {
                      final name = value.trim();
                      if (name.isNotEmpty) {
                        Navigator.of(dialogContext).pop(name);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.notificationsActionCancel),
              ),
              FilledButton(
                style: studioFormPrimaryButtonStyle(dialogContext),
                onPressed: () {
                  final name = draftName.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(dialogContext).pop(name);
                  }
                },
                child: Text(l10n.notificationsActionSave),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _handleSaveDraft(result);
    }
  }

  /// 处理保存草稿
  Future<void> _handleSaveDraft(String name) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSaveDraft(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolveAppLocalizationsForErrors(
                context,
              ).shortVideoVersionManagerSnackbarDraftSaved(name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorDraftSave(
            describeUserVisibleApiErrorResolved(context, e),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 显示草稿列表对话框
  Future<void> _showDraftsDialog() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    await showStudioDialog<void>(
      context: context,
      builder: (context) {
        return StudioAlertDialog(
          title: Text(l10n.shortVideoVersionManagerDraftListTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: widget.drafts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(StudioSpacing.md),
                    child: Center(
                      child: Text(l10n.shortVideoVersionManagerNoDraftsInList),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.drafts.length,
                    itemBuilder: (context, index) {
                      final draft = widget.drafts[index];
                      final theme = Theme.of(context);

                      return studioStaggeredItem(
                        index,
                        entranceKey: widget.drafts.length,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: StudioSpacing.xs,
                          ),
                          child: StudioCard(
                            padding: EdgeInsets.zero,
                            child: StudioListRow(
                              onRestore: () {
                                Navigator.of(context).pop();
                                _handleRestoreDraft(draft);
                              },
                              onDelete: () {
                                Navigator.of(context).pop();
                                _handleDeleteDraft(draft);
                              },
                              deleteLabel: l10n
                                  .shortVideoVersionManagerTooltipDeleteDraft,
                              leading: Icon(
                                Icons.drafts_outlined,
                                color: theme.colorScheme.secondary,
                              ),
                              title: Text(draft.name),
                              subtitle: Text(
                                l10n.shortVideoVersionManagerDraftListRowSubtitle(
                                  draft.shotCount,
                                  _formatDateTime(draft.savedAt),
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StudioIconButton(
                                    icon: Icons.restore,
                                    label: l10n
                                        .shortVideoVersionManagerTooltipRestoreDraft,
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _handleRestoreDraft(draft);
                                    },
                                  ),
                                  StudioIconButton(
                                    icon: Icons.delete_outline,
                                    label: l10n
                                        .shortVideoVersionManagerTooltipDeleteDraft,
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _handleDeleteDraft(draft);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.shortVideoSpaceProductionAssemblyClose),
            ),
          ],
        );
      },
    );
  }

  /// 处理恢复草稿
  Future<void> _handleRestoreDraft(AssemblyDraft draft) async {
    // 显示确认对话框
    final confirmed = await showRestoreDraftConfirmation(
      context,
      draftName: draft.name,
      showDontShowAgain: true,
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onRestoreDraft(draft.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolveAppLocalizationsForErrors(
                context,
              ).shortVideoVersionManagerSnackbarDraftRestored(draft.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorDraftRestore(
            describeUserVisibleApiErrorResolved(context, e),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 处理删除草稿
  Future<void> _handleDeleteDraft(AssemblyDraft draft) async {
    // 显示确认对话框
    final confirmed = await showStudioDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = resolveAppLocalizationsForErrors(context);
        return StudioAlertDialog(
          title: Text(l10n.shortVideoVersionManagerConfirmDeleteDraftTitle),
          content: Text(
            l10n.shortVideoVersionManagerConfirmDeleteDraftBody(draft.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.notificationsActionCancel),
            ),
            FilledButton(
              style: studioFormDestructivePrimaryButtonStyle(context),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.notificationsActionDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onDeleteDraft(draft.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolveAppLocalizationsForErrors(
                context,
              ).shortVideoVersionManagerSnackbarDraftDeleted(draft.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorDraftDelete(
            describeUserVisibleApiErrorResolved(context, e),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 显示版本对比对话框
  Future<void> _showCompareVersionsDialog() async {
    if (widget.versions.length < 2) {
      return;
    }

    // 选择两个版本进行对比
    AssemblyVersion? baseVersion;
    AssemblyVersion? compareVersion;

    await showStudioDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final l10n = resolveAppLocalizationsForErrors(dialogContext);
            return StudioAlertDialog(
              title: Text(l10n.shortVideoVersionManagerCompareDialogTitle),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.shortVideoVersionManagerCompareBaseLabel),
                    const SizedBox(height: StudioSpacing.xs),
                    StudioDropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: StudioLayoutSpacing.insetDense,
                          vertical: StudioSpacing.xs,
                        ),
                      ),
                      hint: Text(l10n.shortVideoVersionManagerCompareBaseHint),
                      initialValue: baseVersion?.id,
                      items: widget.versions.map((version) {
                        return DropdownMenuItem(
                          value: version.id,
                          child: Text(
                            l10n.shortVideoVersionManagerCompareVersionWithShots(
                              version.name,
                              version.shotCount,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          baseVersion = widget.versions.firstWhere(
                            (v) => v.id == value,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: StudioSpacing.sm),
                    Text(l10n.shortVideoVersionManagerCompareTargetLabel),
                    const SizedBox(height: StudioSpacing.xs),
                    StudioDropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: StudioLayoutSpacing.insetDense,
                          vertical: StudioSpacing.xs,
                        ),
                      ),
                      hint: Text(
                        l10n.shortVideoVersionManagerCompareTargetHint,
                      ),
                      initialValue: compareVersion?.id,
                      items: widget.versions.map((version) {
                        return DropdownMenuItem(
                          value: version.id,
                          child: Text(
                            l10n.shortVideoVersionManagerCompareVersionWithShots(
                              version.name,
                              version.shotCount,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          compareVersion = widget.versions.firstWhere(
                            (v) => v.id == value,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.notificationsActionCancel),
                ),
                FilledButton(
                  style: studioFormPrimaryButtonStyle(dialogContext),
                  onPressed:
                      baseVersion != null &&
                          compareVersion != null &&
                          baseVersion!.id != compareVersion!.id
                      ? () {
                          Navigator.of(dialogContext).pop();
                          _showVersionComparison(baseVersion!, compareVersion!);
                        }
                      : null,
                  child: Text(l10n.shortVideoVersionManagerStartCompare),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 显示版本对比界面
  void _showVersionComparison(
    AssemblyVersion baseVersion,
    AssemblyVersion compareVersion,
  ) {
    showStudioDialog<void>(
      context: context,
      builder: (context) {
        return VersionComparison(
          baseVersion: baseVersion,
          compareVersion: compareVersion,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}
