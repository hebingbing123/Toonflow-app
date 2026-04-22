part of '../section.dart';

class _ArtStylesWorkbenchControllers {
  _ArtStylesWorkbenchControllers({
    required this.nameCtrl,
    required this.labelCtrl,
    required this.promptCtrl,
    required this.fileUrlCtrl,
    required this.extractImagesCtrl,
  });

  factory _ArtStylesWorkbenchControllers.create() {
    return _ArtStylesWorkbenchControllers(
      nameCtrl: TextEditingController(),
      labelCtrl: TextEditingController(),
      promptCtrl: TextEditingController(),
      fileUrlCtrl: TextEditingController(),
      extractImagesCtrl: TextEditingController(),
    );
  }

  final TextEditingController nameCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController promptCtrl;
  final TextEditingController fileUrlCtrl;
  final TextEditingController extractImagesCtrl;

  void dispose() {
    nameCtrl.dispose();
    labelCtrl.dispose();
    promptCtrl.dispose();
    fileUrlCtrl.dispose();
    extractImagesCtrl.dispose();
  }
}

