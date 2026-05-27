import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';

/// First-run coach marks (Wave 0b).
class StudioOnboardingCoach extends StatefulWidget {
  const StudioOnboardingCoach({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// When false, coach marks are suppressed (e.g. login / non-projects panes).
  final bool enabled;

  static const _seenKey = 'studio_onboarding_seen_v1';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_seenKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<StudioOnboardingCoach> createState() => _StudioOnboardingCoachState();
}

class _StudioOnboardingCoachState extends State<StudioOnboardingCoach> {
  var _step = 0;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant StudioOnboardingCoach oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _visible) {
      setState(() => _visible = false);
    } else if (widget.enabled && !oldWidget.enabled) {
      unawaited(_init());
    }
  }

  Future<void> _init() async {
    if (!widget.enabled) {
      if (!mounted) return;
      setState(() => _visible = false);
      return;
    }
    final show = await StudioOnboardingCoach.shouldShow();
    if (!mounted) return;
    setState(() {
      _visible = show;
      _step = 0;
    });
  }

  Future<void> _dismiss() async {
    await StudioOnboardingCoach.markSeen();
    if (!mounted) return;
    setState(() => _visible = false);
  }

  List<String> _messages(AppLocalizations l10n) => <String>[
    l10n.studioOnboardingStep1,
    l10n.studioOnboardingStep2,
    l10n.studioOnboardingStep3,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messages = _messages(l10n);
    return Stack(
      children: <Widget>[
        widget.child,
        if (_visible)
          Positioned(
            right: 24,
            bottom: 24,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
              color: StudioTokens.of(context).bgElevated,
              child: Padding(
                padding: const EdgeInsets.all(StudioSpacing.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: StudioLayoutSize.fieldStandard),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(messages[_step.clamp(0, messages.length - 1)]),
                      const SizedBox(height: StudioSpacing.sm),
                      Row(
                        children: <Widget>[
                          Text(
                            l10n.studioOnboardingStepCounter(
                              _step + 1,
                              messages.length,
                            ),
                          ),
                          const Spacer(),
                          if (_step > 0)
                            TextButton(
                              onPressed: () => setState(() => _step--),
                              child: Text(l10n.studioOnboardingPrevious),
                            ),
                          TextButton(
                            onPressed: () {
                              if (_step < messages.length - 1) {
                                setState(() => _step++);
                              } else {
                                _dismiss();
                              }
                            },
                            child: Text(
                              _step < messages.length - 1
                                  ? l10n.studioOnboardingNext
                                  : l10n.studioOnboardingDone,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
