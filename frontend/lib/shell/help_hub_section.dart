part of '../../home_page.dart';

class _HelpHubSection extends StatefulWidget {
  const _HelpHubSection({
    required this.accessToken,
    this.debugWebhooks,
    this.debugLatestCreatedWebhook,
    this.debugBillingEventsPage,
    this.debugWebhookDeliveries,
    this.debugWebhookLastTestResults,
  });

  final String? accessToken;
  final OutboundWebhookListResponseV1? debugWebhooks;
  final OutboundWebhookCreatedResponseV1? debugLatestCreatedWebhook;
  final BillingWebhookEventsResponseV1? debugBillingEventsPage;
  final Map<String, OutboundWebhookDeliveryListResponseV1>?
  debugWebhookDeliveries;
  final Map<String, OutboundWebhookTestResponseV1>? debugWebhookLastTestResults;

  @override
  State<_HelpHubSection> createState() => _HelpHubSectionState();
}

class _WebhookActivityEntry {
  const _WebhookActivityEntry({
    required this.at,
    required this.action,
    required this.webhookId,
    required this.summary,
  });

  final DateTime at;
  final String action;
  final String webhookId;
  final String summary;
}

class _HelpHubSectionState extends State<_HelpHubSection> {
  bool _loading = false;
  String? _error;
  HelpHubLinksResponseV1? _resp;
  HelpHubConfigResponseV1? _helpHubConfig;
  bool _savingHelpHubLinks = false;
  bool _loadingWebhooks = false;
  bool _creatingWebhook = false;
  String? _webhooksError;
  OutboundWebhookListResponseV1? _webhooks;
  OutboundWebhookCreatedResponseV1? _latestCreatedWebhook;
  final _webhookUrlController = TextEditingController();
  final _webhookSecretController = TextEditingController();
  final _webhookSearchController = TextEditingController();
  final _webhookTestEventTypeController = TextEditingController(
    text: 'test.ping',
  );
  final _webhookWorkspaceIdController = TextEditingController();

  /// Create form: selected platform event slugs (empty on server = all types).
  final Set<String> _createWebhookEventTypes = <String>{
    ...kOutboundWebhookPlatformEventTypes,
  };
  final _helpHubSearchController = TextEditingController();
  final _helpHubNewIdController = TextEditingController();
  final _helpHubNewTitleController = TextEditingController();
  final _helpHubNewUrlController = TextEditingController();
  String _helpHubSearchQuery = '';
  String _webhookSearchQuery = '';
  Timer? _helpHubSearchDebounce;
  Timer? _webhookSearchDebounce;
  String? _webhookMutatingId;
  final Map<String, OutboundWebhookTestResponseV1> _webhookLastTestResultById =
      <String, OutboundWebhookTestResponseV1>{};
  final Map<String, OutboundWebhookDeliveryListResponseV1> _webhookDeliveries =
      <String, OutboundWebhookDeliveryListResponseV1>{};
  String? _loadingDeliveriesId;
  final List<_WebhookActivityEntry> _webhookActivity =
      <_WebhookActivityEntry>[];

  /// Per-row draft for PATCH `workspaceId` on existing webhooks.
  final Map<String, TextEditingController> _webhookWorkspaceDraftControllers =
      <String, TextEditingController>{};
  bool _loadingBillingEvents = false;
  bool _loadingMoreBillingEvents = false;
  bool _exportingAllBillingEvents = false;
  String? _billingEventsError;
  BillingWebhookEventsResponseV1? _billingEventsPage;
  final List<BillingWebhookEventItemV1> _billingEvents =
      <BillingWebhookEventItemV1>[];
  final _billingEventTypeController = TextEditingController();
  final _billingProviderEventIdController = TextEditingController();
  final _billingProviderEventIdPrefixController = TextEditingController();
  final _billingRawEventIdController = TextEditingController();
  final _billingRawEventIdPrefixController = TextEditingController();
  final _billingEventCreatedFromController = TextEditingController();
  final _billingEventCreatedToController = TextEditingController();
  final _billingCreatedFromController = TextEditingController();
  final _billingCreatedToController = TextEditingController();
  String _billingProvider = '';
  bool? _billingInformationalOnly;
  String _billingSort = 'id_desc';

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    if (widget.debugWebhooks != null) {
      _webhooks = widget.debugWebhooks;
      _latestCreatedWebhook = widget.debugLatestCreatedWebhook;
      _webhookDeliveries.addAll(widget.debugWebhookDeliveries ?? const {});
      _webhookLastTestResultById.addAll(
        widget.debugWebhookLastTestResults ?? const {},
      );
      _syncWebhookWorkspaceDraftControllers();
    } else {
      unawaited(_loadWebhooks());
    }
    if (widget.debugBillingEventsPage != null) {
      _billingEventsPage = widget.debugBillingEventsPage;
      _billingEvents.addAll(widget.debugBillingEventsPage!.items);
    } else {
      unawaited(_loadBillingEvents());
    }
  }

  @override
  void dispose() {
    _helpHubSearchDebounce?.cancel();
    _webhookSearchDebounce?.cancel();
    _webhookUrlController.dispose();
    _webhookSecretController.dispose();
    _webhookSearchController.dispose();
    _webhookTestEventTypeController.dispose();
    _webhookWorkspaceIdController.dispose();
    _helpHubSearchController.dispose();
    _helpHubNewIdController.dispose();
    _helpHubNewTitleController.dispose();
    _helpHubNewUrlController.dispose();
    _billingEventTypeController.dispose();
    _billingProviderEventIdController.dispose();
    _billingProviderEventIdPrefixController.dispose();
    _billingRawEventIdController.dispose();
    _billingRawEventIdPrefixController.dispose();
    _billingEventCreatedFromController.dispose();
    _billingEventCreatedToController.dispose();
    _billingCreatedFromController.dispose();
    _billingCreatedToController.dispose();
    for (final c in _webhookWorkspaceDraftControllers.values) {
      c.dispose();
    }
    _webhookWorkspaceDraftControllers.clear();
    super.dispose();
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

  void _onWebhookSearchChanged(String value) {
    _webhookSearchDebounce?.cancel();
    _webhookSearchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhookSearchQuery = value;
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
    final filteredWebhooks = _filteredWebhooks();
    final outboundWebhookEmptyMsg = _webhooks == null
        ? null
        : describeOutboundWebhookEmptyState(
            l10n,
            total: _webhooks!.items.length,
            filtered: filteredWebhooks.length,
          );
    final billingWebhookEmptyMsg = describeBillingWebhookEmptyState(
      l10n,
      hasPage: _billingEventsPage != null,
      loaded: _billingEvents.length,
      isLoading: _loadingBillingEvents,
      error: _billingEventsError,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
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
          const SizedBox(height: 16),
          Text(
            l10n.opsWhSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookUrlController,
            decoration: InputDecoration(
              labelText: l10n.opsWhUrlLabel,
              hintText: l10n.opsWhUrlHint,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookSecretController,
            decoration: InputDecoration(labelText: l10n.opsWhSecretLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookWorkspaceIdController,
            decoration: InputDecoration(
              labelText: l10n.opsWhWorkspaceIdLabel,
              hintText: l10n.opsWhWorkspaceIdHint,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.opsWhSubscribeHint,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 4),
          OutboundWebhookEventChips(
            selected: _createWebhookEventTypes,
            enabled: !_loadingWebhooks,
            onSelectionChanged: (next) {
              setState(() {
                _createWebhookEventTypes
                  ..clear()
                  ..addAll(next);
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookTestEventTypeController,
            decoration: InputDecoration(
              labelText: l10n.opsWhTestEventTypeLabel,
              hintText: l10n.opsWhTestEventTypeHint,
            ),
          ),
          if (_latestCreatedWebhook != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.opsWhLatestCreatedTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.helpHubDialogClose,
                          onPressed: () {
                            setState(() {
                              _latestCreatedWebhook = null;
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    SelectableText(
                      l10n.opsWhFieldId(_latestCreatedWebhook!.id),
                    ),
                    SelectableText(
                      l10n.opsWhFieldUrl(_latestCreatedWebhook!.url),
                    ),
                    SelectableText(
                      l10n.opsWhFieldSecret(_latestCreatedWebhook!.secret),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.id),
                          ),
                          child: Text(l10n.opsWhCopyId),
                        ),
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.url),
                          ),
                          child: Text(l10n.opsWhCopyUrl),
                        ),
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.secret),
                          ),
                          child: Text(l10n.opsWhCopySecret),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _creatingWebhook ? null : _createWebhook,
                child: Text(
                  _creatingWebhook ? l10n.opsWhCreating : l10n.opsWhCreate,
                ),
              ),
              OutlinedButton(
                onPressed: _loadingWebhooks ? null : _loadWebhooks,
                child: Text(l10n.opsWhRefreshList),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookSearchController,
            decoration: InputDecoration(labelText: l10n.opsWhSearchLabel),
            onChanged: _onWebhookSearchChanged,
          ),
          const SizedBox(height: 8),
          if (_loadingWebhooks) Text(l10n.opsWhLoading),
          if (_webhooksError != null)
            Text(
              _webhooksError == kProductShellSignInErrorPlaceholder
                  ? l10n.platformConfigPleaseSignIn
                  : _webhooksError!,
              style: const TextStyle(color: Colors.red),
            ),
          if (_webhooks != null)
            Text(_webhookInventorySummary(l10n, filteredWebhooks)),
          if (_webhookActivity.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.opsWhRecentActivity,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._webhookActivity
                .take(6)
                .map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.opsWhActivityEntryTitle(
                        webhookActivityActionLabel(l10n, entry.action),
                        entry.webhookId,
                      ),
                    ),
                    subtitle: SelectableText(
                      '${entry.at.toLocal().toIso8601String()}\n${entry.summary}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      tooltip: l10n.opsWhCopyActivityTooltip,
                      onPressed: () => _copyBillingAuditText(
                        '${webhookActivityActionLabel(l10n, entry.action)}\n'
                        '${entry.webhookId}\n'
                        '${entry.summary}',
                        l10n.opsWhActivityRecordSuffix.trim(),
                      ),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ),
                ),
          ],
          if (outboundWebhookEmptyMsg != null)
            Text(
              outboundWebhookEmptyMsg,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_webhooks != null && filteredWebhooks.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: ListView.builder(
                primary: false,
                itemCount: filteredWebhooks.length,
                itemBuilder: (context, index) {
                  final wh = filteredWebhooks[index];
                  final rowBusy = _webhookMutatingId == wh.id;
                  return Card(
                    color: _latestCreatedWebhook?.id == wh.id
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wh.url,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          if (_latestCreatedWebhook?.id == wh.id)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Chip(
                                label: Text(l10n.opsWhChipLatestCreated),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          Text(l10n.opsWhFieldId(wh.id)),
                          Text(l10n.opsWhFieldCreatedAt(wh.createdAt)),
                          Text(
                            l10n.opsWhFieldUpdatedAt(
                              wh.updatedAt ?? wh.createdAt,
                            ),
                          ),
                          if (!wh.enabled)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Chip(
                                label: Text(l10n.opsWhChipDisabled),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.opsWhSubscribeHeading,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                const SizedBox(height: 4),
                                OutboundWebhookEventChips(
                                  selected: outboundWebhookEffectiveSelection(
                                    wh.eventTypes,
                                  ),
                                  enabled: !_loadingWebhooks && !rowBusy,
                                  onSelectionChanged: (next) {
                                    unawaited(
                                      _patchWebhookEventSubscription(wh, next),
                                    );
                                  },
                                ),
                                if (wh.eventTypes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      l10n.opsWhApiEventTypes(
                                        wh.eventTypes.join(', '),
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.opsWhScopeHeading,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller:
                                      _webhookWorkspaceDraftControllers[wh.id],
                                  decoration: InputDecoration(
                                    hintText: l10n.opsWhScopeFieldHint,
                                    isDense: true,
                                  ),
                                  enabled: !_loadingWebhooks && !rowBusy,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: _loadingWebhooks || rowBusy
                                          ? null
                                          : () => _patchWebhookWorkspaceScope(
                                              wh.id,
                                            ),
                                      child: Text(
                                        rowBusy
                                            ? l10n.opsWhSavingScope
                                            : l10n.opsWhSaveScope,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loadingWebhooks || rowBusy
                                          ? null
                                          : () {
                                              _webhookWorkspaceDraftControllers[wh
                                                      .id]
                                                  ?.clear();
                                            },
                                      child: Text(l10n.opsWhClearInput),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_webhookDeliveries[wh.id] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              l10n.opsWhRecentDeliveries,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            ..._webhookDeliveries[wh.id]!.items
                                .take(6)
                                .map(
                                  (d) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${d.eventType} · ${d.status} · HTTP ${d.httpStatus ?? '-'}',
                                    ),
                                    subtitle: SelectableText(
                                      '${d.createdAt}\n${d.error ?? ''}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ),
                          ],
                          if (_webhookLastTestResultById[wh.id] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _formatWebhookTestResult(
                                  l10n,
                                  _webhookLastTestResultById[wh.id]!,
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              IconButton(
                                tooltip: l10n.opsWhTooltipCopyUrl,
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: wh.url),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.opsWhUrlCopiedSnack),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_outlined),
                              ),
                              OutlinedButton(
                                onPressed: _loadingWebhooks || rowBusy
                                    ? null
                                    : () => _testWebhook(wh.id),
                                child: Text(
                                  rowBusy
                                      ? l10n.opsWhBusy
                                      : l10n.opsWhTestDeliver,
                                ),
                              ),
                              OutlinedButton(
                                onPressed:
                                    _loadingWebhooks ||
                                        rowBusy ||
                                        _loadingDeliveriesId != null
                                    ? null
                                    : () => _loadWebhookDeliveries(wh.id),
                                child: Text(
                                  _loadingDeliveriesId == wh.id
                                      ? l10n.opsWhLoading
                                      : l10n.opsWhDeliveryLog,
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _loadingWebhooks || rowBusy
                                    ? null
                                    : () => _deleteWebhook(wh.id),
                                child: Text(
                                  rowBusy ? l10n.opsWhBusy : l10n.opsWhDelete,
                                ),
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
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final viewportWidth = MediaQuery.sizeOf(context).width;
              final billingDropdownWidth = viewportWidth < 1320 ? 220.0 : 240.0;
              final billingDateFieldWidth = viewportWidth < 1320
                  ? 240.0
                  : 280.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.billingAuditTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: billingDropdownWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _billingProvider,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditProviderLabel,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: '',
                              child: Text(l10n.billingAuditAll),
                            ),
                            DropdownMenuItem(
                              value: 'stripe',
                              child: Text(l10n.billingAuditProviderStripe),
                            ),
                            DropdownMenuItem(
                              value: 'alipay',
                              child: Text(l10n.billingAuditProviderAlipay),
                            ),
                            DropdownMenuItem(
                              value: 'paddle',
                              child: Text(l10n.billingAuditProviderPaddle),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _billingProvider = value ?? '';
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: billingDropdownWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _billingSort,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditSortLabel,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'id_desc',
                              child: Text(l10n.billingAuditSortNewest),
                            ),
                            DropdownMenuItem(
                              value: 'id_asc',
                              child: Text(l10n.billingAuditSortOldest),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _billingSort = value ?? 'id_desc';
                            });
                          },
                        ),
                      ),
                      FilterChip(
                        label: Text(l10n.billingAuditOnlyInformational),
                        selected: _billingInformationalOnly == true,
                        onSelected: (selected) {
                          setState(() {
                            _billingInformationalOnly = selected ? true : null;
                          });
                        },
                      ),
                      FilterChip(
                        label: Text(l10n.billingAuditOnlyStateful),
                        selected: _billingInformationalOnly == false,
                        onSelected: (selected) {
                          setState(() {
                            _billingInformationalOnly = selected ? false : null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingEventTypeController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditEventTypeLabel,
                      hintText: l10n.billingAuditEventTypeHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingProviderEventIdController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditProviderEventIdLabel,
                      hintText: l10n.billingAuditProviderEventIdHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingRawEventIdController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditRawEventIdLabel,
                      hintText: l10n.billingAuditRawEventIdHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingProviderEventIdPrefixController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditProviderEventIdPrefixLabel,
                      hintText: l10n.billingAuditProviderPrefixHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingRawEventIdPrefixController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditRawEventIdPrefixLabel,
                      hintText: l10n.billingAuditRawPrefixHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: billingDateFieldWidth,
                        child: TextField(
                          controller: _billingEventCreatedFromController,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditEventCreatedFromLabel,
                            hintText: l10n.billingAuditEventCreatedFromHint,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: billingDateFieldWidth,
                        child: TextField(
                          controller: _billingEventCreatedToController,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditEventCreatedToLabel,
                            hintText: l10n.billingAuditEventCreatedToHint,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: billingDateFieldWidth,
                        child: TextField(
                          controller: _billingCreatedFromController,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditCreatedFromLabel,
                            hintText: l10n.billingAuditEventCreatedFromHint,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: billingDateFieldWidth,
                        child: TextField(
                          controller: _billingCreatedToController,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditCreatedToLabel,
                            hintText: l10n.billingAuditEventCreatedToHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _loadingBillingEvents ? null : _loadBillingEvents,
                child: Text(
                  _loadingBillingEvents
                      ? l10n.billingAuditQuerying
                      : l10n.billingAuditQuery,
                ),
              ),
              OutlinedButton(
                onPressed: _loadingBillingEvents || _loadingMoreBillingEvents
                    ? null
                    : () {
                        setState(() {
                          _billingProvider = '';
                          _billingInformationalOnly = null;
                          _billingSort = 'id_desc';
                          _billingEventTypeController.clear();
                          _billingProviderEventIdController.clear();
                          _billingProviderEventIdPrefixController.clear();
                          _billingRawEventIdController.clear();
                          _billingRawEventIdPrefixController.clear();
                          _billingEventCreatedFromController.clear();
                          _billingEventCreatedToController.clear();
                          _billingCreatedFromController.clear();
                          _billingCreatedToController.clear();
                        });
                        _loadBillingEvents();
                      },
                child: Text(l10n.billingAuditResetRefresh),
              ),
              OutlinedButton(
                onPressed: _billingEvents.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: _buildBillingEventsCsv()),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.billingAuditCsvCopiedSnack),
                          ),
                        );
                      },
                child: Text(l10n.billingAuditCopyCsv),
              ),
              OutlinedButton(
                onPressed: _copyBillingEventsQuerySummary,
                child: Text(l10n.billingAuditCopyQuerySummary),
              ),
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _billingEventsUri().toString()),
                  );
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.billingAuditQueryUrlCopiedSnack),
                    ),
                  );
                },
                child: Text(l10n.billingAuditCopyQueryUrl),
              ),
              OutlinedButton(
                onPressed: _exportingAllBillingEvents
                    ? null
                    : _copyAllBillingEventsCsv,
                child: Text(
                  _exportingAllBillingEvents
                      ? l10n.billingAuditExporting
                      : l10n.billingAuditCopyFullCsv,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingBillingEvents) Text(l10n.billingAuditLoading),
          if (_billingEventsError != null)
            Text(
              _billingEventsError == kProductShellSignInErrorPlaceholder
                  ? l10n.platformConfigPleaseSignIn
                  : _billingEventsError!,
              style: const TextStyle(color: Colors.red),
            ),
          if (_billingEventsPage != null)
            Text(
              l10n.billingAuditPageStats(
                _billingEventsPage!.total,
                _billingEvents.length,
                '${_billingEventsPage!.hasMore}',
              ),
            ),
          if (billingWebhookEmptyMsg != null)
            Text(
              billingWebhookEmptyMsg,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_billingEvents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.billingAuditCurrentLoadTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...(_billingEventCountsByProvider(l10n).entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .map(
                      (entry) => Chip(
                        label: Text(
                          l10n.billingChipCount(entry.key, entry.value),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                Chip(
                  label: Text(
                    l10n.billingSnapInformational(
                      _billingEvents
                          .where((e) => e.isInformationalEvent)
                          .length,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    l10n.billingSnapStateful(
                      _billingEvents
                          .where((e) => !e.isInformationalEvent)
                          .length,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...(_billingEventCountsByType(l10n).entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .take(8)
                    .map(
                      (entry) => Chip(
                        label: Text(
                          l10n.billingChipCount(entry.key, entry.value),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                OutlinedButton(
                  onPressed: _copyBillingEventsSnapshotSummary,
                  child: Text(l10n.billingAuditCopySnapshot),
                ),
              ],
            ),
          ],
          ..._billingEvents.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.providerEventId,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(_formatBillingEventMeta(l10n, item)),
                    if (item.rawEventId != null && item.rawEventId!.isNotEmpty)
                      SelectableText(
                        l10n.billingRowRawEventId(item.rawEventId!),
                      ),
                    SelectableText(l10n.billingRowId('${item.id}')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _copyBillingAuditText(
                            item.providerEventId,
                            'provider_event_id',
                          ),
                          child: Text(l10n.billingAuditCopyProviderEventId),
                        ),
                        if (item.rawEventId != null &&
                            item.rawEventId!.isNotEmpty)
                          OutlinedButton(
                            onPressed: () => _copyBillingAuditText(
                              item.rawEventId!,
                              'raw_event_id',
                            ),
                            child: Text(l10n.billingAuditCopyRawEventId),
                          ),
                        if (item.provider != null &&
                            item.provider!.trim().isNotEmpty)
                          FilledButton.tonal(
                            onPressed: () => _applyBillingRowFilters(
                              provider: item.provider,
                            ),
                            child: Text(
                              l10n.billingAuditFilterByProvider(
                                item.provider!.trim(),
                              ),
                            ),
                          ),
                        if (item.eventType != null &&
                            item.eventType!.trim().isNotEmpty)
                          FilledButton.tonal(
                            onPressed: () => _applyBillingRowFilters(
                              eventType: item.eventType,
                            ),
                            child: Text(
                              l10n.billingAuditFilterByEventType(
                                item.eventType!.trim(),
                              ),
                            ),
                          ),
                        FilledButton.tonal(
                          onPressed: () => _applyBillingRowFilters(
                            providerEventId: item.providerEventId,
                            rawEventId: item.rawEventId,
                          ),
                          child: Text(l10n.billingAuditOnlyThisEvent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_billingEventsPage?.hasMore == true)
            OutlinedButton(
              onPressed: _loadingBillingEvents || _loadingMoreBillingEvents
                  ? null
                  : () => _loadBillingEvents(append: true),
              child: Text(
                _loadingMoreBillingEvents
                    ? l10n.opsWhLoading
                    : l10n.billingAuditLoadMore,
              ),
            ),
        ],
      ),
    );
  }
}
