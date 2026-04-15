part of 'controller.dart';

extension SkillsHarnessFileController on SkillsHarnessController {
  Future<void> previewSkillFile(BuildContext context) async {
    final token = _accessToken;
    if (token == null) return;
    final path = skillPathController.text.trim();
    if (path.isEmpty) return;
    loadingSkillPreview = true;
    _setError(null);
    _publish();
    try {
      final r = await fetchSkillContent(token, path);
      loadingSkillPreview = false;
      _publish();
      if (!context.mounted) return;
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
      _setError(e.toString());
      loadingSkillPreview = false;
      _publish();
    } catch (e) {
      _setError(e.toString());
      loadingSkillPreview = false;
      _publish();
    }
  }

  Future<void> putSkillProbe() async {
    final token = _accessToken;
    if (token == null) return;
    final path = skillPathController.text.trim();
    if (path.isEmpty) return;
    loadingSkillPut = true;
    _setError(null);
    skillMutationLine = null;
    _publish();
    try {
      final r = await saveSkillContent(
        token,
        path,
        skillContentController.text,
      );
      loadingSkillPut = false;
      skillMutationLine =
          'PUT 200: ${r.path} (${r.content.length} chars written)';
      _publish();
    } on RustApiException catch (e) {
      _setError(e.toString());
      loadingSkillPut = false;
      _publish();
    } catch (e) {
      _setError(e.toString());
      loadingSkillPut = false;
      _publish();
    }
  }

  Future<void> postSkillProbe() async {
    final token = _accessToken;
    if (token == null) return;
    final path = skillPathController.text.trim();
    if (path.isEmpty) return;
    loadingSkillPost = true;
    _setError(null);
    skillMutationLine = null;
    _publish();
    try {
      final r = await createSkillContent(
        token,
        path,
        skillContentController.text,
      );
      loadingSkillPost = false;
      skillMutationLine =
          'POST 201: ${r.path} (${r.content.length} chars written)';
      _publish();
    } on RustApiException catch (e) {
      _setError(e.toString());
      loadingSkillPost = false;
      _publish();
    } catch (e) {
      _setError(e.toString());
      loadingSkillPost = false;
      _publish();
    }
  }

  Future<void> deleteSkillProbe() async {
    final token = _accessToken;
    if (token == null) return;
    final path = skillPathController.text.trim();
    if (path.isEmpty) return;
    loadingSkillDelete = true;
    _setError(null);
    skillMutationLine = null;
    _publish();
    try {
      await deleteSkillContent(token, path);
      loadingSkillDelete = false;
      skillMutationLine = 'DELETE 204: $path';
      _publish();
    } on RustApiException catch (e) {
      _setError(e.toString());
      loadingSkillDelete = false;
      _publish();
    } catch (e) {
      _setError(e.toString());
      loadingSkillDelete = false;
      _publish();
    }
  }
}
