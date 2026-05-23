import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';

import '../l10n/app_localizations.dart';
import '../l10n/studio_code_labels.dart';
import '../l10n/billing_l10n_helpers.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_collapsible_filter_panel.dart';
import '../design_system/components/studio_filter_row.dart';
import '../design_system/components/studio_skeleton.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../utils/localized_formatting.dart';
import 'controller.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

class NotificationsSection extends StatefulWidget {
  const NotificationsSection({
    super.key,
    required this.controller,
    required this.onOpenNotification,
    this.studioPresentation = false,
  });

  final NotificationsController controller;
  final ValueChanged<NotificationRecordV1> onOpenNotification;
  final bool studioPresentation;

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> {
  static const List<String> _complianceStages = <String>[
    'critical_unclaimed',
    'over_capacity',
    'stalled_claimed',
    'escalated_72h',
  ];

  final _searchController = TextEditingController();
  final _workspaceAuditTemplateFilterController = TextEditingController();
  final _workspaceAuditStartAtController = TextEditingController();
  final _workspaceAuditEndAtController = TextEditingController();
  final _clearedThrottleController = TextEditingController();
  final _clearedThrottleFocus = FocusNode();
  final Map<String, TextEditingController> _stageThrottleControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _stageThrottleFocusNodes = <String, FocusNode>{};
  String _typeFilter = 'all';
  bool _unreadOnly = false;
  bool _customTemplatesOnly = false;
  String _workspaceAuditActionFilter = '';
  String _exportHistoryFormat = '';
  final _exportHistoryExportedStartController = TextEditingController();
  final _exportHistoryExportedEndController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _clearedThrottleController.text =
        '${widget.controller.contentComplianceClearedThrottleMinutes}';
    for (final stage in _complianceStages) {
      _stageThrottleControllers[stage] = TextEditingController();
      _stageThrottleFocusNodes[stage] = FocusNode();
    }
    _syncStageThrottleControllersFromState();
    widget.controller.addListener(_handleControllerChanged);
    _primeControllerSoon();
  }

  @override
  void didUpdateWidget(covariant NotificationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _primeControllerSoon();
    }
  }

  void _primeControllerSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.prime();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _searchController.dispose();
    _workspaceAuditTemplateFilterController.dispose();
    _workspaceAuditStartAtController.dispose();
    _workspaceAuditEndAtController.dispose();
    _exportHistoryExportedStartController.dispose();
    _exportHistoryExportedEndController.dispose();
    _clearedThrottleController.dispose();
    _clearedThrottleFocus.dispose();
    for (final controller in _stageThrottleControllers.values) {
      controller.dispose();
    }
    for (final node in _stageThrottleFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!_clearedThrottleFocus.hasFocus) {
      final next =
          '${widget.controller.contentComplianceClearedThrottleMinutes}';
      if (_clearedThrottleController.text != next) {
        _clearedThrottleController.text = next;
      }
    }
    _syncStageThrottleControllersFromState();
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildStudioLoadingBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: studioInsetPanelDecoration(context),
        child: const Padding(
          padding: EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              StudioSkeleton(height: 18),
              SizedBox(height: StudioSpacing.sm),
              StudioSkeleton(height: 72),
              SizedBox(height: StudioSpacing.sm),
              StudioSkeleton(height: 72),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudioHeader(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration:
          studioInsetPanelDecoration(
            context,
            backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
          ).copyWith(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.notificationsCenterTitle,
                    style: studioPaneTitleStyle(context),
                  ),
                  const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
                  Text(
                    l10n.notificationsCenterSubtitle,
                    style: studioSectionIntroStyle(context),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed:
                  widget.controller.markingAllRead ||
                      widget.controller.unreadCount == 0
                  ? null
                  : widget.controller.markAllRead,
              icon: widget.controller.markingAllRead
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all_outlined, size: 18),
              label: Text(l10n.notificationsMarkAllRead),
            ),
          ],
        ),
      ),
    );
  }

  void _syncStageThrottleControllersFromState() {
    final stagePolicy =
        widget.controller.contentComplianceClearedStageThrottleMinutes;
    for (final stage in _complianceStages) {
      final controller = _stageThrottleControllers[stage];
      final focusNode = _stageThrottleFocusNodes[stage];
      if (controller == null || focusNode == null || focusNode.hasFocus) {
        continue;
      }
      final minutes = stagePolicy[stage];
      final nextText = minutes == null ? '' : '$minutes';
      if (controller.text != nextText) {
        controller.text = nextText;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final needle = _searchController.text.trim().toLowerCase();
    final filtered = widget.controller.items
        .where((item) {
          if (_unreadOnly && !item.isUnread) {
            return false;
          }
          if (_typeFilter != 'all' &&
              !_matchesTypeFilter(item.notificationType)) {
            return false;
          }
          if (needle.isEmpty) {
            return true;
          }
          final haystack = <String>[
            item.title,
            item.message,
            item.notificationType,
            item.filePath ?? '',
            item.jobId ?? '',
            item.workspaceId ?? '',
            item.projectId ?? '',
            item.payload.toString(),
          ].join(' ').toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.studioPresentation)
            _buildStudioHeader(context, l10n)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.notificationsCenterTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.notificationsCenterSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: StudioTokens.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      widget.controller.markingAllRead ||
                          widget.controller.unreadCount == 0
                      ? null
                      : widget.controller.markAllRead,
                  icon: widget.controller.markingAllRead
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.done_all_outlined),
                  label: Text(l10n.notificationsMarkAllRead),
                ),
                const SizedBox(width: 4),
                RiskyOperationConfirmPrefsOverflowMenu(
                  tooltip: l10n.notificationsRiskyPrefsTooltip,
                ),
              ],
            ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          if (widget.studioPresentation)
            ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(l10n.studioNotificationsAdvanced),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: RiskyOperationConfirmPrefsOverflowMenu(
                    tooltip: l10n.notificationsRiskyPrefsTooltip,
                  ),
                ),
                const SizedBox(height: 8),
                _buildComplianceAdminPanel(context, theme, l10n),
              ],
            )
          else
            _buildComplianceAdminPanel(context, theme, l10n),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          _buildNotificationListFilters(l10n),
          const SizedBox(height: 12),
          if (widget.controller.loading)
            widget.studioPresentation
                ? _buildStudioLoadingBody(context)
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: StudioEmptyState.noResults(
                title: l10n.notificationsEmptyFiltered,
              ),
            )
          else
            ...filtered.map(
              (item) => _buildNotificationTile(context, l10n, item),
            ),
          if (widget.controller.hasMore) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.controller.loadingMore
                    ? null
                    : widget.controller.loadMore,
                icon: widget.controller.loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(l10n.notificationsLoadMore),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationListFilters(AppLocalizations l10n) {
    final filters = StudioFilterRow(
      wideLayout: widget.studioPresentation
          ? StudioFilterWideLayout.toolbarRow
          : StudioFilterWideLayout.wrap,
      children: _notificationListFilterChildren(
        l10n,
        toolbar: widget.studioPresentation,
      ),
    );
    if (!widget.studioPresentation) {
      return filters;
    }
    return StudioCollapsibleFilterPanel(
      subtitle: _notificationListFilterSummary(l10n),
      child: filters,
    );
  }

  String? _notificationListFilterSummary(AppLocalizations l10n) {
    final parts = <String>[];
    if (_unreadOnly) {
      parts.add(l10n.notificationsFilterUnread(widget.controller.unreadCount));
    }
    if (_typeFilter != 'all') {
      parts.add(_notificationFilterTypeLabel(l10n, _typeFilter));
    }
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      parts.add('${l10n.notificationsSearchLabel}: $query');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }

  String _notificationFilterTypeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'job':
        return l10n.notificationsTypeJob;
      case 'workspace':
        return l10n.notificationsTypeWorkspace;
      case 'skill':
        return l10n.notificationsTypeSkill;
      case 'compliance':
        return l10n.notificationsTypeCompliance;
      default:
        return l10n.notificationsTypeAll;
    }
  }

  List<Widget> _notificationListFilterChildren(
    AppLocalizations l10n, {
    required bool toolbar,
  }) {
    final typeField = SizedBox(
      width: toolbar ? 200 : 220,
      child: StudioDropdownButtonFormField<String>(
        initialValue: _typeFilter,
        decoration: InputDecoration(
          labelText: l10n.notificationsTypeFilterLabel,
          isDense: true,
        ),
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Text(l10n.notificationsTypeAll),
          ),
          DropdownMenuItem(
            value: 'job',
            child: Text(l10n.notificationsTypeJob),
          ),
          DropdownMenuItem(
            value: 'workspace',
            child: Text(l10n.notificationsTypeWorkspace),
          ),
          DropdownMenuItem(
            value: 'skill',
            child: Text(l10n.notificationsTypeSkill),
          ),
          DropdownMenuItem(
            value: 'compliance',
            child: Text(l10n.notificationsTypeCompliance),
          ),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }
          setState(() {
            _typeFilter = value;
          });
        },
      ),
    );

    final searchField = TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: l10n.notificationsSearchLabel,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
      ),
    );

    final refreshButton = TextButton.icon(
      onPressed: widget.controller.loading
          ? null
          : widget.controller.refresh,
      icon: const Icon(Icons.refresh, size: 18),
      label: Text(l10n.notificationsRefresh),
    );

    return <Widget>[
      FilterChip(
        selected: _unreadOnly,
        onSelected: (selected) {
          setState(() {
            _unreadOnly = selected;
          });
        },
        label: Text(
          l10n.notificationsFilterUnread(widget.controller.unreadCount),
        ),
      ),
      typeField,
      if (toolbar) Expanded(child: searchField) else SizedBox(width: 280, child: searchField),
      refreshButton,
    ];
  }

  static const double _kComplianceFilterFieldWidth = 220;

  TextStyle? _complianceMutedStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
      color: StudioTokens.of(context).textSecondary,
    );
  }

  Widget _complianceLabeledField(
    BuildContext context, {
    required String label,
    required Widget child,
    double width = _kComplianceFilterFieldWidth,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: StudioTokens.of(context).textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Semantics(
            label: label,
            textField: true,
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceAdminPanel(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final muted = _complianceMutedStyle(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: studioPanelBorderColor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudioCollapsibleFilterPanel(
            title: l10n.notificationsComplianceClearedThrottleTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StudioFilterRow(
                  wideBreakpoint: 640,
                  children: <Widget>[
                    Text(
                      l10n.notificationsComplianceClearedThrottleTitle,
                style: theme.textTheme.bodyMedium,
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _clearedThrottleController,
                  focusNode: _clearedThrottleFocus,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.notificationsComplianceMinutesHint,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: widget.controller.savingPreferences
                    ? null
                    : _saveClearedThrottlePolicy,
                child: widget.controller.savingPreferences
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.notificationsComplianceSavePolicy),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.savingPreferences
                    ? null
                    : _createTemplateFromCurrentPolicy,
                icon: const Icon(Icons.add),
                label: Text(l10n.notificationsComplianceSaveAsTemplate),
              ),
              OutlinedButton.icon(
                onPressed:
                    widget.controller.savingPreferences ||
                        !widget.controller.canManageWorkspaceSharedTemplates
                    ? null
                    : _createWorkspaceSharedTemplateFromCurrentPolicy,
                icon: const Icon(Icons.group_work_outlined),
                label: Text(l10n.notificationsComplianceSaveToWorkspaceShared),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.savingPreferences
                    ? null
                    : _exportTemplatesToClipboard,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l10n.notificationsComplianceExportTemplatesJson),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.savingPreferences
                    ? null
                    : _openImportTemplatesDialog,
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.notificationsComplianceImportTemplatesJson),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.notificationsComplianceClearedHelpShort, style: muted),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              selected: _customTemplatesOnly,
              label: Text(l10n.notificationsComplianceCustomTemplatesOnly),
              onSelected: (selected) {
                setState(() {
                  _customTemplatesOnly = selected;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ...widget.controller.complianceClearedTemplates
                  .where(
                    (template) =>
                        !_customTemplatesOnly || template.kind == 'custom',
                  )
                  .map(
                    (template) => Tooltip(
                      message: template.description,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ActionChip(
                            label: Text(
                              l10n.notificationsComplianceTemplateChip(
                                template.label,
                              ),
                            ),
                            onPressed: widget.controller.savingPreferences
                                ? null
                                : () => _applyThrottleTemplate(template.id),
                          ),
                          IconButton(
                            tooltip: l10n.notificationsComplianceTooltipMoveUp,
                            onPressed: widget.controller.savingPreferences
                                ? null
                                : () => _reorderTemplate(template.id, up: true),
                            icon: const Icon(Icons.arrow_upward, size: 18),
                          ),
                          IconButton(
                            tooltip:
                                l10n.notificationsComplianceTooltipMoveDown,
                            onPressed: widget.controller.savingPreferences
                                ? null
                                : () =>
                                      _reorderTemplate(template.id, up: false),
                            icon: const Icon(Icons.arrow_downward, size: 18),
                          ),
                          IconButton(
                            tooltip:
                                l10n.notificationsComplianceTooltipEditTemplate,
                            onPressed:
                                widget.controller.savingPreferences ||
                                    !template.canEdit
                                ? null
                                : () => _editTemplate(template),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            tooltip: l10n
                                .notificationsComplianceTooltipDeleteTemplate,
                            onPressed:
                                widget.controller.savingPreferences ||
                                    !template.canDelete
                                ? null
                                : () => _deleteTemplate(template),
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
          if (widget
              .controller
              .workspaceSharedComplianceTemplates
              .isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              l10n.notificationsComplianceWorkspaceSharedHeader,
              style: muted,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: widget.controller.workspaceSharedComplianceTemplates
                  .map(
                    (template) => Tooltip(
                      message: template.description,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ActionChip(
                            label: Text(
                              l10n.notificationsComplianceSharedChip(
                                template.label,
                              ),
                            ),
                            onPressed: widget.controller.savingPreferences
                                ? null
                                : () => _applyThrottleTemplate(template.id),
                          ),
                          IconButton(
                            tooltip: l10n
                                .notificationsComplianceTooltipEditSharedTemplate,
                            onPressed:
                                widget.controller.savingPreferences ||
                                    !widget
                                        .controller
                                        .canManageWorkspaceSharedTemplates
                                ? null
                                : () => _editWorkspaceSharedTemplate(template),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            tooltip: l10n
                                .notificationsComplianceTooltipDeleteSharedTemplate,
                            onPressed:
                                widget.controller.savingPreferences ||
                                    !widget
                                        .controller
                                        .canManageWorkspaceSharedTemplates
                                ? null
                                : () =>
                                      _deleteWorkspaceSharedTemplate(template),
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
              ],
            ),
          ),
          StudioCollapsibleFilterPanel(
            title: l10n.studioFilterToolbarTitle,
            subtitle: l10n.notificationsComplianceStageOverrideHint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StudioFilterRow(
                  wideBreakpoint: 720,
                  wideLayout: StudioFilterWideLayout.wrap,
                  children: _complianceStages
                      .map(
                        (stage) => SizedBox(
                          width: 200,
                          child: _complianceLabeledField(
                            context,
                            label:
                                l10n.notificationsComplianceStageOverrideLabel(
                              studioNotificationsComplianceStageLabel(
                                l10n,
                                stage,
                              ),
                            ),
                            width: 200,
                            child: TextField(
                              controller: _stageThrottleControllers[stage],
                              focusNode: _stageThrottleFocusNodes[stage],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: l10n
                                    .notificationsComplianceStageOverrideHint,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  _buildPreferencesAuditText(
                    l10n,
                    widget.controller.preferencesAudit,
                  ),
                  style: muted,
                ),
              ],
            ),
          ),
          _buildWorkspaceSharedAuditSection(context, theme, l10n),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSharedAuditSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final muted = _complianceMutedStyle(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudioCollapsibleFilterPanel(
          title: l10n.notificationsComplianceSharedAuditTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              StudioFilterRow(
                wideBreakpoint: 720,
                wideLayout: StudioFilterWideLayout.toolbarRow,
                children: <Widget>[
                  _complianceLabeledField(
                    context,
                    label: l10n.notificationsComplianceFilterTemplateId,
              child: TextField(
                controller: _workspaceAuditTemplateFilterController,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            _complianceLabeledField(
              context,
              label: l10n.notificationsComplianceFilterAction,
              child: StudioDropdownButtonFormField<String>(
                initialValue: _workspaceAuditActionFilter,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.notificationsTypeAll),
                  ),
                  DropdownMenuItem(
                    value: 'upsert',
                    child: Text(l10n.notificationsAuditActionUpsert),
                  ),
                  DropdownMenuItem(
                    value: 'delete',
                    child: Text(l10n.notificationsAuditActionDelete),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _workspaceAuditActionFilter = value ?? '';
                  });
                },
              ),
            ),
            _complianceLabeledField(
              context,
              label: l10n.notificationsComplianceFilterStartIso,
              child: TextField(
                controller: _workspaceAuditStartAtController,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            _complianceLabeledField(
              context,
              label: l10n.notificationsComplianceFilterEndIso,
              child: TextField(
                controller: _workspaceAuditEndAtController,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
                ],
              ),
              const SizedBox(height: 8),
              StudioFilterRow(
                wideBreakpoint: 480,
                wideLayout: StudioFilterWideLayout.toolbarRow,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: widget.controller.loadingWorkspaceSharedAudit
                        ? null
                        : _reloadWorkspaceAuditWithFilters,
                    child: Text(l10n.notificationsComplianceApplyFilters),
                  ),
            OutlinedButton.icon(
              onPressed: widget.controller.loadingWorkspaceSharedAudit
                  ? null
                  : _exportWorkspaceAuditJsonToClipboard,
              icon: const Icon(Icons.data_object),
              label: Text(l10n.notificationsComplianceDownloadAuditJson),
            ),
            OutlinedButton.icon(
              onPressed: widget.controller.loadingWorkspaceSharedAudit
                  ? null
                  : _exportWorkspaceAuditCsvToClipboard,
              icon: const Icon(Icons.table_chart_outlined),
              label: Text(l10n.notificationsComplianceDownloadAuditCsv),
            ),
            OutlinedButton.icon(
              onPressed:
                  widget.controller.loadingWorkspaceSharedAudit ||
                      widget
                          .controller
                          .enqueueingWorkspaceSharedAuditAsyncExport
                  ? null
                  : () => _enqueueWorkspaceSharedAuditExportAsync('json'),
              icon: const Icon(Icons.hourglass_empty_outlined),
              label: Text(l10n.notificationsComplianceAsyncJson),
            ),
            OutlinedButton.icon(
              onPressed:
                  widget.controller.loadingWorkspaceSharedAudit ||
                      widget
                          .controller
                          .enqueueingWorkspaceSharedAuditAsyncExport
                  ? null
                  : () => _enqueueWorkspaceSharedAuditExportAsync('csv'),
              icon: const Icon(Icons.hourglass_empty_outlined),
              label: Text(l10n.notificationsComplianceAsyncCsv),
            ),
                ],
              ),
            ],
          ),
        ),
        if ((widget.controller.workspaceSharedAsyncExportInfo ?? '')
            .trim()
            .isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                widget.controller.workspaceSharedAsyncExportInfo!,
                style: theme.textTheme.bodySmall,
              ),
              trailing: IconButton(
                tooltip: l10n.notificationsComplianceCloseTooltip,
                icon: const Icon(Icons.close),
                onPressed:
                    widget.controller.clearWorkspaceSharedAsyncExportInfo,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        StudioCollapsibleFilterPanel(
          title: l10n.notificationsComplianceExportHistoryTitle,
          child: StudioFilterRow(
            wideBreakpoint: 720,
            wideLayout: StudioFilterWideLayout.toolbarRow,
            children: <Widget>[
              _complianceLabeledField(
                context,
                label: l10n.notificationsComplianceExportFormatFilter,
              width: 180,
              child: StudioDropdownButtonFormField<String>(
                // Controlled by _exportHistoryFormat via setState.
                // ignore: deprecated_member_use
                value: _exportHistoryFormat,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.notificationsTypeAll),
                  ),
                  DropdownMenuItem(
                    value: 'json',
                    child: Text(l10n.notificationsComplianceExportFormatJson),
                  ),
                  DropdownMenuItem(
                    value: 'csv',
                    child: Text(l10n.notificationsComplianceExportFormatCsv),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _exportHistoryFormat = value ?? '';
                  });
                },
              ),
            ),
            _complianceLabeledField(
              context,
              label: l10n.notificationsComplianceExportedStartIso,
              child: TextField(
                controller: _exportHistoryExportedStartController,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            _complianceLabeledField(
              context,
              label: l10n.notificationsComplianceExportedEndIso,
              child: TextField(
                controller: _exportHistoryExportedEndController,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: widget.controller.loadingExportHistory
                    ? null
                    : _applyExportHistoryFilters,
                child: widget.controller.loadingExportHistory
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.notificationsComplianceFilterExports),
              ),
            ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...widget.controller.workspaceSharedAuditExports.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Tooltip(
              message: _formatWorkspaceAuditExportItem(l10n, item),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _formatWorkspaceAuditExportItem(l10n, item),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: muted,
                    ),
                  ),
                  IconButton(
                    tooltip:
                        l10n.notificationsComplianceReuseExportFiltersTooltip,
                    onPressed: widget.controller.loadingWorkspaceSharedAudit
                        ? null
                        : () => _reuseExportRecordFilters(item),
                    icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: _exportRecordDownloadTooltip(l10n, item),
                    onPressed: widget.controller.loadingExportHistory
                        ? null
                        : () => _redownloadFromExportRecord(item),
                    icon: const Icon(Icons.download_outlined, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.controller.workspaceSharedExportHistoryHasMore)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.controller.loadingExportHistory
                  ? null
                  : widget.controller.loadMoreExportHistory,
              icon: widget.controller.loadingExportHistory
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more, size: 18),
              label: Text(l10n.notificationsComplianceMoreExportRecords),
            ),
          ),
        const SizedBox(height: 12),
        ...widget.controller.workspaceSharedComplianceAudit
            .take(6)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _formatWorkspaceAuditItem(l10n, item),
                  style: muted,
                ),
              ),
            ),
        if (widget.controller.workspaceSharedAuditHasMore)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.controller.loadingWorkspaceSharedAudit
                  ? null
                  : widget.controller.loadMoreWorkspaceSharedComplianceAudit,
              icon: widget.controller.loadingWorkspaceSharedAudit
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more, size: 18),
              label: Text(l10n.notificationsComplianceLoadMoreAudit),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppLocalizations l10n,
    NotificationRecordV1 item,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
      decoration: BoxDecoration(
        border: Border.all(
          color: item.isUnread
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : studioPanelBorderColor(context),
        ),
        borderRadius: BorderRadius.circular(8),
        color: item.isUnread
            ? StudioTokens.of(context).primarySoft.withValues(alpha: 0.18)
            : null,
      ),
      child: ListTile(
        leading: Icon(_iconForType(item.notificationType)),
        title: Row(
          children: [
            Expanded(child: Text(item.title)),
            if (item.isUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: StudioTokens.of(context).primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.notificationsUnreadBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.message),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                '${_notificationTypeLabel(l10n, item.notificationType)} · ${_formatDateTime(item.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: StudioTokens.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (item.isUnread)
              TextButton(
                onPressed: () => widget.controller.markRead(item),
                child: Text(l10n.notificationsMarkRead),
              ),
            FilledButton.tonal(
              onPressed: () {
                if (item.isUnread) {
                  widget.controller.markRead(item);
                }
                widget.onOpenNotification(item);
              },
              child: Text(l10n.notificationsOpen),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesTypeFilter(String notificationType) {
    switch (_typeFilter) {
      case 'job':
        return notificationType.startsWith('job_');
      case 'workspace':
        return notificationType.startsWith('workspace_');
      case 'skill':
        return notificationType == 'skill_change';
      case 'compliance':
        return notificationType == 'content_compliance_alert' ||
            notificationType == 'content_compliance_alert_cleared';
      default:
        return true;
    }
  }

  IconData _iconForType(String notificationType) {
    if (notificationType.startsWith('job_')) {
      return Icons.task_alt_outlined;
    }
    if (notificationType.startsWith('workspace_')) {
      return Icons.groups_outlined;
    }
    if (notificationType == 'skill_change') {
      return Icons.auto_awesome_outlined;
    }
    if (notificationType == 'content_compliance_alert') {
      return Icons.gpp_maybe_outlined;
    }
    if (notificationType == 'content_compliance_alert_cleared') {
      return Icons.task_alt_outlined;
    }
    return Icons.notifications_none_outlined;
  }

  String _notificationTypeLabel(
    AppLocalizations l10n,
    String notificationType,
  ) {
    switch (notificationType) {
      case 'job_succeeded':
        return l10n.notificationsRecordJobSucceeded;
      case 'job_failed':
        return l10n.notificationsRecordJobFailed;
      case 'job_cancelled':
        return l10n.notificationsRecordJobCancelled;
      case 'workspace_invite_created':
        return l10n.notificationsRecordWorkspaceInviteCreated;
      case 'workspace_invite_resent':
        return l10n.notificationsRecordWorkspaceInviteResent;
      case 'workspace_invite_revoked':
        return l10n.notificationsRecordWorkspaceInviteRevoked;
      case 'workspace_invite_accepted':
        return l10n.notificationsRecordWorkspaceInviteAccepted;
      case 'skill_change':
        return l10n.notificationsRecordSkillChange;
      case 'content_compliance_alert':
        return l10n.notificationsRecordContentComplianceAlert;
      case 'content_compliance_alert_cleared':
        return l10n.notificationsRecordContentComplianceCleared;
      case 'billing_subscription_activated':
      case 'billing_subscription_past_due':
      case 'billing_subscription_canceled':
      case 'billing_payment_failed':
      case 'billing_subscription_expired':
      case 'billing_subscription_trialing':
        return billingNotificationTypeLabel(l10n, notificationType);
      default:
        if (notificationType.startsWith('billing_')) {
          return l10n.billingNotificationUnknown;
        }
        return notificationType;
    }
  }

  String _formatDateTime(DateTime value) {
    return LocalizedFormatting.formatShortDateTime(context, value);
  }

  void _saveClearedThrottlePolicy() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final globalRaw = _clearedThrottleController.text.trim();
    final globalMinutes = int.tryParse(globalRaw);
    if (globalMinutes == null || globalMinutes < 1 || globalMinutes > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notificationsComplianceThrottleInvalidGlobal),
        ),
      );
      return;
    }
    final stageMinutes = <String, int>{};
    for (final stage in _complianceStages) {
      final raw = _stageThrottleControllers[stage]?.text.trim() ?? '';
      if (raw.isEmpty) {
        continue;
      }
      final value = int.tryParse(raw);
      if (value == null || value < 1 || value > 1440) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.notificationsComplianceThrottleStageInvalid(stage),
            ),
          ),
        );
        return;
      }
      stageMinutes[stage] = value;
    }
    widget.controller.saveContentComplianceClearedThrottlePolicy(
      globalMinutes: globalMinutes,
      stageMinutes: stageMinutes,
    );
  }

  Future<void> _applyThrottleTemplate(String templateId) async {
    await widget.controller.applyComplianceClearedThrottleTemplate(templateId);
  }

  Future<void> _createTemplateFromCurrentPolicy() async {
    final idController = TextEditingController();
    final labelController = TextEditingController();
    final descriptionController = TextEditingController();
    final shouldSave = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dl10n = resolveAppLocalizationsForErrors(dialogContext);
        return StudioAlertDialog(
          title: Text(dl10n.notificationsDialogSaveClearedTemplateTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateIdAscii,
                ),
              ),
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateName,
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateDescription,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dl10n.notificationsActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dl10n.notificationsActionSave),
            ),
          ],
        );
      },
    );
    if (shouldSave != true) {
      return;
    }
    if (!mounted) {
      return;
    }
    final id = idController.text.trim().toLowerCase();
    final label = labelController.text.trim();
    final description = descriptionController.text.trim();
    if (id.isEmpty || label.isEmpty) {
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notificationsSnackTemplateIdAndNameRequired),
        ),
      );
      return;
    }
    final stageMinutes = <String, int>{};
    for (final stage in _complianceStages) {
      final raw = _stageThrottleControllers[stage]?.text.trim() ?? '';
      final value = int.tryParse(raw);
      if (value != null && value >= 1 && value <= 1440) {
        stageMinutes[stage] = value;
      }
    }
    final global = int.tryParse(_clearedThrottleController.text.trim()) ?? 30;
    await widget.controller.upsertComplianceClearedTemplate(
      ContentComplianceClearedTemplateItemV1(
        id: id,
        label: label,
        description: description,
        policy: ContentComplianceClearedTemplatePolicyV1(
          globalMinutes: global.clamp(1, 1440),
          stageMinutes: stageMinutes,
        ),
        kind: 'custom',
        canEdit: true,
        canDelete: true,
      ),
    );
  }

  Future<void> _createWorkspaceSharedTemplateFromCurrentPolicy() async {
    final idController = TextEditingController();
    final labelController = TextEditingController();
    final descriptionController = TextEditingController();
    final shouldSave = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dl10n = resolveAppLocalizationsForErrors(dialogContext);
        return StudioAlertDialog(
          title: Text(
            dl10n.notificationsDialogSaveWorkspaceSharedTemplateTitle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateIdAscii,
                ),
              ),
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateName,
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateDescription,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dl10n.notificationsActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dl10n.notificationsActionSave),
            ),
          ],
        );
      },
    );
    if (shouldSave != true || !mounted) {
      return;
    }
    final id = idController.text.trim().toLowerCase();
    final label = labelController.text.trim();
    final description = descriptionController.text.trim();
    if (id.isEmpty || label.isEmpty) {
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notificationsSnackTemplateIdAndNameRequired),
        ),
      );
      return;
    }
    final stageMinutes = <String, int>{};
    for (final stage in _complianceStages) {
      final raw = _stageThrottleControllers[stage]?.text.trim() ?? '';
      final value = int.tryParse(raw);
      if (value != null && value >= 1 && value <= 1440) {
        stageMinutes[stage] = value;
      }
    }
    final global = int.tryParse(_clearedThrottleController.text.trim()) ?? 30;
    await widget.controller.upsertWorkspaceSharedComplianceClearedTemplate(
      ContentComplianceClearedTemplateItemV1(
        id: id,
        label: label,
        description: description,
        policy: ContentComplianceClearedTemplatePolicyV1(
          globalMinutes: global.clamp(1, 1440),
          stageMinutes: stageMinutes,
        ),
        kind: 'workspace_shared',
        canEdit: true,
        canDelete: true,
      ),
    );
  }

  Future<void> _editTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final labelController = TextEditingController(text: template.label);
    final descriptionController = TextEditingController(
      text: template.description,
    );
    final shouldSave = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dl10n = resolveAppLocalizationsForErrors(dialogContext);
        return StudioAlertDialog(
          title: Text(dl10n.notificationsDialogEditTemplateTitle(template.id)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateName,
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateDescription,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dl10n.notificationsActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dl10n.notificationsActionSave),
            ),
          ],
        );
      },
    );
    if (shouldSave != true) {
      return;
    }
    await widget.controller.upsertComplianceClearedTemplate(
      ContentComplianceClearedTemplateItemV1(
        id: template.id,
        label: labelController.text.trim().isEmpty
            ? template.label
            : labelController.text.trim(),
        description: descriptionController.text.trim(),
        policy: template.policy,
        kind: template.kind,
        canEdit: template.canEdit,
        canDelete: template.canDelete,
      ),
    );
  }

  Future<void> _deleteTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final shouldDelete = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dl10n = resolveAppLocalizationsForErrors(dialogContext);
        return StudioAlertDialog(
          title: Text(
            dl10n.notificationsDialogDeleteTemplateTitle(template.label),
          ),
          content: Text(dl10n.notificationsDialogDeleteTemplateBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dl10n.notificationsActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dl10n.notificationsActionDelete),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    await widget.controller.deleteComplianceClearedTemplate(template.id);
  }

  Future<void> _deleteWorkspaceSharedTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final shouldDelete = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dl10n = resolveAppLocalizationsForErrors(dialogContext);
        return StudioAlertDialog(
          title: Text(
            dl10n.notificationsDialogDeleteSharedTemplateTitle(template.label),
          ),
          content: Text(dl10n.notificationsDialogDeleteSharedTemplateBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dl10n.notificationsActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dl10n.notificationsActionDelete),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    await widget.controller.deleteWorkspaceSharedComplianceClearedTemplate(
      template.id,
    );
  }

  Future<void> _editWorkspaceSharedTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final labelController = TextEditingController(text: template.label);
    final descriptionController = TextEditingController(
      text: template.description,
    );
    final shouldSave = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dl10n = resolveAppLocalizationsForErrors(dialogContext);
        return StudioAlertDialog(
          title: Text(
            dl10n.notificationsDialogEditSharedTemplateTitle(template.id),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateName,
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: dl10n.notificationsFieldTemplateDescription,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dl10n.notificationsActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dl10n.notificationsActionSave),
            ),
          ],
        );
      },
    );
    if (shouldSave != true) {
      return;
    }
    await widget.controller.upsertWorkspaceSharedComplianceClearedTemplate(
      ContentComplianceClearedTemplateItemV1(
        id: template.id,
        label: labelController.text.trim().isEmpty
            ? template.label
            : labelController.text.trim(),
        description: descriptionController.text.trim(),
        policy: template.policy,
        kind: template.kind,
        canEdit: template.canEdit,
        canDelete: template.canDelete,
      ),
    );
  }

  Future<void> _reloadWorkspaceAuditWithFilters() async {
    final startAt = DateTime.tryParse(
      _workspaceAuditStartAtController.text.trim(),
    );
    final endAt = DateTime.tryParse(_workspaceAuditEndAtController.text.trim());
    await widget.controller.reloadWorkspaceSharedComplianceAudit(
      templateId: _workspaceAuditTemplateFilterController.text.trim(),
      action: _workspaceAuditActionFilter.trim(),
      startAt: startAt,
      endAt: endAt,
    );
  }

  Future<void> _applyExportHistoryFilters() async {
    await widget.controller.applyExportHistoryFiltersAndReload(
      formatFilter: _exportHistoryFormat,
      exportedStart: DateTime.tryParse(
        _exportHistoryExportedStartController.text.trim(),
      ),
      exportedEnd: DateTime.tryParse(
        _exportHistoryExportedEndController.text.trim(),
      ),
    );
  }

  Future<void> _reuseExportRecordFilters(
    WorkspaceSharedComplianceAuditExportRecordV1 item,
  ) async {
    _workspaceAuditTemplateFilterController.text = item.templateId ?? '';
    final act = (item.action ?? '').trim();
    setState(() {
      _workspaceAuditActionFilter = act == 'upsert' || act == 'delete'
          ? act
          : '';
    });
    _workspaceAuditStartAtController.text = (item.startAt ?? '').trim();
    _workspaceAuditEndAtController.text = (item.endAt ?? '').trim();
    await widget.controller.applyExportRecordToSharedAuditFilters(item);
    if (!mounted) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.notificationsSnackExportFiltersReused)),
    );
  }

  Future<void> _redownloadFromExportRecord(
    WorkspaceSharedComplianceAuditExportRecordV1 item,
  ) async {
    final path = await widget.controller
        .downloadWorkspaceSharedComplianceAuditWithExportRecord(item);
    if (!mounted || path == null) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.notificationsSnackDownloadedByHistory(path))),
    );
  }

  Future<void> _enqueueWorkspaceSharedAuditExportAsync(String format) async {
    final job = await widget.controller
        .enqueueWorkspaceSharedComplianceAuditExportAsync(format: format);
    if (!mounted) {
      return;
    }
    if (job == null) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.notificationsSnackExportQueued(job.numericTaskId)),
      ),
    );
    widget.controller.scheduleWorkspaceSharedAuditExportHistoryPoll(job.id);
  }

  Future<void> _exportWorkspaceAuditJsonToClipboard() async {
    final savedPath = await widget.controller
        .downloadWorkspaceSharedComplianceAuditJson();
    if (!mounted || savedPath == null) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.notificationsSnackSharedAuditJsonSaved(savedPath)),
      ),
    );
  }

  Future<void> _exportWorkspaceAuditCsvToClipboard() async {
    final savedPath = await widget.controller
        .downloadWorkspaceSharedComplianceAuditCsv();
    if (!mounted || savedPath == null) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.notificationsSnackSharedAuditCsvSaved(savedPath)),
      ),
    );
  }

  Future<void> _reorderTemplate(String id, {required bool up}) async {
    final ids = widget.controller.complianceClearedTemplates
        .map((template) => template.id)
        .toList(growable: true);
    final index = ids.indexOf(id);
    if (index < 0) {
      return;
    }
    final target = up ? index - 1 : index + 1;
    if (target < 0 || target >= ids.length) {
      return;
    }
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    await widget.controller.reorderComplianceClearedTemplates(ids);
  }

  Future<void> _exportTemplatesToClipboard() async {
    final json = await widget.controller.exportComplianceClearedTemplatesJson();
    if (!mounted || json == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.notificationsSnackTemplatesJsonCopied)),
    );
  }

  Future<void> _openImportTemplatesDialog() async {
    final jsonController = TextEditingController();
    String mode = 'replace';
    final shouldImport = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setDialogState) {
          final dl10n = resolveAppLocalizationsForErrors(stateContext);
          return StudioAlertDialog(
            title: Text(dl10n.notificationsDialogImportTemplatesJsonTitle),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StudioDropdownButtonFormField<String>(
                    initialValue: mode,
                    decoration: InputDecoration(
                      labelText: dl10n.notificationsFieldImportMode,
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'replace',
                        child: Text(dl10n.notificationsImportModeReplace),
                      ),
                      DropdownMenuItem(
                        value: 'merge',
                        child: Text(dl10n.notificationsImportModeMerge),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        mode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: jsonController,
                    maxLines: 14,
                    decoration: InputDecoration(
                      labelText: dl10n.notificationsFieldPasteTemplatesJson,
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(stateContext).pop(false),
                child: Text(dl10n.notificationsActionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(stateContext).pop(true),
                child: Text(dl10n.notificationsActionImport),
              ),
            ],
          );
        },
      ),
    );
    if (shouldImport != true || !mounted) {
      return;
    }
    final count = await widget.controller.importComplianceClearedTemplatesJson(
      jsonController.text.trim(),
      mode: mode,
    );
    if (!mounted || count == null) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.notificationsSnackImportDone(count))),
    );
  }

  String _buildPreferencesAuditText(
    AppLocalizations l10n,
    NotificationPreferencesAuditMetaV1 audit,
  ) {
    final updatedAt = audit.updatedAt;
    final timePart = updatedAt == null
        ? l10n.notificationsUnknownTime
        : _formatDateTime(updatedAt);
    return l10n.notificationsPrefsAuditUpdatedLine(
      timePart,
      audit.updatedBy,
      audit.source,
    );
  }

  String _auditActionDisplay(AppLocalizations l10n, String action) {
    switch (action.trim().toLowerCase()) {
      case 'upsert':
        return l10n.notificationsAuditActionUpsert;
      case 'delete':
        return l10n.notificationsAuditActionDelete;
      default:
        return studioUnknownCodeLabel(l10n, action);
    }
  }

  String _formatWorkspaceAuditItem(
    AppLocalizations l10n,
    ContentComplianceClearedTemplateAuditItemV1 item,
  ) {
    final at = item.at == null
        ? l10n.notificationsUnknownTime
        : _formatDateTime(item.at!);
    final note = (item.note ?? '').trim();
    final actionLabel = _auditActionDisplay(l10n, item.action);
    if (note.isEmpty) {
      return '$at $actionLabel ${item.templateId}';
    }
    return '$at $actionLabel ${item.templateId} · $note';
  }

  String _exportRecordDownloadTooltip(
    AppLocalizations l10n,
    WorkspaceSharedComplianceAuditExportRecordV1 item,
  ) {
    final d = (item.exportDelivery ?? '').trim().toLowerCase();
    if (d == 'async' && (item.jobId ?? '').trim().isNotEmpty) {
      return l10n.notificationsExportDownloadAsyncArtifact;
    }
    return l10n.notificationsExportRedownloadSync;
  }

  String _formatWorkspaceAuditExportItem(
    AppLocalizations l10n,
    WorkspaceSharedComplianceAuditExportRecordV1 item,
  ) {
    final when = item.exportedAt == null
        ? l10n.notificationsUnknownTime
        : _formatDateTime(item.exportedAt!);
    final format = item.format.toUpperCase();
    final actionRaw = (item.action ?? '').trim();
    final action = actionRaw.isEmpty
        ? l10n.notificationsAuditAllActions
        : _auditActionDisplay(l10n, actionRaw);
    final templateRaw = (item.templateId ?? '').trim();
    final template = templateRaw.isEmpty
        ? l10n.notificationsAuditAllTemplates
        : templateRaw;
    return '${l10n.notificationsExportRecordLeadIn} $when · $format · '
        '$template · $action · ${item.fileName}'
        '${_exportDeliveryLabel(l10n, item)}';
  }

  String _exportDeliveryLabel(
    AppLocalizations l10n,
    WorkspaceSharedComplianceAuditExportRecordV1 item,
  ) {
    final d = (item.exportDelivery ?? '').trim().toLowerCase();
    if (d == 'async') {
      final j = (item.jobId ?? '').trim();
      if (j.isNotEmpty) {
        return l10n.notificationsExportDeliveryAsyncWithJob(j);
      }
      return l10n.notificationsExportDeliveryAsync;
    }
    if (d == 'sync') {
      return l10n.notificationsExportDeliverySync;
    }
    return '';
  }
}
