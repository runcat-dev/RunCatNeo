# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

RunCat Neo is a macOS menu-bar app that animates a running cat in the status bar to reflect system load. Target: macOS 26.0+, built with Xcode 27.2+, Swift 6.2 (with `ExistentialAny` upcoming feature enabled).

## Build & Test

The app shell lives in `RunCatNeo.xcodeproj` and embeds the local Swift Package `LocalPackage/`, which contains essentially all source code. The `xcode` MCP tools (`mcp__xcode__BuildProject`, `mcp__xcode__RunAllTests`, etc.) are the preferred way to build and run tests — fall back to `xcodebuild` only when MCP is unavailable.

Tests live only in the SPM package (`DataSourceTests`, `ModelTests`) and use Swift Testing (`@Test`, `#expect`). There are no UI tests and no linter configured.

On the `xcodebuild` fallback only: run it from `LocalPackage/` with the `LocalPackage-Package` scheme on `platform=macOS,arch=arm64`. SwiftPM generates that scheme for the package, so it is not listed at the repository root — from there the equivalent is the `RunCatNeo` scheme and its `UnitTest.xctestplan`, which cover the same two targets. CI takes the former path (`working-directory: LocalPackage`).

CI (`.github/workflows/test.yml`) runs on tag pushes only — local test runs are the primary verification loop during development.

## Architecture (LUCA)

The codebase follows the [LUCA architecture](https://github.com/Kyome22/LUCA) — three SPM library targets with strict, one-way layering: `DataSource` (leaf) ← `Model` ← `UserInterface`. Never invert.

- **`DataSource`** — `Entities`, `Dependencies` (conform to `DependencyClient`, expose `liveValue` + `testValue`), `Repositories`.
- **`Model`** — `Services` (e.g. `SystemMetricsService`, `RunnerService`, `LogService`), `Stores` (`@MainActor @Observable`, conform to `Composable`; e.g. `Dashboard`, `RunnerBar`, `MetricsBar`, settings stores), `AppDependencies`, `AppDelegate`. Application logic lives here.
- **`UserInterface`** — SwiftUI `Scenes` (e.g. `RunnerBarScene`, `MetricsBarScene`, `SettingsWindowScene`), `Views`, and resources in `UserInterface/Resources/`.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the authoritative rules — including how `DependencyClient` couples with test design (thin, untested boundaries; logic lives in `Service`/`Store`), the Composable/Store pattern (Views mutate state only via `store.send(Action)`), cross-cutting state via `AppStateClient` and `AppDependencies`, and resource-layering constraints (`Model` must not reference Asset/String Catalog resources).

## Code Conventions

`CODING_STYLE.md` defines line-level style rules (language, naming, comments, formatting, license headers). Architecture-level rules live in `ARCHITECTURE.md`. Contribution process rules (one PR per concern, PR/issue templates, review etiquette, localization policy, feature-request cost/benefit bar) live in `CONTRIBUTING.md`.
