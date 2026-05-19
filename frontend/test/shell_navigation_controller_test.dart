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

  test('product pane back stack pops to previous pane', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.tasks);
    controller.selectProductWorkspacePane(ProductWorkspacePane.jobs);

    expect(controller.productWorkspacePane, ProductWorkspacePane.jobs);
    expect(controller.productPaneBackStackDepth, 2);

    expect(controller.popProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.tasks);

    expect(controller.popProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.projects);
    expect(controller.popProductWorkspacePane(), isFalse);
  });

  test('resetProductWorkspacePaneHistory clears back stack', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.jobs);
    controller.resetProductWorkspacePaneHistory();

    expect(controller.productPaneBackStackDepth, 0);
    expect(controller.popProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.projects);
  });
}
