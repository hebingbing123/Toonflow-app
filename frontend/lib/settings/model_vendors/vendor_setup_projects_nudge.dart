import 'package:flutter/material.dart';

import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'domestic_vendor_setup_prefs.dart';
import 'domestic_vendors.dart';
import 'vendor_setup_loader.dart';

/// Compact banner on the projects home when domestic API keys are still missing.
class VendorSetupProjectsNudge extends StatefulWidget {
  const VendorSetupProjectsNudge({
    super.key,
    required this.accessToken,
    required this.onOpenModelVendorSettings,
  });

  final String? accessToken;
  final VoidCallback onOpenModelVendorSettings;

  @override
  State<VendorSetupProjectsNudge> createState() =>
      _VendorSetupProjectsNudgeState();
}

class _VendorSetupProjectsNudgeState extends State<VendorSetupProjectsNudge> {
  var _dismissed = false;
  var _loading = true;
  VendorCredentialSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant VendorSetupProjectsNudge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken) {
      _init();
    }
  }

  Future<void> _init() async {
    final dismissed = await DomesticVendorSetupPrefs.isDismissed();
    if (!mounted) return;
    if (dismissed) {
      setState(() {
        _dismissed = true;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final snap = await loadVendorCredentialSnapshot(widget.accessToken);
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _loading || _snapshot == null) {
      return const SizedBox.shrink();
    }

    final snap = _snapshot!;
    if (isDomesticPrimarySetupComplete(
      snap.vendors,
      snap.credentialConfigured,
    )) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final ready = countDomesticVendorsReady(
      snap.vendors,
      snap.credentialConfigured,
      primaryOnly: true,
    );
    final total =
        filterDomesticVendorsForSetup(snap.vendors, primaryOnly: true).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.primarySoft.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.primary.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(StudioLayoutSpacing.stackMedium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.vpn_key_outlined, color: tokens.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.studioVendorSetupProjectsNudgeTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.settingsDomesticVendorsSetupProgress(ready, total),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: widget.onOpenModelVendorSettings,
                child: Text(l10n.studioVendorSetupSnackAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
