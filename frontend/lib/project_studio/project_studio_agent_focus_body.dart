import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../design_system/components/studio_text_styles.dart';

/// Full-width step body with production/script agent hidden until explicitly opened.
class ProjectStudioAgentFocusBody extends StatefulWidget {
  const ProjectStudioAgentFocusBody({
    super.key,
    required this.agentWorkspace,
    required this.openLabel,
    this.closeLabel,
  });

  final Widget agentWorkspace;
  final String openLabel;
  final String? closeLabel;

  @override
  State<ProjectStudioAgentFocusBody> createState() =>
      _ProjectStudioAgentFocusBodyState();
}

class _ProjectStudioAgentFocusBodyState extends State<ProjectStudioAgentFocusBody> {
  bool _agentOpen = false;

  @override
  Widget build(BuildContext context) {
    if (!_agentOpen) {
      final tokens = StudioTokens.of(context);
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: ColoredBox(color: tokens.bgInset),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Material(
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(24),
              color: tokens.bgSurface.withValues(alpha: 0.96),
              child: InkWell(
                onTap: () => setState(() => _agentOpen = true),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.smart_toy_outlined, size: 20, color: tokens.primary),
                      const SizedBox(width: 8),
                      Text(
                        widget.openLabel,
                        style: studioControlLabelStyle(context)?.copyWith(
                          color: tokens.primary,
                        ),
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

    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _agentOpen = false),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text(widget.closeLabel ?? l10n.studioScriptStepCloseAgent),
          ),
        ),
        Expanded(child: widget.agentWorkspace),
      ],
    );
  }
}
