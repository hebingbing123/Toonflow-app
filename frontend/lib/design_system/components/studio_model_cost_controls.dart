import 'package:flutter/material.dart';

import '../../project_studio/project_studio_model_routing_scope.dart';
import '../../rust_api.dart';
import 'studio_async_data_view.dart';
import 'studio_cost_estimate_chip.dart';
import 'studio_model_picker.dart';
import '../../design_system/tokens.dart';

/// Model picker + live cost estimate for inline generation forms.
class StudioModelCostControls extends StatefulWidget {
  const StudioModelCostControls({
    super.key,
    required this.accessToken,
    required this.taskKind,
    this.typeFilter = 'image',
    this.quantity = 1,
    this.modelValueController,
    this.projectUuid,
    this.studioStepSlug,
    this.modelSlot = 'image',
    this.initialModelId,
    this.enabled = true,
    this.onEstimateChanged,
  });

  final String accessToken;
  final String taskKind;
  final String typeFilter;
  final int quantity;
  final TextEditingController? modelValueController;
  final String? projectUuid;
  final String? studioStepSlug;
  final String modelSlot;
  final String? initialModelId;
  final bool enabled;
  final ValueChanged<BillingEstimateResponse?>? onEstimateChanged;

  @override
  State<StudioModelCostControls> createState() =>
      _StudioModelCostControlsState();
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
        final match = models.where(
          (m) => m.value == v || m.effectiveModelId == v,
        );
        if (match.isNotEmpty) {
          selected = match.first.effectiveModelId;
        }
      }
      selected ??= widget.initialModelId?.trim();
      if ((selected == null || selected.isEmpty) &&
          widget.projectUuid != null &&
          widget.studioStepSlug != null) {
        final scoped = ProjectStudioModelRoutingScope.routingOf(context);
        final fromScope = scoped?.effectiveModelFor(
          step: widget.studioStepSlug!,
          slot: widget.modelSlot,
        );
        if (fromScope != null && fromScope.isNotEmpty) {
          selected = fromScope;
        }
      }
      if ((selected == null || selected.isEmpty) &&
          widget.projectUuid != null &&
          widget.studioStepSlug != null) {
        try {
          final resolved = await resolveProjectModelV1(
            widget.accessToken,
            widget.projectUuid!,
            step: widget.studioStepSlug!,
            slot: widget.modelSlot,
          );
          selected = resolved.modelId;
        } catch (_) {
          // Fall back to catalog default below.
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
        _estimateError = describeUserVisibleApiErrorResolved(context, e);
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
        _estimateError = describeUserVisibleApiErrorResolved(context, e);
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
    if (_models.isEmpty && !_loadingModels) {
      return const SizedBox.shrink();
    }
    return StudioAsyncDataView(
      loading: _loadingModels,
      isEmpty: _models.isEmpty,
      empty: const SizedBox.shrink(),
      scrollableLoading: false,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StudioModelPicker(
          models: _models,
          selectedModelId: _selectedModelId,
          onChanged: _onModelChanged,
          enabled: widget.enabled,
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioCostEstimateChip(
          estimate: _estimate,
          loading: _loadingEstimate,
          error: _estimateError,
        ),
      ],
    ),
    );
  }
}
