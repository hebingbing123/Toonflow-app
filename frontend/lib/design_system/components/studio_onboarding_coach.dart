import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tokens.dart';

/// First-run coach marks (Wave 0b).
class StudioOnboardingCoach extends StatefulWidget {
  const StudioOnboardingCoach({super.key, required this.child});

  final Widget child;

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

  static const _messages = <String>[
    '用左侧导航在「项目」里开始创作。',
    '进入项目后按六步完成剧本到成片。',
    '按 ⌘K 可快速跳转步骤与设置。',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        if (_visible)
          Positioned(
            right: 24,
            bottom: 24,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(12),
              color: StudioTokens.of(context).bgElevated,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_messages[_step.clamp(0, _messages.length - 1)]),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Text('${_step + 1}/${_messages.length}'),
                          const Spacer(),
                          if (_step > 0)
                            TextButton(
                              onPressed: () => setState(() => _step--),
                              child: const Text('上一步'),
                            ),
                          TextButton(
                            onPressed: () {
                              if (_step < _messages.length - 1) {
                                setState(() => _step++);
                              } else {
                                _dismiss();
                              }
                            },
                            child: Text(
                              _step < _messages.length - 1 ? '下一步' : '完成',
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
