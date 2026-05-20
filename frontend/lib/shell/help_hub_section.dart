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
    
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l10n.helpHubDocsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                RiskyOperationConfirmPrefsOverflowMenu(
                  tooltip: l10n.riskyPrefsTooltipSameAsMainPanelHeaders,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            tabs: [
              Tab(text: l10n.helpHubTabPersonal),
              Tab(text: l10n.opsWhSectionTitle),
              Tab(text: l10n.billingAuditTitle),
            ],
          ),
          Expanded(
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