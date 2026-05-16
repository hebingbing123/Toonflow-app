part of 'dialog.dart';

class _AssetGenerationWorkbenchControllers {
  _AssetGenerationWorkbenchControllers({
    required this.modelCtrl,
    required this.resolutionCtrl,
    required this.imageUrlCtrl,
    required this.batchNameCtrl,
    required this.batchLimitCtrl,
  });

  factory _AssetGenerationWorkbenchControllers.create() {
    return _AssetGenerationWorkbenchControllers(
      modelCtrl: TextEditingController(),
      resolutionCtrl: TextEditingController(),
      imageUrlCtrl: TextEditingController(),
      batchNameCtrl: TextEditingController(),
      batchLimitCtrl: TextEditingController(text: '10'),
    );
  }

  final TextEditingController modelCtrl;
  final TextEditingController resolutionCtrl;
  final TextEditingController imageUrlCtrl;
  final TextEditingController batchNameCtrl;
  final TextEditingController batchLimitCtrl;

  void dispose() {
    modelCtrl.dispose();
    resolutionCtrl.dispose();
    imageUrlCtrl.dispose();
    batchNameCtrl.dispose();
    batchLimitCtrl.dispose();
  }
}

