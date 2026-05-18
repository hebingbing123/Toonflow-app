import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';

/// Huobao-style single-episode compact console (Wave 4b).
class EpisodeConsolePage extends StatefulWidget {
  const EpisodeConsolePage({
    super.key,
    required this.projectNumericId,
    required this.scriptNumericId,
    required this.deliverChild,
    required this.onOpenFullStudio,
  });

  final int projectNumericId;
  final int scriptNumericId;
  final Widget deliverChild;
  final VoidCallback onOpenFullStudio;

  @override
  State<EpisodeConsolePage> createState() => _EpisodeConsolePageState();
}

class _EpisodeConsolePageState extends State<EpisodeConsolePage> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/projects/${widget.projectNumericId}/deliver');
            }
          },
        ),
        title: Text(
          l10n.studioEpisodeConsoleTitle(widget.scriptNumericId),
          style: studioProjectTitleStyle(context),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: widget.onOpenFullStudio,
            child: Text(l10n.studioOpenFullStudio),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: List<Widget>.generate(8, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l10n.studioStoryboardShotLabel(i + 1)),
                    selected: i == 0,
                    onSelected: (_) {},
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: ColoredBox(
                    color: tokens.bgInset,
                    child: Center(
                      child: Text(
                        l10n.studioEpisodePreviewPlaceholder,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: tokens.borderSubtle),
                Expanded(
                  flex: 2,
                  child: DefaultTabController(
                    length: 5,
                    child: Column(
                      children: <Widget>[
                        TabBar(
                          isScrollable: true,
                          onTap: (i) => setState(() => _tab = i),
                          tabs: <Tab>[
                            Tab(text: l10n.studioEpisodeTabVoice),
                            Tab(text: l10n.studioEpisodeTabVisual),
                            Tab(text: l10n.studioEpisodeTabVideo),
                            Tab(text: l10n.studioEpisodeTabAssemble),
                            Tab(text: l10n.studioEpisodeTabExport),
                          ],
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _tab,
                            children: <Widget>[
                              _placeholder(l10n.studioEpisodeTabVoice),
                              _placeholder(l10n.studioEpisodeTabVisual),
                              _placeholder(l10n.studioEpisodeTabVideo),
                              widget.deliverChild,
                              _placeholder(l10n.studioEpisodeTabExport),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String label) {
    return Center(child: Text(label));
  }
}
