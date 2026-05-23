import 'package:flutter/material.dart';

import '../account/controller.dart';
import '../account/section.dart';
import '../api_keys/controller.dart';
import '../api_keys/section.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_decorative_icon.dart';
import '../design_system/studio_motion.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import '../settings/model_pricing/model_pricing_catalog_view.dart';
import '../settings/model_vendors/model_vendors_section.dart';
import '../settings/plan_usage/plan_usage_section.dart';
import '../team_workspaces/section.dart';

/// Unified settings (Wave 5): account, plan & usage, API keys, workspaces.
class SettingsHubPage extends StatefulWidget {
  const SettingsHubPage({
    super.key,
    required this.accountController,
    required this.apiKeysController,
    required this.accessToken,
    required this.onAccountDeleted,
    required this.onWorkspaceContextChanged,
    this.currentWorkspaceId,
    this.initialTabIndex = 0,
  });

  final AccountController accountController;
  final ApiKeysController apiKeysController;
  final String? accessToken;
  final Future<void> Function(AccountDeleteResponseV1) onAccountDeleted;
  final Future<void> Function() onWorkspaceContextChanged;
  final String? currentWorkspaceId;

  /// 0 account · 1 plan · 2 API & models · 3 workspaces
  final int initialTabIndex;

  @override
  State<SettingsHubPage> createState() => _SettingsHubPageState();
}

class _SettingsHubPageState extends State<SettingsHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTabIndex.clamp(0, 3),
  )..addListener(_handleTabChanged);

  late int _selectedIndex = widget.initialTabIndex.clamp(0, 3);

  @override
  void didUpdateWidget(covariant SettingsHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialTabIndex.clamp(0, 3);
    if (next != oldWidget.initialTabIndex && _tabController.index != next) {
      _tabController.animateTo(next);
      setState(() => _selectedIndex = next);
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    final nextIndex =
        _tabController.animation?.value.round() ?? _tabController.index;
    if (nextIndex == _selectedIndex || !mounted) {
      return;
    }
    setState(() {
      _selectedIndex = nextIndex;
    });
  }

  List<_SettingsModuleMeta> _modules(AppLocalizations l10n) {
    return <_SettingsModuleMeta>[
      _SettingsModuleMeta(
        label: l10n.studioSettingsTabAccount,
        icon: Icons.badge_outlined,
      ),
      _SettingsModuleMeta(
        label: l10n.studioSettingsTabPlanUsage,
        icon: Icons.stacked_line_chart_rounded,
      ),
      _SettingsModuleMeta(
        label: l10n.studioSettingsTabApiKeys,
        icon: Icons.key_outlined,
      ),
      _SettingsModuleMeta(
        label: l10n.studioSettingsTabWorkspaces,
        icon: Icons.apartment_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modules = _modules(l10n);

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        Widget tabScrollChild(Widget child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: SizedBox(width: contentWidth, child: child),
          );
        }

        final tabView = TabBarView(
          controller: _tabController,
          children: <Widget>[
            tabScrollChild(
              AccountSection(
                controller: widget.accountController,
                onAccountDeleted: widget.onAccountDeleted,
              ),
            ),
            tabScrollChild(PlanUsageSection(accessToken: widget.accessToken)),
            tabScrollChild(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ModelVendorsSection(accessToken: widget.accessToken),
                  const SizedBox(height: 24),
                  ModelPricingCatalogView(accessToken: widget.accessToken),
                  const SizedBox(height: 24),
                  ApiKeysSection(controller: widget.apiKeysController),
                ],
              ),
            ),
            tabScrollChild(
              TeamWorkspacesSection(
                accessToken: widget.accessToken,
                onWorkspaceContextChanged: widget.onWorkspaceContextChanged,
                currentWorkspaceId: widget.currentWorkspaceId,
              ),
            ),
          ],
        );
        final finiteHeight = constraints.maxHeight.isFinite;
        final tabBody = finiteHeight
            ? Expanded(child: tabView)
            : SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.72).clamp(
                  560.0,
                  920.0,
                ),
                child: tabView,
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SettingsHeroCard(
              title: l10n.studioSettingsHubTitle,
              subtitle: l10n.studioSettingsHubSubtitle,
              modules: modules,
              selectedIndex: _selectedIndex,
              controller: _tabController,
              maxWidth: contentWidth,
            ),
            SizedBox(
              height: contentWidth < 720
                  ? StudioLayoutSpacing.section - 8
                  : StudioLayoutSpacing.section - 2,
            ),
            tabBody,
          ],
        );
      },
    );
  }
}

class _SettingsHeroCard extends StatelessWidget {
  const _SettingsHeroCard({
    required this.title,
    required this.subtitle,
    required this.modules,
    required this.selectedIndex,
    required this.controller,
    required this.maxWidth,
  });

  final String title;
  final String subtitle;
  final List<_SettingsModuleMeta> modules;
  final int selectedIndex;
  final TabController controller;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final compact = maxWidth < 640;
    final scrollableTabs = maxWidth < 760;
    final wideDesktop = maxWidth >= 1240;
    final summary = modules[selectedIndex.clamp(0, modules.length - 1)];
    final subtitleStyle =
        studioSectionIntroStyle(context) ??
        TextStyle(color: tokens.textSecondary);
    final tabBar = TabBar(
      controller: controller,
      tabAlignment: scrollableTabs ? TabAlignment.start : TabAlignment.fill,
      indicator: const BoxDecoration(),
      dividerColor: Colors.transparent,
      overlayColor: WidgetStatePropertyAll<Color>(
        tokens.primary.withValues(alpha: 0.08),
      ),
      labelPadding: EdgeInsets.only(
        right: scrollableTabs ? StudioSpacing.xs : 0,
      ),
      isScrollable: scrollableTabs,
      tabs: <Widget>[
        for (var index = 0; index < modules.length; index++)
          Tab(
            height: compact ? 58 : 62,
            child: Padding(
              padding: EdgeInsets.only(
                right: !scrollableTabs && index < modules.length - 1
                    ? StudioSpacing.xs + 2
                    : 0,
              ),
              child: _SettingsModuleTab(
                module: modules[index],
                selected: selectedIndex == index,
                compact: compact,
                expand: !scrollableTabs,
              ),
            ),
          ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard + 10),
        border: Border.all(color: tokens.borderSubtle),
        color: tokens.bgSurface.withValues(alpha: 0.96),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? StudioSpacing.sm : StudioLayoutSpacing.section,
          compact ? StudioSpacing.sm : StudioLayoutSpacing.section - 2,
          compact ? StudioSpacing.sm : StudioLayoutSpacing.section,
          compact ? StudioSpacing.sm : StudioLayoutSpacing.section - 2,
        ),
        child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (compact) ...<Widget>[
                    Text(title, style: studioPageTitleStyle(context)),
                    const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
                    Text(subtitle, style: subtitleStyle),
                    const SizedBox(height: StudioSpacing.sm),
                    _SettingsSummaryTile(
                      compact: true,
                      module: summary,
                      modules: modules,
                      selectedIndex: selectedIndex,
                    ),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: wideDesktop ? 12 : 11,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(title, style: studioPageTitleStyle(context)),
                              const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: Text(subtitle, style: subtitleStyle),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: wideDesktop ? 24 : 18),
                        Flexible(
                          flex: wideDesktop ? 8 : 9,
                          child: _SettingsSummaryTile(
                            compact: false,
                            module: summary,
                            modules: modules,
                            selectedIndex: selectedIndex,
                          ),
                        ),
                      ],
                    ),
                  SizedBox(
                    height: compact
                        ? StudioLayoutSpacing.cardInner + 2
                        : StudioLayoutSpacing.cardInner + 4,
                  ),
                  if (scrollableTabs)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: tokens.borderSubtle.withValues(alpha: 0.55),
                        ),
                        color: tokens.bgInset.withValues(alpha: 0.84),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: tabBar,
                      ),
                    )
                  else
                    tabBar,
                ],
              ),
      ),
    );
  }
}

class _SettingsSummaryTile extends StatelessWidget {
  const _SettingsSummaryTile({
    required this.compact,
    required this.module,
    required this.modules,
    required this.selectedIndex,
  });

  final bool compact;
  final _SettingsModuleMeta module;
  final List<_SettingsModuleMeta> modules;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final currentIndexLabel = (selectedIndex + 1).toString().padLeft(2, '0');
    final totalIndexLabel = modules.length.toString().padLeft(2, '0');

    return AnimatedSwitcher(
      duration: studioAnimationDuration(
        context,
        const Duration(milliseconds: 260),
      ),
      switchInCurve: studioAnimationCurve(context, Curves.easeOutCubic),
      switchOutCurve: studioAnimationCurve(context, Curves.easeInCubic),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Container(
        key: ValueKey<String>(module.label),
        padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 18 : 20),
          border: Border.all(color: tokens.borderSubtle),
          color: tokens.bgInset.withValues(alpha: 0.88),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: tokens.bgInset.withValues(alpha: 0.84),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Icon(module.icon, size: 18, color: tokens.textSecondary),
                ),
                const SizedBox(width: StudioLayoutSpacing.inlineGap),
                Expanded(
                  child: Text(
                    module.label,
                    style: studioCardTitleStyle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (compact)
                  _SettingsProgressDots(
                    count: modules.length,
                    selectedIndex: selectedIndex,
                    activeColor: tokens.primary,
                    inactiveColor: tokens.textMuted.withValues(alpha: 0.55),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tokens.borderSubtle),
                      color: tokens.bgInset.withValues(alpha: 0.72),
                    ),
                    child: Text(
                      '$currentIndexLabel / $totalIndexLabel',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (!compact) ...<Widget>[
              const SizedBox(height: 12),
              _SettingsProgressDots(
                count: modules.length,
                selectedIndex: selectedIndex,
                activeColor: tokens.primary,
                inactiveColor: tokens.textMuted.withValues(alpha: 0.45),
                compact: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsModuleTab extends StatelessWidget {
  const _SettingsModuleTab({
    required this.module,
    required this.selected,
    required this.compact,
    required this.expand,
  });

  final _SettingsModuleMeta module;
  final bool selected;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final label = Text(
      module.label,
      maxLines: 1,
      overflow: expand ? TextOverflow.ellipsis : TextOverflow.visible,
      style: studioControlLabelStyle(context)?.copyWith(
        color: selected ? tokens.textPrimary : tokens.textSecondary,
      ),
    );

    return AnimatedContainer(
      duration: studioAnimationDuration(
        context,
        const Duration(milliseconds: 240),
      ),
      curve: studioAnimationCurve(context, Curves.easeOutCubic),
      constraints: BoxConstraints(
        minWidth: expand ? 0 : (compact ? 120 : 148),
        minHeight: compact ? 50 : 54,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? tokens.primary : tokens.borderSubtle,
          width: selected ? 1.5 : 1,
        ),
        color: selected
            ? tokens.primarySoft.withValues(alpha: 0.85)
            : tokens.bgSurface.withValues(alpha: 0.42),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          studioDecorativeIcon(
            module.icon,
            size: compact ? 18 : 19,
            color: selected ? tokens.textPrimary : tokens.textSecondary,
          ),
          const SizedBox(width: StudioLayoutSpacing.inlineGap),
          if (expand) Expanded(child: label) else label,
        ],
      ),
    );
  }
}

class _SettingsModuleMeta {
  const _SettingsModuleMeta({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _SettingsProgressDots extends StatelessWidget {
  const _SettingsProgressDots({
    required this.count,
    required this.selectedIndex,
    required this.activeColor,
    required this.inactiveColor,
    this.compact = true,
  });

  final int count;
  final int selectedIndex;
  final Color activeColor;
  final Color inactiveColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < count; index++) ...<Widget>[
          if (index > 0) SizedBox(width: compact ? 6 : 8),
          AnimatedContainer(
            duration: studioAnimationDuration(
              context,
              const Duration(milliseconds: 220),
            ),
            curve: studioAnimationCurve(context, Curves.easeOutCubic),
            width: index == selectedIndex
                ? (compact ? 18 : 22)
                : (compact ? 8 : 10),
            height: compact ? 8 : 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: index == selectedIndex ? activeColor : inactiveColor,
            ),
          ),
        ],
      ],
    );
  }
}
