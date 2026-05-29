import 'dart:async' show unawaited;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../components/studio_surfaces.dart';
import '../components/studio_text_styles.dart';
import '../tokens.dart';
import 'studio_native_file_drop.dart';

/// Drop/browse affordance for file uploads (browse via [FilePicker], OS drop on desktop).
class StudioFileDropZone extends StatefulWidget {
  const StudioFileDropZone({
    super.key,
    required this.onFilesSelected,
    this.label,
    this.hint,
    this.allowedExtensions,
    this.allowMultiple = true,
    this.enabled = true,
    this.maxHeight = 160,
  });

  final ValueChanged<List<PlatformFile>> onFilesSelected;
  final String? label;
  final String? hint;
  final List<String>? allowedExtensions;
  final bool allowMultiple;
  final bool enabled;
  final double maxHeight;

  @override
  State<StudioFileDropZone> createState() => _StudioFileDropZoneState();
}

class _StudioFileDropZoneState extends State<StudioFileDropZone> {
  bool _hovering = false;
  bool _picking = false;

  Future<void> _browse() async {
    if (!widget.enabled || _picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: widget.allowMultiple,
        type: widget.allowedExtensions == null
            ? FileType.any
            : FileType.custom,
        allowedExtensions: widget.allowedExtensions,
      );
      if (result != null && result.files.isNotEmpty) {
        widget.onFilesSelected(result.files);
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  Future<void> _handleNativePaths(List<String> paths) async {
    if (!widget.enabled || paths.isEmpty) {
      return;
    }
    final files = <PlatformFile>[];
    for (final path in paths) {
      files.add(PlatformFile(name: path.split('/').last, path: path, size: 0));
    }
    widget.onFilesSelected(files);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final effectiveLabel = widget.label ?? l10n.studioDesignFileDropZoneLabel;
    final borderColor = _hovering ? tokens.primary : tokens.borderSubtle;
    final body = MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _hovering = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovering = false) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? _browse : null,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            decoration: studioInsetPanelDecoration(context).copyWith(
              border: Border.all(
                color: borderColor,
                width: _hovering ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(StudioSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    color: _hovering ? tokens.primary : tokens.textMuted,
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  Text(
                    effectiveLabel,
                    textAlign: TextAlign.center,
                    style: studioControlLabelStyle(context),
                  ),
                  if (widget.hint != null) ...[
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      widget.hint!,
                      textAlign: TextAlign.center,
                      style: studioHintStyle(context),
                    ),
                  ],
                  if (_picking) ...[
                    const SizedBox(height: StudioSpacing.sm),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return studioWrapNativeFileDrop(
      enabled: widget.enabled,
      onPathsDropped: (paths) => unawaited(_handleNativePaths(paths)),
      child: body,
    );
  }
}
