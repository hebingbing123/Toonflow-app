import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design_system/components/studio_icon_button.dart';
import '../design_system/ix/studio_dirty_pop_guard.dart';
import '../design_system/ix/studio_form_keyboard.dart';
import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_primary_button.dart';
import '../design_system/ix/studio_mobile_affordances.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';

/// Three-step create flow (tall sheet; Web uses [StudioWebTallSheetDialog]).
Future<Map<String, dynamic>?> showCreateProjectWizard(
  BuildContext context,
) async {
  final tokens = StudioTokens.of(context);
  return showStudioBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => StudioSystemUiSurface(
      surfaceColor: kIsWeb ? StudioPrimitives.transparent : tokens.bgElevated,
      child: const _CreateProjectWizardSheet(),
    ),
  );
}

class _CreateProjectWizardSheet extends StatefulWidget {
  const _CreateProjectWizardSheet();

  @override
  State<_CreateProjectWizardSheet> createState() =>
      _CreateProjectWizardSheetState();
}

class _CreateProjectWizardSheetState extends State<_CreateProjectWizardSheet> {
  final _page = PageController();
  var _step = 0;
  var _allowPopOnce = false;

  final _name = TextEditingController();
  final _intro = TextEditingController();
  final _novelPaste = TextEditingController();

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _intro.dispose();
    _novelPaste.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() => _step = step);
    unawaited(studioLightImpact());
    _page.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleEnterSubmit() {
    if (_name.text.trim().isEmpty) {
      return;
    }
    if (_step < 2) {
      _go(_step + 1);
      return;
    }
    unawaited(studioMediumImpact());
    setState(() => _allowPopOnce = true);
    Navigator.of(context).pop(_buildFields());
  }

  Map<String, dynamic> _buildFields() {
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'intro': _intro.text.trim(),
    };
    final pasted = _novelPaste.text.trim();
    if (pasted.isNotEmpty) {
      fields['premise'] = pasted;
    }
    return fields;
  }

  bool get _dirty =>
      _step > 0 ||
      _name.text.trim().isNotEmpty ||
      _intro.text.trim().isNotEmpty ||
      _novelPaste.text.trim().isNotEmpty;

  Future<bool> _confirmDiscardDraft() async {
    final l10n = AppLocalizations.of(context)!;
    final discard = await showStudioConfirmDialog(
      context: context,
      title: l10n.studioDiscardProjectDraftTitle,
      message: l10n.studioDiscardProjectDraftMessage,
      destructive: true,
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return StudioDirtyPopGuard(
      isDirty: _dirty,
      allowPop: _allowPopOnce,
      onConfirmDiscard: _confirmDiscardDraft,
      child: StudioFormKeyboardScope(
        onEnterSubmit: _handleEnterSubmit,
        child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Align(
          alignment:
              kIsWeb ? Alignment.center : Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              maxWidth: 640,
            ),
            child: Material(
              color: kIsWeb ? StudioPrimitives.transparent : tokens.bgElevated,
              borderRadius: kIsWeb
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(
                      top: Radius.circular(StudioSpacing.radiusCard),
                    ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!kIsWeb) ...<Widget>[
                    const SizedBox(height: StudioSpacing.xs),
                    Container(
                      width: StudioLayoutSize.skeletonAvatar,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.borderDefault,
                        borderRadius: BorderRadius.circular(
                          StudioSpacing.radiusHairline,
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      StudioSpacing.md,
                      StudioSpacing.sm,
                      StudioSpacing.radiusComfort,
                      StudioSpacing.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          l10n.studioCreateProjectWizardTitle,
                          style: studioDialogTitleStyle(context),
                        ),
                        const Spacer(),
                        StudioIconButton(
                          icon: Icons.close,
                          label: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: () async {
                            if (!_dirty) {
                              Navigator.of(context).pop();
                              return;
                            }
                            final discard = await _confirmDiscardDraft();
                            if (!context.mounted || !discard) {
                              return;
                            }
                            setState(() => _allowPopOnce = true);
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                  _WizardStepIndicator(current: _step),
                  Flexible(
                    child: PageView(
                      controller: _page,
                      physics: const NeverScrollableScrollPhysics(),
                      children: <Widget>[
                        _StepBasics(
                          name: _name,
                          intro: _intro,
                          onChanged: () => setState(() {}),
                          onAdvanceStep: () {
                            if (_name.text.trim().isEmpty) {
                              return;
                            }
                            if (_step < 2) {
                              _go(_step + 1);
                            }
                          },
                        ),
                        _StepNovelPaste(controller: _novelPaste),
                        _StepReview(
                          name: _name.text,
                          intro: _intro.text,
                          hasNovel: _novelPaste.text.trim().isNotEmpty,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(StudioSpacing.md),
                    child: Row(
                      children: <Widget>[
                        if (_step > 0)
                          TextButton(
                            onPressed: () => _go(_step - 1),
                            child: Text(l10n.studioWizardBack),
                          ),
                        const Spacer(),
                        if (_step < 2)
                          StudioPrimaryButton(
                            label: l10n.studioWizardNext,
                            onPressed: _name.text.trim().isEmpty
                                ? null
                                : () => _go(_step + 1),
                          )
                        else
                          StudioPrimaryButton(
                            label: l10n.studioWizardCreate,
                            onPressed: _name.text.trim().isEmpty
                                ? null
                                : () {
                                    unawaited(studioMediumImpact());
                                    setState(() {
                                      _allowPopOnce = true;
                                    });
                                    Navigator.of(context).pop(_buildFields());
                                  },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _WizardStepIndicator extends StatelessWidget {
  const _WizardStepIndicator({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final labels = <String>[
      l10n.studioWizardStepBasics,
      l10n.studioWizardStepContent,
      l10n.studioWizardStepReview,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.xs, StudioSpacing.sm, StudioSpacing.chromeActionGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(labels.length * 2 - 1, (index) {
          if (index.isOdd) {
            final leftStep = index ~/ 2;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: StudioSpacing.radiusComfort),
                child: Container(
                  height: 2,
                  color: leftStep < current
                      ? tokens.primary
                      : tokens.borderSubtle,
                ),
              ),
            );
          }
          final i = index ~/ 2;
          final active = i <= current;
          final isCurrent = i == current;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? tokens.primary : tokens.bgInset,
                    border: isCurrent
                        ? Border.all(color: tokens.accent, width: 2)
                        : null,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: studioWizardStepNumberStyle(
                      context,
                      active
                          ? Theme.of(context).colorScheme.onPrimary
                          : tokens.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: studioWizardStepLabelStyle(
                    context,
                    color: isCurrent
                        ? tokens.textPrimary
                        : active
                        ? tokens.textSecondary
                        : tokens.textMuted,
                    fontWeight:
                        isCurrent ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _StepBasics extends StatelessWidget {
  const _StepBasics({
    required this.name,
    required this.intro,
    required this.onChanged,
    required this.onAdvanceStep,
  });

  final TextEditingController name;
  final TextEditingController intro;
  final VoidCallback onChanged;
  final VoidCallback onAdvanceStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(StudioSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.studioWizardStepBasics,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: StudioSpacing.sm),
          TextField(
            controller: name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.projectsDialogFieldName,
            ),
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onAdvanceStep(),
          ),
          const SizedBox(height: StudioSpacing.sm),
          TextField(
            controller: intro,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.projectsDialogFieldIntro,
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _StepNovelPaste extends StatelessWidget {
  const _StepNovelPaste({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(StudioSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.studioWizardStepContent,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.studioWizardPasteNovelHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: StudioSpacing.sm),
          TextField(
            controller: controller,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: l10n.studioWizardPasteNovelPlaceholder,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepReview extends StatelessWidget {
  const _StepReview({
    required this.name,
    required this.intro,
    required this.hasNovel,
  });

  final String name;
  final String intro;
  final bool hasNovel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(StudioSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.studioWizardStepReview,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: StudioSpacing.sm),
          Text(
            l10n.projectsDialogFieldName,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(name.isEmpty ? '—' : name),
          const SizedBox(height: StudioSpacing.sm),
          Text(
            l10n.projectsDialogFieldIntro,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(intro.isEmpty ? '—' : intro),
          if (hasNovel) ...<Widget>[
            const SizedBox(height: StudioSpacing.sm),
            Text(
              l10n.studioWizardPasteNovelHint,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(l10n.studioWizardNovelAttached),
          ],
        ],
      ),
    );
  }
}
