import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigates into project studio from a product-shell pane that only hosts a redirect.
class ProductStudioRouteLauncher extends StatefulWidget {
  const ProductStudioRouteLauncher({super.key, required this.route});

  final String route;

  @override
  State<ProductStudioRouteLauncher> createState() =>
      _ProductStudioRouteLauncherState();
}

class _ProductStudioRouteLauncherState extends State<ProductStudioRouteLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final router = GoRouter.of(context);
      if (router.state.uri.toString() != widget.route) {
        router.go(widget.route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
