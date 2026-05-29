import 'dart:convert' show LineSplitter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../components/studio_icon_button.dart';
import '../tokens.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// Immutable snapshot of a Flutter error captured for on-screen display.
@immutable
class DebugErrorSnapshot {
  const DebugErrorSnapshot({
    required this.exceptionType,
    required this.message,
    required this.stackLines,
  });

  /// Runtime type name of the exception, e.g. `"FlutterError"`.
  final String exceptionType;

  /// `exception.toString()` — may be empty if the exception has no message.
  final String message;

  /// First 20 lines of the stack trace (may be empty if no stack was captured).
  final List<String> stackLines;

  /// Constructs a snapshot from a [FlutterErrorDetails] object.
  ///
  /// Uses [LineSplitter] to split the stack trace and [Iterable.take] to keep
  /// only the first 20 lines, matching the design spec.
  factory DebugErrorSnapshot.fromDetails(FlutterErrorDetails details) {
    final exception = details.exception;
    final rawStack = details.stack?.toString() ?? '';
    final lines = const LineSplitter()
        .convert(rawStack)
        .take(20)
        .toList(growable: false);
    return DebugErrorSnapshot(
      exceptionType: exception.runtimeType.toString(),
      message: exception.toString(),
      stackLines: lines,
    );
  }

  /// Full text combining type, message, and stack lines — used for clipboard
  /// and the expanded body.
  String get fullText =>
      '$exceptionType\n\n$message\n\n${stackLines.join('\n')}';
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// A collapsible on-screen debug overlay anchored to the bottom of the screen.
///
/// Renders a semi-transparent danger-coloured bar showing the exception type.
/// Tapping the header toggles between collapsed (48 px) and expanded (full
/// scrollable body) states.
///
/// All colours come from [StudioTokens] / [StudioPrimitives] / [StudioSpacing]
/// — no hard-coded colour literals.
class DebugOverlayWidget extends StatefulWidget {
  const DebugOverlayWidget({super.key, required this.snapshot});

  final DebugErrorSnapshot snapshot;

  @override
  State<DebugOverlayWidget> createState() => _DebugOverlayWidgetState();
}

class _DebugOverlayWidgetState extends State<DebugOverlayWidget> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  void _copyToClipboard() {
    final l10n = AppLocalizations.of(context)!;
    final text = widget.snapshot.fullText.trim().isEmpty
        ? l10n.studioDesignDebugNoDetailsAvailable
        : widget.snapshot.fullText;
    Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final maxPanelHeight = MediaQuery.sizeOf(context).height * 0.6;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: _expanded ? maxPanelHeight : StudioSpacing.touchTarget,
        constraints: BoxConstraints(maxHeight: maxPanelHeight),
        child: Material(
          color: tokens.danger.withValues(alpha: 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              GestureDetector(
                onTap: _toggleExpanded,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: StudioSpacing.touchTarget,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StudioSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bug_report_outlined,
                          color: tokens.textPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: StudioSpacing.xs),
                        Expanded(
                          child: Text(
                            widget.snapshot.exceptionType,
                            style: textTheme.labelLarge?.copyWith(
                              color: tokens.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        // Copy-to-clipboard button
                        StudioIconButton(
                          icon: Icons.copy_outlined,
                          label: l10n.studioDesignDebugCopyErrorLabel,
                          size: 18,
                          color: tokens.textPrimary,
                          onPressed: _copyToClipboard,
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(
                              StudioSpacing.touchTarget,
                              StudioSpacing.touchTarget,
                            ),
                            fixedSize: const Size(
                              StudioSpacing.touchTarget,
                              StudioSpacing.touchTarget,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Expanded body ────────────────────────────────────────────
              if (_expanded)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      StudioSpacing.sm,
                      0,
                      StudioSpacing.sm,
                      StudioSpacing.sm,
                    ),
                    child: _buildBodyText(context, tokens, textTheme),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyText(
    BuildContext context,
    StudioTokens tokens,
    TextTheme textTheme,
  ) {
    final snapshot = widget.snapshot;
    final hasMessage = snapshot.message.trim().isNotEmpty;
    final hasStack = snapshot.stackLines.isNotEmpty;

    if (!hasMessage && !hasStack) {
      final l10n = AppLocalizations.of(context)!;
      return SelectableText(
        l10n.studioDesignDebugNoDetailsAvailable,
        style: textTheme.bodySmall?.copyWith(
          color: tokens.textSecondary,
          fontFamily: 'monospace',
        ),
      );
    }

    return SelectableText(
      snapshot.fullText,
      style: textTheme.bodySmall?.copyWith(
        color: tokens.textSecondary,
        fontFamily: 'monospace',
      ),
    );
  }
}
