import 'package:flutter/material.dart';

import '../../config.dart';
import '../../design_system/components/studio_primary_button.dart';
import '../../design_system/components/studio_async_data_view.dart';
import '../../design_system/components/studio_surfaces.dart';
import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/billing_l10n_helpers.dart';
import '../../rust_api.dart';
import '../../shell/studio_settings_hub_navigation.dart';
import '../billing/subscribe_plan_page.dart';
import '../model_pricing/spend_summary_panel.dart';

/// Plan tier, quota, and usage summary for Studio settings.
class PlanUsageSection extends StatefulWidget {
  const PlanUsageSection({super.key, required this.accessToken});

  final String? accessToken;

  @override
  State<PlanUsageSection> createState() => _PlanUsageSectionState();
}

class _PlanUsageSectionState extends State<PlanUsageSection> {
  bool _loading = true;
  String? _error;
  MeV2Response? _me;
  MeResponse? _meV1;
  UsageSummaryResponse? _usage;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenSubscribeFromNavigation());
  }

  Future<void> _maybeOpenSubscribeFromNavigation() async {
    if (!mounted || !StudioSettingsHubNavigation.consumeOpenSubscribe()) {
      return;
    }
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      return;
    }
    final success = StudioSettingsHubNavigation.consumeCheckoutSuccess();
    final tier = _me?.user.planTier ?? _meV1?.planTier;
    final upgraded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => SubscribePlanPage(
          accessToken: token,
          currentPlanTier: tier,
          checkoutSuccess: success,
        ),
      ),
    );
    if (upgraded == true && mounted) {
      await _load();
    }
  }

  Future<void> _openSubscribe() async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      return;
    }
    final tier = _me?.user.planTier ?? _meV1?.planTier;
    final upgraded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => SubscribePlanPage(
          accessToken: token,
          currentPlanTier: tier,
        ),
      ),
    );
    if (upgraded == true && mounted) {
      await _load();
    }
  }

  @override
  void didUpdateWidget(covariant PlanUsageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _me = null;
        _meV1 = null;
        _usage = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      late final String billingScope;
      if (kEnableWorkspaceBilling) {
        MeV2Response? meV2;
        try {
          meV2 = await fetchMeV2(token);
        } catch (_) {
          // V2 might not be available yet; fall back to v1 only.
        }
        if (meV2 != null) {
          billingScope = meV2.billingScope == 'workspace' ? 'workspace' : 'user';
          if (!mounted) return;
          setState(() {
            _me = meV2;
            _meV1 = null;
          });
        } else {
          final me = await fetchMeV1(token);
          billingScope = 'user';
          if (!mounted) return;
          setState(() {
            _meV1 = me;
            _me = null;
          });
        }
      } else {
        final me = await fetchMeV1(token);
        billingScope = 'user';
        if (!mounted) return;
        setState(() {
          _meV1 = me;
          _me = null;
        });
      }
      final usage = await fetchUsageSummary(
        token,
        scope: billingScope == 'workspace'
            ? UsageSummaryScope.workspace
            : UsageSummaryScope.user,
      );
      if (!mounted) return;
      setState(() {
        _usage = usage;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.accessToken == null || widget.accessToken!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: StudioSpacing.sm),
        child: Text(l10n.teamWorkspaceLoginRequired),
      );
    }
    final meV2 = _me;
    final meV1 = _meV1;
    return StudioAsyncDataView(
      loading: _loading || (meV2 == null && meV1 == null && _error == null),
      error: _error,
      onRetry: _load,
      child: _buildPlanUsageBody(context, l10n, meV2: meV2, meV1: meV1),
    );
  }

  Widget _buildPlanUsageBody(
    BuildContext context,
    AppLocalizations l10n, {
    required MeV2Response? meV2,
    required MeResponse? meV1,
  }) {
    if (meV2 == null && meV1 == null) {
      return const SizedBox.shrink();
    }
    final usage = _usage;
    final billingScope = meV2?.billingScope ?? 'user';
    final billing = billingScope == 'workspace' ? meV2?.currentWorkspaceBilling : null;
    final planTier = billing?.planTier ?? meV2?.user.planTier ?? meV1!.planTier;
    final jobsToday =
        usage?.jobsToday ?? billing?.jobsToday ?? meV2?.user.jobsToday ?? meV1?.jobsToday ?? 0;
    final quota =
        usage?.dailyJobQuota ?? billing?.dailyJobQuota ?? meV2?.user.dailyJobQuota ?? meV1?.dailyJobQuota;
    final quotaLabel = quota == null ? '∞' : quota.toString();
    final subStatus = subscriptionStatusLabel(
      l10n,
      meV2?.user.subscriptionStatus ?? meV1?.subscriptionStatus,
    );

    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: StudioSpacing.sm),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration:
                  studioInsetPanelDecoration(
                    context,
                    backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
                  ).copyWith(
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
                child: Text(
                  l10n.studioPlanUsageTitle,
                  style: studioPaneTitleStyle(context),
                ),
              ),
            ),
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            DecoratedBox(
              decoration: studioInsetPanelDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  planTierDisplayName(l10n, planTier),
                  style: studioPageTitleStyle(context),
                ),
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.studioPlanUsageBillingScope(billingScope),
                  style: studioSectionIntroStyle(context),
                ),
                const SizedBox(height: StudioLayoutSpacing.titleTight),
                Text(l10n.studioPlanUsageJobsToday(jobsToday, quotaLabel)),
                if (usage != null) ...<Widget>[
                  const SizedBox(height: StudioLayoutSpacing.titleTight),
                  Text(l10n.studioPlanUsageEvents7d(usage.eventsLast7d)),
                ],
                const SizedBox(height: StudioLayoutSpacing.titleTight),
                Text(l10n.studioPlanUsageSubscription(subStatus)),
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.studioPlanUsageEstimateDisclaimer,
                  style: studioSectionIntroStyle(context),
                ),
                const SizedBox(height: StudioSpacing.md),
                StudioPrimaryButton(
                  label: l10n.billingUpgradePlan,
                  onPressed: _openSubscribe,
                ),
              ],
                ),
              ),
            ),
            if (widget.accessToken != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.md),
              SpendSummaryPanel(accessToken: widget.accessToken!),
            ],
          ],
        ),
      ),
    );
  }
}
