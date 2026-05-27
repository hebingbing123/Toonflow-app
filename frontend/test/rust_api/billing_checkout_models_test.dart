import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/billing/checkout.dart';

void main() {
  test('BillingPlanPublic.fromJson parses providers list', () {
    final plan = BillingPlanPublic.fromJson(<String, dynamic>{
      'plan_tier': 'creator',
      'display_name': 'Creator',
      'description': 'For solo creators',
      'currency': 'CNY',
      'amount_cents': 9900,
      'price_label': '¥99',
      'period_days': 30,
      'providers': <String>['alipay', 'stripe'],
    });

    expect(plan.planTier, 'creator');
    expect(plan.amountCents, 9900);
    expect(plan.providers, <String>['alipay', 'stripe']);
  });

  test('BillingPlanPublic.fromJson tolerates missing providers', () {
    final plan = BillingPlanPublic.fromJson(<String, dynamic>{
      'plan_tier': 'studio',
      'display_name': 'Studio',
      'description': '',
      'currency': 'USD',
      'amount_cents': 19900,
      'price_label': '\$199',
      'period_days': 30,
    });

    expect(plan.providers, isEmpty);
  });

  test('CheckoutResponse.fromJson maps snake_case checkout fields', () {
    final checkout = CheckoutResponse.fromJson(<String, dynamic>{
      'session_id': 'sess-1',
      'status': 'pending',
      'pay_url': 'https://pay.example/checkout',
      'provider': 'alipay',
      'plan_tier': 'pro',
      'amount_cents': 12000,
      'currency': 'CNY',
    });

    expect(checkout.sessionId, 'sess-1');
    expect(checkout.status, 'pending');
    expect(checkout.payUrl, 'https://pay.example/checkout');
    expect(checkout.amountCents, 12000);
  });

  test('CheckoutSessionResponse.fromJson keeps optional paidAt', () {
    final withPaid = CheckoutSessionResponse.fromJson(<String, dynamic>{
      'session_id': 'sess-2',
      'status': 'paid',
      'plan_tier': 'creator',
      'provider': 'bitpay',
      'amount_cents': 5000,
      'currency': 'USD',
      'paid_at': '2026-05-24T12:00:00Z',
      'expires_at': '2026-05-25T12:00:00Z',
    });
    final withoutPaid = CheckoutSessionResponse.fromJson(<String, dynamic>{
      'session_id': 'sess-3',
      'status': 'pending',
      'plan_tier': 'creator',
      'provider': 'stripe',
      'amount_cents': 5000,
      'currency': 'USD',
      'expires_at': '2026-05-25T12:00:00Z',
    });

    expect(withPaid.paidAt, '2026-05-24T12:00:00Z');
    expect(withoutPaid.paidAt, isNull);
  });
}
