import 'package:flutter/material.dart';

import '../account/section.dart';
import '../account/controller.dart';
import '../api_keys/controller.dart';
import '../api_keys/section.dart';
import '../design_system/components/studio_text_styles.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import '../settings/model_pricing/model_pricing_catalog_view.dart';
import '../settings/plan_usage/plan_usage_section.dart';
import '../team_workspaces/section.dart';

/// Unified settings (Wave 5): account, plan & usage, API keys, workspaces.
class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({
    super.key,
    required this.accountController,
    required this.apiKeysController,
    required this.accessToken,
    required this.onAccountDeleted,
    required this.onWorkspaceContextChanged,
    this.currentWorkspaceId,
  });

  final AccountController accountController;
  final ApiKeysController apiKeysController;
  final String? accessToken;
  final Future<void> Function(AccountDeleteResponseV1) onAccountDeleted;
  final Future<void> Function() onWorkspaceContextChanged;
  final String? currentWorkspaceId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final subtitleStyle =
              studioSectionIntroStyle(context) ??
              TextStyle(color: theme.colorScheme.onSurfaceVariant);
          final tabView = TabBarView(
            children: <Widget>[
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: AccountSection(
                  controller: accountController,
                  onAccountDeleted: onAccountDeleted,
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: PlanUsageSection(accessToken: accessToken),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ModelPricingCatalogView(accessToken: accessToken),
                    const SizedBox(height: 24),
                    ApiKeysSection(controller: apiKeysController),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: TeamWorkspacesSection(
                  accessToken: accessToken,
                  onWorkspaceContextChanged: onWorkspaceContextChanged,
                  currentWorkspaceId: currentWorkspaceId,
                ),
              ),
            ],
          );
          final finiteHeight = constraints.maxHeight.isFinite;
          final tabBody = finiteHeight
              ? Expanded(child: tabView)
              : SizedBox(
                  height: (MediaQuery.sizeOf(context).height * 0.72).clamp(
                    520.0,
                    920.0,
                  ),
                  child: tabView,
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.studioSettingsHubTitle,
                style: studioPageTitleStyle(context),
              ),
              const SizedBox(height: 8),
              Text(l10n.studioSettingsHubSubtitle, style: subtitleStyle),
              const SizedBox(height: 16),
              TabBar(
                isScrollable: true,
                labelStyle: studioControlLabelStyle(context),
                unselectedLabelStyle: studioControlLabelStyle(context),
                tabs: <Tab>[
                  Tab(text: l10n.studioSettingsTabAccount),
                  Tab(text: l10n.studioSettingsTabPlanUsage),
                  Tab(text: l10n.studioSettingsTabApiKeys),
                  Tab(text: l10n.studioSettingsTabWorkspaces),
                ],
              ),
              const SizedBox(height: 12),
              tabBody,
            ],
          );
        },
      ),
    );
  }
}
