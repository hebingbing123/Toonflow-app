import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class BillingPlanPublic {
  const BillingPlanPublic({
    required this.planTier,
    required this.displayName,
    required this.description,
    required this.currency,
    required this.amountCents,
    required this.priceLabel,
    required this.periodDays,
    required this.providers,
  });

  final String planTier;
  final String displayName;
  final String description;
  final String currency;
  final int amountCents;
  final String priceLabel;
  final int periodDays;
  final List<String> providers;

  factory BillingPlanPublic.fromJson(Map<String, dynamic> json) {
    final providers = json['providers'];
    return BillingPlanPublic(
      planTier: json['plan_tier'] as String,
      displayName: json['display_name'] as String,
      description: json['description'] as String,
      currency: json['currency'] as String,
      amountCents: (json['amount_cents'] as num).toInt(),
      priceLabel: json['price_label'] as String,
      periodDays: (json['period_days'] as num).toInt(),
      providers: providers is List
          ? providers.map((e) => e.toString()).toList()
          : const <String>[],
    );
  }
}

class BillingPlansResponse {
  const BillingPlansResponse({required this.plans, required this.disclaimer});

  final List<BillingPlanPublic> plans;
  final String disclaimer;

  factory BillingPlansResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['plans'] as List<dynamic>? ?? const [];
    return BillingPlansResponse(
      plans: raw
          .map((e) => BillingPlanPublic.fromJson(e as Map<String, dynamic>))
          .toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

class CheckoutResponse {
  const CheckoutResponse({
    required this.sessionId,
    required this.status,
    required this.payUrl,
    required this.provider,
    required this.planTier,
    required this.amountCents,
    required this.currency,
  });

  final String sessionId;
  final String status;
  final String payUrl;
  final String provider;
  final String planTier;
  final int amountCents;
  final String currency;

  factory CheckoutResponse.fromJson(Map<String, dynamic> json) {
    return CheckoutResponse(
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      payUrl: json['pay_url'] as String,
      provider: json['provider'] as String,
      planTier: json['plan_tier'] as String,
      amountCents: (json['amount_cents'] as num).toInt(),
      currency: json['currency'] as String,
    );
  }
}

class CheckoutSessionResponse {
  const CheckoutSessionResponse({
    required this.sessionId,
    required this.status,
    required this.planTier,
    required this.provider,
    required this.amountCents,
    required this.currency,
    this.paidAt,
    required this.expiresAt,
  });

  final String sessionId;
  final String status;
  final String planTier;
  final String provider;
  final int amountCents;
  final String currency;
  final String? paidAt;
  final String expiresAt;

  factory CheckoutSessionResponse.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionResponse(
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      planTier: json['plan_tier'] as String,
      provider: json['provider'] as String,
      amountCents: (json['amount_cents'] as num).toInt(),
      currency: json['currency'] as String,
      paidAt: json['paid_at'] as String?,
      expiresAt: json['expires_at'] as String,
    );
  }
}

Future<BillingPlansResponse> fetchBillingPlansV1(
  String accessToken, {
  String currency = 'CNY',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/billing/plans').replace(
    queryParameters: <String, String>{'currency': currency},
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return BillingPlansResponse.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<CheckoutResponse> postBillingCheckoutV1(
  String accessToken, {
  required String planTier,
  required String provider,
  String currency = 'CNY',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/billing/checkout');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'plan_tier': planTier,
          'provider': provider,
          'currency': currency,
        }),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  return CheckoutResponse.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<CheckoutSessionResponse> fetchBillingCheckoutSessionV1(
  String accessToken, {
  required String sessionId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/billing/checkout/$sessionId');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return CheckoutSessionResponse.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<String> postBillingPortalV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/billing/portal');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return json['url'] as String;
}
