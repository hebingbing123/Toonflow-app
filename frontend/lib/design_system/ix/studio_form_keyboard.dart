import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop/web intent: submit the surrounding form on Enter.
class StudioFormSubmitIntent extends Intent {
  const StudioFormSubmitIntent();
}

/// Nearest [TextField] ancestor for the current focus, if any.
TextField? studioFocusedTextField(BuildContext? focusContext) {
  return focusContext?.findAncestorWidgetOfExactType<TextField>();
}

/// Whether Enter should trigger [onEnterSubmit] for the focused field.
bool studioFormFieldAcceptsEnterSubmit(BuildContext? context) {
  if (context == null) {
    return true;
  }
  final editable = context.findAncestorWidgetOfExactType<EditableText>();
  if (editable == null) {
    return true;
  }
  final maxLines = editable.maxLines;
  return maxLines != null && maxLines == 1;
}

/// [FocusTraversalGroup] plus optional Enter-to-submit for single-line fields.
class StudioFormKeyboardScope extends StatelessWidget {
  const StudioFormKeyboardScope({
    super.key,
    required this.child,
    this.onEnterSubmit,
  });

  final Widget child;
  final VoidCallback? onEnterSubmit;

  @override
  Widget build(BuildContext context) {
    final submit = onEnterSubmit;
    Widget body = FocusTraversalGroup(child: child);
    if (submit == null) {
      return body;
    }
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): StudioFormSubmitIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): StudioFormSubmitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          StudioFormSubmitIntent: CallbackAction<StudioFormSubmitIntent>(
            onInvoke: (StudioFormSubmitIntent intent) {
              final focus = FocusManager.instance.primaryFocus;
              if (!studioFormFieldAcceptsEnterSubmit(focus?.context)) {
                return null;
              }
              submit();
              return null;
            },
          ),
        },
        child: body,
      ),
    );
  }
}
