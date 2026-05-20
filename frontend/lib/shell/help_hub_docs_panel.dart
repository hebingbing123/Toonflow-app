part of '../../home_page.dart';

/// Help Hub documentation links panel.
/// Manages user and workspace documentation links with search and categorization.
class HelpHubDocsPanel extends StatefulWidget {
  const HelpHubDocsPanel({
    super.key,
    required this.accessToken,
  });

  final String? accessToken;

  @override
  State<HelpHubDocsPanel> createState() => _HelpHubDocsPanelState();
}

class _HelpHubDocsPanelState extends State<HelpHubDocsPanel> {
  bool _loading = false;
  String? _error;
  HelpHubLinksResponseV1? _resp;
  HelpHubConfigResponseV1? _helpHubConfig;
  bool _savingHelpHubLinks = false;

  final _helpHubSearchController = TextEditingController();
  final _helpHubNewIdController = TextEditingController();
  final _helpHubNewTitleController = TextEditingController();
  final _helpHubNewUrlController = TextEditingController();

  String _helpHubSearchQuery = '';
  Timer? _helpHubSearchDebounce;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _helpHubSearchDebounce?.cancel();
    _helpHubSearchController.dispose();
    _helpHubNewIdController.dispose();
    _helpHubNewTitleController.dispose();
    _helpHubNewUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = kProductShellSignInErrorPlaceholder;
        _resp = null;
        _helpHubConfig = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await getSettingsHelpHubConfigV1(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _helpHubConfig = cfg;
        _resp = HelpHubLinksResponseV1(items: cfg.effectiveItems);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, e);
        _resp = null;
        _helpHubConfig = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _onHelpHubSearchChanged(String value) {
    _helpHubSearchDebounce?.cancel();
    _helpHubSearchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _helpHubSearchQuery = value;
      });
    });
  }

  Future<void> _openHelpHubManageDialog() async {
    final token = widget.accessToken;
    final cfg = _helpHubConfig;
    if (token == null || token.isEmpty) {
      return;
    }
    if (cfg == null) {
      await _load();
      if (!mounted) {
        return;
      }
    }

    final initial = _helpHubConfig;
    if (initial == null) {
      return;
    }

    var userItems = initial.userItems.toList(growable: true);
    var workspaceItems = initial.workspaceItems.toList(growable: true);
    var useWorkspaceTab = initial.canManageWorkspace;
    var errorText = '';

    _helpHubNewIdController.text = '';
    _helpHubNewTitleController.text = '';
    _helpHubNewUrlController.text = '';

    Future<void> saveScope({required bool workspace}) async {
      setState(() {
        _savingHelpHubLinks = true;
      });
      try {
        final resp = workspace
            ? await postSettingsHelpHubWorkspaceLinksV1(
                token,
                items: workspaceItems,
              )
            : await postSettingsHelpHubUserLinksV1(token, items: userItems);
        if (!mounted) {
          return;
        }
        setState(() {
          _helpHubConfig = resp;
          _resp = HelpHubLinksResponseV1(items: resp.effectiveItems);
        });
      } catch (e) {
        errorText = describeUserVisibleApiErrorResolved(context, e);
      } finally {
        if (mounted) {
          setState(() {
            _savingHelpHubLinks = false;
          });
        }
      }
    }

    await showStudioDialog<void>(
      context: context,
      builder: (ctx) {
        final dl10n = resolveAppLocalizationsForErrors(ctx);
        return StatefulBuilder(
          builder: (ctx, setInner) {
            final canManageWorkspace =
                _helpHubConfig?.canManageWorkspace ?? false;
            final activeIsWorkspace = canManageWorkspace && useWorkspaceTab;
            final activeItems = activeIsWorkspace ? workspaceItems : userItems;

            void addNew() {
              final id = _helpHubNewIdController.text.trim();
              final title = _helpHubNewTitleController.text.trim();
              final url = _helpHubNewUrlController.text.trim();
              if (id.isEmpty || title.isEmpty || url.isEmpty) {
                setInner(() {
                  errorText = dl10n.helpHubValidationRequired;
                });
                return;
              }
              setInner(() {
                errorText = '';
                activeItems.add(
                  HelpHubLinkItemV1(id: id, title: title, url: url),
                );
                _helpHubNewIdController.text = '';
                _helpHubNewTitleController.text = '';
                _helpHubNewUrlController.text = '';
              });
            }

            return StudioAlertDialog(
              title: Text(dl10n.helpHubManageDialogTitle),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dl10n.helpHubManagePrecedence +
                            (canManageWorkspace
                                ? ''
                                : dl10n.helpHubManageWorkspaceLocked),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (canManageWorkspace)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: Text(dl10n.helpHubTabPersonal),
                              selected: !activeIsWorkspace,
                              onSelected: (v) => setInner(() {
                                useWorkspaceTab = !v;
                                errorText = '';
                              }),
                            ),
                            FilterChip(
                              label: Text(dl10n.helpHubTabWorkspace),
                              selected: activeIsWorkspace,
                              onSelected: (v) => setInner(() {
                                useWorkspaceTab = v;
                                errorText = '';
                              }),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _helpHubNewIdController,
                        decoration: InputDecoration(
                          labelText: dl10n.helpHubFieldId,
                          hintText: dl10n.helpHubHintId,
                        ),
                        enabled: !_savingHelpHubLinks,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _helpHubNewTitleController,
                        decoration: InputDecoration(
                          labelText: dl10n.helpHubFieldTitle,
                        ),
                        enabled: !_savingHelpHubLinks,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _helpHubNewUrlController,
                        decoration: InputDecoration(
                          labelText: dl10n.helpHubFieldUrl,
                          hintText: dl10n.helpHubHintUrl,
                        ),
                        enabled: !_savingHelpHubLinks,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: _savingHelpHubLinks ? null : addNew,
                            child: Text(dl10n.helpHubAdd),
                          ),
                          if (errorText.isNotEmpty)
                            Text(
                              errorText,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (activeItems.isEmpty)
                        Text(
                          dl10n.helpHubNoCustomInScope,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ...activeItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.title} (${item.id})',
                                        style: Theme.of(
                                          ctx,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      SelectableText(item.url),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: dl10n
                                      .notificationsComplianceTooltipMoveUp,
                                  onPressed: (_savingHelpHubLinks || idx == 0)
                                      ? null
                                      : () => setInner(() {
                                          final tmp = activeItems[idx - 1];
                                          activeItems[idx - 1] =
                                              activeItems[idx];
                                          activeItems[idx] = tmp;
                                        }),
                                  icon: const Icon(Icons.arrow_upward),
                                ),
                                IconButton(
                                  tooltip: dl10n
                                      .notificationsComplianceTooltipMoveDown,
                                  onPressed:
                                      (_savingHelpHubLinks ||
                                          idx >= activeItems.length - 1)
                                      ? null
                                      : () => setInner(() {
                                          final tmp = activeItems[idx + 1];
                                          activeItems[idx + 1] =
                                              activeItems[idx];
                                          activeItems[idx] = tmp;
                                        }),
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                                IconButton(
                                  tooltip: dl10n.notificationsActionDelete,
                                  onPressed: _savingHelpHubLinks
                                      ? null
                                      : () => setInner(() {
                                          activeItems.removeAt(idx);
                                        }),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _savingHelpHubLinks
                      ? null
                      : () => Navigator.pop(ctx),
                  child: Text(dl10n.helpHubDialogClose),
                ),
                FilledButton(
                  onPressed: _savingHelpHubLinks
                      ? null
                      : () async {
                          await saveScope(workspace: activeIsWorkspace);
                          if (!ctx.mounted) {
                            return;
                          }
                          if (errorText.isNotEmpty) {
                            setInner(() {});
                            return;
                          }
                          Navigator.pop(ctx);
                        },
                  child: Text(
                    _savingHelpHubLinks
                        ? dl10n.helpHubSaving
                        : dl10n.helpHubSave,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<HelpHubLinkItemV1> _filteredHelpHubLinks() {
    final items = _resp?.items ?? const <HelpHubLinkItemV1>[];
    final needle = _helpHubSearchQuery.trim().toLowerCase();
    if (needle.isEmpty) {
      return items;
    }
    return items
        .where((item) {
          final haystack = '${item.id} ${item.title} ${item.url}'.toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  String _helpHubCategorySlug(HelpHubLinkItemV1 item) {
    final key = '${item.id} ${item.title} ${item.url}'.toLowerCase();
    if (key.contains('runbook') || key.contains('guide')) {
      return 'runbook';
    }
    if (key.contains('webhook') || key.contains('billing')) {
      return 'billing';
    }
    if (key.contains('workspace') || key.contains('team')) {
      return 'workspace';
    }
    if (key.contains('quality') || key.contains('review')) {
      return 'quality';
    }
    if (key.contains('status') || key.contains('health')) {
      return 'status';
    }
    return 'general';
  }

  String _helpHubInventorySummary(
    AppLocalizations l10n,
    List<HelpHubLinkItemV1> filtered,
  ) {
    final items = _resp?.items ?? const <HelpHubLinkItemV1>[];
    final counts = <String, int>{};
    for (final item in filtered) {
      final slug = _helpHubCategorySlug(item);
      counts.update(slug, (value) => value + 1, ifAbsent: () => 1);
    }
    final extra = counts.isEmpty
        ? ''
        : ' · ${counts.entries.map((e) => l10n.helpHubSummaryCategoryCount(_helpHubCategoryLabelForSlug(e.key, l10n), e.value)).join(', ')}';
    return l10n.helpHubSummary(items.length, filtered.length, extra);
  }

  String _helpHubCategoryLabelForSlug(String slug, AppLocalizations l10n) {
    switch (slug) {
      case 'runbook':
        return l10n.helpHubCategoryRunbook;
      case 'billing':
        return l10n.helpHubCategoryBillingWebhook;
      case 'workspace':
        return l10n.helpHubCategoryWorkspace;
      case 'quality':
        return l10n.helpHubCategoryQuality;
      case 'status':
        return l10n.helpHubCategoryStatus;
      default:
        return l10n.helpHubCategoryGeneral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final filteredHelpHubLinks = _filteredHelpHubLinks();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.helpHubDocsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.riskyPrefsTooltipSameAsMainPanelHeaders,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.helpHubLocalRiskLine,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _loading ? null : _load,
                child: Text(l10n.helpHubRefresh),
              ),
              OutlinedButton(
                onPressed: (_loading || _helpHubConfig == null)
                    ? null
                    : _openHelpHubManageDialog,
                child: Text(l10n.helpHubManageEntries),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) Text(l10n.helpHubLoading),
          if (_error != null)
            Text(
              _error == kProductShellSignInErrorPlaceholder
                  ? l10n.platformConfigPleaseSignIn
                  : _error!,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _helpHubSearchController,
            decoration: InputDecoration(labelText: l10n.helpHubSearchLabel),
            onChanged: _onHelpHubSearchChanged,
          ),
          const SizedBox(height: 8),
          if (_resp != null)
            Text(_helpHubInventorySummary(l10n, filteredHelpHubLinks)),
          if (_resp != null && _resp!.items.isEmpty)
            Text(
              l10n.helpHubNoEffectiveLinks,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_resp != null &&
              _resp!.items.isNotEmpty &&
              filteredHelpHubLinks.isEmpty)
            Text(
              l10n.helpHubSearchEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_resp != null && filteredHelpHubLinks.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.builder(
                primary: false,
                itemCount: filteredHelpHubLinks.length,
                itemBuilder: (context, index) {
                  final item = filteredHelpHubLinks[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(
                              _helpHubCategoryLabelForSlug(
                                _helpHubCategorySlug(item),
                                l10n,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(item.url),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              IconButton(
                                tooltip: l10n.helpHubCopyLinkTooltip,
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: item.url),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.helpHubCopied)),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                              ),
                              IconButton(
                                tooltip: l10n.helpHubCopyTitleUrlTooltip,
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: '${item.title}\n${item.url}',
                                    ),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.helpHubCopiedHandoff),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_all_outlined),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
