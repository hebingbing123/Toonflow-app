import 'studio_step.dart';

/// Model routing slots exposed per Studio SOP step.
extension StudioStepModelSlots on StudioStep {
  /// Slot keys stored in API (`text`, `image`, …).
  List<String> get modelSlotKeys {
    switch (this) {
      case StudioStep.script:
      case StudioStep.quality:
        return const <String>['text'];
      case StudioStep.art:
        return const <String>['image'];
      case StudioStep.assets:
        return const <String>['image', 'text'];
      case StudioStep.storyboard:
        return const <String>['image', 'multimodal'];
      case StudioStep.video:
        return const <String>['text', 'multimodal', 'video'];
      case StudioStep.deliver:
        return const <String>[];
    }
  }

  /// Catalog `type` query for [`fetchModelsCatalog`].
  String typeFilterForSlot(String slot) {
    switch (slot) {
      case 'image':
        return 'image';
      case 'video':
        return 'video';
      case 'multimodal':
        return 'multimodal';
      default:
        return 'text';
    }
  }

  /// Typical billing `task_kind` for cost estimate chip in generation forms.
  String taskKindForSlot(String slot) {
    switch (this) {
      case StudioStep.script:
      case StudioStep.quality:
        return 'text_completion';
      case StudioStep.video:
      case StudioStep.storyboard:
        if (slot == 'video') return 'storyboard_video';
        if (slot == 'image') return 'asset_image_batch';
        return 'text_completion';
      case StudioStep.art:
      case StudioStep.assets:
        return 'asset_image_batch';
      case StudioStep.deliver:
        return 'storyboard_video';
    }
  }
}
