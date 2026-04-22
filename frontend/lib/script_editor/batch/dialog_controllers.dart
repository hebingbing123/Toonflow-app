part of '../../../home_page.dart';

class _StoryboardBatchWorkbenchControllers {
  _StoryboardBatchWorkbenchControllers({
    required this.promptSuffixCtrl,
    required this.negativePromptCtrl,
    required this.modelCtrl,
    required this.resolutionCtrl,
  });

  factory _StoryboardBatchWorkbenchControllers.create() {
    return _StoryboardBatchWorkbenchControllers(
      promptSuffixCtrl: TextEditingController(),
      negativePromptCtrl: TextEditingController(),
      modelCtrl: TextEditingController(),
      resolutionCtrl: TextEditingController(),
    );
  }

  final TextEditingController promptSuffixCtrl;
  final TextEditingController negativePromptCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController resolutionCtrl;

  void dispose() {
    promptSuffixCtrl.dispose();
    negativePromptCtrl.dispose();
    modelCtrl.dispose();
    resolutionCtrl.dispose();
  }
}

