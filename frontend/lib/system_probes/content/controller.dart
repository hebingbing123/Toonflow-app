import 'package:flutter/material.dart';

import '../../rust_api.dart';

typedef ContentProbesAccessTokenProvider = String? Function();
typedef ContentProbesErrorSink = void Function(String? error);

class ContentProbesController extends ChangeNotifier {
  ContentProbesController({
    required ContentProbesAccessTokenProvider accessTokenProvider,
    required ContentProbesErrorSink onErrorChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged;

  final ContentProbesAccessTokenProvider _accessTokenProvider;
  final ContentProbesErrorSink _onErrorChanged;

  bool loadingPromptsProbe = false;
  bool loadingVisualManualProbe = false;
  bool loadingDirectorManualProbe = false;
  bool loadingSkillsBinaryProbe = false;
  bool loadingTextModelDefault = false;
  bool loadingModelDetail = false;
  String? promptsProbeBody;
  String? visualManualProbeBody;
  String? directorManualProbeBody;
  String? skillsBinaryProbeBody;
  String? textModelDefaultBody;
  String? modelDetailBody;

  String? get _accessToken => _accessTokenProvider();

  void reset() {
    loadingPromptsProbe = false;
    loadingVisualManualProbe = false;
    loadingDirectorManualProbe = false;
    loadingSkillsBinaryProbe = false;
    loadingTextModelDefault = false;
    loadingModelDetail = false;
    promptsProbeBody = null;
    visualManualProbeBody = null;
    directorManualProbeBody = null;
    skillsBinaryProbeBody = null;
    textModelDefaultBody = null;
    modelDetailBody = null;
    notifyListeners();
  }

  Future<void> callPromptsProbe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingPromptsProbe = true;
    promptsProbeBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final rows = await fetchPromptsV1(token);
      final types = rows.map((row) => row.type).join(', ');
      final totalChars = rows.fold<int>(0, (sum, row) => sum + row.data.length);
      var roundtrip = '';
      final firstPrompt = rows.where((row) => row.id == 1).firstOrNull;
      if (firstPrompt != null) {
        try {
          await fetchPromptByNumericIdV1(token, 1);
          final patched = await patchPromptByNumericIdV1(
            token,
            1,
            firstPrompt.data,
          );
          roundtrip = ' · GET/1+PATCH/1 ok (data_len=${patched.data.length})';
        } on RustApiException catch (error) {
          roundtrip = ' · GET/1+PATCH/1 -> ${error.statusCode}';
        }
      }
      promptsProbeBody =
          'count=${rows.length} · types=$types · data_chars_total=$totalChars$roundtrip';
    } catch (error) {
      reportRustOrDescribeApiError(error, onErrorChanged: _onErrorChanged);
    } finally {
      loadingPromptsProbe = false;
      notifyListeners();
    }
  }

  Future<void> callVisualManualProbe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingVisualManualProbe = true;
    visualManualProbeBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final manual = await fetchVisualManualV1(token);
      final manualPost = await fetchVisualManualPostV1(token);
      if (manual.styles.length != manualPost.styles.length) {
        throw StateError(
          'visual-manual GET/POST style count mismatch: '
          '${manual.styles.length} vs ${manualPost.styles.length}',
        );
      }
      var totalChars = 0;
      var totalImages = 0;
      for (final style in manual.styles) {
        totalImages += style.image.length;
        for (final entry in style.data) {
          totalChars += entry.data.length;
        }
      }
      final sample = manual.styles
          .take(4)
          .map((style) => style.name)
          .join(', ');
      visualManualProbeBody =
          'GET+POST styles=${manual.styles.length} · slots_data_chars_total=$totalChars · image_paths=$totalImages'
          '${sample.isEmpty ? '' : ' · sample: $sample'}';
    } catch (error) {
      reportRustOrDescribeApiError(error, onErrorChanged: _onErrorChanged);
    } finally {
      loadingVisualManualProbe = false;
      notifyListeners();
    }
  }

  Future<void> callDirectorManualProbe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingDirectorManualProbe = true;
    directorManualProbeBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final list = await postProjectQueryDirectorManual(token);
      var slotChars = 0;
      var imagePaths = 0;
      for (final row in list.data) {
        imagePaths += row.image.length;
        for (final slot in row.data) {
          slotChars += slot.data.length;
        }
      }
      final sample = list.data
          .take(3)
          .map((row) => '${row.directorManual}:${row.name}')
          .join(', ');
      directorManualProbeBody =
          'folders=${list.data.length} · slot_data_chars=$slotChars · image_paths=$imagePaths'
          '${sample.isEmpty ? '' : ' · sample: $sample'}';
    } catch (error) {
      reportRustOrDescribeApiError(error, onErrorChanged: _onErrorChanged);
    } finally {
      loadingDirectorManualProbe = false;
      notifyListeners();
    }
  }

  Future<void> callSkillsBinaryProbe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingSkillsBinaryProbe = true;
    skillsBinaryProbeBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      const path = '_smoke/binary_probe.png';
      final bytes = await fetchSkillsBinaryV1(token, path);
      final head = bytes.length >= 4 ? bytes.sublist(0, 4) : bytes;
      final magicOk =
          head.length == 4 &&
          head[0] == 0x89 &&
          head[1] == 0x50 &&
          head[2] == 0x4e &&
          head[3] == 0x47;
      skillsBinaryProbeBody =
          'path=$path · bytes=${bytes.length} · png_magic=$magicOk';
    } catch (error) {
      reportRustOrDescribeApiError(error, onErrorChanged: _onErrorChanged);
    } finally {
      loadingSkillsBinaryProbe = false;
      notifyListeners();
    }
  }

  Future<void> callTextModelDefault() async {
    final token = _accessToken;
    if (token == null) return;
    loadingTextModelDefault = true;
    textModelDefaultBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final before = await fetchTextModelDefaultV1(token);
      final textModels = await fetchModelsCatalog(token, typeFilter: 'text');
      final alternative = textModels
          .map((model) => model.value)
          .where((id) => id != before.defaultModelId)
          .cast<String?>()
          .firstWhere((id) => id != null, orElse: () => null);
      TextModelDefaultV1? patched;
      if (alternative != null) {
        patched = await patchTextModelDefaultV1(token, modelId: alternative);
      }
      final reset = await patchTextModelDefaultV1(token, modelId: null);
      final after = await fetchTextModelDefaultV1(token);
      if (patched != null && patched.defaultModelId != alternative) {
        throw StateError(
          'PATCH text-default expected $alternative, got ${patched.defaultModelId}',
        );
      }
      if (after.defaultModelId != reset.defaultModelId) {
        throw StateError(
          'text-default reset mismatch: '
          'fetch=${after.defaultModelId} reset=${reset.defaultModelId}',
        );
      }
      textModelDefaultBody =
          'stub=${before.stubPlaceholder} · GET=${before.defaultModelId}'
          '${patched == null ? ' · PATCH skipped (single text model)' : ' · PATCH=$alternative'}'
          ' · reset=${reset.defaultModelId}';
    } catch (error) {
      reportRustOrDescribeApiError(error, onErrorChanged: _onErrorChanged);
    } finally {
      loadingTextModelDefault = false;
      notifyListeners();
    }
  }

  Future<void> callModelDetail() async {
    final token = _accessToken;
    if (token == null) return;
    loadingModelDetail = true;
    modelDetailBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final detail = await fetchModelDetail(token, modelId: '1:gpt-4o-mini');
      modelDetailBody =
          '${detail.name} (${detail.modelName}) type=${detail.type} · vendor ${detail.vendorName} [${detail.vendorId}]';
    } catch (error) {
      reportRustOrDescribeApiError(error, onErrorChanged: _onErrorChanged);
    } finally {
      loadingModelDetail = false;
      notifyListeners();
    }
  }
}
