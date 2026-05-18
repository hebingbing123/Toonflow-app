import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// Pricing metadata from `model_pricing.json` (when `include_pricing=true`).
class ModelPricingPublic {
  const ModelPricingPublic({
    required this.modelId,
    required this.pricingUnit,
    required this.creditsPerUnit,
    required this.cnyCentsPerUnit,
    required this.tier,
    required this.valueTier,
    required this.bestFor,
    required this.disclaimer,
  });

  final String modelId;
  final String pricingUnit;
  final int creditsPerUnit;
  final int cnyCentsPerUnit;
  final String tier;
  final String valueTier;
  final String bestFor;
  final String disclaimer;

  factory ModelPricingPublic.fromJson(Map<String, dynamic> json) {
    return ModelPricingPublic(
      modelId: json['model_id'] as String,
      pricingUnit: json['pricing_unit'] as String,
      creditsPerUnit: (json['credits_per_unit'] as num).toInt(),
      cnyCentsPerUnit: (json['cny_cents_per_unit'] as num).toInt(),
      tier: json['tier'] as String,
      valueTier: json['value_tier'] as String,
      bestFor: json['best_for'] as String,
      disclaimer: json['disclaimer'] as String,
    );
  }
}

/// `POST /api/v1/billing/estimate`
class BillingEstimateResponse {
  const BillingEstimateResponse({
    required this.modelId,
    required this.taskKind,
    required this.quantity,
    required this.pricingUnit,
    required this.credits,
    required this.cnyCents,
    required this.quotaImpactJobs,
    required this.warnings,
  });

  final String modelId;
  final String taskKind;
  final int quantity;
  final String pricingUnit;
  final int credits;
  final int cnyCents;
  final int quotaImpactJobs;
  final List<String> warnings;

  factory BillingEstimateResponse.fromJson(Map<String, dynamic> json) {
    final warnings = json['warnings'];
    return BillingEstimateResponse(
      modelId: json['model_id'] as String,
      taskKind: json['task_kind'] as String,
      quantity: (json['quantity'] as num).toInt(),
      pricingUnit: json['pricing_unit'] as String,
      credits: (json['credits'] as num).toInt(),
      cnyCents: (json['cny_cents'] as num).toInt(),
      quotaImpactJobs: (json['quota_impact_jobs'] as num).toInt(),
      warnings: warnings is List
          ? warnings.map((e) => e.toString()).toList()
          : const <String>[],
    );
  }
}

/// `GET /api/v1/billing/spend-summary`
class BillingSpendSummaryResponse {
  const BillingSpendSummaryResponse({
    required this.days,
    required this.disclaimer,
    required this.rows,
  });

  final int days;
  final String disclaimer;
  final List<ModelSpendRow> rows;

  factory BillingSpendSummaryResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['rows'] as List<dynamic>? ?? const [];
    return BillingSpendSummaryResponse(
      days: (json['days'] as num).toInt(),
      disclaimer: json['disclaimer'] as String? ?? '',
      rows: raw
          .map((e) => ModelSpendRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ModelSpendRow {
  const ModelSpendRow({
    required this.modelName,
    this.modelId,
    required this.totalTokens,
    required this.estimatedCostCents,
    required this.callCount,
    this.avgQualityScore,
    this.valueTier,
    required this.sampleSufficient,
  });

  final String modelName;
  final String? modelId;
  final int totalTokens;
  final int estimatedCostCents;
  final int callCount;
  final double? avgQualityScore;
  final String? valueTier;
  final bool sampleSufficient;

  factory ModelSpendRow.fromJson(Map<String, dynamic> json) {
    return ModelSpendRow(
      modelName: json['model_name'] as String,
      modelId: json['model_id'] as String?,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
      estimatedCostCents: (json['estimated_cost_cents'] as num?)?.toInt() ?? 0,
      callCount: (json['call_count'] as num?)?.toInt() ?? 0,
      avgQualityScore: (json['avg_quality_score'] as num?)?.toDouble(),
      valueTier: json['value_tier'] as String?,
      sampleSufficient: json['sample_sufficient'] as bool? ?? false,
    );
  }
}

Future<BillingEstimateResponse> postBillingEstimateV1(
  String accessToken, {
  required String modelId,
  required String taskKind,
  int quantity = 1,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/billing/estimate');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'model_id': modelId,
          'task_kind': taskKind,
          'quantity': quantity,
        }),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return BillingEstimateResponse.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<BillingSpendSummaryResponse> fetchBillingSpendSummaryV1(
  String accessToken, {
  int days = 7,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/billing/spend-summary').replace(
    queryParameters: <String, String>{'days': days.toString()},
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return BillingSpendSummaryResponse.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}
