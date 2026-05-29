import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/platform/studio_optimistic_mutation.dart';

void main() {
  test('studioRunOptimisticMutation rolls back on commit failure', () async {
    var value = 0;
    await expectLater(
      studioRunOptimisticMutation(
        apply: () => value = 1,
        rollback: () => value = 0,
        commit: () async => throw Exception('network'),
      ),
      throwsException,
    );
    expect(value, 0);
  });

  test('studioRunOptimisticMutation keeps apply on success', () async {
    var value = 0;
    await studioRunOptimisticMutation(
      apply: () => value = 2,
      rollback: () => value = 0,
      commit: () async {},
    );
    expect(value, 2);
  });
}
