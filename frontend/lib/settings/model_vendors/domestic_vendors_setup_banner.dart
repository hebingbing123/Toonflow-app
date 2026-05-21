import 'package:flutter/material.dart';

import '../../design_system/components/studio_card.dart';
import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../rust_api/shared_kernel/models.dart';
import 'domestic_vendor_setup_prefs.dart';
import 'domestic_vendors.dart';

/// First-run checklist for China-based model providers (API keys).
class DomesticVendorsSetupBanner extends StatefulWidget {
  const DomesticVendorsSetupBanner({
    super.key,
    required this.vendors,
    required this.credentialConfigured,
    required this.onConfigureVendor,
    this.showExtended = false,
  });

  final List<VendorSummaryItemV1> vendors;
  final Map<String, bool> credentialConfigured;
  final ValueChanged<VendorSummaryItemV1> onConfigureVendor;
  final bool showExtended;

  @override
  State<DomesticVendorsSetupBanner> createState() =>
      _DomesticVendorsSetupBannerState();
}

class _DomesticVendorsSetupBannerState extends State<DomesticVendorsSetupBanner> {
  var _dismissed = false;
  var _showExtended = false;

  @override
  void initState() {
    super.initState();
    _showExtended = widget.showExtended;
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final dismissed = await DomesticVendorSetupPrefs.isDismissed();
    if (!mounted) return;
    setState(() => _dismissed = dismissed);
  }

  Future<void> _dismiss() async {
    await DomesticVendorSetupPrefs.markDismissed();
    if (!mounted) return;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final primary = filterDomesticVendorsForSetup(
      widget.vendors,
      primaryOnly: true,
    );
    if (primary.isEmpty) {
      return const SizedBox.shrink();
    }

    final primaryReady = countDomesticVendorsReady(
      widget.vendors,
      widget.credentialConfigured,
      primaryOnly: true,
    );
    if (primaryReady >= primary.length) {
      return const SizedBox.shrink();
    }

    final extended = filterDomesticVendorsForSetup(
      widget.vendors,
      primaryOnly: false,
    ).where(
      (v) => !kDomesticVendorPrimaryCatalogIds.contains(v.catalog.id),
    );

    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StudioCard(
        emphasized: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.flag_outlined, size: 22, color: tokens.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.settingsDomesticVendorsSetupTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.settingsDomesticVendorsSetupSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.settingsDomesticVendorsSetupProgress(
                          primaryReady,
                          primary.length,
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: tokens.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...primary.map(
              (vendor) => _DomesticVendorSetupRow(
                vendor: vendor,
                ready: isDomesticVendorCredentialReady(
                  vendor,
                  widget.credentialConfigured[vendor.vendorId] ?? false,
                ),
                onConfigure: () => widget.onConfigureVendor(vendor),
              ),
            ),
            if (extended.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _showExtended = !_showExtended),
                child: Text(
                  _showExtended
                      ? l10n.settingsDomesticVendorsSetupHideExtended
                      : l10n.settingsDomesticVendorsSetupShowExtended,
                ),
              ),
              if (_showExtended)
                ...extended.map(
                  (vendor) => _DomesticVendorSetupRow(
                    vendor: vendor,
                    ready: isDomesticVendorCredentialReady(
                      vendor,
                      widget.credentialConfigured[vendor.vendorId] ?? false,
                    ),
                    onConfigure: () => widget.onConfigureVendor(vendor),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _dismiss,
                child: Text(l10n.settingsDomesticVendorsSetupDismiss),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DomesticVendorSetupRow extends StatelessWidget {
  const _DomesticVendorSetupRow({
    required this.vendor,
    required this.ready,
    required this.onConfigure,
  });

  final VendorSummaryItemV1 vendor;
  final bool ready;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgInset.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ready ? tokens.primary.withValues(alpha: 0.35) : tokens.borderSubtle,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(
                ready ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: ready ? tokens.primary : tokens.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vendor.catalog.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!ready)
                TextButton(
                  onPressed: onConfigure,
                  child: Text(l10n.settingsDomesticVendorsSetupConfigureAction),
                )
              else
                Text(
                  l10n.settingsModelVendorsCredentialConfigured,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
