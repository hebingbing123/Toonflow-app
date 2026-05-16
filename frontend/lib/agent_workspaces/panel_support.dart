/// Shared fallback logic for workspace dropdowns.
String? resolveWorkspaceDropdownValue(String value, List<String> allowed) {
  if (allowed.contains(value)) return value;
  if (allowed.isEmpty) return null;
  return allowed.first;
}
