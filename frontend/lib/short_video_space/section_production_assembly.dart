part of 'section.dart';

const _assemblyTerminalJobStatuses = <String>{
  'succeeded',
  'failed',
  'cancelled',
};

const _preAssemblyJobKind = 'short_video.pre_assembly';
const _exportJobKind = 'video.export';

class _AssemblyClipDeskOpEntry {
  const _AssemblyClipDeskOpEntry({
    required this.scriptNumericId,
    required this.storyboardId,
    required this.storyboardNumericId,
    required this.sbIndex,
    required this.selectedMediaUrl,
    required this.selectedMediaKind,
    required this.durationText,
    required this.subtitleText,
    required this.voiceoverScriptReady,
    required this.voiceoverAssetReady,
    required this.voiceoverState,
    required this.voiceoverAudioUrl,
    required this.voiceoverError,
  });

  final int scriptNumericId;
  final String storyboardId;
  final int storyboardNumericId;
  final int? sbIndex;
  final String selectedMediaUrl;
  final String selectedMediaKind;
  final String durationText;
  final String subtitleText;
  final bool voiceoverScriptReady;
  final bool voiceoverAssetReady;
  final String voiceoverState;
  final String voiceoverAudioUrl;
  final String voiceoverError;

  _AssemblyClipDeskOpEntry copyWith({
    String? selectedMediaUrl,
    String? durationText,
    String? subtitleText,
  }) {
    return _AssemblyClipDeskOpEntry(
      scriptNumericId: scriptNumericId,
      storyboardId: storyboardId,
      storyboardNumericId: storyboardNumericId,
      sbIndex: sbIndex,
      selectedMediaUrl: selectedMediaUrl ?? this.selectedMediaUrl,
      selectedMediaKind: selectedMediaKind,
      durationText: durationText ?? this.durationText,
      subtitleText: subtitleText ?? this.subtitleText,
      voiceoverScriptReady: voiceoverScriptReady,
      voiceoverAssetReady: voiceoverAssetReady,
      voiceoverState: voiceoverState,
      voiceoverAudioUrl: voiceoverAudioUrl,
      voiceoverError: voiceoverError,
    );
  }
}
