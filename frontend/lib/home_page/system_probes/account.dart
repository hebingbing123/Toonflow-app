// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageSystemProbesAccount on _HomePageState {
  Future<void> _callMe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingMe = true;
      _error = null;
      _meBody = null;
    });
    try {
      final r = await fetchMeV1(token);
      if (!mounted) return;
      final parts = <String>['sub=${r.sub}', 'plan_tier=${r.planTier}'];
      if (r.email != null && r.email!.isNotEmpty) {
        parts.add('email=${r.email}');
      }
      if (r.billingCurrency != null && r.billingCurrency!.isNotEmpty) {
        parts.add('billing_currency=${r.billingCurrency}');
      }
      if (r.billingProvider != null && r.billingProvider!.isNotEmpty) {
        parts.add('billing_provider=${r.billingProvider}');
      }
      setState(() {
        _meBody = parts.join(' · ');
        _loadingMe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMe = false;
      });
    }
  }

  Future<void> _callUsageSummary() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingUsageSummary = true;
      _error = null;
      _usageSummaryBody = null;
    });
    try {
      final u = await fetchUsageSummary(token);
      if (!mounted) return;
      setState(() {
        _usageSummaryBody =
            'events_last_24h=${u.eventsLast24h} · events_last_7d=${u.eventsLast7d} · event_counts_last_7d=${u.eventCountsLast7d}';
        _loadingUsageSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingUsageSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingUsageSummary = false;
      });
    }
  }
}
