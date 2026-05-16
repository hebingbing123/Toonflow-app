import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/settings/outbound_webhook_platform.dart';

void main() {
  test('effectiveSelection treats empty as all platform types', () {
    expect(
      outboundWebhookEffectiveSelection(const <String>[]),
      equals(kOutboundWebhookPlatformEventTypes.toSet()),
    );
  });

  test('patch payload is empty list when all types selected', () {
    expect(
      outboundWebhookEventTypesPayloadForPatch(
        kOutboundWebhookPlatformEventTypes.toSet(),
      ),
      isEmpty,
    );
  });

  test('create payload is null when all types selected', () {
    expect(
      outboundWebhookEventTypesPayloadForCreate(
        kOutboundWebhookPlatformEventTypes.toSet(),
      ),
      isNull,
    );
  });

  test('patch payload is sorted subset when partial', () {
    expect(
      outboundWebhookEventTypesPayloadForPatch(<String>{'job.failed', 'project.created'}),
      orderedEquals(<String>['job.failed', 'project.created']),
    );
  });

  test('workspace UUID validation', () {
    expect(
      outboundWebhookWorkspaceIdLooksValid(
        '550e8400-e29b-41d4-a716-446655440000',
      ),
      isTrue,
    );
    expect(outboundWebhookWorkspaceIdLooksValid('not-a-uuid'), isFalse);
    expect(outboundWebhookWorkspaceIdLooksValid(''), isFalse);
  });
}
