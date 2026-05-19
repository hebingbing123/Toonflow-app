import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/openflow_brand.dart';
import 'package:openflow_app/design_system/glass.dart';
import 'package:openflow_app/design_system/ix/studio_job_tray.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/global_search/global_search_bar.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_app_bar_actions.dart';
import 'package:openflow_app/rust_api/search/api.dart';
import 'package:openflow_app/shell/navigation_controller.dart';
import 'package:openflow_app/shell/platform_short_drama_pipeline_strip.dart';

/// Product shell chrome strip (app bar + pipeline) for desktop layout goldens.
Widget buildProductShellChromePreview() {
  return Builder(
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final tokens = StudioTokens.of(context);
      return ColoredBox(
        color: tokens.bgBase,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              StudioGlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            const OpenFlowBrandMark(
                              size: 36,
                              borderRadius: 10,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'OpenFlow',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '项目总览',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const StudioJobTray(),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: GlobalSearchBar(
                          accessToken: 'token',
                          currentWorkspaceName: '默认工作区',
                          currentWorkspaceId: 'workspace-1',
                          onNavigateToResults:
                              (
                                query, {
                                initialResultTypes = const <ResultType>[],
                                initialTimeFrom,
                                initialTimeTo,
                              }) {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      StudioAppBarActions(
                        selectedPane: ProductWorkspacePane.projects,
                        unreadNotifications: 5,
                        onSelectPane: (_) {},
                      ),
                      IconButton(
                        tooltip: l10n.productShellMoreMenu,
                        onPressed: () {},
                        icon: const Icon(Icons.apps_outlined),
                      ),
                      PopupMenuButton<String>(
                        tooltip: l10n.localeSectionTitle,
                        icon: const Icon(Icons.language_outlined),
                        itemBuilder: (ctx) => const <PopupMenuEntry<String>>[],
                      ),
                      IconButton(
                        tooltip: l10n.authSignOut,
                        onPressed: () {},
                        icon: const Icon(Icons.logout_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PlatformShortDramaPipelineStrip(
                onSelectPane: (_) {},
                jobsPaneEnabled: true,
                qualityPaneEnabled: true,
              ),
            ],
          ),
        ),
      );
    },
  );
}
