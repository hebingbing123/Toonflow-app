import 'package:flutter/material.dart';

import '../../rust_api.dart';

Future<Map<String, dynamic>?> showCreateProjectDialog(BuildContext context) {
  final nameController = TextEditingController();
  final introController = TextEditingController();
  final premiseController = TextEditingController();
  final audienceController = TextEditingController();
  final toneController = TextEditingController();
  final hookController = TextEditingController();
  final visualController = TextEditingController();
  final brandNameController = TextEditingController();
  final brandPromiseController = TextEditingController();
  final motifsController = TextEditingController();
  final forbiddenController = TextEditingController();
  final continuityController = TextEditingController();

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('新建项目'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '项目名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: introController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '项目简介'),
                ),
                const SizedBox(height: 16),
                Text(
                  '项目立项',
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: premiseController,
                  decoration: const InputDecoration(labelText: 'Premise'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: audienceController,
                  decoration: const InputDecoration(
                    labelText: 'Target audience',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: toneController,
                  decoration: const InputDecoration(
                    labelText: 'Emotional tone',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hookController,
                  decoration: const InputDecoration(labelText: 'Core hook'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: visualController,
                  decoration: const InputDecoration(
                    labelText: 'Visual direction',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '品牌圣经',
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: brandNameController,
                  decoration: const InputDecoration(labelText: 'Brand name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: brandPromiseController,
                  decoration: const InputDecoration(labelText: 'Brand promise'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: motifsController,
                  decoration: const InputDecoration(
                    labelText: 'Visual motifs (每行一个)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: forbiddenController,
                  decoration: const InputDecoration(
                    labelText: 'Forbidden elements (每行一个)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: continuityController,
                  decoration: const InputDecoration(
                    labelText: 'Continuity rules (每行一个)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              List<String> splitLines(String raw) => raw
                  .split('\n')
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .toList(growable: false);

              final brief = ProjectBriefDraft(
                premise: premiseController.text.trim(),
                targetAudience: audienceController.text.trim(),
                emotionalTone: toneController.text.trim(),
                coreHook: hookController.text.trim(),
                visualDirection: visualController.text.trim(),
              ).toJsonOrNull();

              final brandBible = BrandBibleDraft(
                brandName: brandNameController.text.trim(),
                brandPromise: brandPromiseController.text.trim(),
                visualMotifs: splitLines(motifsController.text),
                forbiddenElements: splitLines(forbiddenController.text),
                continuityRules: splitLines(continuityController.text),
              ).toJsonOrNull();

              final result = <String, dynamic>{};
              if (nameController.text.trim().isNotEmpty) {
                result['name'] = nameController.text.trim();
              }
              if (introController.text.trim().isNotEmpty) {
                result['intro'] = introController.text.trim();
              }
              if (brief != null) {
                result['projectBrief'] = brief;
              }
              if (brandBible != null) {
                result['brandBible'] = brandBible;
              }
              Navigator.of(dialogContext).pop(result);
            },
            child: const Text('创建'),
          ),
        ],
      );
    },
  ).whenComplete(() {
    nameController.dispose();
    introController.dispose();
    premiseController.dispose();
    audienceController.dispose();
    toneController.dispose();
    hookController.dispose();
    visualController.dispose();
    brandNameController.dispose();
    brandPromiseController.dispose();
    motifsController.dispose();
    forbiddenController.dispose();
    continuityController.dispose();
  });
}
