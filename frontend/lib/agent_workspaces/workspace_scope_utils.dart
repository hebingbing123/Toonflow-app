String? trimmedNonEmpty(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  return value;
}

int? parsePositiveInt(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0) {
    return null;
  }
  return value;
}

int? toPositiveIntValue(Object? raw) {
  if (raw is int) {
    return raw > 0 ? raw : null;
  }
  if (raw is num) {
    final normalized = raw.toInt();
    return normalized > 0 ? normalized : null;
  }
  if (raw is String) {
    return parsePositiveInt(raw);
  }
  return null;
}

bool looksLikeUuid(String raw) {
  final value = raw.trim();
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
