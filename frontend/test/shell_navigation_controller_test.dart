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

  test('product pane forward stack restores after back', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.tasks);
    controller.selectProductWorkspacePane(ProductWorkspacePane.jobs);

    expect(controller.canGoBackProductWorkspacePane, isTrue);
    expect(controller.canGoForwardProductWorkspacePane, isFalse);

    expect(controller.popProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.tasks);
    expect(controller.canGoForwardProductWorkspacePane, isTrue);

    expect(controller.forwardProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.jobs);
    expect(controller.canGoForwardProductWorkspacePane, isFalse);
  });

  test('utility pane chain pops in visit order', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.account);
    controller.selectProductWorkspacePane(ProductWorkspacePane.notifications);
    controller.selectProductWorkspacePane(ProductWorkspacePane.helpHub);

    expect(controller.productWorkspacePane, ProductWorkspacePane.helpHub);
    expect(controller.productPaneBackStackDepth, 3);

    expect(controller.popProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.notifications);

    expect(controller.popProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.account);

    expect(controller.popProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.projects);
    expect(controller.popProductWorkspacePane(), isFalse);
  });

  test('forward stack is available after pop until a new pane is selected', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.account);
    controller.selectProductWorkspacePane(ProductWorkspacePane.notifications);
    controller.selectProductWorkspacePane(ProductWorkspacePane.helpHub);

    expect(controller.popProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.notifications);
    expect(controller.canGoForwardProductWorkspacePane, isTrue);
    expect(controller.productPaneForwardStackDepth, 1);

    expect(controller.forwardProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.helpHub);
    expect(controller.canGoForwardProductWorkspacePane, isFalse);
  });

  test('rewindProductWorkspacePaneTo walks the back stack', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.account);
    controller.selectProductWorkspacePane(ProductWorkspacePane.notifications);
    controller.selectProductWorkspacePane(ProductWorkspacePane.helpHub);

    expect(
      controller.rewindProductWorkspacePaneTo(ProductWorkspacePane.account),
      isTrue,
    );
    expect(controller.productWorkspacePane, ProductWorkspacePane.account);
    expect(controller.productPaneForwardStackDepth, 2);
  });

  test('advanceProductWorkspacePaneTo walks the forward stack', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.account);
    controller.selectProductWorkspacePane(ProductWorkspacePane.helpHub);
    controller.popProductWorkspacePane();

    expect(
      controller.advanceProductWorkspacePaneTo(ProductWorkspacePane.helpHub),
      isTrue,
    );
    expect(controller.productWorkspacePane, ProductWorkspacePane.helpHub);
    expect(controller.productPaneForwardStackDepth, 0);
  });

  test('applyProductWorkspacePaneFromRoute does not clear forward stack', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.account);
    controller.selectProductWorkspacePane(ProductWorkspacePane.helpHub);
    controller.popProductWorkspacePane();
    expect(controller.canGoForwardProductWorkspacePane, isTrue);

    controller.applyProductWorkspacePaneFromRoute(
      ProductWorkspacePane.notifications,
    );
    expect(controller.canGoForwardProductWorkspacePane, isTrue);
    expect(controller.productPaneForwardStackDepth, 1);
  });

  test('pipeline-style projects switch records history instead of reset', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.tasks);
    controller.selectProductWorkspacePane(ProductWorkspacePane.jobs);
    expect(controller.productPaneBackStackDepth, 2);

    controller.selectProductWorkspacePane(ProductWorkspacePane.projects);
    expect(controller.productWorkspacePane, ProductWorkspacePane.projects);
    expect(controller.productPaneBackStackDepth, 3);

    expect(controller.popProductWorkspacePane(), isTrue);
    expect(controller.productWorkspacePane, ProductWorkspacePane.jobs);
  });

  test('selectProductWorkspacePane clears forward stack', () {
    final controller = ShellNavigationController();

    controller.selectProductWorkspacePane(ProductWorkspacePane.tasks);
    controller.selectProductWorkspacePane(ProductWorkspacePane.jobs);
    controller.popProductWorkspacePane();
    expect(controller.canGoForwardProductWorkspacePane, isTrue);

    controller.selectProductWorkspacePane(ProductWorkspacePane.account);
    expect(controller.canGoForwardProductWorkspacePane, isFalse);
    expect(controller.productWorkspacePane, ProductWorkspacePane.account);
  });
}
