import 'package:flutter/material.dart';

import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';

/// Three-step create flow (full-screen sheet, not [AlertDialog]).
Future<Map<String, dynamic>?> showCreateProjectWizard(
  BuildContext context,
) async {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _CreateProjectWizardSheet(),
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
    _page.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            maxWidth: 640,
          ),
          child: Material(
            color: tokens.bgElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(StudioSpacing.radiusCard),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.borderDefault,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: <Widget>[
                      Text(
                        l10n.studioCreateProjectWizardTitle,
                        style: studioDialogTitleStyle(context),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
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
                  padding: const EdgeInsets.all(20),
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
                              : () => Navigator.of(context).pop(_buildFields()),
                        ),
                    ],
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(labels.length * 2 - 1, (index) {
          if (index.isOdd) {
            final leftStep = index ~/ 2;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 13),
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : tokens.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    color: isCurrent
                        ? tokens.textPrimary
                        : active
                            ? tokens.textSecondary
                            : tokens.textMuted,
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
  });

  final TextEditingController name;
  final TextEditingController intro;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.studioWizardStepBasics,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.projectsDialogFieldName,
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: intro,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.projectsDialogFieldIntro,
            ),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.studioWizardStepContent,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.studioWizardPasteNovelHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.studioWizardStepReview,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.projectsDialogFieldName,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(name.isEmpty ? '—' : name),
          const SizedBox(height: 12),
          Text(
            l10n.projectsDialogFieldIntro,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(intro.isEmpty ? '—' : intro),
          if (hasNovel) ...<Widget>[
            const SizedBox(height: 12),
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
