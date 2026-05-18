import 'package:flutter/material.dart';

import '../../rust_api.dart';
import 'studio_cost_estimate_chip.dart';
import 'studio_model_picker.dart';

/// Model picker + live cost estimate for inline generation forms.
class StudioModelCostControls extends StatefulWidget {
  const StudioModelCostControls({
    super.key,
    required this.accessToken,
    required this.taskKind,
    this.typeFilter = 'image',
    this.quantity = 1,
    this.modelValueController,
    this.enabled = true,
    this.onEstimateChanged,
  });

  final String accessToken;
  final String taskKind;
  final String typeFilter;
  final int quantity;
  final TextEditingController? modelValueController;
  final bool enabled;
  final ValueChanged<BillingEstimateResponse?>? onEstimateChanged;

  @override
  State<StudioModelCostControls> createState() => _StudioModelCostControlsState();
}

class _StudioModelCostControlsState extends State<StudioModelCostControls> {
  bool _loadingModels = true;
  List<ModelListEntry> _models = const <ModelListEntry>[];
  String? _selectedModelId;
  BillingEstimateResponse? _estimate;
  bool _loadingEstimate = false;
  String? _estimateError;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void didUpdateWidget(covariant StudioModelCostControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.typeFilter != widget.typeFilter ||
        oldWidget.quantity != widget.quantity ||
        oldWidget.taskKind != widget.taskKind) {
      _refreshEstimate();
    }
  }

  Future<void> _loadModels() async {
    setState(() => _loadingModels = true);
    try {
      final models = await fetchModelsCatalog(
        widget.accessToken,
        typeFilter: widget.typeFilter,
        includePricing: true,
      );
      if (!mounted) return;
      String? selected;
      final ctrl = widget.modelValueController;
      if (ctrl != null && ctrl.text.trim().isNotEmpty) {
        final v = ctrl.text.trim();
        final match = models.where((m) => m.value == v || m.effectiveModelId == v);
        if (match.isNotEmpty) {
          selected = match.first.effectiveModelId;
        }
      }
      selected ??= models.isNotEmpty ? models.first.effectiveModelId : null;
      setState(() {
        _models = models;
        _selectedModelId = selected;
        _loadingModels = false;
      });
      _syncController();
      await _refreshEstimate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _estimateError = e.toString();
      });
    }
  }

  void _syncController() {
    final ctrl = widget.modelValueController;
    if (ctrl == null || _selectedModelId == null) return;
    final entry = _models.cast<ModelListEntry?>().firstWhere(
      (m) => m?.effectiveModelId == _selectedModelId,
      orElse: () => null,
    );
    if (entry != null) {
      ctrl.text = entry.value;
    }
  }

  Future<void> _refreshEstimate() async {
    final modelId = _selectedModelId;
    if (modelId == null) return;
    setState(() {
      _loadingEstimate = true;
      _estimateError = null;
    });
    try {
      final est = await postBillingEstimateV1(
        widget.accessToken,
        modelId: modelId,
        taskKind: widget.taskKind,
        quantity: widget.quantity,
      );
      if (!mounted) return;
      setState(() {
        _estimate = est;
        _loadingEstimate = false;
      });
      widget.onEstimateChanged?.call(est);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estimateError = e.toString();
        _loadingEstimate = false;
      });
      widget.onEstimateChanged?.call(null);
    }
  }

  void _onModelChanged(String? modelId) {
    setState(() => _selectedModelId = modelId);
    _syncController();
    _refreshEstimate();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingModels) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    if (_models.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StudioModelPicker(
          models: _models,
          selectedModelId: _selectedModelId,
          onChanged: _onModelChanged,
          enabled: widget.enabled,
        ),
        const SizedBox(height: 8),
        StudioCostEstimateChip(
          estimate: _estimate,
          loading: _loadingEstimate,
          error: _estimateError,
        ),
      ],
    );
  }
}
