# Requirements Document

## Introduction

This feature improves the cross-device build and debug configuration for the OpenFlow Flutter web app to support smooth mobile and tablet testing without requiring a desktop computer. It covers three areas: completing the PWA configuration so the app is installable and runs full-screen on mobile browsers; fixing Android-specific gesture and navigation handling so remote-preview and mobile-IDE previews render with full accuracy; and adding a visual on-screen error overlay so UI overflow and render crashes surface as readable debug information rather than a white screen during offline mobile testing.

## Glossary

- **PWA**: Progressive Web App — a web application that can be installed to a device home screen and run in a standalone, address-bar-free window.
- **Service Worker**: A browser-managed background script that enables PWA installability, offline caching, and fetch interception.
- **Manifest**: The `manifest.json` file that declares PWA metadata (name, icons, display mode, etc.) to the browser.
- **IndexHTML**: The `frontend/web/index.html` file that bootstraps the Flutter web app.
- **ErrorOverlay**: The collapsible on-screen widget that renders error details when a Flutter render or overflow error occurs.
- **GlobalErrorHandler**: The `configureGlobalErrorHandling()` function in `frontend/lib/bootstrap/global_error_handling.dart`.
- **MobileAffordances**: The `StudioMobileAffordances` class in `frontend/lib/design_system/ix/studio_mobile_affordances.dart`.
- **ProductShell**: The root scaffold widget built in `frontend/lib/shell/build_product_shell.dart`.
- **GoRouter**: The `go_router` package used for declarative routing throughout the app.
- **DebugOverlayWidget**: The new collapsible overlay widget to be created in `frontend/lib/design_system/debug/`.
- **AndroidWebPlatform**: The combination of `kIsWeb == true` and `defaultTargetPlatform == TargetPlatform.android` at runtime.

---

## Requirements

### Requirement 1 — PWA Viewport and Meta Tags

**User Story:** As a mobile developer, I want the app's HTML head to declare correct viewport and Apple PWA meta tags, so that the layout scales correctly on mobile screens and iOS Safari offers the "Add to Home Screen" prompt.

#### Acceptance Criteria

1. THE IndexHTML SHALL include a `<meta name="viewport" content="width=device-width, initial-scale=1.0">` tag in the `<head>` element.
2. THE IndexHTML SHALL replace the existing `<meta name="mobile-web-app-capable" content="yes">` tag with `<meta name="apple-mobile-web-app-capable" content="yes">`.
3. THE IndexHTML SHALL retain the existing `<meta name="apple-mobile-web-app-status-bar-style" content="black">` tag unchanged.
4. THE IndexHTML SHALL retain the existing `<meta name="apple-mobile-web-app-title" content="OpenFlow">` tag unchanged.

---

### Requirement 2 — Service Worker Registration

**User Story:** As a mobile developer, I want a service worker registered for the app, so that mobile browsers recognise the app as installable and display the "Add to Home Screen" prompt.

#### Acceptance Criteria

1. THE IndexHTML SHALL include a `<script>` block that registers a service worker at `/flutter_service_worker.js` using `navigator.serviceWorker.register()` after the page loads.
2. IF `navigator.serviceWorker` is undefined in the browser, THEN THE IndexHTML SHALL skip service worker registration without throwing a JavaScript error.
3. THE PWA SHALL pass the browser's PWA installability criteria, including: a linked manifest, a registered service worker, and HTTPS (or localhost) delivery.
4. WHEN a user opens the app in a supported mobile browser and the installability criteria are met, THE browser SHALL display an "Add to Home Screen" prompt or banner.

---

### Requirement 3 — Manifest Completeness

**User Story:** As a mobile developer, I want the web manifest to declare all fields required for a standalone PWA, so that the installed app launches without an address bar and with correct branding.

#### Acceptance Criteria

1. THE Manifest SHALL include a `"scope"` field set to `"/"`.
2. THE Manifest SHALL include a `"lang"` field set to `"en"`.
3. THE Manifest SHALL include a `"categories"` field listing at least one category (e.g., `["productivity"]`).
4. THE Manifest SHALL retain the existing `"display": "standalone"` value unchanged.
5. THE Manifest SHALL retain all four existing icon entries (192 px, 512 px, maskable-192 px, maskable-512 px) unchanged.
6. WHEN the app is launched from the home screen, THE PWA SHALL open in standalone display mode with no browser address bar visible.

---

### Requirement 4 — Android Web Back-Button Interception

**User Story:** As a mobile developer, I want the hardware back button on Android to navigate within the app rather than closing the browser tab, so that remote-preview and mobile-IDE sessions behave the same as native app testing.

#### Acceptance Criteria

1. WHEN the app is running on AndroidWebPlatform and the user presses the hardware back button, THE ProductShell SHALL intercept the browser `popstate` event and invoke the GoRouter `pop()` method if the router stack has a previous entry.
2. WHEN the app is running on AndroidWebPlatform and the GoRouter stack has no previous entry, THE ProductShell SHALL allow the default browser back-navigation to proceed.
3. WHILE the app is running on a non-Android platform or as a native binary (`kIsWeb == false`), THE ProductShell SHALL NOT install the `popstate` event listener.
4. THE MobileAffordances SHALL expose a `supportsAndroidWebBack` getter that returns `true` only when `kIsWeb == true` and `defaultTargetPlatform == TargetPlatform.android`.

---

### Requirement 5 — Android Web Overscroll and Ripple Boundary

**User Story:** As a mobile developer, I want Android-specific overscroll and ripple effects to be suppressed or bounded when running as a web PWA, so that the UI renders with the same visual accuracy as a native Android build.

#### Acceptance Criteria

1. WHEN the app is running on AndroidWebPlatform, THE ProductShell SHALL set `ScrollConfiguration` to use a `ClampingScrollPhysics` scroll behaviour, replacing the default `GlowingOverscrollIndicator`.
2. WHEN the app is running on AndroidWebPlatform, THE ProductShell SHALL wrap the root widget with a `Theme` override that sets `splashFactory` to `InkRipple.splashFactory` and `highlightColor` to `Colors.transparent`, preventing double-ripple artefacts from the browser's native touch feedback.
3. WHILE the app is running on a non-Android platform or as a native binary, THE ProductShell SHALL NOT apply the Android-web scroll or ripple overrides.

---

### Requirement 6 — ErrorWidget Builder Override

**User Story:** As a mobile developer, I want Flutter render errors to display a visible on-screen overlay instead of a red error box or white screen, so that I can read crash details during offline mobile testing without a connected debugger.

#### Acceptance Criteria

1. THE GlobalErrorHandler SHALL set `ErrorWidget.builder` to a function that returns a `DebugOverlayWidget` populated with the error's exception message and stack trace.
2. WHEN `kReleaseMode` is `true`, THE GlobalErrorHandler SHALL set `ErrorWidget.builder` to a function that returns a minimal, non-intrusive placeholder widget instead of the full `DebugOverlayWidget`.
3. THE GlobalErrorHandler SHALL continue to call `developer.log` for all errors as it does today, in addition to rendering the `DebugOverlayWidget`.
4. WHEN a `FlutterErrorDetails` object is passed to `ErrorWidget.builder`, THE DebugOverlayWidget SHALL display the exception type, the exception message, and the first 20 lines of the stack trace.

---

### Requirement 7 — DebugOverlayWidget

**User Story:** As a mobile developer, I want a collapsible on-screen overlay that shows error details, so that I can inspect crash information on a physical device without needing a desktop terminal.

#### Acceptance Criteria

1. THE DebugOverlayWidget SHALL render as a semi-transparent overlay anchored to the bottom of the screen, with a minimum height of 48 logical pixels when collapsed.
2. WHEN the user taps the collapsed DebugOverlayWidget, THE DebugOverlayWidget SHALL expand to show the full error message and stack trace in a scrollable text area.
3. WHEN the user taps the expanded DebugOverlayWidget header, THE DebugOverlayWidget SHALL collapse back to its minimum height.
4. THE DebugOverlayWidget SHALL display a copy-to-clipboard button that, when tapped, copies the full error message and stack trace to the device clipboard.
5. THE DebugOverlayWidget SHALL be implemented in `frontend/lib/design_system/debug/` and exported from the design system's public barrel file.
6. IF the error message or stack trace string is empty, THEN THE DebugOverlayWidget SHALL display the text "No details available" in place of the empty field.
7. THE DebugOverlayWidget SHALL use only colours and text styles from the existing `StudioPrimitives` and `StudioTheme` tokens, with no hard-coded colour literals.

---

### Requirement 8 — PlatformDispatcher Async Error Capture

**User Story:** As a mobile developer, I want async errors that escape the Flutter zone to be captured and surfaced in the on-screen overlay, so that errors triggered by background operations are visible during mobile testing.

#### Acceptance Criteria

1. WHEN `PlatformDispatcher.instance.onError` is invoked with an unhandled error, THE GlobalErrorHandler SHALL invoke `ErrorWidget.builder` with a synthetic `FlutterErrorDetails` constructed from the error and stack trace.
2. THE GlobalErrorHandler SHALL continue to chain the previously registered `PlatformDispatcher.instance.onError` handler after invoking the overlay, preserving existing behaviour.
3. IF no previous `PlatformDispatcher.instance.onError` handler was registered, THEN THE GlobalErrorHandler SHALL return `true` from the error callback to mark the error as handled.
