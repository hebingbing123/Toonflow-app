part of '../../home_page.dart';

/// Help Hub billing webhook events panel.
/// Displays and filters billing webhook events with export capabilities.
class HelpHubBillingPanel extends StatefulWidget {
  const HelpHubBillingPanel({
    super.key,
    required this.accessToken,
    this.debugBillingEventsPage,
  });

  final String? accessToken;
  final BillingWebhookEventsResponseV1? debugBillingEventsPage;

  @override
  State<HelpHubBillingPanel> createState() => _HelpHubBillingPanelState();
}

class _HelpHubBillingPanelState extends State<HelpHubBillingPanel> {
  bool _loadingBillingEvents = false;
  bool _loadingMoreBillingEvents = false;
  bool _exportingAllBillingEvents = false;
  String? _billingEventsError;
  BillingWebhookEventsResponseV1? _billingEventsPage;
  final List<BillingWebhookEventItemV1> _billingEvents = [];

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

  @override
  void initState() {
    super.initState();
    if (widget.debugBillingEventsPage != null) {
      _billingEventsPage = widget.debugBillingEventsPage;
      _billingEvents.addAll(widget.debugBillingEventsPage!.items);
    } else {
      unawaited(_loadBillingEvents());
    }
  }

  @override
  void dispose() {
    _billingEventTypeController.dispose();
    _billingProviderEventIdController.dispose();
    _billingProviderEventIdPrefixController.dispose();
    _billingRawEventIdController.dispose();
    _billingRawEventIdPrefixController.dispose();
    _billingEventCreatedFromController.dispose();
    _billingEventCreatedToController.dispose();
    _billingCreatedFromController.dispose();
    _billingCreatedToController.dispose();
    super.dispose();
  }

  BillingWebhookEventsQueryV1 _buildBillingEventsQuery({int offset = 0}) {
      return BillingWebhookEventsQueryV1(
        informationalEvent: _billingInformationalOnly,
        provider: _billingProvider,
        rawEventId: _billingRawEventIdController.text,
        rawEventIdPrefix: _billingRawEventIdPrefixController.text,
        eventType: _billingEventTypeController.text,
        providerEventId: _billingProviderEventIdController.text,
        providerEventIdPrefix: _billingProviderEventIdPrefixController.text,
        eventCreatedFrom: _billingEventCreatedFromController.text,
        eventCreatedTo: _billingEventCreatedToController.text,
        createdFrom: _billingCreatedFromController.text,
        createdTo: _billingCreatedToController.text,
        sort: _billingSort,
        limit: 30,
        offset: offset,
      );
    }

    Uri _billingEventsUri({int offset = 0}) {
      final query = _buildBillingEventsQuery(offset: offset);
      return Uri.parse(
        '$kApiBaseUrl/api/v1/webhooks/billing/events',
      ).replace(queryParameters: query.toQueryParameters());
    }

    Future<void> _loadBillingEvents({bool append = false}) async {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        setState(() {
          _billingEventsError = kProductShellSignInErrorPlaceholder;
          _billingEventsPage = null;
          _billingEvents.clear();
        });
        return;
      }
      setState(() {
        if (append) {
          _loadingMoreBillingEvents = true;
        } else {
          _loadingBillingEvents = true;
        }
        _billingEventsError = null;
      });
      try {
        final response = await getBillingWebhookEventsV1(
          token,
          query: _buildBillingEventsQuery(
            offset: append
                ? (_billingEventsPage?.nextOffset ?? _billingEvents.length)
                : 0,
          ),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _billingEventsPage = response;
          if (append) {
            _billingEvents.addAll(response.items);
          } else {
            _billingEvents
              ..clear()
              ..addAll(response.items);
          }
        });
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _billingEventsError = describeUserVisibleApiErrorResolved(context, e);
          if (!append) {
            _billingEventsPage = null;
            _billingEvents.clear();
          }
        });
      } finally {
        if (mounted) {
          setState(() {
            _loadingBillingEvents = false;
            _loadingMoreBillingEvents = false;
          });
        }
      }
    }

    String _formatBillingEventMeta(
      AppLocalizations l10n,
      BillingWebhookEventItemV1 item,
    ) {
      final parts = <String>[
        l10n.billingMetaProvider(item.provider ?? '-'),
        l10n.billingMetaType(item.eventType ?? '-'),
        l10n.billingMetaCreated(item.createdAt.toLocal().toIso8601String()),
      ];
      if (item.eventCreatedAt != null) {
        parts.add(
          l10n.billingMetaEventCreated(
            item.eventCreatedAt!.toLocal().toIso8601String(),
          ),
        );
      }
      parts.add(
        item.isInformationalEvent
            ? l10n.billingMetaInformational
            : l10n.billingMetaStateful,
      );
      return parts.join(' · ');
    }

    Map<String, int> _billingEventCountsByProvider(AppLocalizations l10n) {
      return countBillingEventsByProvider(l10n, _billingEvents);
    }

    Map<String, int> _billingEventCountsByType(AppLocalizations l10n) {
      return countBillingEventsByType(l10n, _billingEvents);
    }

    String _billingEventsSnapshotSummary(AppLocalizations l10n) {
      return buildBillingEventsSnapshotSummary(l10n, _billingEvents);
    }

    String _billingEventsQuerySummary(AppLocalizations l10n) {
      final parts = <String>[
        l10n.billingAuditQuerySummaryProvider(
          studioBillingProviderValueLabel(l10n, _billingProvider),
        ),
        l10n.billingAuditQuerySummaryInformational(
          studioBillingInformationalValueLabel(l10n, _billingInformationalOnly),
        ),
        l10n.billingAuditQuerySummarySort(
          studioBillingSortValueLabel(l10n, _billingSort),
        ),
      ];
      void addText(String fieldKey, TextEditingController controller) {
        final value = controller.text.trim();
        if (value.isNotEmpty) {
          parts.add(
            l10n.billingAuditQueryFilterLine(
              studioBillingAuditQueryFieldLabel(l10n, fieldKey),
              value,
            ),
          );
        }
      }

      addText('event_type', _billingEventTypeController);
      addText('provider_event_id', _billingProviderEventIdController);
      addText(
        'provider_event_id_prefix',
        _billingProviderEventIdPrefixController,
      );
      addText('raw_event_id', _billingRawEventIdController);
      addText('raw_event_id_prefix', _billingRawEventIdPrefixController);
      addText('event_created_from', _billingEventCreatedFromController);
      addText('event_created_to', _billingEventCreatedToController);
      addText('created_from', _billingCreatedFromController);
      addText('created_to', _billingCreatedToController);
      return parts.join('\n');
    }

    String _buildBillingEventsCsv() {
      final rows = <List<String>>[
        <String>[
          'id',
          'provider_event_id',
          'provider',
          'raw_event_id',
          'event_type',
          'event_created_at',
          'created_at',
          'is_informational_event',
        ],
        ..._billingEvents.map(
          (item) => <String>[
            '${item.id}',
            item.providerEventId,
            item.provider ?? '',
            item.rawEventId ?? '',
            item.eventType ?? '',
            item.eventCreatedAt?.toUtc().toIso8601String() ?? '',
            item.createdAt.toUtc().toIso8601String(),
            item.isInformationalEvent ? 'true' : 'false',
          ],
        ),
      ];
      return rows.map(_toCsvLine).join('\n');
    }

    String _toCsvLine(List<String> cells) {
      return cells.map((cell) => '"${cell.replaceAll('"', '""')}"').join(',');
    }

    Future<void> _copyBillingEventsQuerySummary() async {
      final l10n = resolveAppLocalizationsForErrors(context);
      await Clipboard.setData(
        ClipboardData(text: _billingEventsQuerySummary(l10n)),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.billingAuditQuerySummaryCopied)),
      );
    }

    Future<void> _copyBillingEventsSnapshotSummary() async {
      final l10n = resolveAppLocalizationsForErrors(context);
      await Clipboard.setData(
        ClipboardData(text: _billingEventsSnapshotSummary(l10n)),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.billingAuditSnapshotCopied)));
    }

    Future<void> _copyBillingAuditText(String text, String labelForSnack) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.billingCopiedWithLabel(labelForSnack))),
      );
    }

    Future<void> _applyBillingRowFilters({
      String? provider,
      String? eventType,
      String? providerEventId,
      String? rawEventId,
    }) async {
      setState(() {
        if (provider != null) {
          _billingProvider = provider.trim();
        }
        if (eventType != null) {
          _billingEventTypeController.text = eventType.trim();
        }
        if (providerEventId != null) {
          _billingProviderEventIdController.text = providerEventId.trim();
        }
        if (rawEventId != null) {
          _billingRawEventIdController.text = rawEventId.trim();
        }
      });
      await _loadBillingEvents();
    }

    Future<void> _copyAllBillingEventsCsv() async {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        setState(() {
          _billingEventsError = kProductShellSignInErrorPlaceholder;
        });
        return;
      }
      final exportL10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _exportingAllBillingEvents = true;
        _billingEventsError = null;
      });
      try {
        final all = <BillingWebhookEventItemV1>[];
        var offset = 0;
        const pageSize = 200;
        for (var page = 0; page < 20; page++) {
          final response = await getBillingWebhookEventsV1(
            token,
            query: BillingWebhookEventsQueryV1(
              informationalEvent: _billingInformationalOnly,
              provider: _billingProvider,
              rawEventId: _billingRawEventIdController.text,
              rawEventIdPrefix: _billingRawEventIdPrefixController.text,
              eventType: _billingEventTypeController.text,
              providerEventId: _billingProviderEventIdController.text,
              providerEventIdPrefix: _billingProviderEventIdPrefixController.text,
              eventCreatedFrom: _billingEventCreatedFromController.text,
              eventCreatedTo: _billingEventCreatedToController.text,
              createdFrom: _billingCreatedFromController.text,
              createdTo: _billingCreatedToController.text,
              sort: _billingSort,
              limit: pageSize,
              offset: offset,
            ),
          );
          all.addAll(response.items);
          if (!response.hasMore || response.nextOffset == null) {
            break;
          }
          offset = response.nextOffset!;
        }
        final rows = <List<String>>[
          <String>['query_summary', _billingEventsQuerySummary(exportL10n)],
          <String>[],
          <String>[
            'id',
            'provider_event_id',
            'provider',
            'raw_event_id',
            'event_type',
            'event_created_at',
            'created_at',
            'is_informational_event',
          ],
          ...all.map(
            (item) => <String>[
              '${item.id}',
              item.providerEventId,
              item.provider ?? '',
              item.rawEventId ?? '',
              item.eventType ?? '',
              item.eventCreatedAt?.toUtc().toIso8601String() ?? '',
              item.createdAt.toUtc().toIso8601String(),
              item.isInformationalEvent ? 'true' : 'false',
            ],
          ),
        ];
        await Clipboard.setData(
          ClipboardData(text: rows.map(_toCsvLine).join('\n')),
        );
        if (!mounted) {
          return;
        }
        final l10n = resolveAppLocalizationsForErrors(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.billingAuditFullCsvCopied(all.length))),
        );
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _billingEventsError = describeUserVisibleApiErrorResolved(context, e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _exportingAllBillingEvents = false;
          });
        }
      }
    }


  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final billingWebhookEmptyMsg = describeBillingWebhookEmptyState(
      l10n,
      hasPage: _billingEventsPage != null,
      loaded: _billingEvents.length,
      isLoading: _loadingBillingEvents,
      error: _billingEventsError,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
      child: Builder(
        builder: (context) {
          final viewportWidth = MediaQuery.sizeOf(context).width;
          final billingDropdownWidth = viewportWidth < 1320 ? 220.0 : 240.0;
          final billingDateFieldWidth = viewportWidth < 1320 ? 240.0 : 280.0;
          final filterSummary = _billingEventsQuerySummary(l10n)
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .take(2)
              .join(' · ');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.billingAuditTitle,
                style: studioCardTitleStyle(context),
              ),
              const SizedBox(height: 8),
              StudioCollapsibleFilterPanel(
                subtitle: filterSummary.isEmpty ? null : filterSummary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    StudioFilterRow(
                      wideLayout: StudioFilterWideLayout.wrap,
                      wideBreakpoint: 720,
                      children: <Widget>[
                        SizedBox(
                          width: billingDropdownWidth,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _billingProvider,
                            decoration: InputDecoration(
                              labelText: l10n.billingAuditProviderLabel,
                              isDense: true,
                            ),
                            items: <DropdownMenuItem<String>>[
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
                              isDense: true,
                            ),
                            items: <DropdownMenuItem<String>>[
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
                        StudioFilterChip(
                          label: Text(l10n.billingAuditOnlyInformational),
                          selected: _billingInformationalOnly == true,
                          onSelected: (selected) {
                            setState(() {
                              _billingInformationalOnly = selected
                                  ? true
                                  : null;
                            });
                          },
                        ),
                        StudioFilterChip(
                          label: Text(l10n.billingAuditOnlyStateful),
                          selected: _billingInformationalOnly == false,
                          onSelected: (selected) {
                            setState(() {
                              _billingInformationalOnly = selected
                                  ? false
                                  : null;
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
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _billingProviderEventIdController,
                      decoration: InputDecoration(
                        labelText: l10n.billingAuditProviderEventIdLabel,
                        hintText: l10n.billingAuditProviderEventIdHint,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _billingRawEventIdController,
                      decoration: InputDecoration(
                        labelText: l10n.billingAuditRawEventIdLabel,
                        hintText: l10n.billingAuditRawEventIdHint,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _billingProviderEventIdPrefixController,
                      decoration: InputDecoration(
                        labelText: l10n.billingAuditProviderEventIdPrefixLabel,
                        hintText: l10n.billingAuditProviderPrefixHint,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _billingRawEventIdPrefixController,
                      decoration: InputDecoration(
                        labelText: l10n.billingAuditRawEventIdPrefixLabel,
                        hintText: l10n.billingAuditRawPrefixHint,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StudioFilterRow(
                      wideLayout: StudioFilterWideLayout.wrap,
                      wideBreakpoint: 720,
                      children: <Widget>[
                        SizedBox(
                          width: billingDateFieldWidth,
                          child: TextField(
                            controller: _billingEventCreatedFromController,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.billingAuditEventCreatedFromLabel,
                              hintText: l10n.billingAuditEventCreatedFromHint,
                              isDense: true,
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
                              isDense: true,
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
                              isDense: true,
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
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StudioFilterRow(
                      wideLayout: StudioFilterWideLayout.wrap,
                      wideBreakpoint: 560,
                      children: <Widget>[
                        FilledButton.tonal(
                          onPressed: _loadingBillingEvents
                              ? null
                              : _loadBillingEvents,
                          child: Text(
                            _loadingBillingEvents
                                ? l10n.billingAuditQuerying
                                : l10n.billingAuditQuery,
                          ),
                        ),
                        OutlinedButton(
                          onPressed:
                              _loadingBillingEvents || _loadingMoreBillingEvents
                              ? null
                              : () {
                                  setState(() {
                                    _billingProvider = '';
                                    _billingInformationalOnly = null;
                                    _billingSort = 'id_desc';
                                    _billingEventTypeController.clear();
                                    _billingProviderEventIdController.clear();
                                    _billingProviderEventIdPrefixController
                                        .clear();
                                    _billingRawEventIdController.clear();
                                    _billingRawEventIdPrefixController.clear();
                                    _billingEventCreatedFromController.clear();
                                    _billingEventCreatedToController.clear();
                                    _billingCreatedFromController.clear();
                                    _billingCreatedToController.clear();
                                  });
                                  unawaited(_loadBillingEvents());
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
                                      content: Text(
                                        l10n.billingAuditCsvCopiedSnack,
                                      ),
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
                              ClipboardData(
                                text: _billingEventsUri().toString(),
                              ),
                            );
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.billingAuditQueryUrlCopiedSnack,
                                ),
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
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingBillingEvents) Text(l10n.billingAuditLoading),
              if (_billingEventsError != null)
                Text(
                  _billingEventsError == kProductShellSignInErrorPlaceholder
                      ? l10n.platformConfigPleaseSignIn
                      : _billingEventsError!,
                  style: TextStyle(color: StudioTokens.of(context).danger),
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
              if (_billingEvents.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  l10n.billingAuditCurrentLoadTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ...(_billingEventCountsByProvider(l10n).entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .map(
                          (entry) => StudioChip(
                            label: Text(
                              l10n.billingChipCount(entry.key, entry.value),
                            ),
                          ),
                        ),
                    StudioChip(
                      label: Text(
                        l10n.billingSnapInformational(
                          _billingEvents
                              .where((e) => e.isInformationalEvent)
                              .length,
                        ),
                      ),
                    ),
                    StudioChip(
                      label: Text(
                        l10n.billingSnapStateful(
                          _billingEvents
                              .where((e) => !e.isInformationalEvent)
                              .length,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ...(_billingEventCountsByType(l10n).entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .take(8)
                        .map(
                          (entry) => StudioChip(
                            label: Text(
                              l10n.billingChipCount(entry.key, entry.value),
                            ),
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
                  margin: const EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.providerEventId,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: StudioLayoutSpacing.titleTight),
                        SelectableText(_formatBillingEventMeta(l10n, item)),
                        if (item.rawEventId != null &&
                            item.rawEventId!.isNotEmpty)
                          SelectableText(
                            l10n.billingRowRawEventId(item.rawEventId!),
                          ),
                        SelectableText(l10n.billingRowId('${item.id}')),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
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
              if (_billingEventsPage?.hasMore == true) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: _loadingBillingEvents || _loadingMoreBillingEvents
                        ? null
                        : () => _loadBillingEvents(append: true),
                    child: Text(
                      _loadingMoreBillingEvents
                          ? l10n.opsWhLoading
                          : l10n.billingAuditLoadMore,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
