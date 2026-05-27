part of '../../home_page.dart';

/// Help Hub outbound webhooks panel.
/// Manages webhook creation, configuration, testing, and delivery monitoring.
class HelpHubWebhooksPanel extends StatefulWidget {
  const HelpHubWebhooksPanel({
    super.key,
    required this.accessToken,
    this.debugWebhooks,
    this.debugLatestCreatedWebhook,
    this.debugWebhookDeliveries,
    this.debugWebhookLastTestResults,
  });

  final String? accessToken;
  final OutboundWebhookListResponseV1? debugWebhooks;
  final OutboundWebhookCreatedResponseV1? debugLatestCreatedWebhook;
  final Map<String, OutboundWebhookDeliveryListResponseV1>? debugWebhookDeliveries;
  final Map<String, OutboundWebhookTestResponseV1>? debugWebhookLastTestResults;

  @override
  State<HelpHubWebhooksPanel> createState() => _HelpHubWebhooksPanelState();
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

class _HelpHubWebhooksPanelState extends State<HelpHubWebhooksPanel> {
  bool _loadingWebhooks = false;
  bool _creatingWebhook = false;
  String? _webhooksError;
  OutboundWebhookListResponseV1? _webhooks;
  OutboundWebhookCreatedResponseV1? _latestCreatedWebhook;

  final _webhookUrlController = TextEditingController();
  final _webhookSecretController = TextEditingController();
  final _webhookSearchController = TextEditingController();
  final _webhookTestEventTypeController = TextEditingController(text: 'test.ping');
  final _webhookWorkspaceIdController = TextEditingController();

  final Set<String> _createWebhookEventTypes = <String>{
    ...kOutboundWebhookPlatformEventTypes,
  };

  String _webhookSearchQuery = '';
  Timer? _webhookSearchDebounce;
  String? _webhookMutatingId;

  final Map<String, OutboundWebhookTestResponseV1> _webhookLastTestResultById = {};
  final Map<String, OutboundWebhookDeliveryListResponseV1> _webhookDeliveries = {};
  String? _loadingDeliveriesId;
  final List<_WebhookActivityEntry> _webhookActivity = [];
  final Map<String, TextEditingController> _webhookWorkspaceDraftControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.debugWebhooks != null) {
      _webhooks = widget.debugWebhooks;
      _latestCreatedWebhook = widget.debugLatestCreatedWebhook;
      _webhookDeliveries.addAll(widget.debugWebhookDeliveries ?? const {});
      _webhookLastTestResultById.addAll(widget.debugWebhookLastTestResults ?? const {});
      _syncWebhookWorkspaceDraftControllers();
    } else if (!ProductDemoMode.instance.shouldSkipLiveApi) {
      unawaited(_loadWebhooks());
    }
  }

  @override
  void dispose() {
    _webhookSearchDebounce?.cancel();
    _webhookUrlController.dispose();
    _webhookSecretController.dispose();
    _webhookSearchController.dispose();
    _webhookTestEventTypeController.dispose();
    _webhookWorkspaceIdController.dispose();
    for (final c in _webhookWorkspaceDraftControllers.values) {
      c.dispose();
    }
    _webhookWorkspaceDraftControllers.clear();
    super.dispose();
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

  void _syncWebhookWorkspaceDraftControllers() {
      final items = _webhooks?.items ?? const <OutboundWebhookListItemV1>[];
      final alive = items.map((e) => e.id).toSet();
      for (final id in _webhookWorkspaceDraftControllers.keys.toList()) {
        if (!alive.contains(id)) {
          _webhookWorkspaceDraftControllers.remove(id)?.dispose();
        }
      }
      for (final wh in items) {
        _webhookWorkspaceDraftControllers.putIfAbsent(
          wh.id,
          () => TextEditingController(text: wh.workspaceId ?? ''),
        );
      }
    }

    void _disposeAllWebhookWorkspaceDraftControllers() {
      for (final c in _webhookWorkspaceDraftControllers.values) {
        c.dispose();
      }
      _webhookWorkspaceDraftControllers.clear();
    }

    Future<void> _loadWebhooks() async {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        setState(() {
          _webhooksError = kProductShellSignInErrorPlaceholder;
          _webhooks = null;
        });
        _disposeAllWebhookWorkspaceDraftControllers();
        return;
      }
      setState(() {
        _loadingWebhooks = true;
        _webhooksError = null;
      });
      try {
        final resp = await getSettingsOutboundWebhookListV1(token);
        if (!mounted) {
          return;
        }
        setState(() {
          _webhooks = resp;
          _syncWebhookWorkspaceDraftControllers();
        });
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _webhooksError = describeUserVisibleApiErrorResolved(context, e);
          _webhooks = null;
        });
        _disposeAllWebhookWorkspaceDraftControllers();
      } finally {
        if (mounted) {
          setState(() {
            _loadingWebhooks = false;
          });
        }
      }
    }

    Future<void> _createWebhook() async {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      final url = _webhookUrlController.text.trim();
      if (url.isEmpty) {
        setState(() {
          _webhooksError = l10n.opsWhErrorUrlRequired;
        });
        return;
      }
      final wsRaw = _webhookWorkspaceIdController.text.trim();
      String? workspaceId;
      if (wsRaw.isNotEmpty) {
        if (!outboundWebhookWorkspaceIdLooksValid(wsRaw)) {
          setState(() {
            _webhooksError = l10n.opsWhErrorWorkspaceId;
          });
          return;
        }
        workspaceId = wsRaw;
      }
      setState(() {
        _creatingWebhook = true;
        _webhooksError = null;
      });
      try {
        final created = await postSettingsOutboundWebhookCreateV1(
          token,
          OutboundWebhookCreateBodyV1(
            url: url,
            secret: _webhookSecretController.text.trim().isEmpty
                ? null
                : _webhookSecretController.text.trim(),
            workspaceId: workspaceId,
            eventTypes: outboundWebhookEventTypesPayloadForCreate(
              _createWebhookEventTypes,
            ),
          ),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _latestCreatedWebhook = created;
          _webhookUrlController.clear();
          _webhookSecretController.clear();
          _webhookWorkspaceIdController.clear();
          _createWebhookEventTypes
            ..clear()
            ..addAll(kOutboundWebhookPlatformEventTypes);
          _appendWebhookActivity(
            action: 'created',
            webhookId: created.id,
            summary: created.url,
          );
        });
        await Clipboard.setData(ClipboardData(text: created.secret));
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolveAppLocalizationsForErrors(context).opsWhSnackCreated,
            ),
          ),
        );
        await _loadWebhooks();
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _webhooksError = describeUserVisibleApiErrorResolved(context, e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _creatingWebhook = false;
          });
        }
      }
    }

    Future<void> _patchWebhookWorkspaceScope(String webhookId) async {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        return;
      }
      final ctrl = _webhookWorkspaceDraftControllers[webhookId];
      final draft = ctrl?.text.trim() ?? '';

      setState(() {
        _webhooksError = null;
        _webhookMutatingId = webhookId;
      });
      try {
        if (draft.isNotEmpty && !outboundWebhookWorkspaceIdLooksValid(draft)) {
          if (!mounted) {
            return;
          }
          setState(() {
            _webhooksError = resolveAppLocalizationsForErrors(
              context,
            ).opsWhErrorWorkspaceIdPatch;
          });
          return;
        }
        if (draft.isEmpty) {
          await patchSettingsOutboundWebhookV1(
            token,
            webhookId,
            const OutboundWebhookPatchBodyV1(clearWorkspaceId: true),
          );
        } else {
          await patchSettingsOutboundWebhookV1(
            token,
            webhookId,
            OutboundWebhookPatchBodyV1(workspaceId: draft),
          );
        }
        if (!mounted) {
          return;
        }
        final patchL10n = resolveAppLocalizationsForErrors(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              draft.isEmpty
                  ? patchL10n.opsWhSnackScopeGlobal
                  : patchL10n.opsWhSnackScopeWorkspaceUpdated,
            ),
          ),
        );
        await _loadWebhooks();
        OutboundWebhookListItemV1? refreshed;
        final list = _webhooks?.items;
        if (list != null) {
          for (final w in list) {
            if (w.id == webhookId) {
              refreshed = w;
              break;
            }
          }
        }
        _webhookWorkspaceDraftControllers[webhookId]?.text =
            refreshed?.workspaceId ?? '';
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _webhooksError = describeUserVisibleApiErrorResolved(context, e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _webhookMutatingId = null;
          });
        }
      }
    }

    Future<void> _patchWebhookEventSubscription(
      OutboundWebhookListItemV1 wh,
      Set<String> nextSelection,
    ) async {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        return;
      }
      setState(() {
        _webhooksError = null;
        _webhookMutatingId = wh.id;
      });
      try {
        await patchSettingsOutboundWebhookV1(
          token,
          wh.id,
          OutboundWebhookPatchBodyV1(
            eventTypes: outboundWebhookEventTypesPayloadForPatch(nextSelection),
          ),
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolveAppLocalizationsForErrors(context).opsWhSnackEventsUpdated,
            ),
          ),
        );
        await _loadWebhooks();
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _webhooksError = describeUserVisibleApiErrorResolved(context, e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _webhookMutatingId = null;
          });
        }
      }
    }

    Future<void> _deleteWebhook(String id) async {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        return;
      }
      final confirmed = await showStudioDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final dl10n = resolveAppLocalizationsForErrors(dialogContext);
          return StudioAlertDialog(
            title: Text(dl10n.opsWhDeleteTitle),
            content: SelectableText(dl10n.opsWhDeleteBody(id)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dl10n.notificationsActionCancel),
              ),
              FilledButton(
                style: studioFormPrimaryButtonStyle(dialogContext),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dl10n.opsWhDeleteConfirmButton),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }
      setState(() {
        _webhooksError = null;
        _webhookMutatingId = id;
      });
      try {
        await deleteSettingsOutboundWebhookV1(token, id);
        if (!mounted) {
          return;
        }
        setState(() {
          _webhookLastTestResultById.remove(id);
          _webhookDeliveries.remove(id);
          _webhookWorkspaceDraftControllers.remove(id)?.dispose();
          if (_latestCreatedWebhook?.id == id) {
            _latestCreatedWebhook = null;
          }
          _appendWebhookActivity(
            action: 'deleted',
            webhookId: id,
            summary: resolveAppLocalizationsForErrors(
              context,
            ).opsWhActivitySummaryDeleted,
          );
        });
        await _loadWebhooks();
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _webhooksError = describeUserVisibleApiErrorResolved(context, e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _webhookMutatingId = null;
          });
        }
      }
    }

    List<OutboundWebhookListItemV1> _filteredWebhooks() {
      final items = _webhooks?.items ?? const <OutboundWebhookListItemV1>[];
      final needle = _webhookSearchQuery.trim().toLowerCase();
      if (needle.isEmpty) {
        return items;
      }
      return items
          .where((wh) {
            final haystack =
                '${wh.id} ${wh.url} ${wh.createdAt} ${wh.updatedAt ?? ''} ${wh.eventTypes.join(',')} ${wh.workspaceId ?? ''}'
                    .toLowerCase();
            return haystack.contains(needle);
          })
          .toList(growable: false);
    }

    Future<void> _loadWebhookDeliveries(String id) async {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        return;
      }
      setState(() {
        _webhooksError = null;
        _loadingDeliveriesId = id;
      });
      try {
        final r = await getSettingsOutboundWebhookDeliveriesV1(
          token,
          id,
          limit: 30,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _webhookDeliveries[id] = r;
        });
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _webhooksError = describeUserVisibleApiErrorResolved(context, e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _loadingDeliveriesId = null;
          });
        }
      }
    }

    int _countWebhookActivity(String action) {
      return countWebhookActivity(
        _webhookActivity.map((entry) => entry.action),
        action,
      );
    }

    String _webhookInventorySummary(
      AppLocalizations l10n,
      List<OutboundWebhookListItemV1> filtered,
    ) {
      return buildWebhookInventorySummary(
        l10n,
        total: _webhooks?.items.length ?? 0,
        filtered: filtered.length,
        sessionTestOkCount: _countWebhookActivity('test_success'),
        sessionTestFailedCount: _countWebhookActivity('test_failed'),
        latestWebhookId: _latestCreatedWebhook?.id,
      );
    }

    void _appendWebhookActivity({
      required String action,
      required String webhookId,
      required String summary,
    }) {
      _webhookActivity.insert(
        0,
        _WebhookActivityEntry(
          at: DateTime.now(),
          action: action,
          webhookId: webhookId,
          summary: summary,
        ),
      );
      if (_webhookActivity.length > 20) {
        _webhookActivity.removeRange(20, _webhookActivity.length);
      }
    }

    Future<void> _testWebhook(String id) async {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        return;
      }
      setState(() {
        _webhooksError = null;
        _webhookMutatingId = id;
      });
      try {
        final res = await postSettingsOutboundWebhookTestV1(
          token,
          id,
          OutboundWebhookTestBodyV1(
            eventType: _webhookTestEventTypeController.text.trim().isEmpty
                ? null
                : _webhookTestEventTypeController.text.trim(),
          ),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _webhookLastTestResultById[id] = res;
          _appendWebhookActivity(
            action: res.delivered ? 'test_success' : 'test_failed',
            webhookId: id,
            summary: webhookActivityTestSummary(
              resolveAppLocalizationsForErrors(context),
              delivered: res.delivered,
              httpStatus: res.httpStatus,
              error: res.error,
            ),
          );
        });
        final testL10n = resolveAppLocalizationsForErrors(context);
        final httpLabel = res.httpStatus?.toString() ?? '-';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.delivered
                  ? testL10n.opsWhSnackDeliverOk(httpLabel)
                  : testL10n.opsWhSnackDeliverFail(
                      res.error?.trim().isNotEmpty == true
                          ? res.error!.trim()
                          : testL10n.globalSearchUnknownError,
                    ),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _webhooksError = describeUserVisibleApiErrorResolved(context, e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _webhookMutatingId = null;
          });
        }
      }
    }

    String _formatWebhookTestResult(
      AppLocalizations l10n,
      OutboundWebhookTestResponseV1 result,
    ) {
      final httpLabel = result.httpStatus?.toString() ?? '-';
      if (result.delivered) {
        return l10n.opsWhLastTestOk(httpLabel);
      }
      return l10n.opsWhLastTestFail(
        httpLabel,
        result.error?.trim().isNotEmpty == true
            ? result.error!.trim()
            : l10n.globalSearchUnknownError,
      );
    }


  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final filteredWebhooks = _filteredWebhooks();
    final outboundWebhookEmptyMsg = _webhooks == null
        ? null
        : describeOutboundWebhookEmptyState(
            l10n,
            total: _webhooks!.items.length,
            filtered: filteredWebhooks.length,
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.opsWhSectionTitle,
            style: studioCardTitleStyle(context),
          ),
          const SizedBox(height: StudioSpacing.xs),
          StudioCollapsibleFilterPanel(
            collapsible: true,
            title: l10n.opsWhCreate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _webhookUrlController,
                  decoration: InputDecoration(
                    labelText: l10n.opsWhUrlLabel,
                    hintText: l10n.opsWhUrlHint,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: _webhookSecretController,
                  decoration: InputDecoration(
                    labelText: l10n.opsWhSecretLabel,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: _webhookWorkspaceIdController,
                  decoration: InputDecoration(
                    labelText: l10n.opsWhWorkspaceIdLabel,
                    hintText: l10n.opsWhWorkspaceIdHint,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.opsWhSubscribeHint,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(height: StudioLayoutSpacing.titleTight),
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
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: _webhookTestEventTypeController,
                  decoration: InputDecoration(
                    labelText: l10n.opsWhTestEventTypeLabel,
                    hintText: l10n.opsWhTestEventTypeHint,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    style: studioFormTonalButtonStyle(context),
                    onPressed: _creatingWebhook ? null : _createWebhook,
                    child: Text(
                      _creatingWebhook ? l10n.opsWhCreating : l10n.opsWhCreate,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_latestCreatedWebhook != null) ...[
            const SizedBox(height: StudioSpacing.xs),
            Container(
              width: double.infinity,
              decoration: studioInsetPanelDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
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
                        StudioUtilityIconButton(
                          icon: Icons.close,
                          label: l10n.helpHubDialogClose,
                          onPressed: () {
                            setState(() {
                              _latestCreatedWebhook = null;
                            });
                          },
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
                    const SizedBox(height: StudioSpacing.xs),
                    StudioDenseActionRow(
                      spacing: StudioSpacing.xs,
                      children: [
                        OutlinedButton(
                          style: studioFormSecondaryButtonStyle(context),
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.id),
                          ),
                          child: Text(l10n.opsWhCopyId),
                        ),
                        OutlinedButton(
                          style: studioFormSecondaryButtonStyle(context),
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.url),
                          ),
                          child: Text(l10n.opsWhCopyUrl),
                        ),
                        OutlinedButton(
                          style: studioFormSecondaryButtonStyle(context),
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
          const SizedBox(height: StudioSpacing.xs),
          StudioCollapsibleFilterPanel(
            subtitle: _webhookSearchQuery.trim().isEmpty
                ? null
                : '${l10n.opsWhSearchLabel}: ${_webhookSearchQuery.trim()}',
            child: StudioFilterRow(
              wideLayout: StudioFilterWideLayout.toolbarRow,
              wideBreakpoint: 560,
              children: <Widget>[
                OutlinedButton(
                  style: studioFormSecondaryButtonStyle(context),
                  onPressed: _loadingWebhooks ? null : _loadWebhooks,
                  child: Text(l10n.opsWhRefreshList),
                ),
                Expanded(
                  child: TextField(
                    controller: _webhookSearchController,
                    decoration: InputDecoration(
                      labelText: l10n.opsWhSearchLabel,
                      isDense: true,
                    ),
                    onChanged: _onWebhookSearchChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          StudioAsyncDataView(
            loading: _loadingWebhooks,
            error: _webhooksError == kProductShellSignInErrorPlaceholder
                ? l10n.platformConfigPleaseSignIn
                : _webhooksError,
            onRetry: _loadWebhooks,
            loadingPlaceholder: StudioLoadingPlaceholder.list,
            loadingItemCount: 2,
            scrollableLoading: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
          if (_webhooks != null)
            Text(_webhookInventorySummary(l10n, filteredWebhooks)),
          if (_webhookActivity.isNotEmpty) ...[
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.opsWhRecentActivity,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: StudioSpacing.xs),
            ..._webhookActivity
                .take(6)
                .map(
                  (entry) => StudioListRow(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onCopy: () async {
                      final text = '${webhookActivityActionLabel(l10n, entry.action)}\n'
                          '${entry.webhookId}\n'
                          '${entry.summary}';
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.opsWhActivityRecordSuffix.trim())),
                      );
                    },
                    copyLabel: l10n.opsWhCopyActivityTooltip,
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
                    trailing: StudioUtilityIconButton(
                      icon: Icons.copy_outlined,
                      label: l10n.opsWhCopyActivityTooltip,
                      onPressed: () async {
                        final text = '${webhookActivityActionLabel(l10n, entry.action)}\n'
                            '${entry.webhookId}\n'
                            '${entry.summary}';
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.opsWhActivityRecordSuffix.trim())),
                        );
                      },
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
                  final tokens = StudioTokens.of(context);
                  final highlightLatest = _latestCreatedWebhook?.id == wh.id;
                  return studioStaggeredItem(
                    index,
                    entranceKey: filteredWebhooks.length,
                    child: Card(
                    color: highlightLatest
                        ? tokens.primarySoft.withValues(alpha: 0.92)
                        : null,
                    elevation: highlightLatest ? 0 : null,
                    child: Padding(
                      padding: const EdgeInsets.all(
                        StudioSpacing.radiusComfort,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wh.url,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: StudioLayoutSpacing.titleTight),
                          if (_latestCreatedWebhook?.id == wh.id)
                            Padding(
                              padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
                              child: StudioChip(
                                label: Text(l10n.opsWhChipLatestCreated),
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
                              padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
                              child: StudioChip(
                                label: Text(l10n.opsWhChipDisabled),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: StudioLayoutSpacing.microGap),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.opsWhSubscribeHeading,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                const SizedBox(height: StudioLayoutSpacing.titleTight),
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
                                    padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
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
                            padding: const EdgeInsets.only(top: StudioSpacing.xs),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.opsWhScopeHeading,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                const SizedBox(height: StudioLayoutSpacing.titleTight),
                                TextField(
                                  controller:
                                      _webhookWorkspaceDraftControllers[wh.id],
                                  decoration: InputDecoration(
                                    hintText: l10n.opsWhScopeFieldHint,
                                    isDense: true,
                                  ),
                                  enabled: !_loadingWebhooks && !rowBusy,
                                ),
                                const SizedBox(height: StudioSpacing.xs),
                                StudioDenseActionRow(
                                  spacing: StudioSpacing.xs,
                                  children: [
                                    OutlinedButton(
                                      style: studioFormSecondaryButtonStyle(
                                        context,
                                      ),
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
                            const SizedBox(height: StudioSpacing.xs),
                            Text(
                              l10n.opsWhRecentDeliveries,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            ..._webhookDeliveries[wh.id]!.items
                                .take(6)
                                .map(
                                  (d) => StudioListRow(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    onCopy: () async {
                                      final text =
                                          '${d.eventType} · ${d.status} · HTTP ${d.httpStatus ?? '-'}\n'
                                          '${d.createdAt}\n${d.error ?? ''}';
                                      await Clipboard.setData(
                                        ClipboardData(text: text),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(l10n.opsWhActivityRecordSuffix.trim()),
                                        ),
                                      );
                                    },
                                    copyLabel: l10n.opsWhCopyActivityTooltip,
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
                              padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
                              child: Text(
                                _formatWebhookTestResult(
                                  l10n,
                                  _webhookLastTestResultById[wh.id]!,
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: StudioSpacing.xs),
                          StudioDenseActionRow(
                            spacing: StudioSpacing.xs,
                            children: [
                              StudioUtilityIconButton(
                                icon: Icons.copy_outlined,
                                label: l10n.opsWhTooltipCopyUrl,
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
                              ),
                              OutlinedButton(
                                style: studioFormSecondaryButtonStyle(context),
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
                                style: studioFormSecondaryButtonStyle(context),
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
                                style: studioFormSecondaryButtonStyle(context),
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
                  ),
                  );
                },
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
