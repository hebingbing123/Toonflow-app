# Implementation Plan: Mobile PWA Debug Experience

## Overview

Three independent concerns are implemented in parallel-friendly waves:

1. **PWA completeness** — `index.html` viewport/apple meta tags + service worker
   registration; `manifest.json` scope/lang/categories fields.
2. **Android-web platform fixes** — `supportsAndroidWebBack` getter, `popstate`
   back-button interception via conditional import stub, overscroll physics, and
   ripple suppression in the product shell.
3. **On-screen debug overlay** — `DebugOverlayWidget` + `DebugErrorSnapshot` data
   model, barrel export, wired into `ErrorWidget.builder` and
   `PlatformDispatcher.onError` in `global_error_handling.dart`.

No new packages are introduced. All Dart code targets the existing Flutter SDK,
`go_router`, and `StudioTokens` / `StudioPrimitives` design tokens.

---

## Tasks

- [x] 1. PWA static-file changes
  - [x] 1.1 Update `frontend/web/index.html` — viewport meta, apple meta, SW registration
    - Add `<meta name="viewport" content="width=device-width, initial-scale=1.0">` inside `<head>`
    - Replace `<meta name="mobile-web-app-capable" content="yes">` with `<meta name="apple-mobile-web-app-capable" content="yes">`
    - Retain `apple-mobile-web-app-status-bar-style` and `apple-mobile-web-app-title` tags unchanged
    - Add SW registration `<script>` block (guarded by `'serviceWorker' in navigator`) before `</body>`
    - Retain the existing `flutter_bootstrap.js` script tag unchanged
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2_

  - [x] 1.2 Update `frontend/web/manifest.json` — add scope, lang, categories
    - Add `"scope": "/"`, `"lang": "en"`, `"categories": ["productivity"]` to the JSON object
    - Preserve all existing fields verbatim (`"display": "standalone"`, all four icon entries, etc.)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x]* 1.3 Write smoke tests for `index.html` and `manifest.json`
    - Parse `index.html` and assert viewport meta, `apple-mobile-web-app-capable`, and SW registration script are present
    - Parse `manifest.json` and assert `scope`, `lang`, `categories`, `display`, and all four icon entries are present
    - _Requirements: 1.1, 1.2, 2.1, 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 2. Android-web platform detection
  - [x] 2.1 Add `supportsAndroidWebBack` getter to `StudioMobileAffordances`
    - Add `static bool get supportsAndroidWebBack => kIsWeb && defaultTargetPlatform == TargetPlatform.android;` to `frontend/lib/design_system/ix/studio_mobile_affordances.dart`
    - This is the single source of truth for AndroidWebPlatform detection used by the shell
    - _Requirements: 4.4_

  - [x]* 2.2 Write unit tests for `supportsAndroidWebBack`
    - Verify getter returns `false` on non-web platforms and non-Android platforms
    - Verify getter returns `true` only when both `kIsWeb` and `TargetPlatform.android` conditions hold
    - _Requirements: 4.4_

- [x] 3. Android-web shell fixes — back-button, scroll, ripple
  - [x] 3.1 Create conditional import stubs for `dart:html` back-handler
    - Create `frontend/lib/shell/shell_back_handler_stub.dart` with a no-op `installPopStateListener` / `removePopStateListener` API
    - Create `frontend/lib/shell/shell_back_handler_web.dart` that wraps `window.onPopState.listen(...)` using `dart:html`
    - The web implementation calls `GoRouter.maybeOf(context).pop()` when `canPop()` is true; otherwise lets the browser default proceed
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 3.2 Wire back-button listener into `home_page.dart` (`_HomePageState`)
    - Conditional import in `home_page.dart` selects `shell_back_handler_web.dart` on web, stub otherwise
    - In `initState`, install the popstate listener only when `StudioMobileAffordances.supportsAndroidWebBack` is true
    - In `dispose`, remove the listener unconditionally (no-op on non-web via stub)
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 3.3 Add scroll-physics and ripple overrides to `build_product_shell.dart`
    - Add `_ClampingScrollBehaviour` private class (extends `ScrollBehavior`, returns `ClampingScrollPhysics`)
    - Add `_wrapAndroidWebScrollBehaviour(Widget child)` helper — returns `ScrollConfiguration` wrapping child only when `supportsAndroidWebBack` is true
    - Add `_wrapAndroidWebTheme(Widget child)` helper — returns `Theme` override with `splashFactory: InkRipple.splashFactory` and `highlightColor: StudioPrimitives.transparent` only when `supportsAndroidWebBack` is true
    - Apply both wrappers at the root of `buildProductShell`: theme wraps scroll-behaviour wrapper, which wraps the existing scaffold
    - _Requirements: 5.1, 5.2, 5.3_

  - [x]* 3.4 Write unit/widget tests for Android-web shell overrides
    - Test that `_wrapAndroidWebScrollBehaviour` returns the child unchanged on non-Android-web
    - Test that `_wrapAndroidWebTheme` returns the child unchanged on non-Android-web
    - Test that the popstate listener is not installed when `supportsAndroidWebBack` is false
    - _Requirements: 4.3, 5.3_

- [x] 4. Checkpoint — ensure all tests pass so far
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. DebugOverlayWidget and data model
  - [x] 5.1 Create `DebugErrorSnapshot` data model and `DebugOverlayWidget` in `frontend/lib/design_system/debug/debug_overlay_widget.dart`
    - Implement `DebugErrorSnapshot` immutable class with `exceptionType`, `message`, `stackLines` (first 20 lines), and `fullText` getter
    - Implement `DebugErrorSnapshot.fromDetails(FlutterErrorDetails)` factory using `LineSplitter` and `.take(20)`
    - Implement `DebugOverlayWidget` as a `StatefulWidget` with `_expanded` bool state (default `false`)
    - Widget structure: `Align(bottomCenter)` → `AnimatedContainer(height: _expanded ? null : 48)` → `Material(color: tokens.danger.withValues(alpha: 0.92))` → `Column` with header + optional scrollable body
    - Header: `GestureDetector` toggling `_expanded`, containing bug icon, exception type text, and copy-to-clipboard `IconButton`
    - Body (when expanded): `SingleChildScrollView` → `SelectableText(fullText)` or `'No details available'` if empty
    - Use only `StudioPrimitives` / `StudioTokens` / `StudioSpacing` tokens — no hard-coded colour literals
    - Collapsed min-height: `StudioSpacing.touchTarget` (48 logical px)
    - Clipboard: `Clipboard.setData(ClipboardData(text: ...))` using `fullText` or `'No details available'`
    - Empty-field fallback: render `'No details available'` when `message` or `stackLines` is empty
    - _Requirements: 6.4, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

  - [x] 5.2 Create barrel export `frontend/lib/design_system/debug/debug.dart`
    - Add `export 'debug_overlay_widget.dart';`
    - _Requirements: 7.5_

  - [x]* 5.3 Write widget tests for `DebugOverlayWidget`
    - Test collapsed height is ≥ 48 logical pixels
    - Test expand/collapse toggle on header tap
    - Test clipboard copy button invokes `Clipboard.setData` with correct text
    - Test empty-field fallback renders `'No details available'`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.6_

  - [x]* 5.4 Write property test for Property 2 — collapse–expand–collapse round-trip
    - **Property 2: Collapse–expand–collapse round-trip restores original state**
    - Generate random `DebugErrorSnapshot` instances, mount `DebugOverlayWidget`, simulate tap-expand then tap-collapse, assert widget returns to collapsed state (height ≥ 48, body not visible)
    - Minimum 100 iterations
    - **Validates: Requirements 7.2, 7.3**

- [x] 6. Wire DebugOverlayWidget into global error handling
  - [x] 6.1 Update `frontend/lib/bootstrap/global_error_handling.dart` — `ErrorWidget.builder` override
    - Import `DebugOverlayWidget` and `DebugErrorSnapshot` from `design_system/debug/debug.dart`
    - In debug mode (`!kReleaseMode`): set `ErrorWidget.builder` to return `DebugOverlayWidget(snapshot: DebugErrorSnapshot.fromDetails(details))`
    - In release mode: set `ErrorWidget.builder` to return `const SizedBox.shrink()`
    - Preserve the existing `FlutterError.onError` chain (which calls `developer.log`) unchanged — the `ErrorWidget.builder` override is additive
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 6.2 Update `global_error_handling.dart` — `PlatformDispatcher.onError` extension
    - Capture `previousPlatformOnError` before overriding
    - In the new handler: call existing `developer.log` (unchanged), then in debug mode invoke `ErrorWidget.builder(FlutterErrorDetails(exception: error, stack: stack))` for overlay visibility
    - Chain `previousPlatformOnError?.call(error, stack) ?? true` as the return value (note: change from current `?? false` to `?? true` per Requirement 8.3)
    - _Requirements: 8.1, 8.2, 8.3_

  - [x]* 6.3 Write unit tests for `global_error_handling.dart`
    - Verify `ErrorWidget.builder` is set after `configureGlobalErrorHandling()` is called
    - Verify `developer.log` is still called for Flutter errors
    - Verify release-mode path returns a non-`DebugOverlayWidget` placeholder (`SizedBox.shrink`)
    - Verify `PlatformDispatcher.onError` chains the previous handler
    - _Requirements: 6.1, 6.2, 6.3, 8.2, 8.3_

  - [x]* 6.4 Write property test for Property 1 — ErrorWidget builder populates overlay from any error details
    - **Property 1: ErrorWidget builder populates overlay from any error details**
    - Generate random exception objects and stack traces, wrap in `FlutterErrorDetails`, call `ErrorWidget.builder`, assert returned widget is `DebugOverlayWidget` and its rendered text contains exception type, message, and ≤ 20 stack lines
    - Minimum 100 iterations
    - **Validates: Requirements 6.1, 6.4**

  - [x]* 6.5 Write property test for Property 3 — PlatformDispatcher async errors reach the overlay builder
    - **Property 3: PlatformDispatcher async errors reach the overlay builder**
    - Generate random `(Object, StackTrace)` pairs, deliver to the installed `PlatformDispatcher.instance.onError`, capture the `FlutterErrorDetails` passed to `ErrorWidget.builder`, assert `exception` equals the original error object and `stack` equals the original stack trace
    - Minimum 100 iterations
    - **Validates: Requirements 8.1**

- [x] 7. Final checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Async error overlay host (Requirement 8 follow-through)
  - [x] 8.1 `DebugErrorOverlayController` + `DebugErrorOverlayHost` in `design_system/debug/`
  - [x] 8.2 `configureGlobalErrorHandling` reports to controller on Flutter + platform errors
  - [x] 8.3 Wire `DebugErrorOverlayHost` in `studio_app.dart`, `main.dart`, `main_harness.dart`, `main_product.dart`
  - [x] 8.4 Tests: host visibility, controller report, `developer.log` hook, rendered overlay text

---

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Concerns 1 (PWA static files), 2 (platform detection), and 5 (overlay widget) are fully independent and can be implemented in parallel
- The conditional import stub pattern (`shell_back_handler_stub.dart` / `shell_back_handler_web.dart`) avoids `dart:html` compile errors on native targets
- The `?? false` → `?? true` change in `PlatformDispatcher.onError` is intentional per Requirement 8.3 (mark error as handled when no previous handler exists)
- Property tests use `package:test` with a generator loop; minimum 100 iterations per property
- No new pub packages are introduced

---

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "2.1", "5.1"] },
    { "id": 1, "tasks": ["1.3", "2.2", "3.1", "5.2"] },
    { "id": 2, "tasks": ["3.2", "3.3", "5.3", "5.4"] },
    { "id": 3, "tasks": ["3.4", "6.1"] },
    { "id": 4, "tasks": ["6.2", "6.3"] },
    { "id": 5, "tasks": ["6.4", "6.5"] }
  ]
}
```
