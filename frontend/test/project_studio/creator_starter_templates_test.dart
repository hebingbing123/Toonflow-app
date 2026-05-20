import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_en.dart';
import 'package:openflow_app/project_studio/creator_starter_templates.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('creatorStarterTemplatesForScript keeps plot then rhythm order', () {
    final starters = creatorStarterTemplatesForScript(
      <ProjectHomeStarterTemplate>[
        ProjectHomeStarterTemplate(
          key: 'starter_creator_shot_rhythm',
          title: 'Rhythm',
          detail: 'd',
          targetStep: 'storyboard',
          ctaLabel: 'Go',
        ),
        ProjectHomeStarterTemplate(
          key: 'other',
          title: 'Other',
          detail: 'd',
          targetStep: 'script',
          ctaLabel: 'Go',
        ),
        ProjectHomeStarterTemplate(
          key: 'starter_creator_plot',
          title: 'Plot',
          detail: 'd',
          targetStep: 'script',
          ctaLabel: 'Go',
        ),
      ],
    );

    expect(starters, hasLength(2));
    expect(starters.first.key, 'starter_creator_plot');
    expect(starters.last.key, 'starter_creator_shot_rhythm');
  });

  test('creatorStarterLocalizedCopy maps known keys', () {
    final l10n = AppLocalizationsEn();
    const plot = ProjectHomeStarterTemplate(
      key: 'starter_creator_plot',
      title: '服务端标题',
      detail: '服务端说明',
      targetStep: 'script',
      ctaLabel: '服务端按钮',
    );

    final copy = creatorStarterLocalizedCopy(l10n, plot);
    expect(copy.title, l10n.studioCreatorStarterPlotTitle);
    expect(copy.ctaLabel, l10n.studioCreatorStarterPlotCta);
  });
}
