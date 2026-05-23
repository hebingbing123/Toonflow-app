import 'package:flutter/material.dart';

import '../../design_system/components/studio_card.dart';
import '../../design_system/components/studio_skeleton.dart';
import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/billing_l10n_helpers.dart';
import '../../rust_api.dart';
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
  UsageSummaryResponse? _usage;

  @override
  void initState() {
    super.initState();
    _load();
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
        _usage = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await fetchMeV2(token);
      final scope = me.billingScope == 'workspace' ? 'workspace' : 'user';
      final usage = await fetchUsageSummary(
        token,
        scope: scope == 'workspace' ? UsageSummaryScope.workspace : UsageSummaryScope.user,
      );
      if (!mounted) return;
      setState(() {
        _me = me;
        _usage = usage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: StudioSkeleton(height: 120),
      );
    }
    if (widget.accessToken == null || widget.accessToken!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(l10n.teamWorkspaceLoginRequired),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_error!),
            TextButton(onPressed: _load, child: Text(l10n.taskCenterRetry)),
          ],
        ),
      );
    }
    final me = _me!;
    final usage = _usage;
    final billing = me.billingScope == 'workspace'
        ? me.currentWorkspaceBilling
        : null;
    final planTier = billing?.planTier ?? me.user.planTier;
    final jobsToday = usage?.jobsToday ?? billing?.jobsToday ?? me.user.jobsToday ?? 0;
    final quota = usage?.dailyJobQuota ?? billing?.dailyJobQuota ?? me.user.dailyJobQuota;
    final quotaLabel = quota == null ? '∞' : quota.toString();
    final subStatus = subscriptionStatusLabel(l10n, me.user.subscriptionStatus);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.studioPlanUsageTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          StudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  planTierDisplayName(l10n, planTier),
                  style: studioPageTitleStyle(context),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.studioPlanUsageBillingScope(me.billingScope),
                  style: studioSectionIntroStyle(context),
                ),
                const SizedBox(height: 4),
                Text(l10n.studioPlanUsageJobsToday(jobsToday, quotaLabel)),
                if (usage != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(l10n.studioPlanUsageEvents7d(usage.eventsLast7d)),
                ],
                const SizedBox(height: 4),
                Text(l10n.studioPlanUsageSubscription(subStatus)),
                const SizedBox(height: 8),
                Text(
                  l10n.studioPlanUsageEstimateDisclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: StudioTokens.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (widget.accessToken != null) ...<Widget>[
            const SizedBox(height: 24),
            SpendSummaryPanel(accessToken: widget.accessToken!),
          ],
        ],
      ),
    );
  }
}
