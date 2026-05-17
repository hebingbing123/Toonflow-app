part of '../../home_page.dart';

class _StoryboardCharacterSection extends StatelessWidget {
  const _StoryboardCharacterSection({
    required this.saving,
    required this.loadingCharacters,
    required this.characters,
    required this.selectedCharacterId,
    required this.onCharacterChanged,
    required this.onReloadCharacters,
  });

  final bool saving;
  final bool loadingCharacters;
  final List<ProjectCharacterV1> characters;
  final String? selectedCharacterId;
  final ValueChanged<String?> onCharacterChanged;
  final VoidCallback onReloadCharacters;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.storyboardWorkbenchCharacterLabel,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.storyboardWorkbenchCharacterReload,
                  onPressed: loadingCharacters || saving ? null : onReloadCharacters,
                  icon: loadingCharacters
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: ValueKey<String?>(
                _resolvedSelection(selectedCharacterId, characters),
              ),
              initialValue: _resolvedSelection(selectedCharacterId, characters),
              decoration: InputDecoration(
                labelText: l10n.storyboardWorkbenchCharacterDropdownLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.storyboardWorkbenchCharacterNone),
                ),
                ...characters.map(
                  (character) => DropdownMenuItem<String?>(
                    value: character.id,
                    child: Text(character.name),
                  ),
                ),
              ],
              onChanged: saving || loadingCharacters ? null : onCharacterChanged,
            ),
          ],
        ),
      ),
    );
  }

  String? _resolvedSelection(
    String? selectedId,
    List<ProjectCharacterV1> rows,
  ) {
    final trimmed = selectedId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    for (final row in rows) {
      if (row.id == trimmed) {
        return trimmed;
      }
    }
    return null;
  }
}
