import 'package:flutter/material.dart';

import '../tokens.dart';

/// Horizontal studio tabs with keyboard-friendly [TabBar].
class StudioTabs extends StatelessWidget {
  const StudioTabs({
    super.key,
    required this.tabs,
    required this.controller,
    this.isScrollable = false,
  });

  final List<Tab> tabs;
  final TabController controller;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return TabBar(
      controller: controller,
      isScrollable: isScrollable,
      labelColor: tokens.primary,
      unselectedLabelColor: tokens.textSecondary,
      indicatorColor: tokens.primary,
      indicatorSize: TabBarIndicatorSize.label,
      tabs: tabs,
    );
  }
}
