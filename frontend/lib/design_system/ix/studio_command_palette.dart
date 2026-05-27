import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../components/studio_dialog_shell.dart';
import '../components/studio_empty_state.dart';
import '../components/studio_surfaces.dart';
import '../components/studio_entrance_motion.dart';
import '../tokens.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

/// Command palette action (⌘K / Ctrl+K).
class StudioCommandAction {
  const StudioCommandAction({
    required this.id,
    required this.label,
    required this.onInvoke,
    this.keywords = const <String>[],
    this.icon,
  });

  final String id;
  final String label;
  final List<String> keywords;
  final IconData? icon;
  final VoidCallback onInvoke;
}

/// Opens a modal command palette. Returns when dismissed.
Future<void> showStudioCommandPalette(
  BuildContext context, {
  required List<StudioCommandAction> actions,
}) async {
  await showStudioDialog<void>(
    context: context,
    builder: (ctx) => _StudioCommandPaletteDialog(actions: actions),
  );
}

/// Registers ⌘K / Ctrl+K to open [showStudioCommandPalette].
class StudioCommandPaletteIntent extends Intent {
  const StudioCommandPaletteIntent();
}

class StudioCommandPaletteShortcuts extends StatelessWidget {
  const StudioCommandPaletteShortcuts({
    super.key,
    required this.actions,
    required this.child,
  });

  final List<StudioCommandAction> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            StudioCommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            StudioCommandPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          StudioCommandPaletteIntent: CallbackAction<StudioCommandPaletteIntent>(
            onInvoke: (_) {
              showStudioCommandPalette(context, actions: actions);
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _StudioCommandPaletteDialog extends StatefulWidget {
  const _StudioCommandPaletteDialog({required this.actions});

  final List<StudioCommandAction> actions;

  @override
  State<_StudioCommandPaletteDialog> createState() =>
      _StudioCommandPaletteDialogState();
}

class _StudioCommandPaletteDialogState extends State<_StudioCommandPaletteDialog> {
  final _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<StudioCommandAction> get _filtered {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return widget.actions;
    return widget.actions.where((a) {
      if (a.label.toLowerCase().contains(q)) return true;
      return a.keywords.any((k) => k.toLowerCase().contains(q));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final items = _filtered;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
        child: Material(
          color: StudioPrimitives.transparent,
          child: DecoratedBox(
            decoration: studioInsetPanelDecoration(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(StudioSpacing.sm),
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l10n.studioCommandPaletteSearchHint,
                        prefixIcon: Icon(
                          Icons.search,
                          color: tokens.textMuted,
                        ),
                      ),
                      onChanged: (v) => setState(() => _filter = v),
                      onSubmitted: (_) {
                        if (items.isNotEmpty) {
                          Navigator.of(context).pop();
                          items.first.onInvoke();
                        }
                      },
                    ),
                  ),
                  Divider(height: 1, color: tokens.borderSubtle),
                  Flexible(
                    child: items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(StudioSpacing.sm),
                            child: StudioEmptyState.noResults(
                              title: l10n.studioCommandPaletteNoResultsTitle,
                              subtitle: l10n.studioCommandPaletteNoResultsHint,
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final action = items[index];
                              return studioStaggeredItem(
                                index,
                                entranceKey: items.length,
                                child: StudioListRow(
                                  minVerticalPadding: 10,
                                  leading: Icon(
                                    action.icon ?? Icons.chevron_right,
                                    color: tokens.textSecondary,
                                  ),
                                  title: Text(
                                    action.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: tokens.textPrimary),
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    action.onInvoke();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
