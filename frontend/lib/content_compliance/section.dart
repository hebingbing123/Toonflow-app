import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'controller.dart';

class ContentComplianceSection extends StatefulWidget {
  const ContentComplianceSection({
    super.key,
    required this.controller,
    this.onOpenTarget,
    this.onOpenOpsTarget,
  });

  final ContentComplianceController controller;
  final Future<void> Function(ContentComplianceReportItemV1 item)? onOpenTarget;
  final Future<void> Function(ContentComplianceReportItemV1 item)?
  onOpenOpsTarget;

  @override
  State<ContentComplianceSection> createState() =>
      _ContentComplianceSectionState();
}

class _ContentComplianceSectionState extends State<ContentComplianceSection> {
  static const String _alertActionPreferenceKey =
      'content_compliance_alert_action_preference_stages_v1';
  final _targetIdController = TextEditingController();
  final _detailController = TextEditingController();
  final _resolutionNoteController = TextEditingController();
  final _reassignReviewerController = TextEditingController();
  String _targetType = 'project';
  String _category = 'other';
  String _severity = 'medium';
  String _disposition = 'none';
  String _queueStatus = 'all';
  String _queueCategory = 'all';
  String _queueTargetType = 'all';
  String? _queueWorkspaceId;
  String? _queueWorkspaceName;
  String? _queueClaimedByLabel;
  String? _queueSlaBucket;
  String? _queueEscalationStage;
  bool _queueClaimedOnly = false;
  final Set<String> _selectedReportIds = <String>{};
  final Set<String> _preferSecondaryAsPrimaryStages = <String>{};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _syncFilterStateFromController();
    _loadAlertActionPreferences();
    if (widget.controller.queueEnabled &&
        !widget.controller.skipAutoLoadQueueOnMount) {
      widget.controller.loadQueue();
    }
  }

  @override
  void didUpdateWidget(covariant ContentComplianceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _syncFilterStateFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _targetIdController.dispose();
    _detailController.dispose();
    _resolutionNoteController.dispose();
    _reassignReviewerController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      _syncFilterStateFromController();
      setState(() {});
    }
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

  String _openTargetLabel(AppLocalizations l10n, ContentComplianceReportItemV1 item) {
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

  List<String> _buildAuditLines(ContentComplianceReportItemV1 item) {
    final lines = <String>['created ${item.createdAt}'];
    if ((item.claimedByLabel ?? '').isNotEmpty ||
        (item.claimedAt ?? '').isNotEmpty) {
      lines.add(
        'claimed ${item.claimedByLabel ?? 'internal_ops'}'
        '${(item.claimedAt ?? '').isNotEmpty ? ' @ ${item.claimedAt}' : ''}',
      );
    }
    if ((item.resolutionLabel ?? '').isNotEmpty ||
        (item.resolvedAt ?? '').isNotEmpty) {
      lines.add(
        '${item.status} ${item.resolutionLabel ?? 'internal_ops'}'
        '${(item.resolvedAt ?? '').isNotEmpty ? ' @ ${item.resolvedAt}' : ''}',
      );
    }
    return lines;
  }

  String _auditSummary(ContentComplianceAuditItemV1 item) {
    final parts = <String>[
      item.action,
      if ((item.fromStatus ?? '').isNotEmpty ||
          (item.toStatus ?? '').isNotEmpty)
        '${item.fromStatus ?? '-'} -> ${item.toStatus ?? '-'}',
      item.actorLabel,
      if ((item.disposition ?? '').isNotEmpty)
        'disposition=${item.disposition}',
    ];
    return parts.join(' · ');
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

  String _ownerSummaryLabel(AppLocalizations l10n, ContentComplianceOwnerSummaryV1 item) {
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

  Color _alertBorderColor(ThemeData theme, String level) {
    switch (level) {
      case 'critical':
        return theme.colorScheme.error;
      case 'high':
        return theme.colorScheme.tertiary;
      case 'medium':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.outlineVariant;
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

  String _topAlertActionHint(AppLocalizations l10n, ContentComplianceQueueAlertV1 alert) {
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

  Future<void> _runTopAlertPrimaryAction(ContentComplianceQueueAlertV1 alert) async {
    final l10n = AppLocalizations.of(context)!;
    switch (alert.stage) {
      case 'critical_unclaimed':
        final count = _selectCriticalUnclaimedFromCurrentQueue();
        if (count == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.contentComplianceSnackNoCriticalUnclaimedBulkClaim),
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
          SnackBar(content: Text(l10n.contentComplianceSnackSelectedStalledClaimed(count))),
        );
        return;
      case 'escalated_72h':
        final count = _selectEscalated72hFromCurrentQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.contentComplianceSnackSelected72hUnconverged(count))),
        );
        return;
      default:
        await _applyAlertShortcut(alert.stage);
        return;
    }
  }

  String _topAlertPrimaryLabel(AppLocalizations l10n, ContentComplianceQueueAlertV1 alert) {
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

  String? _topAlertSecondaryLabel(AppLocalizations l10n, ContentComplianceQueueAlertV1 alert) {
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
    final l10n = AppLocalizations.of(context)!;
    switch (alert.stage) {
      case 'critical_unclaimed':
        final count = _selectCriticalUnclaimedFromCurrentQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.contentComplianceSnackSelectedCriticalUnclaimed(count))),
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
          SnackBar(content: Text(l10n.contentComplianceSnackSelected72hItems(count))),
        );
        return;
      default:
        return;
    }
  }

  String _effectiveTopPrimaryLabel(AppLocalizations l10n, ContentComplianceQueueAlertV1 alert) {
    final secondaryLabel = _topAlertSecondaryLabel(l10n, alert);
    if (_preferSecondaryAsPrimaryStages.contains(alert.stage) &&
        secondaryLabel != null) {
      return secondaryLabel;
    }
    return _topAlertPrimaryLabel(l10n, alert);
  }

  String? _effectiveTopSecondaryLabel(AppLocalizations l10n, ContentComplianceQueueAlertV1 alert) {
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
    final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;
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
      final stored = prefs.getString(_alertActionPreferenceKey);
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
      await prefs.setString(_alertActionPreferenceKey, ordered.join(','));
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
      await prefs.remove(_alertActionPreferenceKey);
    } catch (_) {
      // Ignore local preference reset failures.
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.contentComplianceSnackRestoredDefaultActionOrder)),
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
              item.status == 'claimed' && item.escalationStage == 'stalled_claimed',
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
    final l10n = AppLocalizations.of(context)!;
    final verb = switch (action) {
      'claim' => l10n.contentComplianceBulkClaim,
      'resolve' => l10n.contentComplianceBulkResolve,
      'dismiss' => l10n.contentComplianceBulkDismiss,
      _ => l10n.contentComplianceBulkGeneric,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(verb),
        content: Text(
          l10n.contentComplianceBulkConfirmBody(verb, _selectedReportIds.length) +
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
            .where((alert) => alert.level == 'critical' || alert.level == 'high')
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

  Future<void> _copyCurrentQueueCsv() async {
    final queue = widget.controller.queue;
    if (queue == null) {
      return;
    }
    final rows = <List<String>>[
      <String>[
        'report_id',
        'status',
        'severity',
        'category',
        'claimed_by',
        'workspace_name',
        'project_name',
        'target_type',
        'target_id',
        'reporter',
        'created_at',
        'claimed_at',
        'resolved_at',
        'detail',
      ],
      ...queue.items.map(
        (item) => <String>[
          item.id,
          item.status,
          item.severity,
          item.category,
          item.claimedByLabel ?? '',
          item.workspaceName ?? '',
          item.projectName ?? '',
          item.targetType,
          item.targetId,
          item.reporterEmail ?? item.reporterUserId,
          item.createdAt,
          item.claimedAt ?? '',
          item.resolvedAt ?? '',
          item.detail ?? '',
        ],
      ),
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
      SnackBar(content: Text(AppLocalizations.of(context)!.contentComplianceCsvCopied(queue.items.length))),
    );
  }

  Future<void> _runReassign() async {
    if (_selectedReportIds.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final assignee = _reassignReviewerController.text.trim();
    if (assignee.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.contentComplianceFillReviewerFirst)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.contentComplianceReassignTitle),
        content: Text(l10n.contentComplianceReassignBody(_selectedReportIds.length, assignee)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.taskCenterCancel),
          ),
          FilledButton(
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
    final l10n = AppLocalizations.of(context)!;
    final queue = widget.controller.queue;
    if (queue == null) {
      return;
    }
    if (!dryRun && queue.capacity.overloadedReviewerCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.contentComplianceAutoRebalanceNoOverload)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dryRun ? l10n.contentComplianceStartPreview : l10n.contentComplianceExecuteNow),
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
    final l10n = AppLocalizations.of(context)!;
    final rows = await widget.controller.fetchReportAudit(item.id);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.contentComplianceAuditTitle(item.id)),
          content: SizedBox(
            width: 640,
            child: rows.isEmpty
                ? Text(l10n.contentComplianceAuditEmpty)
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rows
                          .map(
                            (audit) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _auditSummary(audit),
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      audit.createdAt,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final queue = widget.controller.queue;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.contentComplianceTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.contentComplianceIntro,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.contentComplianceSubmitReportTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownMenu<String>(
                  initialSelection: _targetType,
                  label: const Text('targetType'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'project', label: 'project'),
                    DropdownMenuEntry(value: 'script', label: 'script'),
                    DropdownMenuEntry(value: 'storyboard', label: 'storyboard'),
                    DropdownMenuEntry(value: 'asset', label: 'asset'),
                    DropdownMenuEntry(value: 'novel', label: 'novel'),
                    DropdownMenuEntry(value: 'user', label: 'user'),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _targetType = value;
                    });
                  },
                ),
                DropdownMenu<String>(
                  initialSelection: _category,
                  label: const Text('category'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'copyright', label: 'copyright'),
                    DropdownMenuEntry(value: 'safety', label: 'safety'),
                    DropdownMenuEntry(value: 'harassment', label: 'harassment'),
                    DropdownMenuEntry(value: 'adult', label: 'adult'),
                    DropdownMenuEntry(value: 'violence', label: 'violence'),
                    DropdownMenuEntry(value: 'spam', label: 'spam'),
                    DropdownMenuEntry(value: 'other', label: 'other'),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _category = value;
                    });
                  },
                ),
                DropdownMenu<String>(
                  initialSelection: _severity,
                  label: const Text('severity'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'low', label: 'low'),
                    DropdownMenuEntry(value: 'medium', label: 'medium'),
                    DropdownMenuEntry(value: 'high', label: 'high'),
                    DropdownMenuEntry(value: 'critical', label: 'critical'),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _severity = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetIdController,
              decoration: InputDecoration(
                labelText: 'target UUID',
                hintText: l10n.contentComplianceTargetUuidHint,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.contentComplianceDetailLabel,
                hintText: l10n.contentComplianceDetailHint,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: widget.controller.submittingReport
                  ? null
                  : () => widget.controller.submitReport(
                      targetType: _targetType,
                      targetId: _targetIdController.text,
                      category: _category,
                      severity: _severity,
                      detail: _detailController.text,
                    ),
              icon: widget.controller.submittingReport
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.report_outlined),
              label: Text(
                widget.controller.submittingReport
                    ? l10n.contentComplianceSubmitting
                    : l10n.contentComplianceSubmitReport,
              ),
            ),
            if (widget.controller.queueEnabled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.contentComplianceQueueTitle, style: theme.textTheme.titleSmall),
                  ),
                  TextButton.icon(
                    onPressed:
                        widget.controller.loadingQueue ||
                            (!_queueClaimedOnly &&
                                _queueStatus == 'all' &&
                                _queueCategory == 'all' &&
                                _queueTargetType == 'all' &&
                                (_queueWorkspaceId ?? '').isEmpty &&
                                (_queueClaimedByLabel ?? '').isEmpty &&
                                (_queueSlaBucket ?? '').isEmpty &&
                                (_queueEscalationStage ?? '').isEmpty)
                        ? null
                        : widget.controller.clearQueueFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: Text(l10n.contentComplianceClearFilters),
                  ),
                  TextButton.icon(
                    onPressed: widget.controller.loadingQueue
                        ? null
                        : widget.controller.loadQueue,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.contentComplianceRefresh),
                  ),
                  TextButton.icon(
                    onPressed: queue == null || queue.items.isEmpty
                        ? null
                        : _copyCurrentQueueCsv,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(l10n.contentComplianceCopyCsv),
                  ),
                ],
              ),
              if (queue != null) ...[
                if (queue.alerts.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final sortedAlerts = [...queue.alerts]
                        ..sort(
                          (a, b) => _alertPriority(a)
                              .compareTo(_alertPriority(b)),
                        );
                      final topAlert = sortedAlerts.first;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _alertBorderColor(theme, topAlert.level),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.contentComplianceTopActionSummary(
                                topAlert.title,
                                topAlert.count,
                                _topAlertActionHint(l10n, topAlert),
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  key: const ValueKey(
                                    'contentComplianceTopAlertPrimary',
                                  ),
                                  onPressed: widget.controller.mutatingQueue
                                      ? null
                                      : () => _runEffectiveTopPrimaryAction(
                                          topAlert,
                                        ),
                                  child: Text(
                                    _effectiveTopPrimaryLabel(l10n, topAlert),
                                  ),
                                ),
                                if (_effectiveTopSecondaryLabel(l10n, topAlert) !=
                                    null)
                                  FilledButton.tonal(
                                    onPressed: widget.controller.mutatingQueue
                                        ? null
                                        : () async {
                                            _rememberSecondaryPreferenceForStage(
                                              topAlert.stage,
                                            );
                                            await _runEffectiveTopSecondaryAction(
                                              topAlert,
                                            );
                                          },
                                    child: Text(
                                      _effectiveTopSecondaryLabel(l10n, topAlert)!,
                                    ),
                                  ),
                                OutlinedButton(
                                  onPressed: widget.controller.loadingQueue
                                      ? null
                                      : () => _applyAlertShortcut(topAlert.stage),
                                  child: Text(l10n.contentComplianceViewLayer),
                                ),
                                OutlinedButton(
                                  key: const ValueKey(
                                    'contentComplianceResetAlertPreferences',
                                  ),
                                  onPressed: _preferSecondaryAsPrimaryStages
                                          .isEmpty
                                      ? null
                                      : _resetAlertActionPreferences,
                                  child: Text(l10n.contentComplianceRestoreDefaultActionOrder),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final sortedAlerts = [...queue.alerts]
                        ..sort(
                          (a, b) => _alertPriority(a)
                              .compareTo(_alertPriority(b)),
                        );
                      return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sortedAlerts
                        .map(
                          (alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _alertBorderColor(theme, alert.level),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${alert.title} (${alert.count})',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    alert.message,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton(
                                        onPressed: widget.controller.loadingQueue
                                            ? null
                                            : () => _applyAlertShortcut(
                                                alert.stage,
                                              ),
                                        child: Text(l10n.contentComplianceViewLayer),
                                      ),
                                      if (alert.stage == 'over_capacity')
                                        FilledButton.tonal(
                                          onPressed: widget.controller
                                                  .mutatingQueue
                                              ? null
                                              : () =>
                                                    _runAutoRebalance(dryRun: true),
                                          child: Text(l10n.contentCompliancePreviewRebalanceShort),
                                        ),
                                      if (alert.stage == 'over_capacity')
                                        FilledButton(
                                          onPressed: widget.controller
                                                  .mutatingQueue
                                              ? null
                                              : () => _runAutoRebalance(
                                                  dryRun: false,
                                                ),
                                          child: Text(l10n.contentComplianceExecuteRebalanceShort),
                                        ),
                                      if (alert.stage == 'critical_unclaimed')
                                        OutlinedButton(
                                          onPressed: widget.controller.loadingQueue
                                              ? null
                                              : () {
                                                  final count =
                                                      _selectCriticalUnclaimedFromCurrentQueue();
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        l10n.contentComplianceSnackSelectedCriticalReadyClaim(count),
                                                      ),
                                                    ),
                                                  );
                                                },
                                          child: Text(l10n.contentComplianceSelectCriticalUnclaimed),
                                        ),
                                      if (alert.stage == 'critical_unclaimed')
                                        FilledButton(
                                          onPressed:
                                              widget.controller.mutatingQueue
                                                  ? null
                                                  : () {
                                                      final count =
                                                          _selectCriticalUnclaimedFromCurrentQueue();
                                                      if (count == 0) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              l10n.contentComplianceSnackNoCriticalUnclaimedInList,
                                                            ),
                                                          ),
                                                        );
                                                        return;
                                                      }
                                                      _runBulkAction('claim');
                                                    },
                                          child: Text(l10n.contentComplianceBulkClaimOneClick),
                                        ),
                                      if (alert.stage == 'stalled_claimed')
                                        OutlinedButton(
                                          onPressed: widget.controller.loadingQueue
                                              ? null
                                              : () {
                                                  final count =
                                                      _selectStalledClaimedFromCurrentQueue();
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        l10n.contentComplianceSnackSelectedStalledClaimed(count),
                                                      ),
                                                    ),
                                                  );
                                                },
                                          child: Text(l10n.contentComplianceSelectStalled),
                                        ),
                                      if (alert.stage == 'stalled_claimed')
                                        FilledButton.tonal(
                                          onPressed: widget.controller
                                                  .mutatingQueue
                                              ? null
                                              : () => _runAutoRebalance(dryRun: true),
                                          child: Text(l10n.contentCompliancePreviewStalledRebalance),
                                        ),
                                      if (alert.stage == 'escalated_72h')
                                        OutlinedButton(
                                          onPressed: widget.controller.loadingQueue
                                              ? null
                                              : () {
                                                  final count =
                                                      _selectEscalated72hFromCurrentQueue();
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        l10n.contentComplianceSnackSelected72hUnconverged(count),
                                                      ),
                                                    ),
                                                  );
                                                },
                                          child: Text(l10n.contentComplianceLabelSelect72hUnconverged),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DropdownMenu<String>(
                      initialSelection: _queueStatus,
                      label: const Text('status'),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'all', label: 'all'),
                        DropdownMenuEntry(value: 'pending', label: 'pending'),
                        DropdownMenuEntry(value: 'claimed', label: 'claimed'),
                        DropdownMenuEntry(value: 'resolved', label: 'resolved'),
                        DropdownMenuEntry(
                          value: 'dismissed',
                          label: 'dismissed',
                        ),
                      ],
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          _queueStatus = value;
                        });
                        widget.controller.applyQueueFilters(
                          status: value,
                          category: _queueCategory,
                          targetType: _queueTargetType,
                          workspaceId: _queueWorkspaceId,
                          workspaceName: _queueWorkspaceName,
                          claimedByLabel: _queueClaimedByLabel,
                          slaBucket: _queueSlaBucket,
                          escalationStage: _queueEscalationStage,
                          claimedOnly: _queueClaimedOnly,
                        );
                      },
                    ),
                    DropdownMenu<String>(
                      initialSelection: _queueCategory,
                      label: const Text('category'),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'all', label: 'all'),
                        DropdownMenuEntry(
                          value: 'copyright',
                          label: 'copyright',
                        ),
                        DropdownMenuEntry(value: 'safety', label: 'safety'),
                        DropdownMenuEntry(
                          value: 'harassment',
                          label: 'harassment',
                        ),
                        DropdownMenuEntry(value: 'adult', label: 'adult'),
                        DropdownMenuEntry(value: 'violence', label: 'violence'),
                        DropdownMenuEntry(value: 'spam', label: 'spam'),
                        DropdownMenuEntry(value: 'other', label: 'other'),
                      ],
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          _queueCategory = value;
                        });
                        widget.controller.applyQueueFilters(
                          status: _queueStatus,
                          category: value,
                          targetType: _queueTargetType,
                          workspaceId: _queueWorkspaceId,
                          workspaceName: _queueWorkspaceName,
                          claimedByLabel: _queueClaimedByLabel,
                          slaBucket: _queueSlaBucket,
                          escalationStage: _queueEscalationStage,
                          claimedOnly: _queueClaimedOnly,
                        );
                      },
                    ),
                    DropdownMenu<String>(
                      initialSelection: _queueTargetType,
                      label: const Text('targetType'),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'all', label: 'all'),
                        DropdownMenuEntry(value: 'project', label: 'project'),
                        DropdownMenuEntry(value: 'script', label: 'script'),
                        DropdownMenuEntry(
                          value: 'storyboard',
                          label: 'storyboard',
                        ),
                        DropdownMenuEntry(value: 'asset', label: 'asset'),
                        DropdownMenuEntry(value: 'novel', label: 'novel'),
                        DropdownMenuEntry(value: 'user', label: 'user'),
                      ],
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          _queueTargetType = value;
                        });
                        widget.controller.applyQueueFilters(
                          status: _queueStatus,
                          category: _queueCategory,
                          targetType: value,
                          workspaceId: _queueWorkspaceId,
                          workspaceName: _queueWorkspaceName,
                          claimedByLabel: _queueClaimedByLabel,
                          slaBucket: _queueSlaBucket,
                          escalationStage: _queueEscalationStage,
                          claimedOnly: _queueClaimedOnly,
                        );
                      },
                    ),
                    FilterChip(
                      label: Text(l10n.contentComplianceClaimedOnly),
                      selected: _queueClaimedOnly,
                      onSelected: (selected) {
                        setState(() {
                          _queueClaimedOnly = selected;
                        });
                        widget.controller.applyQueueFilters(
                          status: _queueStatus,
                          category: _queueCategory,
                          targetType: _queueTargetType,
                          workspaceId: _queueWorkspaceId,
                          workspaceName: _queueWorkspaceName,
                          claimedByLabel: _queueClaimedByLabel,
                          slaBucket: _queueSlaBucket,
                          escalationStage: _queueEscalationStage,
                          claimedOnly: selected,
                        );
                      },
                    ),
                    if ((_queueWorkspaceId ?? '').isNotEmpty ||
                        (_queueWorkspaceName ?? '').isNotEmpty)
                      InputChip(
                        label: Text(_queueWorkspaceName ?? _queueWorkspaceId!),
                        onDeleted: () {
                          setState(() {
                            _queueWorkspaceId = null;
                            _queueWorkspaceName = null;
                          });
                          widget.controller.applyQueueFilters(
                            status: _queueStatus,
                            category: _queueCategory,
                            targetType: _queueTargetType,
                            workspaceId: '',
                            workspaceName: '',
                            claimedByLabel: _queueClaimedByLabel,
                            slaBucket: _queueSlaBucket,
                            escalationStage: _queueEscalationStage,
                            claimedOnly: _queueClaimedOnly,
                          );
                        },
                      ),
                    if ((_queueClaimedByLabel ?? '').isNotEmpty)
                      InputChip(
                        label: Text(
                          _queueClaimedByLabel == 'unclaimed'
                              ? l10n.contentComplianceOwnerChipUnclaimed
                              : l10n.contentComplianceOwnerChip(_queueClaimedByLabel!),
                        ),
                        onDeleted: () {
                          setState(() {
                            _queueClaimedByLabel = null;
                          });
                          widget.controller.applyQueueFilters(
                            status: _queueStatus,
                            category: _queueCategory,
                            targetType: _queueTargetType,
                            workspaceId: _queueWorkspaceId,
                            workspaceName: _queueWorkspaceName,
                            claimedByLabel: '',
                            slaBucket: _queueSlaBucket,
                            escalationStage: _queueEscalationStage,
                            claimedOnly: _queueClaimedOnly,
                          );
                        },
                      ),
                    if ((_queueSlaBucket ?? '').isNotEmpty)
                      InputChip(
                        label: Text('SLA: ${_queueSlaBucket!}'),
                        onDeleted: () {
                          setState(() {
                            _queueSlaBucket = null;
                          });
                          widget.controller.applyQueueFilters(
                            status: _queueStatus,
                            category: _queueCategory,
                            targetType: _queueTargetType,
                            workspaceId: _queueWorkspaceId,
                            workspaceName: _queueWorkspaceName,
                            claimedByLabel: _queueClaimedByLabel,
                            slaBucket: '',
                            escalationStage: _queueEscalationStage,
                            claimedOnly: _queueClaimedOnly,
                          );
                        },
                      ),
                    if ((_queueEscalationStage ?? '').isNotEmpty)
                      InputChip(
                        label: Text(
                          l10n.contentComplianceEscalationChipPrefix(
                            _escalationStageLabel(l10n, _queueEscalationStage!),
                          ),
                        ),
                        onDeleted: () {
                          setState(() {
                            _queueEscalationStage = null;
                          });
                          widget.controller.applyQueueFilters(
                            status: _queueStatus,
                            category: _queueCategory,
                            targetType: _queueTargetType,
                            workspaceId: _queueWorkspaceId,
                            workspaceName: _queueWorkspaceName,
                            claimedByLabel: _queueClaimedByLabel,
                            slaBucket: _queueSlaBucket,
                            escalationStage: '',
                            claimedOnly: _queueClaimedOnly,
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('pending ${queue.summary.pending}')),
                    Chip(label: Text('claimed ${queue.summary.claimed}')),
                    Chip(label: Text('resolved ${queue.summary.resolved}')),
                    Chip(label: Text('dismissed ${queue.summary.dismissed}')),
                    Chip(label: Text('critical ${queue.summary.critical}')),
                    Chip(label: Text('high ${queue.summary.high}')),
                    FilterChip(
                      label: Text('open>24h ${queue.sla.openOver24h}'),
                      selected: _queueSlaBucket == 'open_over_24h',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'open_over_24h'
                            ? null
                            : 'open_over_24h',
                      ),
                    ),
                    FilterChip(
                      label: Text('open>72h ${queue.sla.openOver72h}'),
                      selected: _queueSlaBucket == 'open_over_72h',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'open_over_72h'
                            ? null
                            : 'open_over_72h',
                      ),
                    ),
                    FilterChip(
                      label: Text('claimed>24h ${queue.sla.claimedOver24h}'),
                      selected: _queueSlaBucket == 'claimed_over_24h',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'claimed_over_24h'
                            ? null
                            : 'claimed_over_24h',
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        l10n.contentComplianceSlaUnclaimedCritical(queue.sla.unclaimedCritical),
                      ),
                      selected: _queueSlaBucket == 'unclaimed_critical',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'unclaimed_critical'
                            ? null
                            : 'unclaimed_critical',
                      ),
                    ),
                    Chip(
                      label: Text('oldest ${queue.sla.oldestOpenAgeHours}h'),
                    ),
                    Chip(
                      label: Text(
                        'capacity ${queue.capacity.reviewerCapacityLimit}/reviewer',
                      ),
                    ),
                    if (queue.capacity.overloadedReviewerCount > 0)
                      Chip(
                        label: Text(
                          l10n.contentComplianceOverloadedReviewers(
                            queue.capacity.overloadedReviewerCount,
                          ),
                        ),
                      ),
                    if (queue.capacity.overloadedClaimedCount > 0)
                      Chip(
                        label: Text(
                          l10n.contentComplianceRebalanceNeeded(
                            queue.capacity.overloadedClaimedCount,
                          ),
                        ),
                      ),
                  ],
                ),
                if (queue.ownerSummaries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.contentComplianceReviewerOwnerLoad,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: queue.ownerSummaries
                        .map(
                          (owner) => SizedBox(
                            width: 220,
                            child: OutlinedButton(
                              onPressed: widget.controller.loadingQueue
                                  ? null
                                  : () => _applyOwnerFilter(owner),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.all(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _ownerSummaryLabel(l10n, owner),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'pending ${owner.pendingCount} · claimed ${owner.claimedCount}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'critical ${owner.criticalOpenCount} · overdue ${owner.overdueCount} · oldest ${owner.oldestOpenAgeHours}h'
                                    '${owner.overCapacity ? l10n.contentComplianceOverCapacitySuffix(owner.overCapacityBy) : ''}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: owner.overCapacity
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if (queue.escalationSummaries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.contentComplianceEscalationRhythm, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: queue.escalationSummaries
                        .map(
                          (item) => FilterChip(
                            label: Text(
                              '${_escalationStageLabel(l10n, item.escalationStage)} ${item.reportCount}',
                            ),
                            selected:
                                _queueEscalationStage == item.escalationStage,
                            onSelected: (_) => _applyEscalationStageFilter(
                              _queueEscalationStage == item.escalationStage
                                  ? null
                                  : item.escalationStage,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if (queue.workspaceSummaries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.contentComplianceWorkspaceHotspots, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: queue.workspaceSummaries
                        .map(
                          (workspace) => SizedBox(
                            width: 230,
                            child: OutlinedButton(
                              onPressed: widget.controller.loadingQueue
                                  ? null
                                  : () => _applyWorkspaceFilter(workspace),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.all(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _workspaceSummaryLabel(l10n, workspace),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'open ${workspace.openCount} · pending ${workspace.pendingCount} · claimed ${workspace.claimedCount}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'critical ${workspace.criticalOpenCount} · high ${workspace.highOpenCount} · SLA ${workspace.slaBreachedCount} · oldest ${workspace.oldestOpenAgeHours}h',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 8),
                if (queue.items.isEmpty)
                  Text(
                    l10n.contentComplianceQueueEmpty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...queue.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _selectedReportIds.contains(item.id),
                                  onChanged: widget.controller.mutatingQueue
                                      ? null
                                      : (selected) {
                                          setState(() {
                                            if (selected == true) {
                                              _selectedReportIds.add(item.id);
                                            } else {
                                              _selectedReportIds.remove(
                                                item.id,
                                              );
                                            }
                                          });
                                        },
                                ),
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Chip(
                                        label: Text(
                                          '${item.targetType} · ${item.category}',
                                        ),
                                      ),
                                      Chip(label: Text(item.severity)),
                                      Chip(label: Text(item.status)),
                                      Chip(
                                        label: Text(
                                          _escalationStageLabel(
                                            l10n,
                                            item.escalationStage,
                                          ),
                                        ),
                                      ),
                                      if ((item.projectName ?? '').isNotEmpty)
                                        Chip(label: Text(item.projectName!)),
                                      if ((item.workspaceName ?? '').isNotEmpty)
                                        Chip(label: Text(item.workspaceName!)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              'report ${item.id}\n'
                              'target ${item.targetId}\n'
                              'reporter ${item.reporterEmail ?? item.reporterUserId}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _buildAuditLines(item).join('\n'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if ((item.detail ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                item.detail!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if ((item.resolutionNote ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'resolution: ${item.resolutionNote!}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: item.targetId),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.contentComplianceCopiedTargetUuid),
                                      ),
                                    );
                                  },
                                  child: Text(l10n.contentComplianceCopyTarget),
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: item.id),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.contentComplianceCopiedReportUuid),
                                      ),
                                    );
                                  },
                                  child: Text(l10n.contentComplianceCopyReport),
                                ),
                                if (widget.onOpenTarget != null)
                                  OutlinedButton(
                                    onPressed: () => widget.onOpenTarget!(item),
                                    child: Text(_openTargetLabel(l10n, item)),
                                  ),
                                if (widget.onOpenOpsTarget != null)
                                  OutlinedButton(
                                    onPressed: () =>
                                        widget.onOpenOpsTarget!(item),
                                    child: Text(l10n.contentComplianceAdminConsoleContext),
                                  ),
                                OutlinedButton(
                                  onPressed:
                                      widget.controller.loadingAuditReportId ==
                                          item.id
                                      ? null
                                      : () => _showAuditDialog(item),
                                  child: Text(
                                    widget.controller.loadingAuditReportId ==
                                            item.id
                                        ? l10n.contentComplianceLoadingAudit
                                        : l10n.contentComplianceViewAudit,
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      widget.controller.mutatingQueue ||
                                          item.status != 'pending'
                                      ? null
                                      : () => widget.controller.claimReport(
                                          item.id,
                                        ),
                                  child: const Text('claim'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      widget.controller.mutatingQueue ||
                                          (item.status != 'pending' &&
                                              item.status != 'claimed')
                                      ? null
                                      : () => widget.controller.resolveReport(
                                          item.id,
                                          status: 'resolved',
                                          disposition: _disposition,
                                          resolutionNote:
                                              _resolutionNoteController.text,
                                        ),
                                  child: const Text('resolve'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      widget.controller.mutatingQueue ||
                                          (item.status != 'pending' &&
                                              item.status != 'claimed')
                                      ? null
                                      : () => widget.controller.resolveReport(
                                          item.id,
                                          status: 'dismissed',
                                          disposition: _disposition,
                                          resolutionNote:
                                              _resolutionNoteController.text,
                                        ),
                                  child: const Text('dismiss'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (queue.items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reassignReviewerController,
                    decoration: InputDecoration(
                      labelText: l10n.contentComplianceBulkReassignReviewerLabel,
                      hintText: l10n.contentComplianceBulkReassignReviewerHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n.contentComplianceSelectedCount(_selectedReportIds.length)),
                        selected: _selectedReportIds.isNotEmpty,
                        onSelected: (_) {},
                      ),
                      OutlinedButton(
                        onPressed: widget.controller.mutatingQueue
                            ? null
                            : () {
                                final selectable = queue.items
                                    .where(
                                      (item) =>
                                          item.status == 'pending' ||
                                          item.status == 'claimed',
                                    )
                                    .map((item) => item.id)
                                    .toSet();
                                setState(() {
                                  _selectedReportIds
                                    ..clear()
                                    ..addAll(selectable);
                                });
                              },
                        child: Text(l10n.contentComplianceSelectAllOpen),
                      ),
                      OutlinedButton(
                        onPressed: _selectedReportIds.isEmpty
                            ? null
                            : () => setState(() {
                                _selectedReportIds.clear();
                              }),
                        child: Text(l10n.contentComplianceClearSelection),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            widget.controller.mutatingQueue ||
                                _selectedReportIds.isEmpty
                            ? null
                            : _runReassign,
                        child: Text(l10n.contentComplianceBulkReassign),
                      ),
                      FilledButton.tonal(
                        onPressed: widget.controller.mutatingQueue
                            ? null
                            : () => _runAutoRebalance(dryRun: true),
                        child: Text(l10n.contentComplianceAutoRebalanceTitlePreview),
                      ),
                      FilledButton(
                        onPressed: widget.controller.mutatingQueue
                            ? null
                            : () => _runAutoRebalance(dryRun: false),
                        child: Text(l10n.contentComplianceAutoRebalanceTitleExecute),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            widget.controller.mutatingQueue ||
                                _selectedReportIds.isEmpty
                            ? null
                            : () => _runBulkAction('claim'),
                        child: Text(l10n.contentComplianceBulkClaim),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            widget.controller.mutatingQueue ||
                                _selectedReportIds.isEmpty
                            ? null
                            : () => _runBulkAction('resolve'),
                        child: Text(l10n.contentComplianceBulkResolve),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            widget.controller.mutatingQueue ||
                                _selectedReportIds.isEmpty
                            ? null
                            : () => _runBulkAction('dismiss'),
                        child: Text(l10n.contentComplianceBulkDismiss),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                DropdownMenu<String>(
                  initialSelection: _disposition,
                  label: const Text('disposition'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'none', label: 'none'),
                    DropdownMenuEntry(
                      value: 'archive_project',
                      label: 'archive_project',
                    ),
                    DropdownMenuEntry(
                      value: 'suspend_user',
                      label: 'suspend_user',
                    ),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _disposition = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _resolutionNoteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'resolution note',
                    hintText: l10n.contentComplianceResolutionNoteHint,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
