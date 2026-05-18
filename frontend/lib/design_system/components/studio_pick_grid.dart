import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'studio_media_card.dart';

/// Candidate pick grid with keyboard navigation (Wave 4).
class StudioPickGrid extends StatefulWidget {
  const StudioPickGrid({
    super.key,
    required this.candidateUrls,
    required this.onSelected,
    this.selectedIndex = 0,
  });

  final List<String> candidateUrls;
  final ValueChanged<int> onSelected;
  final int selectedIndex;

  @override
  State<StudioPickGrid> createState() => _StudioPickGridState();
}

class _StudioPickGridState extends State<StudioPickGrid> {
  late int _index = widget.selectedIndex.clamp(0, widget.candidateUrls.length - 1);

  @override
  Widget build(BuildContext context) {
    if (widget.candidateUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          setState(() => _index = (_index - 1).clamp(0, widget.candidateUrls.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(() => _index = (_index + 1).clamp(0, widget.candidateUrls.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onSelected(_index);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 16 / 9,
        ),
        itemCount: widget.candidateUrls.length,
        itemBuilder: (context, i) {
          final selected = i == _index;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
              border: Border.all(
                color: selected
                    ? StudioTokens.of(context).primary
                    : StudioTokens.of(context).borderSubtle,
                width: selected ? 2 : 1,
              ),
            ),
            child: StudioMediaCard(
              imageUrl: widget.candidateUrls[i],
              onTap: () {
                setState(() => _index = i);
                widget.onSelected(i);
              },
            ),
          );
        },
      ),
    );
  }
}
