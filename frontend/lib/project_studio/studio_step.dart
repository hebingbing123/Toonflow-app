/// Six-step (+ optional quality) project studio SOP.
enum StudioStep {
  script('script', 0),
  art('art', 1),
  assets('assets', 2),
  storyboard('storyboard', 3),
  video('video', 4),
  deliver('deliver', 5),
  quality('quality', 6);

  const StudioStep(this.slug, this.order);

  final String slug;
  final int order;

  static const List<StudioStep> sopSteps = <StudioStep>[
    StudioStep.script,
    StudioStep.art,
    StudioStep.assets,
    StudioStep.storyboard,
    StudioStep.video,
    StudioStep.deliver,
  ];

  static StudioStep fromSlug(String? raw) {
    if (raw == null || raw.isEmpty) return StudioStep.script;
    for (final step in StudioStep.values) {
      if (step.slug == raw) return step;
    }
    return StudioStep.script;
  }

  StudioStep? get next {
    final i = sopSteps.indexOf(this);
    if (i < 0 || i >= sopSteps.length - 1) return null;
    return sopSteps[i + 1];
  }
}
