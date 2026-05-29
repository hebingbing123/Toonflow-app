part of 'version_manager.dart';

// ignore_for_file: invalid_use_of_protected_member

class _VersionManagerState extends State<VersionManager> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final currentVersion = widget.versions.firstWhere(
      (v) => v.id == widget.currentVersionId,
      orElse: () => widget.versions.isNotEmpty
          ? widget.versions.first
          : AssemblyVersion(
              id: 'default',
              name: l10n.shortVideoVersionManagerDefaultVersion,
              createdAt: DateTime.now(),
              shotCount: 0,
              shotConfig: {},
            ),
    );

    return Card(
      margin: const EdgeInsets.all(StudioSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: StudioIconSize.md,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: StudioSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.shortVideoVersionManagerTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioDenseActionRow(
                children: [
                  if (widget.versions.length >= 2)
                    FilledButton.tonalIcon(
                      style: studioFormIconLabeledButtonStyle(context),
                      onPressed: _isLoading ? null : _showCompareVersionsDialog,
                      icon: const Icon(
                        Icons.compare_arrows,
                        size: StudioIconSize.sm,
                      ),
                      label: Text(l10n.shortVideoVersionManagerCompareVersions),
                    ),
                  FilledButton.tonalIcon(
                    style: studioFormIconLabeledButtonStyle(context),
                    onPressed: _isLoading ? null : _showCreateVersionDialog,
                    icon: const Icon(Icons.add, size: StudioIconSize.sm),
                    label: Text(l10n.shortVideoVersionManagerCreateNewVersion),
                  ),
                  FilledButton.tonalIcon(
                    style: studioFormIconLabeledButtonStyle(context),
                    onPressed: _isLoading ? null : _showSaveDraftDialog,
                    icon: const Icon(
                      Icons.save_outlined,
                      size: StudioIconSize.sm,
                    ),
                    label: Text(l10n.shortVideoVersionManagerSaveDraft),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.sm),

              if (_errorMessage != null) ...[
                StudioApiErrorCallout(
                  error: _errorMessage!,
                  emphasis: StudioApiErrorCalloutEmphasis.subtle,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: StudioSpacing.sm),
              ],

              // 当前版本信息
              Container(
                padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
                decoration: BoxDecoration(
                  color: StudioTokens.of(context).primarySoft,
                  borderRadius: BorderRadius.circular(
                    StudioSpacing.radiusDense,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: StudioIconSize.md,
                    ),
                    const SizedBox(width: StudioSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.shortVideoVersionManagerCurrentVersion(
                              currentVersion.name,
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          Text(
                            l10n.shortVideoVersionManagerCurrentVersionMeta(
                              currentVersion.shotCount,
                              _formatDateTime(currentVersion.createdAt),
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StudioSpacing.sm),

              // 版本列表
              Text(
                l10n.shortVideoVersionManagerAllVersions(
                  widget.versions.length,
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),

              if (widget.versions.isEmpty)
                StudioEmptyState.emptyData(
                  title: l10n.shortVideoVersionManagerNoVersionsHint,
                  icon: Icons.layers_outlined,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.versions.length,
                  itemBuilder: (context, index) {
                    final version = widget.versions[index];
                    final isCurrent = version.id == widget.currentVersionId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: StudioSpacing.xs),
                      color: isCurrent
                          ? StudioTokens.of(
                              context,
                            ).primarySoft.withValues(alpha: 0.72)
                          : null,
                      child: StudioListRow(
                        onAlternate: !isCurrent && !_isLoading
                            ? () => _handleSwitchVersion(version.id)
                            : null,
                        alternateLabel:
                            l10n.shortVideoVersionManagerTooltipSwitchVersion,
                        alternateIcon: Icons.swap_horiz,
                        onDelete: !_isLoading && !isCurrent
                            ? () => _handleDeleteVersion(version)
                            : null,
                        deleteLabel:
                            l10n.shortVideoVersionManagerTooltipDeleteVersion,
                        leading: Icon(
                          isCurrent
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isCurrent
                              ? StudioTokens.of(context).primary
                              : StudioTokens.of(context).textSecondary,
                        ),
                        title: Text(
                          version.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          l10n.shortVideoVersionManagerVersionRowSubtitle(
                            version.shotCount,
                            _formatDateTime(version.createdAt),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isCurrent)
                              StudioIconButton(
                                icon: Icons.swap_horiz,
                                label: l10n
                                    .shortVideoVersionManagerTooltipSwitchVersion,
                                onPressed: _isLoading
                                    ? null
                                    : () => _handleSwitchVersion(version.id),
                              ),
                            StudioIconButton(
                              icon: Icons.delete_outline,
                              label: l10n
                                  .shortVideoVersionManagerTooltipDeleteVersion,
                              onPressed: _isLoading || isCurrent
                                  ? null
                                  : () => _handleDeleteVersion(version),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: StudioSpacing.md),

              // 草稿列表
              Row(
                children: [
                  Text(
                    l10n.shortVideoVersionManagerDraftsHeader(
                      widget.drafts.length,
                      10,
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.drafts.isNotEmpty)
                    TextButton.icon(
                      style: studioFormTextButtonIconStyle(context),
                      onPressed: _isLoading ? null : _showDraftsDialog,
                      icon: const Icon(Icons.list, size: StudioIconSize.sm),
                      label: Text(l10n.shortVideoVersionManagerViewAllDrafts),
                    ),
                ],
              ),
              const SizedBox(height: StudioSpacing.xs),

              if (widget.drafts.isEmpty)
                StudioEmptyState.emptyData(
                  title: l10n.shortVideoVersionManagerNoDraftsHint,
                  icon: Icons.drafts_outlined,
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (
                      var index = 0;
                      index <
                          (widget.drafts.length > 3 ? 3 : widget.drafts.length);
                      index++
                    )
                      Builder(
                        builder: (context) {
                          final draft = widget.drafts[index];

                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: StudioSpacing.xs,
                            ),
                            child: StudioCard(
                              padding: EdgeInsets.zero,
                              child: StudioListRow(
                                onRestore: !_isLoading
                                    ? () => _handleRestoreDraft(draft)
                                    : null,
                                onDelete: !_isLoading
                                    ? () => _handleDeleteDraft(draft)
                                    : null,
                                deleteLabel: l10n
                                    .shortVideoVersionManagerTooltipDeleteDraft,
                                leading: Icon(
                                  Icons.drafts_outlined,
                                  color: theme.colorScheme.secondary,
                                ),
                                title: Text(
                                  draft.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  l10n.shortVideoVersionManagerDraftRowSubtitle(
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
                                      onPressed: _isLoading
                                          ? null
                                          : () => _handleRestoreDraft(draft),
                                    ),
                                    StudioIconButton(
                                      icon: Icons.delete_outline,
                                      label: l10n
                                          .shortVideoVersionManagerTooltipDeleteDraft,
                                      onPressed: _isLoading
                                          ? null
                                          : () => _handleDeleteDraft(draft),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),

              StudioAsyncDataView(
                loading: _isLoading,
                loadingPlaceholder: StudioLoadingPlaceholder.list,
                loadingItemCount: 3,
                scrollableLoading: false,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
