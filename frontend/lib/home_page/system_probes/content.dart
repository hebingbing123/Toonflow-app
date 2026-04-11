// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageSystemProbesContent on _HomePageState {
  Future<void> _callPromptsProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingPromptsProbe = true;
      _error = null;
      _promptsProbeBody = null;
    });
    try {
      final rows = await fetchPromptsV1(token);
      if (!mounted) return;
      final types = rows.map((r) => r.type).join(', ');
      final totalChars = rows.fold<int>(0, (a, r) => a + r.data.length);
      var roundtrip = '';
      final r1s = rows.where((r) => r.id == 1);
      if (r1s.isNotEmpty) {
        final r1 = r1s.first;
        try {
          await fetchPromptByNumericIdV1(token, 1);
          final patched = await patchPromptByNumericIdV1(token, 1, r1.data);
          roundtrip = ' · GET/1+PATCH/1 ok (data_len=${patched.data.length})';
        } on RustApiException catch (e) {
          roundtrip = ' · GET/1+PATCH/1 -> ${e.statusCode}';
        }
      }
      setState(() {
        _promptsProbeBody =
            'count=${rows.length} · types=$types · data_chars_total=$totalChars$roundtrip';
        _loadingPromptsProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingPromptsProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingPromptsProbe = false;
      });
    }
  }

  Future<void> _callVisualManualProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingVisualManualProbe = true;
      _error = null;
      _visualManualProbeBody = null;
    });
    try {
      final vm = await fetchVisualManualV1(token);
      final vmPost = await fetchVisualManualPostV1(token);
      if (!mounted) return;
      if (vm.styles.length != vmPost.styles.length) {
        setState(() {
          _error =
              'visual-manual GET/POST style count mismatch: ${vm.styles.length} vs ${vmPost.styles.length}';
          _loadingVisualManualProbe = false;
        });
        return;
      }
      var totalChars = 0;
      var totalImages = 0;
      for (final s in vm.styles) {
        totalImages += s.image.length;
        for (final e in s.data) {
          totalChars += e.data.length;
        }
      }
      final sample = vm.styles.take(4).map((s) => s.name).join(', ');
      setState(() {
        _visualManualProbeBody =
            'GET+POST styles=${vm.styles.length} · slots_data_chars_total=$totalChars · image_paths=$totalImages'
            '${sample.isEmpty ? '' : ' · sample: $sample'}';
        _loadingVisualManualProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingVisualManualProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingVisualManualProbe = false;
      });
    }
  }

  Future<void> _callDirectorManualProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingDirectorManualProbe = true;
      _error = null;
      _directorManualProbeBody = null;
    });
    try {
      final list = await postProjectQueryDirectorManual(token);
      if (!mounted) return;
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
          .map((r) => '${r.directorManual}:${r.name}')
          .join(', ');
      setState(() {
        _directorManualProbeBody =
            'folders=${list.data.length} · slot_data_chars=$slotChars · '
            'image_paths=$imagePaths'
            '${sample.isEmpty ? '' : ' · sample: $sample'}';
        _loadingDirectorManualProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingDirectorManualProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingDirectorManualProbe = false;
      });
    }
  }

  Future<void> _callSkillsBinaryProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingSkillsBinaryProbe = true;
      _error = null;
      _skillsBinaryProbeBody = null;
    });
    try {
      const path = '_smoke/binary_probe.png';
      final bytes = await fetchSkillsBinaryV1(token, path);
      if (!mounted) return;
      final head = bytes.length >= 4 ? bytes.sublist(0, 4) : bytes;
      final magicOk =
          head.length == 4 &&
          head[0] == 0x89 &&
          head[1] == 0x50 &&
          head[2] == 0x4e &&
          head[3] == 0x47;
      setState(() {
        _skillsBinaryProbeBody =
            'path=$path · bytes=${bytes.length} · png_magic=$magicOk';
        _loadingSkillsBinaryProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsBinaryProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsBinaryProbe = false;
      });
    }
  }

  Future<void> _callTextModelDefault() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingTextModelDefault = true;
      _error = null;
      _textModelDefaultBody = null;
    });
    try {
      final before = await fetchTextModelDefaultV1(token);
      final textModels = await fetchModelsCatalog(token, typeFilter: 'text');
      final alternative = textModels
          .map((m) => m.value)
          .where((id) => id != before.defaultModelId)
          .cast<String?>()
          .firstWhere((id) => id != null, orElse: () => null);
      TextModelDefaultV1? patched;
      if (alternative != null) {
        patched = await patchTextModelDefaultV1(token, modelId: alternative);
      }
      final reset = await patchTextModelDefaultV1(token, modelId: null);
      final after = await fetchTextModelDefaultV1(token);
      if (!mounted) return;
      if (patched != null && patched.defaultModelId != alternative) {
        setState(() {
          _error =
              'PATCH text-default expected $alternative, got ${patched!.defaultModelId}';
          _loadingTextModelDefault = false;
        });
        return;
      }
      if (after.defaultModelId != reset.defaultModelId) {
        setState(() {
          _error =
              'text-default reset mismatch: fetch=${after.defaultModelId} reset=${reset.defaultModelId}';
          _loadingTextModelDefault = false;
        });
        return;
      }
      setState(() {
        _textModelDefaultBody =
            'stub=${before.stubPlaceholder} · GET=${before.defaultModelId}'
            '${patched == null ? ' · PATCH skipped (single text model)' : ' · PATCH=$alternative'}'
            ' · reset=${reset.defaultModelId}';
        _loadingTextModelDefault = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTextModelDefault = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTextModelDefault = false;
      });
    }
  }

  Future<void> _callModelDetail() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingModelDetail = true;
      _error = null;
      _modelDetailBody = null;
    });
    try {
      final d = await fetchModelDetail(token, modelId: '1:gpt-4o-mini');
      if (!mounted) return;
      setState(() {
        _modelDetailBody =
            '${d.name} (${d.modelName}) type=${d.type} · vendor ${d.vendorName} [${d.vendorId}]';
        _loadingModelDetail = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingModelDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingModelDetail = false;
      });
    }
  }
}
