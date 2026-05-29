import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../rust_api/search/api.dart';
import '../studio_motion.dart';

/// Default duration for fades, switches, and pane transitions.
const Duration studioMotionStandardDuration = Duration(milliseconds: 250);

/// Slightly faster micro-interactions (icon swaps, chips).
const Duration studioMotionQuickDuration = Duration(milliseconds: 200);

/// Per-item delay for staggered list/grid entrance.
const Duration studioStaggerItemDelay = Duration(milliseconds: 48);

/// Cap total stagger wait so long lists do not feel sluggish.
const Duration studioStaggerMaxDelay = Duration(milliseconds: 420);

/// Hero tag for the six-step progress ring (projects home → project studio).
///
/// Pair with the same tag on [StudioStepProgressRing] in the studio pane header.
/// Entry from the projects grid must use [openProjectStudioRoute] with
/// `pushFromProjectsHome: true` so the source route stays mounted during flight.
String studioHeroTagProjectProgress(int projectNumericId) =>
    'studio.hero.project.progress.$projectNumericId';

/// Hero tag for project title text (projects home → project studio header).
String studioHeroTagProjectTitle(int projectNumericId) =>
    'studio.hero.project.title.$projectNumericId';

/// Hero tag for creator journey milestone icons (script → art → storyboard → deliver).
String studioHeroTagCreatorJourneyMilestone(int projectNumericId, int milestoneIndex) =>
    'studio.hero.journey.$projectNumericId.$milestoneIndex';

/// Hero tag for search result leading avatar (type icon).
String studioHeroTagSearchResultLeading(ResultType type, String resultId) =>
    'studio.hero.search.${type.wireName}.$resultId';

/// Staggered list/grid row wrapper (alias for [StudioStaggeredEntrance]).
Widget studioStaggeredItem(
  int index, {
  required Widget child,
  Object? entranceKey,
}) {
  return StudioStaggeredEntrance(
    index: index,
    entranceKey: entranceKey,
    child: child,
  );
}

/// Applies staggered entrance to each child (for [Column] / [ListView] children).
List<Widget> studioStaggeredChildren(
  Iterable<Widget> children, {
  Object? entranceKey,
}) {
  final list = children is List<Widget>
      ? children
      : children.toList(growable: false);
  return <Widget>[
    for (final (index, child) in list.indexed)
      studioStaggeredItem(
        index,
        entranceKey: entranceKey ?? list.length,
        child: child,
      ),
  ];
}

/// Wraps [child] in a [Hero] when [tag] is non-null (Material leaf for flight).
class StudioHero extends StatelessWidget {
  const StudioHero({
    super.key,
    required this.tag,
    required this.child,
    this.placeholder,
  });

  final String? tag;
  final Widget child;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    if (tag == null || tag!.isEmpty) {
      return child;
    }
    // When a studio route is pushed on top (projects grid still in the stack),
    // disable heroes on the background route so E2E/runtime do not see duplicate tags.
    final route = ModalRoute.of(context);
    final heroEnabled = route == null || route.isCurrent;
    return HeroMode(
      enabled: heroEnabled,
      child: Hero(
        tag: tag!,
        placeholderBuilder: placeholder == null
            ? null
            : (context, size, child) => placeholder!,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// Fade + slight vertical slide for content keyed by [transitionKey].
class StudioFadeSwitcher extends StatelessWidget {
  const StudioFadeSwitcher({
    super.key,
    required this.transitionKey,
    required this.child,
    this.duration = studioMotionStandardDuration,
    this.slideOffset = const Offset(0, 0.02),
  });

  final Object transitionKey;
  final Widget child;
  final Duration duration;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: studioAnimationDuration(context, duration),
      switchInCurve: studioAnimationCurve(context, Curves.easeOutCubic),
      switchOutCurve: studioAnimationCurve(context, Curves.easeInCubic),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: slideOffset,
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
      child: KeyedSubtree(key: ValueKey<Object>(transitionKey), child: child),
    );
  }
}

/// Cross-fades between two widgets (e.g. expand/collapse panels).
class StudioCrossFade extends StatelessWidget {
  const StudioCrossFade({
    super.key,
    required this.showPrimary,
    required this.primary,
    required this.secondary,
    this.duration = studioMotionStandardDuration,
  });

  final bool showPrimary;
  final Widget primary;
  final Widget secondary;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: primary,
      secondChild: secondary,
      crossFadeState: showPrimary
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      duration: studioAnimationDuration(context, duration),
      sizeCurve: studioAnimationCurve(context, Curves.easeInOut),
    );
  }
}

/// Swaps icons or small labels with a short fade (favorite, pin, counts).
class StudioIconSwap extends StatelessWidget {
  const StudioIconSwap({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
    this.duration = studioMotionQuickDuration,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: studioAnimationDuration(context, duration),
      switchInCurve: studioAnimationCurve(context, Curves.easeOut),
      switchOutCurve: studioAnimationCurve(context, Curves.easeIn),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: Icon(
        icon,
        key: ValueKey<IconData>(icon),
        size: size,
        color: color,
      ),
    );
  }
}

/// Animates a numeric label when the value changes.
class StudioAnimatedNumber extends StatelessWidget {
  const StudioAnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.duration = studioMotionQuickDuration,
  });

  final String value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: studioAnimationDuration(context, duration),
      switchInCurve: studioAnimationCurve(context, Curves.easeOut),
      switchOutCurve: studioAnimationCurve(context, Curves.easeIn),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(value, key: ValueKey<String>(value), style: style),
    );
  }
}

/// Brief fade when [index] changes (e.g. [IndexedStack] step body).
class StudioIndexedPaneFade extends StatefulWidget {
  const StudioIndexedPaneFade({
    super.key,
    required this.index,
    required this.child,
    this.duration = studioMotionStandardDuration,
  });

  final int index;
  final Widget child;
  final Duration duration;

  @override
  State<StudioIndexedPaneFade> createState() => _StudioIndexedPaneFadeState();
}

class _StudioIndexedPaneFadeState extends State<StudioIndexedPaneFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  late final Animation<double> _opacity = _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = studioAnimationDuration(context, widget.duration);
  }

  @override
  void didUpdateWidget(covariant StudioIndexedPaneFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _replayEntrance();
    }
  }

  void _replayEntrance() {
    if (studioDisableAnimations(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// Slide-up + fade entrance for list/grid rows (first paint or [entranceKey] reset).
class StudioStaggeredEntrance extends StatefulWidget {
  const StudioStaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.entranceKey,
  });

  final int index;
  final Widget child;

  /// When this changes, the entrance animation replays (e.g. new search page).
  final Object? entranceKey;

  @override
  State<StudioStaggeredEntrance> createState() =>
      _StudioStaggeredEntranceState();
}

class _StudioStaggeredEntranceState extends State<StudioStaggeredEntrance>
    with SingleTickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 320);

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Object? _lastEntranceKey;
  bool _scheduled = false;
  Timer? _staggerTimer;

  @override
  void initState() {
    super.initState();
    _lastEntranceKey = widget.entranceKey;
    _controller = AnimationController(vsync: this, duration: _entranceDuration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = studioAnimationDuration(context, _entranceDuration);
    if (!_scheduled) {
      _scheduled = true;
      _scheduleEntrance();
    }
  }

  @override
  void didUpdateWidget(covariant StudioStaggeredEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entranceKey != _lastEntranceKey) {
      _lastEntranceKey = widget.entranceKey;
      _scheduleEntrance();
    }
  }

  void _scheduleEntrance() {
    if (studioDisableAnimations(context)) {
      _staggerTimer?.cancel();
      _staggerTimer = null;
      _controller.value = 1;
      return;
    }
    _staggerTimer?.cancel();
    _staggerTimer = null;
    _controller.value = 0;
    final cappedIndex = widget.index.clamp(0, 12);
    final delay = Duration(
      milliseconds: (cappedIndex * studioStaggerItemDelay.inMilliseconds).clamp(
        0,
        studioStaggerMaxDelay.inMilliseconds,
      ),
    );
    _staggerTimer = Timer(delay, () {
      if (!mounted) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.value = 1;
      });
    });
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _staggerTimer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (studioDisableAnimations(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
