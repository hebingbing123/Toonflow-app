import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Compile-time constant: rubric version from docs/plans/quality-rubric.md
// ---------------------------------------------------------------------------
const String kRubricVersion = '2026-06-01';

// ---------------------------------------------------------------------------
// Dimension key → Chinese label mapping
// ---------------------------------------------------------------------------
const Map<String, String> kDimensionLabels = {
  'visual_consistency': '画面/人设一致性',
  'narrative_coherence': '叙事连贯性',
  'lip_sync': '对口型',
  'pacing': '节奏',
  'character_consistency': '人设一致性',
  'dialogue_naturalness': '对白自然度',
  'faithfulness': '与原著/设定符合度',
};

/// Ordered list of dimension keys (preserves display order).
const List<String> kDimensionKeys = [
  'visual_consistency',
  'narrative_coherence',
  'lip_sync',
  'pacing',
  'character_consistency',
  'dialogue_naturalness',
  'faithfulness',
];

// ---------------------------------------------------------------------------
// hasDimensionRisk
// ---------------------------------------------------------------------------

/// Returns `true` if any value in [scores] is ≤ 3.
///
/// Returns `false` when [scores] is null or empty.
bool hasDimensionRisk(Map<String, int>? scores) {
  if (scores == null || scores.isEmpty) return false;
  return scores.values.any((v) => v <= 3);
}

// ---------------------------------------------------------------------------
// DimensionScoreFormWidget
// ---------------------------------------------------------------------------

/// A form widget that lets the user rate 7 quality dimensions on a 1–10 scale.
///
/// Each dimension row has:
/// - A Chinese label
/// - A [Slider] (1–10, 9 divisions)
/// - A [TextFormField] showing the current integer value with inline validation
/// - A "跳过" checkbox; when checked the dimension is excluded from the output
///
/// The rubric version is shown at the top of the form.
class DimensionScoreFormWidget extends StatefulWidget {
  const DimensionScoreFormWidget({
    super.key,
    this.initialScores,
    required this.onChanged,
  });

  /// Pre-fills the controls. Keys not present are treated as skipped.
  final Map<String, int>? initialScores;

  /// Called whenever any score changes. Passes `null` when all dimensions are
  /// skipped; otherwise passes a map containing only the non-skipped entries.
  final void Function(Map<String, int>? scores) onChanged;

  @override
  State<DimensionScoreFormWidget> createState() =>
      _DimensionScoreFormWidgetState();
}

class _DimensionScoreFormWidgetState extends State<DimensionScoreFormWidget> {
  // Per-dimension state
  late final Map<String, int> _scores;
  late final Map<String, bool> _skipped;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String?> _errors;

  @override
  void initState() {
    super.initState();
    _scores = {};
    _skipped = {};
    _controllers = {};
    _errors = {};

    for (final key in kDimensionKeys) {
      final initial = widget.initialScores?[key];
      final isSkipped = initial == null;
      _scores[key] = initial ?? 5;
      _skipped[key] = isSkipped;
      _controllers[key] = TextEditingController(
        text: isSkipped ? '' : '${_scores[key]}',
      );
      _errors[key] = null;
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _notifyChanged() {
    final result = <String, int>{};
    for (final key in kDimensionKeys) {
      if (!(_skipped[key] ?? false)) {
        result[key] = _scores[key]!;
      }
    }
    widget.onChanged(result.isEmpty ? null : result);
  }

  void _onSliderChanged(String key, double value) {
    final intVal = value.round();
    setState(() {
      _scores[key] = intVal;
      _errors[key] = null;
      _controllers[key]!.text = '$intVal';
    });
    _notifyChanged();
  }

  void _onTextChanged(String key, String text) {
    final parsed = int.tryParse(text.trim());
    setState(() {
      if (parsed == null) {
        _errors[key] = '请输入 1–10 的整数';
      } else if (parsed < 1 || parsed > 10) {
        _errors[key] = '分值须在 1–10 之间';
      } else {
        _errors[key] = null;
        _scores[key] = parsed;
      }
    });
    if (_errors[key] == null) {
      _notifyChanged();
    }
  }

  void _onSkipChanged(String key, bool? value) {
    final skip = value ?? false;
    setState(() {
      _skipped[key] = skip;
      if (skip) {
        _controllers[key]!.text = '';
        _errors[key] = null;
      } else {
        _controllers[key]!.text = '${_scores[key]}';
      }
    });
    _notifyChanged();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rubric version header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '量表版本：$kRubricVersion',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        // Dimension rows
        ...kDimensionKeys.map(
          (key) => _DimensionRow(
            dimensionKey: key,
            label: kDimensionLabels[key]!,
            score: _scores[key]!,
            skipped: _skipped[key]!,
            controller: _controllers[key]!,
            errorText: _errors[key],
            onSliderChanged: (v) => _onSliderChanged(key, v),
            onTextChanged: (v) => _onTextChanged(key, v),
            onSkipChanged: (v) => _onSkipChanged(key, v),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _DimensionRow (private helper widget)
// ---------------------------------------------------------------------------

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.dimensionKey,
    required this.label,
    required this.score,
    required this.skipped,
    required this.controller,
    required this.errorText,
    required this.onSliderChanged,
    required this.onTextChanged,
    required this.onSkipChanged,
  });

  final String dimensionKey;
  final String label;
  final int score;
  final bool skipped;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<bool?> onSkipChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row + skip checkbox
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: skipped ? Theme.of(context).disabledColor : null,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '跳过',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  Checkbox(
                    value: skipped,
                    onChanged: onSkipChanged,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          // Slider + text field (hidden when skipped)
          if (!skipped) ...[
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: score.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$score',
                    onChanged: onSliderChanged,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                      errorMaxLines: 2,
                    ),
                    onChanged: onTextChanged,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DimensionScoreDisplayWidget
// ---------------------------------------------------------------------------

/// Displays dimension scores in a detail view.
///
/// Shows each dimension with its Chinese label and score value.
/// When [scores] is null or empty, shows a placeholder text.
class DimensionScoreDisplayWidget extends StatelessWidget {
  const DimensionScoreDisplayWidget({super.key, required this.scores});

  final Map<String, int>? scores;

  @override
  Widget build(BuildContext context) {
    if (scores == null || scores!.isEmpty) {
      return Text(
        '暂无维度评分',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show dimensions in canonical order; fall back to map iteration order
        // for any keys not in kDimensionKeys.
        for (final key in _orderedKeys(scores!))
          _ScoreRow(label: kDimensionLabels[key] ?? key, score: scores![key]!),
      ],
    );
  }

  /// Returns keys in canonical order, followed by any unknown keys.
  List<String> _orderedKeys(Map<String, int> s) {
    final ordered = kDimensionKeys.where(s.containsKey).toList();
    final extra = s.keys.where((k) => !kDimensionKeys.contains(k)).toList();
    return [...ordered, ...extra];
  }
}

// ---------------------------------------------------------------------------
// _ScoreRow (private helper widget)
// ---------------------------------------------------------------------------

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final isRisk = score <= 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            '$score',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isRisk
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
