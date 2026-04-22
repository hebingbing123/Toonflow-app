part of '../section.dart';

Map<String, dynamic> buildArtStylePatchBody({
  required String name,
  required String label,
  required String prompt,
  required String fileUrl,
}) {
  final normalizedName = name.trim();
  final normalizedLabel = label.trim();
  final normalizedPrompt = prompt.trim();
  final normalizedFileUrl = fileUrl.trim();
  return <String, dynamic>{
    'name': normalizedName,
    'label': normalizedLabel.isEmpty ? null : normalizedLabel,
    'prompt': normalizedPrompt.isEmpty ? null : normalizedPrompt,
    'file_url': normalizedFileUrl.isEmpty ? null : normalizedFileUrl,
  };
}

List<String> parseArtStyleExtractImages(String raw) {
  return raw
      .split(RegExp(r'[\n,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

