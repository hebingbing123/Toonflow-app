/// Optimistic UI helper — apply locally, rollback on API failure (11.2).
Future<void> studioRunOptimisticMutation({
  required void Function() apply,
  required void Function() rollback,
  required Future<void> Function() commit,
}) async {
  apply();
  try {
    await commit();
  } catch (error) {
    rollback();
    rethrow;
  }
}
