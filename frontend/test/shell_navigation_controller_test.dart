import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

void main() {
  test('shell navigation controller defaults to product/projects', () {
    final controller = ShellNavigationController();

    expect(controller.homeSectionMode, HomeSectionMode.product);
    expect(controller.productWorkspacePane, ProductWorkspacePane.projects);
    expect(controller.isProductMode, isTrue);
  });

  test('shell navigation controller notifies only on actual changes', () {
    final controller = ShellNavigationController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.selectHomeSectionMode(HomeSectionMode.product);
    controller.selectHomeSectionMode(HomeSectionMode.debug);
    controller.selectHomeSectionMode(null);
    controller.selectProductWorkspacePane(ProductWorkspacePane.projects);
    controller.selectProductWorkspacePane(ProductWorkspacePane.jobs);

    expect(controller.homeSectionMode, HomeSectionMode.debug);
    expect(controller.productWorkspacePane, ProductWorkspacePane.jobs);
    expect(controller.isProductMode, isFalse);
    expect(notifications, 2);
  });
}
