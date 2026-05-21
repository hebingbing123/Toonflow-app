import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/components/studio_collapsible_filter_panel.dart';
import '../design_system/components/studio_code_dropdown_field.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../l10n/studio_code_labels.dart';
import '../rust_api.dart';
import 'controller.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

// Split into multiple files for maintainability
part 'section_helpers.dart';

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
  static const List<String> _reportTargetTypeCodes = <String>[
    'project',
    'script',
    'storyboard',
    'asset',
    'novel',
    'user',
  ];
  static const List<String> _categoryCodes = <String>[
    'copyright',
    'safety',
    'harassment',
    'adult',
    'violence',
    'spam',
    'other',
  ];
  static const List<String> _severityCodes = <String>[
    'low',
    'medium',
    'high',
    'critical',
  ];
  static const List<String> _queueStatusCodes = <String>[
    'all',
    'pending',
    'claimed',
    'resolved',
    'dismissed',
  ];
  static const List<String> _queueCategoryCodes = <String>[
    'all',
    ..._categoryCodes,
  ];
  static const List<String> _queueTargetTypeCodes = <String>[
    'all',
    ..._reportTargetTypeCodes,
  ];
  static const List<String> _dispositionCodes = <String>[
    'none',
    'archive_project',
    'suspend_user',
  ];

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

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final queue = widget.controller.queue;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: studioPanelBorderColor(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.contentComplianceTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.contentComplianceIntro,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.contentComplianceSubmitReportTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StudioCodeDropdownField(
                  value: _targetType,
                  labelText: l10n.contentComplianceFieldTargetType,
                  codes: _reportTargetTypeCodes,
                  labelForValue: (code) => _targetTypeLabel(l10n, code),
                  onChanged: (value) {
                    setState(() {
                      _targetType = value;
                    });
                  },
                ),
                StudioCodeDropdownField(
                  value: _category,
                  labelText: l10n.contentComplianceFieldCategory,
                  codes: _categoryCodes,
                  labelForValue: (code) => _categoryLabel(l10n, code),
                  onChanged: (value) {
                    setState(() {
                      _category = value;
                    });
                  },
                ),
                StudioCodeDropdownField(
                  value: _severity,
                  labelText: l10n.contentComplianceFieldSeverity,
                  codes: _severityCodes,
                  labelForValue: (code) => _severityLabel(l10n, code),
                  onChanged: (value) {
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
                labelText: l10n.contentComplianceFieldTargetUuid,
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
                    child: Text(
                      l10n.contentComplianceQueueTitle,
                      style: theme.textTheme.titleSmall,
                    ),
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
                          (a, b) =>
                              _alertPriority(a).compareTo(_alertPriority(b)),
                        );
                      final topAlert = sortedAlerts.first;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _alertBorderColor(context, topAlert.level),
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
                                if (_effectiveTopSecondaryLabel(
                                      l10n,
                                      topAlert,
                                    ) !=
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
                                      _effectiveTopSecondaryLabel(
                                        l10n,
                                        topAlert,
                                      )!,
                                    ),
                                  ),
                                OutlinedButton(
                                  onPressed: widget.controller.loadingQueue
                                      ? null
                                      : () =>
                                            _applyAlertShortcut(topAlert.stage),
                                  child: Text(l10n.contentComplianceViewLayer),
                                ),
                                OutlinedButton(
                                  key: const ValueKey(
                                    'contentComplianceResetAlertPreferences',
                                  ),
                                  onPressed:
                                      _preferSecondaryAsPrimaryStages.isEmpty
                                      ? null
                                      : _resetAlertActionPreferences,
                                  child: Text(
                                    l10n.contentComplianceRestoreDefaultActionOrder,
                                  ),
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
                          (a, b) =>
                              _alertPriority(a).compareTo(_alertPriority(b)),
                        );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sortedAlerts
                            .map(
                              (alert) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _alertBorderColor(
                                        context,
                                        alert.level,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${alert.title} (${alert.count})',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        alert.message,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: tokens.textSecondary,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton(
                                            onPressed:
                                                widget.controller.loadingQueue
                                                ? null
                                                : () => _applyAlertShortcut(
                                                    alert.stage,
                                                  ),
                                            child: Text(
                                              l10n.contentComplianceViewLayer,
                                            ),
                                          ),
                                          if (alert.stage == 'over_capacity')
                                            FilledButton.tonal(
                                              onPressed:
                                                  widget
                                                      .controller
                                                      .mutatingQueue
                                                  ? null
                                                  : () => _runAutoRebalance(
                                                      dryRun: true,
                                                    ),
                                              child: Text(
                                                l10n.contentCompliancePreviewRebalanceShort,
                                              ),
                                            ),
                                          if (alert.stage == 'over_capacity')
                                            FilledButton(
                                              onPressed:
                                                  widget
                                                      .controller
                                                      .mutatingQueue
                                                  ? null
                                                  : () => _runAutoRebalance(
                                                      dryRun: false,
                                                    ),
                                              child: Text(
                                                l10n.contentComplianceExecuteRebalanceShort,
                                              ),
                                            ),
                                          if (alert.stage ==
                                              'critical_unclaimed')
                                            OutlinedButton(
                                              onPressed:
                                                  widget.controller.loadingQueue
                                                  ? null
                                                  : () {
                                                      final count =
                                                          _selectCriticalUnclaimedFromCurrentQueue();
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            l10n.contentComplianceSnackSelectedCriticalReadyClaim(
                                                              count,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              child: Text(
                                                l10n.contentComplianceSelectCriticalUnclaimed,
                                              ),
                                            ),
                                          if (alert.stage ==
                                              'critical_unclaimed')
                                            FilledButton(
                                              onPressed:
                                                  widget
                                                      .controller
                                                      .mutatingQueue
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
                                              child: Text(
                                                l10n.contentComplianceBulkClaimOneClick,
                                              ),
                                            ),
                                          if (alert.stage == 'stalled_claimed')
                                            OutlinedButton(
                                              onPressed:
                                                  widget.controller.loadingQueue
                                                  ? null
                                                  : () {
                                                      final count =
                                                          _selectStalledClaimedFromCurrentQueue();
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            l10n.contentComplianceSnackSelectedStalledClaimed(
                                                              count,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              child: Text(
                                                l10n.contentComplianceSelectStalled,
                                              ),
                                            ),
                                          if (alert.stage == 'stalled_claimed')
                                            FilledButton.tonal(
                                              onPressed:
                                                  widget
                                                      .controller
                                                      .mutatingQueue
                                                  ? null
                                                  : () => _runAutoRebalance(
                                                      dryRun: true,
                                                    ),
                                              child: Text(
                                                l10n.contentCompliancePreviewStalledRebalance,
                                              ),
                                            ),
                                          if (alert.stage == 'escalated_72h')
                                            OutlinedButton(
                                              onPressed:
                                                  widget.controller.loadingQueue
                                                  ? null
                                                  : () {
                                                      final count =
                                                          _selectEscalated72hFromCurrentQueue();
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            l10n.contentComplianceSnackSelected72hUnconverged(
                                                              count,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              child: Text(
                                                l10n.contentComplianceLabelSelect72hUnconverged,
                                              ),
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
                StudioCollapsibleFilterPanel(
                  subtitle: _queueFilterSummary(l10n, queue),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StudioCodeDropdownField(
                      value: _queueStatus,
                      labelText: l10n.contentComplianceFieldStatus,
                      codes: _queueStatusCodes,
                      labelForValue: (code) => _statusLabel(l10n, code),
                      onChanged: (value) {
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
                    StudioCodeDropdownField(
                      value: _queueCategory,
                      labelText: l10n.contentComplianceFieldCategory,
                      codes: _queueCategoryCodes,
                      labelForValue: (code) => _categoryLabel(l10n, code),
                      onChanged: (value) {
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
                    StudioCodeDropdownField(
                      value: _queueTargetType,
                      labelText: l10n.contentComplianceFieldTargetType,
                      codes: _queueTargetTypeCodes,
                      labelForValue: (code) => _targetTypeLabel(l10n, code),
                      onChanged: (value) {
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
                              : l10n.contentComplianceOwnerChip(
                                  _queueClaimedByLabel!,
                                ),
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
                        label: Text(
                          l10n.contentComplianceSlaChip(
                            _slaBucketLabel(l10n, _queueSlaBucket!),
                          ),
                        ),
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
                    Chip(
                      label: Text(
                        l10n.contentComplianceMetricPending(
                          queue.summary.pending,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        l10n.contentComplianceMetricClaimed(
                          queue.summary.claimed,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        l10n.contentComplianceMetricResolved(
                          queue.summary.resolved,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        l10n.contentComplianceMetricDismissed(
                          queue.summary.dismissed,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        l10n.contentComplianceMetricCritical(
                          queue.summary.critical,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        l10n.contentComplianceMetricHigh(queue.summary.high),
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        l10n.contentComplianceSlaOpenOver24h(
                          queue.sla.openOver24h,
                        ),
                      ),
                      selected: _queueSlaBucket == 'open_over_24h',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'open_over_24h'
                            ? null
                            : 'open_over_24h',
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        l10n.contentComplianceSlaOpenOver72h(
                          queue.sla.openOver72h,
                        ),
                      ),
                      selected: _queueSlaBucket == 'open_over_72h',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'open_over_72h'
                            ? null
                            : 'open_over_72h',
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        l10n.contentComplianceSlaClaimedOver24h(
                          queue.sla.claimedOver24h,
                        ),
                      ),
                      selected: _queueSlaBucket == 'claimed_over_24h',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'claimed_over_24h'
                            ? null
                            : 'claimed_over_24h',
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        l10n.contentComplianceSlaUnclaimedCritical(
                          queue.sla.unclaimedCritical,
                        ),
                      ),
                      selected: _queueSlaBucket == 'unclaimed_critical',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'unclaimed_critical'
                            ? null
                            : 'unclaimed_critical',
                      ),
                    ),
                    Chip(
                      label: Text(
                        l10n.contentComplianceOldestHours(
                          queue.sla.oldestOpenAgeHours,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        l10n.contentComplianceCapacityPerReviewer(
                          queue.capacity.reviewerCapacityLimit,
                        ),
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
                                    l10n.contentComplianceOwnerCounts(
                                      owner.pendingCount,
                                      owner.claimedCount,
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.contentComplianceOwnerDetail(
                                      [
                                        l10n.contentComplianceMetricCritical(
                                          owner.criticalOpenCount,
                                        ),
                                        l10n.contentComplianceMetricOverdue(
                                          owner.overdueCount,
                                        ),
                                        l10n.contentComplianceOldestHours(
                                          owner.oldestOpenAgeHours,
                                        ),
                                        if (owner.overCapacity)
                                          l10n.contentComplianceOverCapacitySuffix(
                                            owner.overCapacityBy,
                                          ),
                                      ].join(' · '),
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: owner.overCapacity
                                          ? theme.colorScheme.error
                                          : tokens.textSecondary,
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
                  Text(
                    l10n.contentComplianceEscalationRhythm,
                    style: theme.textTheme.titleSmall,
                  ),
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
                  Text(
                    l10n.contentComplianceWorkspaceHotspots,
                    style: theme.textTheme.titleSmall,
                  ),
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
                                    l10n.contentComplianceWorkspaceCounts(
                                      workspace.openCount,
                                      workspace.pendingCount,
                                      workspace.claimedCount,
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.contentComplianceWorkspaceDetail(
                                      workspace.criticalOpenCount,
                                      workspace.highOpenCount,
                                      workspace.slaBreachedCount,
                                      workspace.oldestOpenAgeHours,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: tokens.textSecondary,
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
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (queue.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: StudioEmptyState.emptyData(
                      title: l10n.contentComplianceQueueEmpty,
                      icon: Icons.fact_check_outlined,
                    ),
                  )
                else
                  ...queue.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: studioPanelBorderColor(context),
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
                                          '${_targetTypeLabel(l10n, item.targetType)} · ${_categoryLabel(l10n, item.category)}',
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          _severityLabel(l10n, item.severity),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          _statusLabel(l10n, item.status),
                                        ),
                                      ),
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
                              l10n.contentComplianceReportInfo(
                                item.id,
                                item.targetId,
                                item.reporterEmail ?? item.reporterUserId,
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _buildAuditLines(l10n, item).join('\n'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
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
                                l10n.contentComplianceResolutionLine(
                                  item.resolutionNote!,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: StudioLayoutSpacing.inlineGap),
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
                                        content: Text(
                                          l10n.contentComplianceCopiedTargetUuid,
                                        ),
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
                                        content: Text(
                                          l10n.contentComplianceCopiedReportUuid,
                                        ),
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
                                    child: Text(
                                      l10n.contentComplianceAdminConsoleContext,
                                    ),
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
                                  child: Text(
                                    l10n.contentComplianceActionClaim,
                                  ),
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
                                  child: Text(
                                    l10n.contentComplianceActionResolve,
                                  ),
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
                                  child: Text(
                                    l10n.contentComplianceActionDismiss,
                                  ),
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
                      labelText:
                          l10n.contentComplianceBulkReassignReviewerLabel,
                      hintText: l10n.contentComplianceBulkReassignReviewerHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(
                          l10n.contentComplianceSelectedCount(
                            _selectedReportIds.length,
                          ),
                        ),
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
                        child: Text(
                          l10n.contentComplianceAutoRebalanceTitlePreview,
                        ),
                      ),
                      FilledButton(
                        onPressed: widget.controller.mutatingQueue
                            ? null
                            : () => _runAutoRebalance(dryRun: false),
                        child: Text(
                          l10n.contentComplianceAutoRebalanceTitleExecute,
                        ),
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
                StudioCodeDropdownField(
                  value: _disposition,
                  labelText: l10n.contentComplianceFieldDisposition,
                  codes: _dispositionCodes,
                  labelForValue: (code) => _dispositionCodeLabel(l10n, code),
                  onChanged: (value) {
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
                    labelText: l10n.contentComplianceFieldResolutionNote,
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
