import 'dart:collection';

import '../../rust_api.dart';

part 'support_models.dart';
part 'support_filters.dart';
part 'support_actions.dart';
part 'support_stats.dart';

int _qualityScorePercent(int? score, {int fallback = 10}) {
  final normalized = (score ?? fallback).clamp(0, 10);
  return normalized * 10;
}
