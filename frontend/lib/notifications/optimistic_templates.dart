import '../rust_api.dart';

List<ContentComplianceClearedTemplateItemV1>
studioRemoveComplianceTemplateById(
  List<ContentComplianceClearedTemplateItemV1> items,
  String id,
) {
  return items
      .where((template) => template.id != id)
      .toList(growable: false);
}
