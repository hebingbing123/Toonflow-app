part of '../../home_page.dart';

extension _HelpHubWebhookActions on _HelpHubSectionState {
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
}
