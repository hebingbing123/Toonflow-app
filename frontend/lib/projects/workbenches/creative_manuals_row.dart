part of 'creative_manuals.dart';

class _CreativeManualRow {
  const _CreativeManualRow({
    required this.name,
    required this.path,
    required this.images,
    required this.slots,
  });

  final String name;
  final String path;
  final List<String> images;
  final List<DirectorManualDataSlot> slots;

  factory _CreativeManualRow.fromDirector(DirectorManualStyleRow row) {
    return _CreativeManualRow(
      name: row.name,
      path: row.directorManual,
      images: row.image,
      slots: row.data,
    );
  }

  factory _CreativeManualRow.fromVisual(VisualManualStyleV1 row) {
    return _CreativeManualRow(
      name: row.name,
      path: row.stylePath,
      images: row.image,
      slots: row.data
          .map(
            (slot) => DirectorManualDataSlot(
              label: slot.label,
              value: slot.value,
              data: slot.data,
            ),
          )
          .toList(growable: false),
    );
  }
}
