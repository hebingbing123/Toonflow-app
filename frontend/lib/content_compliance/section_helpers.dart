// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unqualified_reference_to_static_member_of_extended_type

part of 'section.dart';

/// Helper methods for ContentComplianceSection
extension _ContentComplianceSectionHelpers on _ContentComplianceSectionState {
  String? _queueFilterSummary(
    AppLocalizations l10n,
    ContentComplianceQueueResponseV1 queue,
  ) {
    final parts = <String>[];
    if (_queueStatus != 'all') {
      parts.add(_statusLabel(l10n, _queueStatus));
    }
    if (_queueCategory != 'all') {
      parts.add(_categoryLabel(l10n, _queueCategory));
    }
    if (_queueTargetType != 'all') {
      parts.add(_targetTypeLabel(l10n, _queueTargetType));
    }
    if (_queueClaimedOnly) {
      parts.add(l10n.contentComplianceClaimedOnly);
    }
    if ((_queueWorkspaceName ?? _queueWorkspaceId ?? '').isNotEmpty) {
      parts.add(_queueWorkspaceName ?? _queueWorkspaceId!);
    }
    if ((_queueClaimedByLabel ?? '').isNotEmpty) {
      parts.add(
        _queueClaimedByLabel == 'unclaimed'
            ? l10n.contentComplianceOwnerChipUnclaimed
            : l10n.contentComplianceOwnerChip(_queueClaimedByLabel!),
      );
    }
    if ((_queueSlaBucket ?? '').isNotEmpty) {
      parts.add(_slaBucketLabel(l10n, _queueSlaBucket!));
    }
    if ((_queueEscalationStage ?? '').isNotEmpty) {
      parts.add(_escalationStageLabel(l10n, _queueEscalationStage!));
    }
    if (parts.isEmpty) {
      return l10n.contentComplianceMetricPending(queue.summary.pending);
    }
    return '${parts.join(' · ')} · '
        '${l10n.contentComplianceMetricPending(queue.summary.pending)}';
  }

  void _syncFilterStateFromController() {
    _queueStatus = widget.controller.queueStatusFilter ?? 'all';
    _queueCategory = widget.controller.queueCategoryFilter ?? 'all';
    _queueTargetType = widget.controller.queueTargetTypeFilter ?? 'all';
    _queueWorkspaceId = widget.controller.queueWorkspaceIdFilter;
    _queueWorkspaceName = widget.controller.queueWorkspaceNameFilter;
    _queueClaimedByLabel = widget.controller.queueClaimedByLabelFilter;
    _queueSlaBucket = widget.controller.queueSlaBucketFilter;
    _queueEscalationStage = widget.controller.queueEscalationStageFilter;
    _queueClaimedOnly = widget.controller.queueClaimedOnly;
    final activeIds =
        widget.controller.queue?.items.map((item) => item.id).toSet() ??
        const <String>{};
    _selectedReportIds.removeWhere((id) => !activeIds.contains(id));
  }

  String _openTargetLabel(
    AppLocalizations l10n,
    ContentComplianceReportItemV1 item,
  ) {
    switch (item.targetType) {
      case 'project':
        return l10n.contentComplianceOpenProject;
      case 'script':
        return l10n.contentComplianceOpenScriptProject;
      case 'storyboard':
        return l10n.contentComplianceOpenStoryboardProject;
      case 'asset':
        return l10n.contentComplianceOpenAssetProject;
      case 'novel':
        return l10n.contentComplianceOpenNovelProject;
      case 'user':
        return l10n.contentComplianceOpenUserContext;
      default:
        return l10n.contentComplianceOpenContext;
    }
  }

  String _actorDisplay(AppLocalizations l10n, String? label) {
    final v = (label ?? '').trim();
    if (v.isEmpty || v == 'internal_ops') {
      return l10n.contentComplianceActorInternalOps;
    }
    return v;
  }

  List<String> _buildAuditLines(
    AppLocalizations l10n,
    ContentComplianceReportItemV1 item,
  ) {
    final lines = <String>[
      l10n.contentComplianceItemLineCreated(item.createdAt),
    ];
    if ((item.claimedByLabel ?? '').isNotEmpty ||
        (item.claimedAt ?? '').isNotEmpty) {
      final actor = _actorDisplay(l10n, item.claimedByLabel);
      final claimedAt = (item.claimedAt ?? '').trim();
      if (claimedAt.isEmpty) {
        lines.add(l10n.contentComplianceItemLineClaimed(actor));
      } else {
        lines.add(
          l10n.contentComplianceItemLineClaimedWithTime(actor, claimedAt),
        );
      }
    }
    if ((item.resolutionLabel ?? '').isNotEmpty ||
        (item.resolvedAt ?? '').isNotEmpty) {
      final status = _statusLabel(l10n, item.status);
      final resolutionBy = _actorDisplay(l10n, item.resolutionLabel);
      final resolvedAt = (item.resolvedAt ?? '').trim();
      if (resolvedAt.isEmpty) {
        lines.add(l10n.contentComplianceItemLineOutcome(status, resolutionBy));
      } else {
        lines.add(
          l10n.contentComplianceItemLineOutcomeWithTime(
            status,
            resolutionBy,
            resolvedAt,
          ),
        );
      }
    }
    return lines;
  }

  String _auditActionLabel(AppLocalizations l10n, String action) {
    switch (action.trim()) {
      case 'claim':
        return l10n.contentComplianceAuditVerbClaim;
      case 'resolve':
        return l10n.contentComplianceAuditVerbResolve;
      case 'dismiss':
        return l10n.contentComplianceAuditVerbDismiss;
      case 'reassign':
        return l10n.contentComplianceAuditVerbReassign;
      case 'auto_rebalance':
      case 'auto-rebalance':
        return l10n.contentComplianceAuditVerbAutoRebalance;
      default:
        return studioUnknownCodeLabel(l10n, action);
    }
  }

  String _fmtAuditStatusRef(AppLocalizations l10n, String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty || t == '-') {
      return '—';
    }
    return _statusLabel(l10n, t);
  }

  String _dispositionCodeLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'none':
        return l10n.contentComplianceDispositionNone;
      case 'archive_project':
        return l10n.contentComplianceDispositionArchiveProject;
      case 'suspend_user':
        return l10n.contentComplianceDispositionSuspendUser;
      default:
        return studioUnknownCodeLabel(l10n, code);
    }
  }

  String _auditSummary(
    AppLocalizations l10n,
    ContentComplianceAuditItemV1 item,
  ) {
    final parts = <String>[
      _auditActionLabel(l10n, item.action),
      if ((item.fromStatus ?? '').isNotEmpty ||
          (item.toStatus ?? '').isNotEmpty)
        l10n.contentComplianceAuditStatusChanged(
          _fmtAuditStatusRef(l10n, item.fromStatus),
          _fmtAuditStatusRef(l10n, item.toStatus),
        ),
      if (item.actorLabel.trim().isNotEmpty)
        _actorDisplay(l10n, item.actorLabel),
      if ((item.disposition ?? '').trim().isNotEmpty)
        l10n.contentComplianceAuditDispositionEntry(
          _dispositionCodeLabel(l10n, item.disposition!.trim()),
        ),
    ];
    return parts.where((s) => s.isNotEmpty).join(' · ');
  }

  String _auditDetails(ContentComplianceAuditItemV1 item) {
    if (item.details.isEmpty) {
      return '{}';
    }
    return item.details.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }

  String _workspaceSummaryLabel(
    AppLocalizations l10n,
    ContentComplianceWorkspaceSummaryV1 item,
  ) {
    final name = (item.workspaceName ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    return l10n.contentComplianceWorkspacePersonalScope;
  }

  String _targetTypeLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'project':
        return l10n.contentComplianceTargetProject;
      case 'script':
        return l10n.contentComplianceTargetScript;
      case 'storyboard':
        return l10n.contentComplianceTargetStoryboard;
      case 'asset':
        return l10n.contentComplianceTargetAsset;
      case 'novel':
        return l10n.contentComplianceTargetNovel;
      case 'user':
        return l10n.contentComplianceTargetUser;
      case 'all':
        return l10n.contentComplianceOptionAll;
      default:
        return studioUnknownCodeLabel(l10n, value);
    }
  }

  String _categoryLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'copyright':
        return l10n.contentComplianceCategoryCopyright;
      case 'safety':
        return l10n.contentComplianceCategorySafety;
      case 'harassment':
        return l10n.contentComplianceCategoryHarassment;
      case 'adult':
        return l10n.contentComplianceCategoryAdult;
      case 'violence':
        return l10n.contentComplianceCategoryViolence;
      case 'spam':
        return l10n.contentComplianceCategorySpam;
      case 'other':
        return l10n.contentComplianceCategoryOther;
      case 'all':
        return l10n.contentComplianceOptionAll;
      default:
        return studioUnknownCodeLabel(l10n, value);
    }
  }

  String _severityLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'low':
        return l10n.contentComplianceSeverityLow;
      case 'medium':
        return l10n.contentComplianceSeverityMedium;
      case 'high':
        return l10n.contentComplianceSeverityHigh;
      case 'critical':
        return l10n.contentComplianceSeverityCritical;
      default:
        return studioUnknownCodeLabel(l10n, value);
    }
  }

  String _statusLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'pending':
        return l10n.contentComplianceStatusPending;
      case 'claimed':
        return l10n.contentComplianceStatusClaimed;
      case 'resolved':
        return l10n.contentComplianceStatusResolved;
      case 'dismissed':
        return l10n.contentComplianceStatusDismissed;
      case 'all':
        return l10n.contentComplianceOptionAll;
      default:
        return studioUnknownCodeLabel(l10n, value);
    }
  }

  String _slaBucketLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'open_over_24h':
        return l10n.contentComplianceSlaOpenOver24h(0).replaceFirst(' 0', '');
      case 'open_over_72h':
        return l10n.contentComplianceSlaOpenOver72h(0).replaceFirst(' 0', '');
      case 'claimed_over_24h':
        return l10n
            .contentComplianceSlaClaimedOver24h(0)
            .replaceFirst(' 0', '');
      case 'unclaimed_critical':
        return l10n
            .contentComplianceSlaUnclaimedCritical(0)
            .replaceFirst(' 0', '');
      default:
        return studioUnknownCodeLabel(l10n, value);
    }
  }

  Future<void> _applyWorkspaceFilter(
    ContentComplianceWorkspaceSummaryV1 item,
  ) async {
    setState(() {
      _queueWorkspaceId = item.workspaceId;
      _queueWorkspaceName = item.workspaceName;
    });
    await widget.controller.applyQueueFilters(
      status: _queueStatus,
      category: _queueCategory,
      targetType: _queueTargetType,
      workspaceId: item.workspaceId,
      workspaceName: item.workspaceName,
      claimedByLabel: _queueClaimedByLabel,
      slaBucket: _queueSlaBucket,
      escalationStage: _queueEscalationStage,
      claimedOnly: _queueClaimedOnly,
    );
  }

  String _ownerSummaryLabel(
    AppLocalizations l10n,
    ContentComplianceOwnerSummaryV1 item,
  ) {
    return item.ownerLabel == 'unclaimed'
        ? l10n.contentComplianceOwnerUnclaimed
        : item.ownerLabel;
  }

  Future<void> _applyOwnerFilter(ContentComplianceOwnerSummaryV1 item) async {
    setState(() {
      _queueClaimedByLabel = item.ownerLabel;
    });
    await widget.controller.applyQueueFilters(
      status: _queueStatus,
      category: _queueCategory,
      targetType: _queueTargetType,
      workspaceId: _queueWorkspaceId,
      workspaceName: _queueWorkspaceName,
      claimedByLabel: item.ownerLabel,
      slaBucket: _queueSlaBucket,
      escalationStage: _queueEscalationStage,
      claimedOnly: _queueClaimedOnly,
    );
  }

  Future<void> _applySlaBucketFilter(String? bucket) async {
    setState(() {
      _queueSlaBucket = bucket;
    });
    await widget.controller.applyQueueFilters(
      status: _queueStatus,
      category: _queueCategory,
      targetType: _queueTargetType,
      workspaceId: _queueWorkspaceId,
      workspaceName: _queueWorkspaceName,
      claimedByLabel: _queueClaimedByLabel,
      slaBucket: bucket,
      escalationStage: _queueEscalationStage,
      claimedOnly: _queueClaimedOnly,
    );
  }

  String _escalationStageLabel(AppLocalizations l10n, String stage) {
    switch (stage) {
      case 'critical_unclaimed':
        return l10n.contentComplianceEscalationCriticalUnclaimed;
      case 'stalled_claimed':
        return l10n.contentComplianceEscalationStalledClaimed;
      case 'over_capacity':
        return l10n.contentComplianceEscalationOverCapacity;
      case 'escalated_72h':
        return l10n.contentComplianceEscalationEscalated72h;
      case 'urgent':
        return l10n.contentComplianceEscalationUrgent;
      case 'closed':
        return l10n.contentComplianceEscalationClosed;
      default:
        return l10n.contentComplianceEscalationWatch;
    }
  }

  Color _alertBorderColor(BuildContext context, String level) {
    final theme = Theme.of(context);
    switch (level) {
      case 'critical':
        return theme.colorScheme.error;
      case 'high':
        return theme.colorScheme.tertiary;
      case 'medium':
        return theme.colorScheme.primary;
      default:
        return studioPanelBorderColor(context);
    }
  }

  int _alertPriority(ContentComplianceQueueAlertV1 alert) {
    if (alert.stage == 'critical_unclaimed') {
      return 0;
    }
    if (alert.stage == 'over_capacity') {
      return 1;
    }
    if (alert.stage == 'stalled_claimed') {
      return 2;
    }
    if (alert.stage == 'escalated_72h') {
      return 3;
    }
    switch (alert.level) {
      case 'critical':
        return 4;
      case 'high':
        return 5;
      case 'medium':
        return 6;
      default:
        return 7;
    }
  }

  String _topAlertActionHint(
    AppLocalizations l10n,
    ContentComplianceQueueAlertV1 alert,
  ) {
    switch (alert.stage) {
      case 'critical_unclaimed':
        return l10n.contentComplianceAlertHintCriticalUnclaimed;
      case 'over_capacity':
        return l10n.contentComplianceAlertHintOverCapacity;
      case 'stalled_claimed':
        return l10n.contentComplianceAlertHintStalledClaimed;
      case 'escalated_72h':
        return l10n.contentComplianceAlertHintEscalated72h;
      default:
        return l10n.contentComplianceAlertHintDefault;
    }
  }

  Future<void> _runTopAlertPrimaryAction(
    ContentComplianceQueueAlertV1 alert,
  ) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    switch (alert.stage) {
      case 'critical_unclaimed':
        final count = _selectCriticalUnclaimedFromCurrentQueue();
        if (count == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.contentComplianceSnackNoCriticalUnclaimedBulkClaim,
              ),
            ),
          );
          return;
        }
        await _runBulkAction('claim');
        return;
      case 'over_capacity':
        await _runAutoRebalance(dryRun: true);
        return;
      case 'stalled_claimed':
        final count = _selectStalledClaimedFromCurrentQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.contentComplianceSnackSelectedStalledClaimed(count),
            ),
          ),
        );
        return;
      case 'escalated_72h':
        final count = _selectEscalated72hFromCurrentQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.contentComplianceSnackSelected72hUnconverged(count),
            ),
          ),
        );
        return;
      default:
        await _applyAlertShortcut(alert.stage);
        return;
    }
  }

  String _topAlertPrimaryLabel(
    AppLocalizations l10n,
    ContentComplianceQueueAlertV1 alert,
  ) {
    switch (alert.stage) {
      case 'critical_unclaimed':
        return l10n.contentComplianceBulkClaimOneClick;
      case 'over_capacity':
        return l10n.contentComplianceAutoRebalanceTitlePreview;
      case 'stalled_claimed':
        return l10n.contentComplianceSelectStalled;
      case 'escalated_72h':
        return l10n.contentComplianceLabelSelect72hUnconverged;
      default:
        return l10n.contentComplianceViewLayer;
    }
  }

  String? _topAlertSecondaryLabel(
    AppLocalizations l10n,
    ContentComplianceQueueAlertV1 alert,
  ) {
    switch (alert.stage) {
      case 'critical_unclaimed':
        return l10n.contentComplianceTopSecondaryPendingOnly;
      case 'over_capacity':
        return l10n.contentComplianceAutoRebalanceTitleExecute;
      case 'stalled_claimed':
        return l10n.contentCompliancePreviewStalledRebalance;
      case 'escalated_72h':
        return l10n.contentComplianceTopSecondarySelect72hOnly;
      default:
        return null;
    }
  }

  Future<void> _runTopAlertSecondaryAction(
    ContentComplianceQueueAlertV1 alert,
  ) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    switch (alert.stage) {
      case 'critical_unclaimed':
        final count = _selectCriticalUnclaimedFromCurrentQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.contentComplianceSnackSelectedCriticalUnclaimed(count),
            ),
          ),
        );
        return;
      case 'over_capacity':
        await _runAutoRebalance(dryRun: false);
        return;
      case 'stalled_claimed':
        await _runAutoRebalance(dryRun: true);
        return;
      case 'escalated_72h':
        final count = _selectEscalated72hFromCurrentQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.contentComplianceSnackSelected72hItems(count)),
          ),
        );
        return;
      default:
        return;
    }
  }

  String _effectiveTopPrimaryLabel(
    AppLocalizations l10n,
    ContentComplianceQueueAlertV1 alert,
  ) {
    final secondaryLabel = _topAlertSecondaryLabel(l10n, alert);
    if (_preferSecondaryAsPrimaryStages.contains(alert.stage) &&
        secondaryLabel != null) {
      return secondaryLabel;
    }
    return _topAlertPrimaryLabel(l10n, alert);
  }

  String? _effectiveTopSecondaryLabel(
    AppLocalizations l10n,
    ContentComplianceQueueAlertV1 alert,
  ) {
    final secondaryLabel = _topAlertSecondaryLabel(l10n, alert);
    if (secondaryLabel == null) {
      return null;
    }
    if (_preferSecondaryAsPrimaryStages.contains(alert.stage)) {
      return _topAlertPrimaryLabel(l10n, alert);
    }
    return secondaryLabel;
  }

  Future<void> _runEffectiveTopPrimaryAction(
    ContentComplianceQueueAlertV1 alert,
  ) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final secondaryLabel = _topAlertSecondaryLabel(l10n, alert);
    if (_preferSecondaryAsPrimaryStages.contains(alert.stage) &&
        secondaryLabel != null) {
      await _runTopAlertSecondaryAction(alert);
      return;
    }
    await _runTopAlertPrimaryAction(alert);
  }

  Future<void> _runEffectiveTopSecondaryAction(
    ContentComplianceQueueAlertV1 alert,
  ) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final secondaryLabel = _topAlertSecondaryLabel(l10n, alert);
    if (secondaryLabel == null) {
      return;
    }
    if (_preferSecondaryAsPrimaryStages.contains(alert.stage)) {
      await _runTopAlertPrimaryAction(alert);
      return;
    }
    await _runTopAlertSecondaryAction(alert);
  }

  void _rememberSecondaryPreferenceForStage(String stage) {
    if (stage.isEmpty) {
      return;
    }
    setState(() {
      _preferSecondaryAsPrimaryStages.add(stage);
    });
    _saveAlertActionPreferences();
  }

  Future<void> _loadAlertActionPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(
        _ContentComplianceSectionState._alertActionPreferenceKey,
      );
      if (stored == null || stored.trim().isEmpty) {
        return;
      }
      final stages = stored
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
      if (!mounted || stages.isEmpty) {
        return;
      }
      setState(() {
        _preferSecondaryAsPrimaryStages
          ..clear()
          ..addAll(stages);
      });
    } catch (_) {
      // Ignore local preference read failures.
    }
  }

  Future<void> _saveAlertActionPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordered = _preferSecondaryAsPrimaryStages.toList()..sort();
      await prefs.setString(
        _ContentComplianceSectionState._alertActionPreferenceKey,
        ordered.join(','),
      );
    } catch (_) {
      // Ignore local preference write failures.
    }
  }

  Future<void> _resetAlertActionPreferences() async {
    setState(() {
      _preferSecondaryAsPrimaryStages.clear();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(
        _ContentComplianceSectionState._alertActionPreferenceKey,
      );
    } catch (_) {
      // Ignore local preference reset failures.
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          )!.contentComplianceSnackRestoredDefaultActionOrder,
        ),
      ),
    );
  }

  Future<void> _applyAlertShortcut(String stage) async {
    if (stage.isEmpty) {
      return;
    }
    await _applyEscalationStageFilter(stage);
  }

  int _selectCriticalUnclaimedFromCurrentQueue() {
    final queue = widget.controller.queue;
    if (queue == null) {
      return 0;
    }
    final selectable = queue.items
        .where(
          (item) =>
              item.status == 'pending' &&
              item.severity == 'critical' &&
              (item.claimedByLabel ?? '').trim().isEmpty,
        )
        .map((item) => item.id)
        .toSet();
    setState(() {
      _selectedReportIds
        ..clear()
        ..addAll(selectable);
    });
    return selectable.length;
  }

  int _selectStalledClaimedFromCurrentQueue() {
    final queue = widget.controller.queue;
    if (queue == null) {
      return 0;
    }
    final selectable = queue.items
        .where(
          (item) =>
              item.status == 'claimed' &&
              item.escalationStage == 'stalled_claimed',
        )
        .map((item) => item.id)
        .toSet();
    setState(() {
      _selectedReportIds
        ..clear()
        ..addAll(selectable);
    });
    return selectable.length;
  }

  int _selectEscalated72hFromCurrentQueue() {
    final queue = widget.controller.queue;
    if (queue == null) {
      return 0;
    }
    final selectable = queue.items
        .where(
          (item) =>
              (item.status == 'pending' || item.status == 'claimed') &&
              item.escalationStage == 'escalated_72h',
        )
        .map((item) => item.id)
        .toSet();
    setState(() {
      _selectedReportIds
        ..clear()
        ..addAll(selectable);
    });
    return selectable.length;
  }

  Future<void> _applyEscalationStageFilter(String? stage) async {
    setState(() {
      _queueEscalationStage = stage;
    });
    await widget.controller.applyQueueFilters(
      status: _queueStatus,
      category: _queueCategory,
      targetType: _queueTargetType,
      workspaceId: _queueWorkspaceId,
      workspaceName: _queueWorkspaceName,
      claimedByLabel: _queueClaimedByLabel,
      slaBucket: _queueSlaBucket,
      escalationStage: stage,
      claimedOnly: _queueClaimedOnly,
    );
  }

  Future<void> _runBulkAction(String action) async {
    if (_selectedReportIds.isEmpty) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final verb = switch (action) {
      'claim' => l10n.contentComplianceBulkClaim,
      'resolve' => l10n.contentComplianceBulkResolve,
      'dismiss' => l10n.contentComplianceBulkDismiss,
      _ => l10n.contentComplianceBulkGeneric,
    };
    final confirmed = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) => StudioAlertDialog(
        title: Text(verb),
        content: Text(
          l10n.contentComplianceBulkConfirmBody(
                verb,
                _selectedReportIds.length,
              ) +
              (_resolutionNoteController.text.trim().isNotEmpty
                  ? l10n.contentComplianceBulkConfirmNoteReuse
                  : ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.taskCenterCancel),
          ),
          FilledButton(
            style: studioFormPrimaryButtonStyle(dialogContext),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.contentComplianceDialogContinue),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final response = await widget.controller.batchMutateReports(
      reportIds: _selectedReportIds.toList(growable: false),
      action: action,
      disposition: _disposition,
      resolutionNote: _resolutionNoteController.text,
    );
    if (!mounted || response == null) {
      return;
    }
    setState(() {
      _selectedReportIds.clear();
    });
    final queueAfter = widget.controller.queue;
    final remainingAlerts = queueAfter?.alerts.length ?? 0;
    final criticalAlerts =
        queueAfter?.alerts
            .where(
              (alert) => alert.level == 'critical' || alert.level == 'high',
            )
            .length ??
        0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.contentComplianceBulkResult(
            verb,
            response.succeededCount,
            response.failedCount,
            remainingAlerts,
            criticalAlerts,
          ),
        ),
      ),
    );
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  List<String> _csvHeaderRow(AppLocalizations l10n) => <String>[
    l10n.contentComplianceCsvColumnReportId,
    l10n.contentComplianceFieldStatus,
    l10n.contentComplianceFieldSeverity,
    l10n.contentComplianceFieldCategory,
    l10n.contentComplianceCsvColumnClaimedBy,
    l10n.contentComplianceCsvColumnWorkspaceName,
    l10n.contentComplianceCsvColumnProjectName,
    l10n.contentComplianceFieldTargetType,
    l10n.contentComplianceCsvColumnTargetId,
    l10n.contentComplianceCsvColumnReporter,
    l10n.contentComplianceCsvColumnCreatedAt,
    l10n.contentComplianceCsvColumnClaimedAt,
    l10n.contentComplianceCsvColumnResolvedAt,
    l10n.contentComplianceCsvColumnDetail,
  ];

  List<String> _csvDataRow(AppLocalizations l10n, ContentComplianceReportItemV1 item) =>
      <String>[
        item.id,
        _statusLabel(l10n, item.status),
        _severityLabel(l10n, item.severity),
        _categoryLabel(l10n, item.category),
        item.claimedByLabel ?? '',
        item.workspaceName ?? '',
        item.projectName ?? '',
        _targetTypeLabel(l10n, item.targetType),
        item.targetId,
        item.reporterEmail ?? item.reporterUserId,
        item.createdAt,
        item.claimedAt ?? '',
        item.resolvedAt ?? '',
        item.detail ?? '',
      ];

  Future<void> _copyCurrentQueueCsv() async {
    final queue = widget.controller.queue;
    if (queue == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final rows = <List<String>>[
      _csvHeaderRow(l10n),
      ...queue.items.map((item) => _csvDataRow(l10n, item)),
    ];
    await Clipboard.setData(
      ClipboardData(
        text: rows.map((row) => row.map(_csvCell).join(',')).join('\n'),
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          )!.contentComplianceCsvCopied(queue.items.length),
        ),
      ),
    );
  }

  Future<void> _runReassign() async {
    if (_selectedReportIds.isEmpty) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final assignee = _reassignReviewerController.text.trim();
    if (assignee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.contentComplianceFillReviewerFirst)),
      );
      return;
    }
    final confirmed = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) => StudioAlertDialog(
        title: Text(l10n.contentComplianceReassignTitle),
        content: Text(
          l10n.contentComplianceReassignBody(
            _selectedReportIds.length,
            assignee,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.taskCenterCancel),
          ),
          FilledButton(
            style: studioFormPrimaryButtonStyle(dialogContext),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.contentComplianceDialogContinue),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final response = await widget.controller.reassignReports(
      reportIds: _selectedReportIds.toList(growable: false),
      assigneeLabel: assignee,
      note: _resolutionNoteController.text,
    );
    if (!mounted || response == null) {
      return;
    }
    setState(() {
      _selectedReportIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.contentComplianceReassignResult(
            response.assigneeLabel,
            response.succeededCount,
            response.failedCount,
          ),
        ),
      ),
    );
  }

  Future<void> _runAutoRebalance({required bool dryRun}) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final queue = widget.controller.queue;
    if (queue == null) {
      return;
    }
    if (!dryRun && queue.capacity.overloadedReviewerCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.contentComplianceAutoRebalanceNoOverload)),
      );
      return;
    }
    final confirmed = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) => StudioAlertDialog(
        title: Text(
          dryRun
              ? l10n.contentComplianceAutoRebalanceTitlePreview
              : l10n.contentComplianceAutoRebalanceTitleExecute,
        ),
        content: Text(
          dryRun
              ? l10n.contentComplianceAutoRebalanceBodyPreview(
                  queue.capacity.reviewerCapacityLimit,
                )
              : l10n.contentComplianceAutoRebalanceBodyExecute(
                  queue.capacity.reviewerCapacityLimit,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.taskCenterCancel),
          ),
          FilledButton(
            style: studioFormPrimaryButtonStyle(dialogContext),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              dryRun
                  ? l10n.contentComplianceStartPreview
                  : l10n.contentComplianceExecuteNow,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final response = await widget.controller.autoRebalanceReports(
      dryRun: dryRun,
      note: _resolutionNoteController.text,
    );
    if (!mounted || response == null) {
      return;
    }
    final queueAfter = widget.controller.queue;
    final remainingAlerts = queueAfter?.alerts.length ?? 0;
    final overCapacityRemaining =
        queueAfter?.alerts
            .where((alert) => alert.stage == 'over_capacity')
            .fold<int>(0, (sum, alert) => sum + alert.count) ??
        0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          dryRun
              ? l10n.contentComplianceAutoRebalanceResultPreview(
                  response.plannedMoveCount,
                  response.reviewerCapacityLimit,
                )
              : l10n.contentComplianceAutoRebalanceResultExecute(
                  response.plannedMoveCount,
                  response.executedMoveCount,
                  overCapacityRemaining,
                  remainingAlerts,
                ),
        ),
      ),
    );
  }

  Future<void> _showAuditDialog(ContentComplianceReportItemV1 item) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final rows = await widget.controller.fetchReportAudit(item.id);
    if (!mounted) {
      return;
    }
    await showStudioDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final tokens = StudioTokens.of(dialogContext);
        return StudioAlertDialog(
          title: Text(l10n.contentComplianceAuditTitle(item.id)),
          content: SizedBox(
            width: studioConstrainedDialogWidth(context, maxWidth: 640),
            child: rows.isEmpty
                ? StudioEmptyState.emptyData(
                    title: l10n.contentComplianceAuditEmpty,
                    icon: Icons.history_outlined,
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rows
                          .map(
                            (audit) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: studioPanelBorderColor(context),
                                  ),
                                  borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _auditSummary(l10n, audit),
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      audit.createdAt,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: tokens.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      _auditDetails(audit),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.helpHubDialogClose),
            ),
          ],
        );
      },
    );
  }

}
