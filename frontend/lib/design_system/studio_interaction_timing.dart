/// Shared debounce / throttle durations for Studio interaction safety.
abstract final class StudioInteractionTiming {
  /// Primary submit buttons and confirm dialogs (double-tap guard).
  static const Duration submitDebounce = Duration(milliseconds: 500);

  /// Live search / suggestion API calls while typing.
  static const Duration searchThrottle = Duration(milliseconds: 300);

  /// Full search navigation after Enter / search button.
  static const Duration searchSubmitLock = Duration(milliseconds: 500);

  /// Palette overlay rebuild while the query string changes.
  static const Duration overlayRebuildDebounce = Duration(milliseconds: 48);
}
