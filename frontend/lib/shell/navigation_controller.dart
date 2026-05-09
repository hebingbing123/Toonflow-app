import 'package:flutter/material.dart';

enum HomeSectionMode { product, debug }

enum ProductWorkspacePane {
  shortVideoSpace,
  projects,
  notifications,
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

  HomeSectionMode get homeSectionMode => _homeSectionMode;
  ProductWorkspacePane get productWorkspacePane => _productWorkspacePane;
  bool get isProductMode => _homeSectionMode == HomeSectionMode.product;

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
    _productWorkspacePane = pane;
    notifyListeners();
  }
}
