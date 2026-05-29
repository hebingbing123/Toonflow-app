import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design_system/components/studio_async_data_view.dart';
import '../../design_system/components/studio_loading_placeholders.dart';
import '../../design_system/components/studio_toolbar_button.dart';
import '../../design_system/components/studio_surfaces.dart';
import '../../design_system/components/studio_metric_switch.dart';
import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/studio_responsive_layout.dart';
import '../../design_system/components/studio_entrance_motion.dart';
import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/billing_l10n_helpers.dart';
import '../../rust_api.dart';

/// Self-serve plan purchase (Alipay / Stripe / BitPay when configured).
class SubscribePlanPage extends StatefulWidget {
  const SubscribePlanPage({
    super.key,
    required this.accessToken,
    this.currentPlanTier,
    this.checkoutSuccess = false,
  });

  final String accessToken;
  final String? currentPlanTier;
  final bool checkoutSuccess;

  @override
  State<SubscribePlanPage> createState() => _SubscribePlanPageState();
}

class _SubscribePlanPageState extends State<SubscribePlanPage> {
  bool _loading = true;
  String? _error;
  List<BillingPlanPublic> _plans = const [];
  String? _pendingSessionId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.checkoutSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.billingCheckoutSuccess),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await fetchBillingPlansV1(widget.accessToken, currency: 'CNY');
      if (!mounted) return;
      setState(() {
        _plans = resp.plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, e);
        _loading = false;
      });
    }
  }

  void _startPolling(String sessionId) {
    _pollTimer?.cancel();
    _pendingSessionId = sessionId;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _pendingSessionId == null) return;
      try {
        final session = await fetchBillingCheckoutSessionV1(
          widget.accessToken,
          sessionId: _pendingSessionId!,
        );
        if (session.status == 'paid' && mounted) {
          _pollTimer?.cancel();
          _pendingSessionId = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.billingCheckoutSuccess),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (_) {
        // keep polling
      }
    });
  }

  Future<void> _checkout(String planTier, String provider) async {
    try {
      final checkout = await postBillingCheckoutV1(
        widget.accessToken,
        planTier: planTier,
        provider: provider,
      );
      final uri = Uri.tryParse(checkout.payUrl);
      if (uri == null) {
        throw StateError('invalid pay_url');
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('could not open payment URL');
      }
      _startPolling(checkout.sessionId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeUserVisibleApiErrorResolved(context, e)),
        ),
      );
    }
  }

  Future<void> _openPortal() async {
    try {
      final url = await postBillingPortalV1(widget.accessToken);
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeUserVisibleApiErrorResolved(context, e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(l10n.billingSubscribeTitle)),
      body: StudioAsyncDataView(
        loading: _loading,
        error: _error,
        onRetry: _load,
        loadingPlaceholder: StudioLoadingPlaceholder.list,
        loadingItemCount: 3,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = studioGridCrossAxisCount(
              constraints.maxWidth,
              handset: 1,
              tablet: 1,
              desktop: 2,
            );
            final header = <Widget>[
              if (widget.currentPlanTier != null)
                Text(
                  l10n.billingCurrentPlan(
                    planTierDisplayName(l10n, widget.currentPlanTier!),
                  ),
                  style: studioSectionIntroStyle(context),
                ),
              const SizedBox(height: StudioSpacing.md),
            ];
            final footer = Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openPortal,
                child: Text(l10n.billingManageSubscription),
              ),
            );
            if (crossAxisCount <= 1) {
              return ListView(
                padding: const EdgeInsets.all(
                  StudioLayoutSpacing.insetComfortable,
                ),
                children: <Widget>[
                  ...header,
                  for (var i = 0; i < _plans.length; i++) ...<Widget>[
                    studioStaggeredItem(
                      i,
                      entranceKey: _plans.length,
                      child: _PlanCard(
                        plan: _plans[i],
                        highlighted: _plans[i].planTier == widget.currentPlanTier,
                        onAlipay: _plans[i].providers.contains('alipay')
                            ? () => _checkout(_plans[i].planTier, 'alipay')
                            : null,
                        onStripe: _plans[i].providers.contains('stripe')
                            ? () => _checkout(_plans[i].planTier, 'stripe')
                            : null,
                        onBitpay: _plans[i].providers.contains('bitpay')
                            ? () => _checkout(_plans[i].planTier, 'bitpay')
                            : null,
                      ),
                    ),
                    const SizedBox(height: StudioSpacing.md),
                  ],
                  footer,
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(
                StudioLayoutSpacing.insetComfortable,
              ),
              children: <Widget>[
                ...header,
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: StudioSpacing.md,
                    crossAxisSpacing: StudioSpacing.md,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    return studioStaggeredItem(
                      index,
                      entranceKey: _plans.length,
                      child: _PlanCard(
                        plan: plan,
                        highlighted: plan.planTier == widget.currentPlanTier,
                        onAlipay: plan.providers.contains('alipay')
                            ? () => _checkout(plan.planTier, 'alipay')
                            : null,
                        onStripe: plan.providers.contains('stripe')
                            ? () => _checkout(plan.planTier, 'stripe')
                            : null,
                        onBitpay: plan.providers.contains('bitpay')
                            ? () => _checkout(plan.planTier, 'bitpay')
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: StudioSpacing.md),
                footer,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.highlighted,
    this.onAlipay,
    this.onStripe,
    this.onBitpay,
  });

  final BillingPlanPublic plan;
  final bool highlighted;
  final VoidCallback? onAlipay;
  final VoidCallback? onStripe;
  final VoidCallback? onBitpay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context).copyWith(
        border: highlighted
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(plan.displayName, style: studioCardTitleStyle(context)),
            const SizedBox(height: StudioSpacing.xs),
            StudioMetricSwitch(
              transitionKey: plan.priceLabel,
              child: Text(
                plan.priceLabel,
                style: studioMetricTitleStyle(context),
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              plan.description,
              style: studioSectionIntroStyle(context),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: StudioSpacing.md),
            if (onAlipay != null)
              StudioToolbarButton(
                label: l10n.billingPayWithAlipay,
                onPressed: onAlipay,
                primary: highlighted,
              ),
            if (onStripe != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.sm),
              StudioToolbarButton(
                label: l10n.billingPayWithStripe,
                onPressed: onStripe,
              ),
            ],
            if (onBitpay != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.sm),
              OutlinedButton(
                onPressed: onBitpay,
                child: Text(l10n.billingPayWithBitpay),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
