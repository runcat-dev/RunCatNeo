# Coding Style Guidelines

These are the authoritative line-level style rules for all Swift code in this repository. For architecture-level rules (layering, `DependencyClient` boundaries, Store/View responsibilities, resource placement), see [ARCHITECTURE.md](ARCHITECTURE.md).

## Language

- All code, identifiers, comments, and commit messages must be written in **English**.
- User-facing text must go through the localization system (`UserInterface/Resources`).

## Naming

- Use meaningful and descriptive names.
- Acronyms are all-lowercase or all-uppercase (✅ `userID`, `fileURL`; ❌ `userId`, `fileUrl`).
- In principle, avoid abbreviated names (✅ `count`, `image`; ❌ `cnt`, `img`).

## Comments

- Default to no code comments; choose names that make the code self-explanatory.
- Do not use `// MARK:` comments; organize members by the ordering convention instead.

## Formatting

- In multiline string literals, indent the content and the closing `"""` one level (4 spaces) deeper than the line containing the opening `"""`:

  ```swift
  let json = """
      { "title": "Card" }
      """
  ```

- When a function signature or call does not fit on one line, put one parameter per line and the closing parenthesis on its own line.
- Do not put a trailing comma after the last element of parameter and argument lists.
- Put a trailing comma after the last element of multiline collection literals:

  ```swift
  userDefaultsClient.register([
      .runnerID: RunnerKind.cat.id,
      .speedDecreasesUnderLoad: false,
  ])
  ```

- Use blank lines sparingly inside function bodies. When a body seems to need blank-line grouping, extract a named function or restructure the data instead.

## Code Patterns

- Prefer `guard` with early return over nested `if` for optional unwrapping and validation.
- In multiline `guard` statements, write `else {` at the end of the last condition line — never on its own line:

  ```swift
  guard let data = representation.representation(using: .tiff, properties: [:]),
        let image = NSImage(data: data) else {
      return nil
  }
  ```
- Write simple value mappings as switch expressions with single-line cases (`case .cat: 5`).
- Prefer `if`/`switch` expressions for variable assignment whenever they fit: assigning the result of one expression reads more cleanly than repeating the assignment inside every branch of an `if`/`switch` statement. (For SwiftUI view modifiers and other inline values, a ternary expression is sometimes clearer — use judgment.)
- Prefer leading-dot shorthand and semantic constants when the type is inferable (`.zero` over `0`).
- Write constants initialized from literals without a type annotation (`static let maxCount = 30`, `static let widthRange = 10 ... 100`).
- When constants describe a domain concept, consider grouping them as static members of a type named after that concept (`FrameImage.maxCount`, `SymbolImage.pixelSize`) instead of `private static let` constants on a service, when that makes the code easier to follow.
- Within a type, order members as: stored dependencies (`private let`), state properties, `init`, public methods, private helpers, nested types at the end.

## SwiftUI

- Pass `bundle: .module` to every localized `Text`/`Label` initializer.
- Do not add `#Preview` blocks.

## Tests

- Name test functions in snake_case as `subject_condition_expectation` (e.g. `decode_throws_when_title_missing`, `send_viewAppeared_reloads_customMetricsSources_from_user_defaults`).
- Compare whole `Equatable` values with a single `#expect` instead of asserting properties one by one; add `Equatable` conformance to entities when tests need it.
- Pass the expression under test directly to `#expect` instead of binding it to a temporary constant like `actual`; bind a constant (with a meaningful name) only when multiple assertions need the same value.
- Write boolean assertions as `#expect(value)` and `#expect(!value)` — never `#expect(value == true)` or `#expect(value == false)`.
- When the asserted value is `Bool?`, unwrap the optional with `try #require` into a named constant first and assert on that, adding `throws` to the test function as needed.
  This is the one case where binding a constant for a single assertion is expected.

  ```swift
  let removedContainerURL = try #require(removedURL.withLock { $0 })
  #expect(removedContainerURL.hasPathSuffix("RunCatNeo/alpha"))
  ```

- Read an `AllocatedUnfairLock` inside `#require` with the closure form (`withLock { $0 }`), not the key-path form (`withLock(\.self)`), because the macro expansion loses the key path's root type and fails to compile.
  The key-path form remains fine inside `#expect`.
- `waitUntil { … }` takes a plain `() -> Bool`, so `== true` and `== false` stay there as the way to flatten an optional condition.
- Use `AllocatedUnfairLock` for mutable state captured by mock dependency closures.

## License Headers

- Every source file under `LocalPackage/Sources/` carries the Apache-2.0 license header. Preserve it when editing and include it when creating new files.
- Test files under `LocalPackage/Tests/` omit the header by convention and start directly with `import`.

## Simplicity

- Avoid unnecessary complexity.
- Prefer readable and self-explanatory code over clever solutions.
