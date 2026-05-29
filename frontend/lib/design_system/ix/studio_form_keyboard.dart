import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/studio_debounced_action.dart';

/// Counts single-line [TextField] widgets in a dialog/form [content] subtree.
///
/// Used to avoid Enter-to-submit on multi-field dialogs (would skip unfilled fields).
int studioCountSingleLineTextFields(Widget? root) {
  if (root == null) {
    return 0;
  }
  var count = 0;
  void visit(Widget widget) {
    if (widget is TextField) {
      final maxLines = widget.maxLines;
      if (maxLines == null || maxLines == 1) {
        count++;
      }
      return;
    }
    if (widget is SingleChildScrollView) {
      final child = widget.child;
      if (child != null) {
        visit(child);
      }
      return;
    }
    if (widget is Padding) {
      final child = widget.child;
      if (child != null) {
        visit(child);
      }
      return;
    }
    if (widget is SizedBox) {
      final child = widget.child;
      if (child != null) {
        visit(child);
      }
      return;
    }
    if (widget is ConstrainedBox) {
      final child = widget.child;
      if (child != null) {
        visit(child);
      }
      return;
    }
    if (widget is Column) {
      for (final child in widget.children) {
        visit(child);
      }
      return;
    }
    if (widget is Row) {
      for (final child in widget.children) {
        visit(child);
      }
      return;
    }
    if (widget is ListBody) {
      for (final child in widget.children) {
        visit(child);
      }
      return;
    }
    if (widget is DefaultTextStyle) {
      visit(widget.child);
    }
  }

  visit(root);
  return count;
}

/// Prefer the trailing [FilledButton] in dialog [actions] as the primary action.
VoidCallback? studioDialogPrimaryActionFromActions(List<Widget>? actions) {
  if (actions == null || actions.isEmpty) {
    return null;
  }
  for (var i = actions.length - 1; i >= 0; i--) {
    final action = actions[i];
    if (action is FilledButton && action.onPressed != null) {
      return action.onPressed;
    }
    if (action is StudioDebouncedAction && action.onPressed != null) {
      return () => action.onPressed!();
    }
  }
  return null;
}

/// Resolves Enter-to-submit for [StudioAlertDialog]-style chrome.
VoidCallback? studioResolveAlertDialogEnterSubmit({
  required bool enterSubmitEnabled,
  VoidCallback? onEnterSubmit,
  Widget? content,
  List<Widget>? actions,
}) {
  if (!enterSubmitEnabled) {
    return null;
  }
  if (onEnterSubmit != null) {
    return onEnterSubmit;
  }
  if (studioCountSingleLineTextFields(content) != 1) {
    return null;
  }
  return studioDialogPrimaryActionFromActions(actions);
}

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
