import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../design_system/tokens.dart';

/// Structured coach copy for a demo tour stop (zh/en).
@immutable
class ProductDemoTourGuideSections {
  const ProductDemoTourGuideSections({
    this.positionZh,
    this.positionEn,
    required this.goalZh,
    required this.goalEn,
    this.bulletsZh = const <String>[],
    this.bulletsEn = const <String>[],
    this.demoNoteZh,
    this.demoNoteEn,
    this.nextHintZh,
    this.nextHintEn,
  });

  final String? positionZh;
  final String? positionEn;
  final String goalZh;
  final String goalEn;
  final List<String> bulletsZh;
  final List<String> bulletsEn;
  final String? demoNoteZh;
  final String? demoNoteEn;
  final String? nextHintZh;
  final String? nextHintEn;

  String? positionForLocale(String languageCode) =>
      languageCode.startsWith('zh') ? positionZh : positionEn;

  String goalForLocale(String languageCode) =>
      languageCode.startsWith('zh') ? goalZh : goalEn;

  List<String> bulletsForLocale(String languageCode) =>
      languageCode.startsWith('zh') ? bulletsZh : bulletsEn;

  String? demoNoteForLocale(String languageCode) =>
      languageCode.startsWith('zh') ? demoNoteZh : demoNoteEn;

  String? nextHintForLocale(String languageCode) =>
      languageCode.startsWith('zh') ? nextHintZh : nextHintEn;

  /// Plain-text fallback for compact banners.
  String compactBodyForLocale(String languageCode) {
    final buffer = StringBuffer();
    final position = positionForLocale(languageCode);
    if (position != null && position.isNotEmpty) {
      buffer.writeln(position);
    }
    buffer.writeln(goalForLocale(languageCode));
    for (final bullet in bulletsForLocale(languageCode)) {
      buffer.writeln('• $bullet');
    }
    final demo = demoNoteForLocale(languageCode);
    if (demo != null && demo.isNotEmpty) {
      buffer.writeln(demo);
    }
    final next = nextHintForLocale(languageCode);
    if (next != null && next.isNotEmpty) {
      buffer.writeln(next);
    }
    return buffer.toString().trim();
  }
}

/// Rich coach body for [ProductDemoTourGuideSections].
class ProductDemoTourGuideBody extends StatelessWidget {
  const ProductDemoTourGuideBody({
    super.key,
    required this.sections,
    required this.languageCode,
    required this.l10n,
    required this.textStyle,
    required this.labelStyle,
  });

  final ProductDemoTourGuideSections sections;
  final String languageCode;
  final AppLocalizations l10n;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    void addParagraph(String? text) {
      if (text == null || text.isEmpty) {
        return;
      }
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: StudioSpacing.xs));
      }
      children.add(Text(text, style: textStyle));
    }

    void addLabeledBlock(String label, String body) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: StudioSpacing.radiusComfort));
      }
      children.add(Text(label, style: labelStyle));
      children.add(const SizedBox(height: StudioSpacing.chromeActionGap));
      children.add(Text(body, style: textStyle));
    }

    final position = sections.positionForLocale(languageCode);
    if (position != null && position.isNotEmpty) {
      addParagraph(position);
    }

    addLabeledBlock(
      l10n.productDemoGuideSectionGoal,
      sections.goalForLocale(languageCode),
    );

    final bullets = sections.bulletsForLocale(languageCode);
    if (bullets.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: StudioSpacing.radiusComfort));
      }
      children.add(Text(l10n.productDemoGuideSectionWhere, style: labelStyle));
      children.add(const SizedBox(height: StudioSpacing.chromeActionGap));
      for (final bullet in bullets) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('• ', style: textStyle),
                Expanded(child: Text(bullet, style: textStyle)),
              ],
            ),
          ),
        );
      }
    }

    final demo = sections.demoNoteForLocale(languageCode);
    if (demo != null && demo.isNotEmpty) {
      addLabeledBlock(l10n.productDemoGuideSectionDemo, demo);
    }

    final next = sections.nextHintForLocale(languageCode);
    if (next != null && next.isNotEmpty) {
      addLabeledBlock(l10n.productDemoGuideSectionNext, next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
