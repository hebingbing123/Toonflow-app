import 'package:flutter/material.dart';

import 'app_localizations.dart';

String subscriptionStatusLabel(AppLocalizations l10n, String? status) {
  final normalized = status?.trim();
  if (normalized == null || normalized.isEmpty) {
    return l10n.billingSubscriptionStatusNotSet;
  }
  switch (normalized.toLowerCase()) {
    case 'active':
      return l10n.billingSubscriptionStatusActive;
    case 'past_due':
      return l10n.billingSubscriptionStatusPastDue;
    case 'canceled':
      return l10n.billingSubscriptionStatusCanceled;
    case 'trialing':
      return l10n.billingSubscriptionStatusTrialing;
    case 'paused':
      return l10n.billingSubscriptionStatusPaused;
    case 'unpaid':
      return l10n.billingSubscriptionStatusUnpaid;
    case 'unknown':
    case 'none':
    case 'inactive':
      return l10n.billingSubscriptionStatusNotSet;
    default:
      return l10n.billingSubscriptionStatusUnknown;
  }
}

Color? subscriptionStatusColor(BuildContext context, String? status) {
  final theme = Theme.of(context);
  switch (status?.trim().toLowerCase()) {
    case 'past_due':
      return theme.colorScheme.tertiary;
    case 'canceled':
      return theme.colorScheme.secondary;
    default:
      return null;
  }
}

String planTierDisplayName(AppLocalizations l10n, String? planTier) {
  switch (planTier?.trim().toLowerCase()) {
    case 'free':
      return l10n.billingPlanTierFree;
    case 'creator':
      return l10n.billingPlanTierCreator;
    case 'pro':
      return l10n.billingPlanTierPro;
    case 'studio':
      return l10n.billingPlanTierStudio;
    case 'enterprise':
      return l10n.billingPlanTierEnterprise;
    default:
      return l10n.billingPlanTierUnknown;
  }
}

String pricingUnitLabel(AppLocalizations l10n, String unit) {
  switch (unit.trim().toLowerCase()) {
    case 'per_1k_tokens':
      return l10n.billingPricingUnitPer1kTokens;
    case 'per_image':
      return l10n.billingPricingUnitPerImage;
    case 'per_video_second':
      return l10n.billingPricingUnitPerVideoSecond;
    case 'per_job':
      return l10n.billingPricingUnitPerJob;
    default:
      return unit;
  }
}

String valueTierLabel(AppLocalizations l10n, String? tier) {
  switch (tier?.trim().toLowerCase()) {
    case 'economy':
      return l10n.studioValueTierEconomy;
    case 'balanced':
      return l10n.studioValueTierBalanced;
    case 'quality':
      return l10n.studioValueTierQuality;
    default:
      return tier ?? '';
  }
}

String tokenEfficiencyRoiLabel(AppLocalizations l10n, String? roiBand) {
  switch (roiBand?.trim().toLowerCase()) {
    case 'efficient':
      return l10n.studioTokenEfficiencyEfficient;
    case 'high_token_low_quality':
      return l10n.studioTokenEfficiencyHighCost;
    case 'observe':
      return l10n.studioTokenEfficiencyObserve;
    default:
      return roiBand ?? '';
  }
}

String formatCnyFromCents(int cents) {
  final yuan = cents / 100.0;
  if (yuan == yuan.roundToDouble()) {
    return yuan.toStringAsFixed(0);
  }
  return yuan.toStringAsFixed(2);
}

String billingNotificationTypeLabel(
  AppLocalizations l10n,
  String notificationType,
) {
  switch (notificationType) {
    case 'billing_subscription_activated':
      return l10n.billingNotificationSubscriptionActivated;
    case 'billing_subscription_past_due':
      return l10n.billingNotificationSubscriptionPastDue;
    case 'billing_subscription_canceled':
      return l10n.billingNotificationSubscriptionCanceled;
    case 'billing_payment_failed':
      return l10n.billingNotificationPaymentFailed;
    case 'billing_subscription_expired':
      return l10n.billingNotificationSubscriptionExpired;
    case 'billing_subscription_trialing':
      return l10n.billingNotificationSubscriptionTrialing;
    default:
      return l10n.billingNotificationUnknown;
  }
}

String quotaExceededMessage(AppLocalizations l10n, String? planTier) {
  final tier = planTier?.trim().toLowerCase();
  final planName = planTierDisplayName(l10n, planTier);
  switch (tier) {
    case 'free':
      return l10n.billingQuotaExceededFree(planName);
    case 'pro':
      return l10n.billingQuotaExceededPro(planName);
    default:
      return l10n.billingQuotaExceededTitle;
  }
}
