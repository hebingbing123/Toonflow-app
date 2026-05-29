part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionBuild on _ShortVideoSpaceSectionState {
  Widget buildShortVideoSpaceSection(BuildContext context) {
    final bundle = compileSectionBuildBundle(context);
    return buildShortVideoSectionLayout(context, bundle);
  }
}
