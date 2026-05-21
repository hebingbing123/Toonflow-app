part of '../section.dart';

/// Export settings dialog for configuring video export parameters
///
/// This dialog allows users to:
/// - Select export format (MP4/MOV/WebM)
/// - Configure quality settings (resolution, bitrate, framerate)
/// - View estimated file size
///
/// **Validates: Requirements 15, 16**
extension _ShortVideoSpaceSectionExportSettingsDialog
    on _ShortVideoSpaceSectionState {
  /// Opens the export settings dialog
  ///
  /// Returns an [ExportSettings] object if user confirms, null if cancelled
  // ignore: unused_element
  Future<ExportSettings?> _openExportSettingsDialog({
    required BuildContext context,
    ExportSettings? initialSettings,
    int? estimatedDurationSeconds,
  }) async {
    return showStudioDialog<ExportSettings>(
      context: context,
      builder: (dialogContext) {
        return ExportSettingsDialog(
          initialSettings: initialSettings,
          estimatedDurationSeconds: estimatedDurationSeconds,
        );
      },
    );
  }
}

const List<String> kSupportedExportFormats = <String>[
  'mp4',
  'mov',
  'webm',
];

const List<String> kSupportedResolutions = <String>[
  '1080p',
  '720p',
  '480p',
  '360p',
];

const List<String> kSupportedBitrates = <String>[
  'high',
  'medium',
  'low',
];

const List<int> kSupportedFramerates = <int>[
  60,
  30,
  24,
];

String getFormatDisplayName(AppLocalizations l10n, String format) {
  switch (format) {
    case 'mp4':
      return l10n.shortVideoExportFormatMp4;
    case 'mov':
      return l10n.shortVideoExportFormatMov;
    case 'webm':
      return l10n.shortVideoExportFormatWebm;
    default:
      return format.toUpperCase();
  }
}

String getResolutionDisplayName(AppLocalizations l10n, String resolution) {
  switch (resolution) {
    case '1080p':
      return l10n.shortVideoExportResolution1080p;
    case '720p':
      return l10n.shortVideoExportResolution720p;
    case '480p':
      return l10n.shortVideoExportResolution480p;
    case '360p':
      return l10n.shortVideoExportResolution360p;
    default:
      return resolution;
  }
}

String getBitrateDisplayName(AppLocalizations l10n, String bitrate) {
  switch (bitrate) {
    case 'high':
      return l10n.shortVideoExportBitrateHigh;
    case 'medium':
      return l10n.shortVideoExportBitrateMedium;
    case 'low':
      return l10n.shortVideoExportBitrateLow;
    default:
      return bitrate;
  }
}

int getBitrateValue(String bitrate) {
  const bitrateValues = <String, int>{
    'high': 8000,
    'medium': 4000,
    'low': 2000,
  };
  return bitrateValues[bitrate] ?? 4000;
}

class ExportSettingsDialog extends StatefulWidget {
  const ExportSettingsDialog({
    super.key,
    this.initialSettings,
    this.estimatedDurationSeconds,
  });

  final ExportSettings? initialSettings;
  final int? estimatedDurationSeconds;

  @override
  State<ExportSettingsDialog> createState() => _ExportSettingsDialogState();
}

class _ExportSettingsDialogState extends State<ExportSettingsDialog> {
  late String _selectedFormat;
  late String _selectedResolution;
  late String _selectedBitrate;
  late int _selectedFramerate;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings ?? const ExportSettings();
    _selectedFormat = settings.format;
    _selectedResolution = settings.resolution;
    _selectedBitrate = settings.bitrate;
    _selectedFramerate = settings.framerate;
  }

  /// Calculate estimated file size in MB
  double _calculateEstimatedFileSize() {
    final durationSeconds = widget.estimatedDurationSeconds ?? 60;
    final bitrateKbps = getBitrateValue(_selectedBitrate);
    // File size (MB) = (bitrate in kbps × duration in seconds) / (8 × 1024)
    final fileSizeMB = (bitrateKbps * durationSeconds) / (8 * 1024);
    return fileSizeMB;
  }

  String _formatFileSize(AppLocalizations l10n, double sizeMB) {
    if (sizeMB < 1) {
      return l10n.shortVideoSpaceDialogExportHistoryFileSizeKB(
        (sizeMB * 1024).toStringAsFixed(0),
      );
    }
    if (sizeMB < 1024) {
      return l10n.shortVideoSpaceDialogExportHistoryFileSizeMB(
        sizeMB.toStringAsFixed(1),
      );
    }
    return l10n.shortVideoSpaceDialogExportHistoryFileSizeGB(
      (sizeMB / 1024).toStringAsFixed(2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final tokens = StudioTokens.of(context);
    final estimatedSize = _calculateEstimatedFileSize();

    return StudioAlertDialog(
      scrollable: false,
      maxWidth: 560,
      title: Text(l10n.shortVideoExportSettingsTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shortVideoExportSettingsFormatLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StudioDropdownButtonFormField<String>(
                initialValue: _selectedFormat,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: kSupportedExportFormats
                    .map(
                      (format) => DropdownMenuItem(
                        value: format,
                        child: Text(getFormatDisplayName(l10n, format)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedFormat = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.shortVideoExportSettingsResolutionLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StudioDropdownButtonFormField<String>(
                initialValue: _selectedResolution,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: kSupportedResolutions
                    .map(
                      (resolution) => DropdownMenuItem(
                        value: resolution,
                        child: Text(getResolutionDisplayName(l10n, resolution)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedResolution = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.shortVideoExportSettingsBitrateLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StudioDropdownButtonFormField<String>(
                initialValue: _selectedBitrate,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: kSupportedBitrates
                    .map(
                      (bitrate) => DropdownMenuItem(
                        value: bitrate,
                        child: Text(getBitrateDisplayName(l10n, bitrate)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedBitrate = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.shortVideoExportSettingsFramerateLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StudioDropdownButtonFormField<int>(
                initialValue: _selectedFramerate,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: kSupportedFramerates
                    .map(
                      (framerate) => DropdownMenuItem(
                        value: framerate,
                        child: Text(l10n.shortVideoExportSettingsFramerateOption(framerate)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedFramerate = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: StudioTokens.of(context).primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.storage_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.shortVideoExportSettingsEstimatedSize,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatFileSize(l10n, estimatedSize),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    if (widget.estimatedDurationSeconds != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.shortVideoExportSettingsBasedOnDuration(
                          widget.estimatedDurationSeconds!,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.shortVideoExportSettingsExportTimeHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.notificationsActionCancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              ExportSettings(
                format: _selectedFormat,
                resolution: _selectedResolution,
                bitrate: _selectedBitrate,
                framerate: _selectedFramerate,
              ),
            );
          },
          child: Text(l10n.shortVideoExportSettingsStartExport),
        ),
      ],
    );
  }
}

/// Export settings data class
///
/// Holds video export configuration parameters
class ExportSettings {
  const ExportSettings({
    this.format = 'mp4',
    this.resolution = '1080p',
    this.bitrate = 'medium',
    this.framerate = 30,
  });

  final String format;
  final String resolution;
  final String bitrate;
  final int framerate;

  ExportSettings copyWith({
    String? format,
    String? resolution,
    String? bitrate,
    int? framerate,
  }) {
    return ExportSettings(
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
      bitrate: bitrate ?? this.bitrate,
      framerate: framerate ?? this.framerate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'resolution': resolution,
      'bitrate': bitrate,
      'framerate': framerate,
    };
  }

  factory ExportSettings.fromJson(Map<String, dynamic> json) {
    return ExportSettings(
      format: json['format'] as String? ?? 'mp4',
      resolution: json['resolution'] as String? ?? '1080p',
      bitrate: json['bitrate'] as String? ?? 'medium',
      framerate: (json['framerate'] as num?)?.toInt() ?? 30,
    );
  }

  @override
  String toString() {
    return 'ExportSettings(format: $format, resolution: $resolution, '
        'bitrate: $bitrate, framerate: $framerate FPS)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExportSettings &&
        other.format == format &&
        other.resolution == resolution &&
        other.bitrate == bitrate &&
        other.framerate == framerate;
  }

  @override
  int get hashCode {
    return Object.hash(format, resolution, bitrate, framerate);
  }
}
