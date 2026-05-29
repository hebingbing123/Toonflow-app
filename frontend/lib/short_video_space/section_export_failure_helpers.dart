part of 'section.dart';

/// Scroll/focus target when opening short-video space from studio deliver.
enum ShortVideoSpaceInitialFocus { none, assembly }

String? _classifyExportFailurePhase(String? stage, String? code) {
  final normalizedStage = (stage ?? '').trim().toLowerCase();
  if (normalizedStage.isNotEmpty) {
    return normalizedStage;
  }
  switch ((code ?? '').trim().toLowerCase()) {
    case 'payload_missing_source_url':
    case 'payload_source_url_empty':
    case 'video_download_http':
    case 'video_download_stream':
    case 'video_content_length_exceeds_limit':
    case 'video_body_exceeds_limit':
      return 'loading_assets';
    case 'payload_format_invalid':
    case 'video_format_mismatch_no_transcode':
    case 'export_provider_failed':
      return 'encoding';
    case 'local_export_dir_unset':
    case 'export_directory_create_failed':
    case 'export_file_persist_failed':
      return 'finalizing';
    default:
      return null;
  }
}

ShortVideoLatestExportAction recommendExportFailureAction(
  String? failurePhaseKey,
  String? failureCode,
) {
  final code = (failureCode ?? '').trim().toLowerCase();
  final phase = (failurePhaseKey ?? '').trim().toLowerCase();
  if (code == 'payload_format_invalid' ||
      code == 'payload_missing_source_url' ||
      code == 'payload_source_url_empty' ||
      code == 'video_download_http' ||
      code == 'video_download_stream' ||
      code == 'video_content_length_exceeds_limit' ||
      code == 'video_body_exceeds_limit' ||
      phase == 'loading_assets') {
    return ShortVideoLatestExportAction.openProductionWorkspace;
  }
  return ShortVideoLatestExportAction.retry;
}
