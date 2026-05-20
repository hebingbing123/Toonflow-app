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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Builder(
        builder: (context) {
          final viewportWidth = MediaQuery.sizeOf(context).width;
          final billingDropdownWidth = viewportWidth < 1320 ? 220.0 : 240.0;
          final billingDateFieldWidth = viewportWidth < 1320 ? 240.0 : 280.0;

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
    );
  }
}
