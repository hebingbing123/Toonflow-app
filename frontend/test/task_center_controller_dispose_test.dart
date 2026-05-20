import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/task_center/controller.dart';

void main() {
  test('loadTaskProjects after dispose does not notify listeners', () async {
    var notifyCount = 0;
    final controller = TaskCenterController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => null,
    )..addListener(() {
        notifyCount += 1;
      });

    final loadFuture = controller.loadTaskProjects();
    controller.dispose();
    await loadFuture;

    expect(notifyCount, 0);
  });
}
