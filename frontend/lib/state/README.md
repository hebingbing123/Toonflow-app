# Flutter state management (Studio)

## When to use what

| Scope | Mechanism | Examples |
|-------|-----------|----------|
| Widget-local UI | `StatefulWidget` | expansion, hover, form field focus |
| Shell / session | `ChangeNotifier` + `ListenableBuilder` | `AppLocaleNotifier`, `ShellNavigationController` |
| Feature panel | `Future` / `Stream` in `State` + `StudioAsyncDataView` | project lists, notifications |
| Shared read-mostly | `Provider` / constructor injection | API clients, auth token |

## Async data

Prefer `StudioAsyncDataView` + `resolveStudioPaneLoadState` ([`platform/studio_load_state.dart`](../platform/studio_load_state.dart)) for pane-sized surfaces. See [`design_system/ASYNC_LOADING.md`](../design_system/ASYNC_LOADING.md).

## Rules

1. No side effects in `build` — use `initState`, callbacks, or `StudioScheduler.scheduleOncePerFrame`.
2. Narrow rebuilds: `ListenableBuilder` / `select`-style listeners on notifiers.
3. Cancel timers and subscriptions in `dispose`.
4. Errors: `describeUserVisibleApiErrorResolved` — never `e.toString()` in UI.

## Anti-patterns

- Global mutable singletons without a notifier
- Full-page `CircularProgressIndicator` for list/panel fetch
- Pushing business rules into `design_system/` widgets

## Future

Hand-rolled immutable templates: [`immutable_state_template.dart`](immutable_state_template.dart). Full Riverpod/Freezed migration is **not** required; adopt per vertical slice when a feature already uses codegen.
