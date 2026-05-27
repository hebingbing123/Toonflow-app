import 'package:flutter/material.dart';

import '../../design_system/components/studio_card.dart';
import '../../design_system/components/studio_entrance_motion.dart';
import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../rust_api/shared_kernel/models.dart';
import 'domestic_vendors.dart';
import 'international_vendor_setup_prefs.dart';
import 'international_vendors.dart';

/// API key checklist for international cloud providers (after domestic core).
class InternationalVendorsSetupBanner extends StatefulWidget {
  const InternationalVendorsSetupBanner({
    super.key,
    required this.vendors,
    required this.credentialConfigured,
    required this.onConfigureVendor,
  });

  final List<VendorSummaryItemV1> vendors;
  final Map<String, bool> credentialConfigured;
  final ValueChanged<VendorSummaryItemV1> onConfigureVendor;

  @override
  State<InternationalVendorsSetupBanner> createState() =>
      _InternationalVendorsSetupBannerState();
}

class _InternationalVendorsSetupBannerState
    extends State<InternationalVendorsSetupBanner> {
  var _dismissed = false;
  var _showExtended = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final dismissed = await InternationalVendorSetupPrefs.isDismissed();
    if (!mounted) return;
    setState(() => _dismissed = dismissed);
  }

  Future<void> _dismiss() async {
    await InternationalVendorSetupPrefs.markDismissed();
    if (!mounted) return;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final primary = filterInternationalVendorsForSetup(
      widget.vendors,
      primaryOnly: true,
    );
    if (primary.isEmpty) {
      return const SizedBox.shrink();
    }

    final primaryReady = countInternationalVendorsReady(
      widget.vendors,
      widget.credentialConfigured,
      primaryOnly: true,
    );
    if (primaryReady >= primary.length) {
      return const SizedBox.shrink();
    }

    final extended = filterInternationalVendorsForSetup(
      widget.vendors,
      primaryOnly: false,
    ).where(
      (v) => !kInternationalVendorPrimaryCatalogIds.contains(v.catalog.id),
    );

    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: StudioSpacing.sm),
      child: StudioCard(
        emphasized: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.public_outlined, size: 22, color: tokens.primary),
                const SizedBox(width: StudioLayoutSpacing.inlineGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.settingsInternationalVendorsSetupTitle,
                        style: studioAccentBannerTitleStyle(
                          context,
                          tokens.primary,
                        ),
                      ),
                      const SizedBox(height: StudioLayoutSpacing.titleTight),
                      Text(
                        l10n.settingsInternationalVendorsSetupSubtitle,
                        style: studioAccentBannerBodyStyle(
                          context,
                          tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      Text(
                        l10n.settingsInternationalVendorsSetupProgress(
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
            const SizedBox(height: StudioSpacing.sm),
            ...studioStaggeredChildren(
              primary.map(
                (vendor) => _IntlVendorSetupRow(
                  vendor: vendor,
                  ready: isDomesticVendorCredentialReady(
                    vendor,
                    widget.credentialConfigured[vendor.vendorId] ?? false,
                  ),
                  onConfigure: () => widget.onConfigureVendor(vendor),
                ),
              ),
              entranceKey: primary.length,
            ),
            if (extended.isNotEmpty) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              TextButton(
                onPressed: () => setState(() => _showExtended = !_showExtended),
                child: Text(
                  _showExtended
                      ? l10n.settingsInternationalVendorsSetupHideExtended
                      : l10n.settingsInternationalVendorsSetupShowExtended,
                ),
              ),
              if (_showExtended)
                ...studioStaggeredChildren(
                  extended.map(
                    (vendor) => _IntlVendorSetupRow(
                      vendor: vendor,
                      ready: isDomesticVendorCredentialReady(
                        vendor,
                        widget.credentialConfigured[vendor.vendorId] ?? false,
                      ),
                      onConfigure: () => widget.onConfigureVendor(vendor),
                    ),
                  ),
                  entranceKey: extended.length,
                ),
            ],
            const SizedBox(height: StudioSpacing.xs),
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

class _IntlVendorSetupRow extends StatelessWidget {
  const _IntlVendorSetupRow({
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
      padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.microGap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgInset.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          border: Border.all(
            color: ready
                ? tokens.primary.withValues(alpha: 0.35)
                : tokens.borderSubtle,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.radiusComfort, vertical: StudioSpacing.xs),
          child: Row(
            children: <Widget>[
              Icon(
                ready ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: ready ? tokens.primary : tokens.textMuted,
              ),
              const SizedBox(width: StudioLayoutSpacing.inlineGap),
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
