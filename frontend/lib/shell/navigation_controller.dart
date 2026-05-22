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
  final List<ProductWorkspacePane> _productPaneForwardStack =
      <ProductWorkspacePane>[];

  HomeSectionMode get homeSectionMode => _homeSectionMode;
  ProductWorkspacePane get productWorkspacePane => _productWorkspacePane;
  bool get isProductMode => _homeSectionMode == HomeSectionMode.product;
  int get productPaneBackStackDepth => _productPaneBackStack.length;
  int get productPaneForwardStackDepth => _productPaneForwardStack.length;

  ProductWorkspacePane? get productPaneBackPeek =>
      _productPaneBackStack.isEmpty ? null : _productPaneBackStack.last;

  ProductWorkspacePane? get productPaneForwardPeek =>
      _productPaneForwardStack.isEmpty ? null : _productPaneForwardStack.last;

  bool get canGoBackProductWorkspacePane {
    if (_productPaneBackStack.isNotEmpty) {
      return true;
    }
    return _productWorkspacePane != ProductWorkspacePane.projects;
  }

  bool get canGoForwardProductWorkspacePane =>
      _productPaneForwardStack.isNotEmpty;

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
    _productPaneForwardStack.clear();
    _productWorkspacePane = pane;
    notifyListeners();
  }

  /// Pops to the previous product pane, or [ProductWorkspacePane.projects] when empty.
  bool popProductWorkspacePane() {
    if (!canGoBackProductWorkspacePane) {
      return false;
    }
    _productPaneForwardStack.add(_productWorkspacePane);
    if (_productPaneBackStack.isEmpty) {
      _productWorkspacePane = ProductWorkspacePane.projects;
      notifyListeners();
      return true;
    }
    _productWorkspacePane = _productPaneBackStack.removeLast();
    notifyListeners();
    return true;
  }

  /// Moves forward after a prior [popProductWorkspacePane].
  bool forwardProductWorkspacePane() {
    if (!canGoForwardProductWorkspacePane) {
      return false;
    }
    _productPaneBackStack.add(_productWorkspacePane);
    _productWorkspacePane = _productPaneForwardStack.removeLast();
    notifyListeners();
    return true;
  }

  void resetProductWorkspacePaneHistory() {
    _productPaneBackStack.clear();
    _productPaneForwardStack.clear();
  }

  /// Switches pane without recording history (e.g. explicit «home» navigation).
  void replaceProductWorkspacePane(ProductWorkspacePane pane) {
    if (pane == _productWorkspacePane) {
      return;
    }
    _productPaneForwardStack.clear();
    _productWorkspacePane = pane;
    notifyListeners();
  }

  /// Mirrors a shell-home URI change without touching back/forward stacks.
  void applyProductWorkspacePaneFromRoute(ProductWorkspacePane pane) {
    if (pane == _productWorkspacePane) {
      return;
    }
    _productWorkspacePane = pane;
    notifyListeners();
  }

  static const int _maxPaneHistorySteps = 48;

  /// Walks the in-app back stack until [pane] is active (browser back on web).
  bool rewindProductWorkspacePaneTo(ProductWorkspacePane pane) {
    if (_productWorkspacePane == pane) {
      return true;
    }
    var steps = 0;
    while (_productWorkspacePane != pane &&
        canGoBackProductWorkspacePane &&
        steps < _maxPaneHistorySteps) {
      if (!popProductWorkspacePane()) {
        break;
      }
      steps++;
    }
    return _productWorkspacePane == pane;
  }

  /// Walks the in-app forward stack until [pane] is active (browser forward on web).
  bool advanceProductWorkspacePaneTo(ProductWorkspacePane pane) {
    if (_productWorkspacePane == pane) {
      return true;
    }
    var steps = 0;
    while (_productWorkspacePane != pane &&
        canGoForwardProductWorkspacePane &&
        steps < _maxPaneHistorySteps) {
      if (!forwardProductWorkspacePane()) {
        break;
      }
      steps++;
    }
    return _productWorkspacePane == pane;
  }
}
