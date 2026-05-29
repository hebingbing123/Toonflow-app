import 'package:flutter/material.dart';

import '../../demo/benchmark_demo_data.dart';
import '../../design_system/components/studio_loading_placeholders.dart';
import '../../design_system/tokens.dart';
import 'section.dart' deferred as benchmark;

/// Deferred benchmark pane — keeps heavy bench module off first frame (9.3).
class DeferredBenchmarkSection extends StatefulWidget {
  const DeferredBenchmarkSection({
    super.key,
    required this.accessToken,
    this.debugSnapshot,
    this.demoMode = false,
  });

  final String? accessToken;
  final BenchmarkDemoSnapshot? debugSnapshot;
  final bool demoMode;

  @override
  State<DeferredBenchmarkSection> createState() =>
      _DeferredBenchmarkSectionState();
}

class _DeferredBenchmarkSectionState extends State<DeferredBenchmarkSection> {
  Widget? _child;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await benchmark.loadLibrary();
    if (!mounted) {
      return;
    }
    setState(() {
      _child = benchmark.BenchmarkSection(
        accessToken: widget.accessToken,
        debugSnapshot: widget.debugSnapshot,
        demoMode: widget.demoMode,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _child ??
        const Padding(
          padding: EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
          child: StudioPaneLoadingSkeleton(),
        );
  }
}
