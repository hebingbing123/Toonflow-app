// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageSkillsHarnessFiles on _HomePageState {
  Future<void> _previewSkillFile() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPreview = true;
      _error = null;
    });
    try {
      final r = await fetchSkillContent(token, path);
      if (!mounted) return;
      setState(() => _loadingSkillPreview = false);
      final text = r.content.length > 12000
          ? '${r.content.substring(0, 12000)}…\n\n(truncated)'
          : r.content;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(r.path),
          content: SingleChildScrollView(
            child: SelectableText(
              text,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPreview = false;
      });
    }
  }

  Future<void> _putSkillProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPut = true;
      _error = null;
      _skillMutationLine = null;
    });
    try {
      final r = await saveSkillContent(token, path, _skillContentCtrl.text);
      if (!mounted) return;
      setState(() {
        _loadingSkillPut = false;
        _skillMutationLine =
            'PUT 200: ${r.path} (${r.content.length} chars written)';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPut = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPut = false;
      });
    }
  }

  Future<void> _postSkillProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPost = true;
      _error = null;
      _skillMutationLine = null;
    });
    try {
      final r = await createSkillContent(token, path, _skillContentCtrl.text);
      if (!mounted) return;
      setState(() {
        _loadingSkillPost = false;
        _skillMutationLine =
            'POST 201: ${r.path} (${r.content.length} chars written)';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPost = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPost = false;
      });
    }
  }

  Future<void> _deleteSkillProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillDelete = true;
      _error = null;
      _skillMutationLine = null;
    });
    try {
      await deleteSkillContent(token, path);
      if (!mounted) return;
      setState(() {
        _loadingSkillDelete = false;
        _skillMutationLine = 'DELETE 204: $path';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillDelete = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillDelete = false;
      });
    }
  }
}
