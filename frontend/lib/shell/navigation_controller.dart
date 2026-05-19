import 'package:flutter/material.dart';

enum HomeSectionMode { product, debug }

enum ProductWorkspacePane {
  shortVideoSpace,
  projects,
  account,
  apiKeys,
  notifications,
  contentCompliance,
  platformStatus,
  teamWorkspaces,
  scriptWorkspace,
  productionWorkspace,
  workspaceActivity,
  benchmark,
  tasks,
  jobs,
  quality,
  platformConfig,
  helpHub,
}

class ShellNavigationController extends ChangeNotifier {
  HomeSectionMode _homeSectionMode = HomeSectionMode.product;
  ProductWorkspacePane _productWorkspacePane = ProductWorkspacePane.projects;
  final List<ProductWorkspacePane> _productPaneBackStack = <ProductWorkspacePane>[];

  HomeSectionMode get homeSectionMode => _homeSectionMode;
  ProductWorkspacePane get productWorkspacePane => _productWorkspacePane;
  bool get isProductMode => _homeSectionMode == HomeSectionMode.product;
  int get productPaneBackStackDepth => _productPaneBackStack.length;

  void selectHomeSectionMode(HomeSectionMode? nextMode) {
    if (nextMode == null || nextMode == _homeSectionMode) {
      return;
    }
    _homeSectionMode = nextMode;
    notifyListeners();
  }

  void selectProductWorkspacePane(ProductWorkspacePane pane) {
    if (pane == _productWorkspacePane) {
      return;
    }
    _productPaneBackStack.add(_productWorkspacePane);
    _productWorkspacePane = pane;
    notifyListeners();
  }

  /// Pops to the previous product pane, or [ProductWorkspacePane.projects] when empty.
  bool popProductWorkspacePane() {
    if (_productPaneBackStack.isEmpty) {
      if (_productWorkspacePane == ProductWorkspacePane.projects) {
        return false;
      }
      _productWorkspacePane = ProductWorkspacePane.projects;
      notifyListeners();
      return true;
    }
    _productWorkspacePane = _productPaneBackStack.removeLast();
    notifyListeners();
    return true;
  }

  void resetProductWorkspacePaneHistory() {
    _productPaneBackStack.clear();
  }

  /// Switches pane without recording history (e.g. explicit «home» navigation).
  void replaceProductWorkspacePane(ProductWorkspacePane pane) {
    if (pane == _productWorkspacePane) {
      return;
    }
    _productWorkspacePane = pane;
    notifyListeners();
  }
}
