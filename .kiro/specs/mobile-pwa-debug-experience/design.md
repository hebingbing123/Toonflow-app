# Design Document — Mobile PWA Debug Experience

## Overview

This feature hardens the Flutter web app for mobile and tablet testing across three
orthogonal concerns:

1. **PWA completeness** — `index.html` and `manifest.json` changes that satisfy
   browser installability criteria and correct iOS/Android meta tags.
2. **Android-web platform fixes** — back-button interception, overscroll physics, and
   ripple suppression so remote-preview sessions render identically to a native build.
3. **On-screen debug overlay** — a collapsible `DebugOverlayWidget` wired into
   `ErrorWidget.builder` and `PlatformDispatcher.onError` so render crashes and async
   errors surface as readable text on the device screen.

No new packages are introduced. All Dart code uses existing Flutter SDK APIs,
`go_router`, and the project's `StudioTokens` / `StudioPrimitives` design tokens.

---

## Architecture

```
frontend/
├── web/
│   ├── index.html                          ← viewport + apple meta + SW registration
│   └── manifest.json                       ← scope / lang / categories added
│
└── lib/
    ├── bootstrap/
    │   └── global_error_handling.dart      ← ErrorWidget.builder + PlatformDispatcher
    │
    ├── design_system/
    │   └── debug/
    │       ├── debug_overlay_widget.dart   ← new collapsible overlay
    │       └── debug.dart                  ← barrel export
    │
    ├── design_system/
    │   └── ix/
    │       └── studio_mobile_affordances.dart  ← supportsAndroidWebBack getter added
    │
    └── shell/
        └── build_product_shell.dart        ← popstate listener + scroll/ripple overrides
```

The three concerns are independent and touch disjoint files; they can be implemented
and reviewed in any order.

---

## Components and Interfaces

### 1. `frontend/web/index.html` — PWA Meta & Service Worker

**Changes required:**

| # | Change |
|---|--------|
| 1 | Add `<meta name="viewport" content="width=device-width, initial-scale=1.0">` inside `<head>` |
| 2 | Replace `<meta name="mobile-web-app-capable" content="yes">` with `<meta name="apple-mobile-web-app-capable" content="yes">` |
| 3 | Add service worker registration `<script>` block before `</body>` |

The service worker registration script must guard against environments where
`navigator.serviceWorker` is absent (e.g. non-HTTPS, older browsers):

```html
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('/flutter_service_worker.js');
    });
  }
</script>
```

The existing `flutter_bootstrap.js` script tag is retained unchanged.

---

### 2. `frontend/web/manifest.json` — Manifest Completeness

Three fields are added to the existing JSON object. All existing fields (including
`"display": "standalone"` and all four icon entries) are preserved verbatim.

```json
{
  "scope": "/",
  "lang": "en",
  "categories": ["productivity"]
}
```

---

### 3. `StudioMobileAffordances` — `supportsAndroidWebBack` Getter

A new static getter is added to the existing `StudioMobileAffordances` class in
`frontend/lib/design_system/ix/studio_mobile_affordances.dart`:

```dart
/// True only when running as a Flutter web app on an Android browser.
/// Used to gate popstate back-button interception in the product shell.
static bool get supportsAndroidWebBack =>
    kIsWeb && defaultTargetPlatform == TargetPlatform.android;
```

This is the single source of truth for the AndroidWebPlatform detection used by
both the back-button listener and the scroll/ripple overrides.

---

### 4. `build_product_shell.dart` — Android Web Back-Button & Overrides

The `_HomePageProductShell` extension gains two new responsibilities, both gated
behind `StudioMobileAffordances.supportsAndroidWebBack`.

#### 4a. Back-button interception via `popstate`

A `dart:html` `EventListener` is registered in `initState` / disposed in `dispose`
of the shell's `State`. Because `dart:html` is web-only, the import is conditional:

```dart
// Conditional import — dart:html on web, stub on native.
import 'shell_back_handler_stub.dart'
    if (dart.library.html) 'shell_back_handler_web.dart';
```

`shell_back_handler_web.dart` wraps `window.onPopState.listen(...)`.
`shell_back_handler_stub.dart` provides a no-op implementation.

The handler logic:

```dart
void _onPopState(Event _) {
  if (!mounted) return;
  final router = GoRouter.maybeOf(context);
  if (router != null && router.canPop()) {
    router.pop();
  }
  // If canPop() is false, the default browser back-navigation proceeds.
}
```

The listener is installed only when `supportsAndroidWebBack` is true.

#### 4b. Scroll physics override

```dart
Widget _wrapAndroidWebScrollBehaviour(Widget child) {
  if (!StudioMobileAffordances.supportsAndroidWebBack) return child;
  return ScrollConfiguration(
    behavior: const _ClampingScrollBehaviour(),
    child: child,
  );
}

class _ClampingScrollBehaviour extends ScrollBehavior {
  const _ClampingScrollBehaviour();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
```

#### 4c. Ripple / highlight override

```dart
Widget _wrapAndroidWebTheme(Widget child) {
  if (!StudioMobileAffordances.supportsAndroidWebBack) return child;
  return Theme(
    data: Theme.of(context).copyWith(
      splashFactory: InkRipple.splashFactory,
      highlightColor: StudioPrimitives.transparent,
    ),
    child: child,
  );
}
```

Both wrappers are applied at the root of `buildProductShell`, wrapping the existing
scaffold widget. The order is: scroll behaviour wraps the scaffold; theme wraps the
scroll behaviour wrapper.

---

### 5. `DebugOverlayWidget` — Collapsible Error Overlay

**File:** `frontend/lib/design_system/debug/debug_overlay_widget.dart`

#### Data model

```dart
/// Immutable snapshot of a Flutter error for display.
class DebugErrorSnapshot {
  const DebugErrorSnapshot({
    required this.exceptionType,
    required this.message,
    required this.stackLines,
  });

  final String exceptionType;   // e.g. "FlutterError"
  final String message;         // exception.toString()
  final List<String> stackLines; // first 20 lines of stack trace

  factory DebugErrorSnapshot.fromDetails(FlutterErrorDetails details) {
    final exception = details.exception;
    final stack = details.stack?.toString() ?? '';
    final lines = const LineSplitter()
        .convert(stack)
        .take(20)
        .toList(growable: false);
    return DebugErrorSnapshot(
      exceptionType: exception.runtimeType.toString(),
      message: exception.toString(),
      stackLines: lines,
    );
  }

  String get fullText =>
      '$exceptionType\n\n$message\n\n${stackLines.join('\n')}';
}
```

#### Widget structure

`DebugOverlayWidget` is a `StatefulWidget`. Its state holds a single `bool _expanded`
flag (default `false`).

```
Align(alignment: Alignment.bottomCenter)
└── AnimatedContainer(height: _expanded ? null : 48)
    └── Material(color: tokens.danger.withOpacity(0.92))
        └── Column
            ├── _Header (GestureDetector → toggles _expanded)
            │   ├── Icon(Icons.bug_report_outlined)
            │   ├── Text(snapshot.exceptionType)
            │   └── IconButton(copy-to-clipboard)
            └── if _expanded:
                └── Expanded
                    └── SingleChildScrollView
                        └── SelectableText(fullText or "No details available")
```

**Token usage:**

| Element | Token |
|---------|-------|
| Background | `tokens.danger.withValues(alpha: 0.92)` |
| Header text | `tokens.textPrimary` via `Theme.of(context).textTheme.labelLarge` |
| Body text | `tokens.textSecondary` via `Theme.of(context).textTheme.bodySmall` with `fontFamily: 'monospace'` |
| Copy icon | `tokens.textPrimary` |
| Collapsed min-height | `StudioSpacing.touchTarget` (48 logical px) |

No hard-coded colour literals are used.

#### Clipboard

```dart
void _copyToClipboard() {
  final text = snapshot.fullText.isEmpty ? 'No details available' : snapshot.fullText;
  Clipboard.setData(ClipboardData(text: text));
}
```

#### Empty-field fallback

Both `message` and `stackLines` are checked independently. If either is empty, the
corresponding section renders `'No details available'` instead.

#### Barrel export

`frontend/lib/design_system/debug/debug.dart`:

```dart
export 'debug_overlay_widget.dart';
```

---

### 6. `global_error_handling.dart` — ErrorWidget & PlatformDispatcher

#### 6a. `ErrorWidget.builder` override

```dart
if (!kReleaseMode) {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return DebugOverlayWidget(
      snapshot: DebugErrorSnapshot.fromDetails(details),
    );
  };
} else {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Minimal non-intrusive placeholder in release builds.
    return const SizedBox.shrink();
  };
}
```

The existing `FlutterError.onError` chain (which calls `developer.log`) is preserved
unchanged. The `ErrorWidget.builder` override is additive — it does not replace the
logging path.

#### 6b. `PlatformDispatcher.onError` — overlay invocation

The existing handler is extended to also invoke `ErrorWidget.builder` with a
synthetic `FlutterErrorDetails`:

```dart
final previousPlatformOnError = PlatformDispatcher.instance.onError;
PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
  // Existing logging (unchanged).
  developer.log(
    error.toString(),
    name: logName,
    error: error,
    stackTrace: stack,
    level: 1000,
  );

  // Invoke overlay builder with synthetic details (debug mode only).
  if (!kReleaseMode) {
    final details = FlutterErrorDetails(exception: error, stack: stack);
    ErrorWidget.builder(details);
  }

  // Chain previous handler; return true if none was registered.
  return previousPlatformOnError?.call(error, stack) ?? true;
};
```

Note: `ErrorWidget.builder` is invoked here for side-effect visibility (the overlay
is rendered wherever the next `ErrorWidget` is placed in the tree). The return value
of `previousPlatformOnError` is preserved; when no previous handler existed the
callback returns `true` to mark the error as handled.

---

## Data Models

| Model | Location | Purpose |
|-------|----------|---------|
| `DebugErrorSnapshot` | `debug_overlay_widget.dart` | Immutable error data for overlay display |

No new persistent data models, database tables, or API contracts are introduced.

---

## Error Handling

| Scenario | Handling |
|----------|---------|
| `navigator.serviceWorker` absent | JS `'serviceWorker' in navigator` guard; silent skip |
| `ErrorWidget.builder` called in release mode | Returns `SizedBox.shrink()` — no crash, no visible overlay |
| Empty exception message or stack trace | `DebugOverlayWidget` renders `'No details available'` |
| `PlatformDispatcher.onError` with no previous handler | Returns `true` to mark error handled |
| `GoRouter.canPop()` returns false on Android web back | Popstate handler does nothing; browser default proceeds |
| `dart:html` unavailable (native binary) | Conditional import stub provides no-op; no runtime error |

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid
executions of a system — essentially, a formal statement about what the system should
do. Properties serve as the bridge between human-readable specifications and
machine-verifiable correctness guarantees.*

### Property 1: ErrorWidget builder populates overlay from any error details

*For any* `FlutterErrorDetails` object with a non-empty exception, after
`configureGlobalErrorHandling()` is called in debug mode, `ErrorWidget.builder`
invoked with those details SHALL return a `DebugOverlayWidget` whose rendered text
contains the exception type string, the exception message, and at most 20 lines of
the stack trace.

**Validates: Requirements 6.1, 6.4**

---

### Property 2: Collapse–expand–collapse round-trip restores original state

*For any* `DebugOverlayWidget` in its initial collapsed state, tapping the header to
expand and then tapping the header again to collapse SHALL return the widget to its
original collapsed state (height ≥ 48 logical pixels, body content not visible).

**Validates: Requirements 7.2, 7.3**

---

### Property 3: PlatformDispatcher async errors reach the overlay builder

*For any* `(Object error, StackTrace stack)` pair delivered to
`PlatformDispatcher.instance.onError` after `configureGlobalErrorHandling()` is
called in debug mode, `ErrorWidget.builder` SHALL be invoked with a
`FlutterErrorDetails` whose `exception` equals the original error object and whose
`stack` equals the original stack trace.

**Validates: Requirements 8.1**

---

## Testing Strategy

### Unit / widget tests

- `global_error_handling_test.dart` — verifies `ErrorWidget.builder` is set, that
  `developer.log` is still called, and that the release-mode path returns a
  non-`DebugOverlayWidget` placeholder.
- `debug_overlay_widget_test.dart` — verifies collapsed height, expand/collapse
  toggle, clipboard copy, and the empty-field fallback text.
- `studio_mobile_affordances_test.dart` — verifies `supportsAndroidWebBack` returns
  `false` on non-web and non-Android platforms.

### Property-based tests

Property tests use `package:test` with a simple generator loop (or `package:checks`
with randomised inputs). Minimum 100 iterations per property.

- **Property 1** — generate random exception objects and stack traces, wrap in
  `FlutterErrorDetails`, call `ErrorWidget.builder`, assert widget type and text
  content.
- **Property 2** — generate random `DebugErrorSnapshot` instances, mount
  `DebugOverlayWidget`, simulate tap sequence, assert final state.
- **Property 3** — generate random `(Object, StackTrace)` pairs, deliver to the
  installed `PlatformDispatcher.onError`, capture the `FlutterErrorDetails` passed to
  `ErrorWidget.builder`, assert field equality.

### Smoke / integration tests

- Parse `index.html` and assert viewport meta, apple-mobile-web-app-capable, and SW
  registration script are present.
- Parse `manifest.json` and assert `scope`, `lang`, `categories`, `display`, and all
  four icon entries are present.
- Manual Lighthouse PWA audit on device / CI headless Chrome to verify installability
  score.
