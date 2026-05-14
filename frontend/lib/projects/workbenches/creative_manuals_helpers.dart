// ignore_for_file: library_private_types_in_public_api

part of 'creative_manuals.dart';

List<String> parseCreativeManualImages(String raw) {
  return raw
      .split(RegExp(r'[\n,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

List<DirectorManualDataSlot> parseCreativeManualSlots(String raw) {
  final lines = raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  final slots = <DirectorManualDataSlot>[];
  for (final line in lines) {
    final parts = line.split('|');
    if (parts.length < 3) {
      throw FormatException(line);
    }
    slots.add(
      DirectorManualDataSlot(
        label: parts[0].trim(),
        value: parts[1].trim(),
        data: parts.sublist(2).join('|').trim(),
      ),
    );
  }
  return slots;
}

String encodeCreativeManualSlots(
  List<DirectorManualDataSlot> slots, {
  required String emptyDefault,
}) {
  if (slots.isEmpty) {
    return emptyDefault;
  }
  return slots
      .map((slot) => '${slot.label}|${slot.value}|${slot.data}')
      .join('\n');
}

String creativeManualKindLabel(
  AppLocalizations l10n,
  _CreativeManualKind kind,
) {
  return kind == _CreativeManualKind.director
      ? l10n.projectsCreativeManualKindDirector
      : l10n.projectsCreativeManualKindVisual;
}
