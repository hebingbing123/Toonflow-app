part of '../../home_page.dart';

/// Help Hub section with three tabs: Docs, Webhooks, and Billing Events.
/// Refactored from a 1620-line StatefulWidget into a clean tabbed interface.
class _HelpHubSection extends StatelessWidget {
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
  final Map<String, OutboundWebhookDeliveryListResponseV1>? debugWebhookDeliveries;
  final Map<String, OutboundWebhookTestResponseV1>? debugWebhookLastTestResults;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    // Product shell places this pane in a vertical sliver list (unbounded height).
    // TabBarView needs a finite height; derive from viewport instead of Expanded.
    final tabBodyHeight = (MediaQuery.sizeOf(context).height * 0.72).clamp(
      420.0,
      900.0,
    );

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: StudioLayoutSpacing.cardInner - 4,
              left: StudioLayoutSpacing.cardInner - 4,
              right: StudioLayoutSpacing.cardInner - 4,
            ),
            child: DecoratedBox(
              decoration: studioInsetPanelDecoration(context).copyWith(
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: studioShadowColor(context, alpha: 0.12),
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
                  children: [
                    Expanded(
                      child: Text(
                        l10n.helpHubDocsTitle,
                        style: studioPaneTitleStyle(context),
                      ),
                    ),
                    RiskyOperationConfirmPrefsOverflowMenu(
                      tooltip: l10n.riskyPrefsTooltipSameAsMainPanelHeaders,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
          TabBar(
            tabs: [
              Tab(text: l10n.helpHubTabPersonal),
              Tab(text: l10n.opsWhSectionTitle),
              Tab(text: l10n.billingAuditTitle),
            ],
          ),
          SizedBox(
            height: tabBodyHeight,
            child: TabBarView(
              children: [
                HelpHubDocsPanel(accessToken: accessToken),
                HelpHubWebhooksPanel(
                  accessToken: accessToken,
                  debugWebhooks: debugWebhooks,
                  debugLatestCreatedWebhook: debugLatestCreatedWebhook,
                  debugWebhookDeliveries: debugWebhookDeliveries,
                  debugWebhookLastTestResults: debugWebhookLastTestResults,
                ),
                HelpHubBillingPanel(
                  accessToken: accessToken,
                  debugBillingEventsPage: debugBillingEventsPage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}