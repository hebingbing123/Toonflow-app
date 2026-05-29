import 'package:flutter/foundation.dart';

import '../design_system/components/studio_transfer_progress.dart';

/// In-app transfer queue for uploads/exports (20.3).
class StudioTransferQueue extends ChangeNotifier {
  StudioTransferQueue._();
  static final StudioTransferQueue instance = StudioTransferQueue._();

  final List<StudioTransferProgressItem> _items = <StudioTransferProgressItem>[];

  List<StudioTransferProgressItem> get items =>
      List<StudioTransferProgressItem>.unmodifiable(_items);

  bool get hasActive => _items.isNotEmpty;

  void upsert(String id, StudioTransferProgressItem item) {
    final index = _items.indexWhere((row) => row.label == id);
    if (index < 0) {
      _items.add(item);
    } else {
      _items[index] = item;
    }
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((row) => row.label == id);
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) {
      return;
    }
    _items.clear();
    notifyListeners();
  }
}
