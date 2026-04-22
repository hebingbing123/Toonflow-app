part of 'creative_manuals.dart';

class _CreativeManualsWorkbenchControllers {
  _CreativeManualsWorkbenchControllers({
    required this.nameCtrl,
    required this.pathCtrl,
    required this.imagesCtrl,
    required this.slotsCtrl,
  });

  factory _CreativeManualsWorkbenchControllers.create() {
    return _CreativeManualsWorkbenchControllers(
      nameCtrl: TextEditingController(),
      pathCtrl: TextEditingController(),
      imagesCtrl: TextEditingController(),
      slotsCtrl: TextEditingController(text: _defaultCreativeManualSlotsText),
    );
  }

  final TextEditingController nameCtrl;
  final TextEditingController pathCtrl;
  final TextEditingController imagesCtrl;
  final TextEditingController slotsCtrl;

  void dispose() {
    nameCtrl.dispose();
    pathCtrl.dispose();
    imagesCtrl.dispose();
    slotsCtrl.dispose();
  }
}

