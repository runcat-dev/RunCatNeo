# Architecture

RunCat Neo follows the [LUCA architecture](https://github.com/Kyome22/LUCA). All source lives in the `LocalPackage/` Swift Package under three library targets with a strict, one-way dependency direction:

```
UserInterface  →  Model  →  DataSource
```

Arrows show the direction of `import`. `UserInterface` may import `Model` and `DataSource`; `Model` may import `DataSource`; `DataSource` imports nothing from the other two. **Never invert this direction.**

## Layer Responsibilities

- **`DataSource`** — leaf layer. Holds:
  - `Entities` — plain `Sendable` values (`AppState`, `Metrics`, `Runner`, `AsyncStreamBundle`, etc.)
  - `Dependencies` — thin `Sendable` wrappers around system APIs (`UserDefaults`, `NSWorkspace`, `FileManager`, `SMAppService`, etc.), each conforming to `DependencyClient` with `liveValue` + `testValue`
  - `Repositories` — composed of dependencies
  - No application logic.

- **`Model`** — depends on `DataSource`. Holds:
  - `Services` — long-lived workers wired in `AppDelegate` (`MetricsService`, `RunnerService`, `LogService`)
  - `Stores` — `@MainActor @Observable` view-models conforming to `Composable` (`Dashboard`, `RunnerBar`, `MetricsBar`, settings stores)
  - `AppDependencies` — the bag of all dependency clients, injected everywhere via the `\.appDependencies` SwiftUI environment value
  - `AppDelegate`
  - **This is where application logic lives.**

- **`UserInterface`** — depends on `DataSource` + `Model`. Holds:
  - SwiftUI `Scenes` (`RunnerBarScene`, `MetricsBarScene`, `SettingsWindowScene`)
  - SwiftUI `Views`
  - Localized strings and image assets in `UserInterface/Resources/`
  - **No logic.**

## DependencyClient

`DependencyClient` conformances exist so tests can inject overrides via `testDependency(of:injection:)`. Treat them as thin, untested boundaries — nothing more.

- **Never put logic inside a `DependencyClient`.** Clients themselves are never covered by tests. Any conditional, error-handling branch, retry, or state coordination written inside a client is behaviorally unverified — it silently degrades the test guarantees the rest of the codebase relies on.
- A client method should be **one direct call into the underlying system API**, wrapping the result into `Sendable` values where necessary. Anything more sits in a `Service` or `Store`, which are covered by tests.
- Use `DependencyClient` **only as a spot-mock window for effects the project does not control** — `UserDefaults`, `FileManager`, `NSWorkspace`, `SMAppService`, networking, notifications, and similar system-owned side effects. If a piece of code does not need to be swapped in tests, it does not belong in a client.

## Stores and the Composable pattern

Stores implement `Composable`: they expose an `Action` enum and a `reduce(_ action:)` async function, with `send(_:)` calling `reduce` and then forwarding to a parent-provided `action` closure. This is the only way views mutate state.

- When adding a new screen, create a `Store` in `Model/Stores/`, define its `Action`, and pair it with a SwiftUI `View` that calls `store.send(...)`.
- All state mutation and control flow initiated by the UI must go through `Action` + `reduce(_:)`. Views call `store.send(...)` and read `@Observable` state — nothing else.
- **Views must not contain logic.** No conditionals over multiple state fields, no derived computations beyond trivial formatting, no direct dependency calls, no `Task { ... }` blocks that reach for repositories or services. If a view feels like it wants an `if`, express that decision in the store and expose the result as state.

## Cross-cutting state

Global app state flows through `AppStateClient` (an `AllocatedUnfairLock<AppState>`). Async streams in `AppState` (e.g. `metrics`, `runnerBundles`, `runnerSpeeds`) are produced by services and consumed by stores via `for await` loops launched inside `reduce(.task)`.

`AppDependencies.shared` is the live singleton injected through the `\.appDependencies` SwiftUI environment value; tests construct one via `AppDependencies.testDependencies(...)`, overriding only the clients they care about.

## Resources

- Asset Catalog and String Catalog lookups (`Image(...)`, `String(localized:)`, `Text("key", bundle: .module)`, `.module` bundle references, etc.) must **only** appear in `UserInterface`.
- **`Model` must not reference bundle resources.** Logic that reasons about "which image / which localized string" belongs in the UI layer. In the logic layer, represent the choice as a plain-value key — an enum case, an entity ID, a semantic constant — that `UserInterface` maps to the concrete resource. This keeps `Model` testable without a resource bundle and keeps localization decisions out of business logic.
