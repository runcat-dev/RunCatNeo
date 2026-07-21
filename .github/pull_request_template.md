## Context of Contribution

<!-- Each pull request should fix only one issue or propose one feature. -->
<!-- Do not mix unrelated changes in a single PR. -->

- [ ] Bug Fix
- [ ] Refactoring
- [ ] New Feature
- [ ] Localization (new language or translation update)
- [ ] Others

## Summary of the Proposal

<!-- Provide a concise summary of what this pull request proposes. -->

## Reason for the new feature

<!-- If it's a new feature, explain why this feature is necessary. -->
<!-- Explain how important this feature is to many users. -->
<!-- Explain if the benefits of the new feature outweigh the maintenance cost. -->

## Checklist

- [ ] I have read the [CONTRIBUTING.md](../blob/main/CONTRIBUTING.md) and agree to follow it.
- [ ] This PR does not contain commits of multiple contexts.
- [ ] The diff is minimal — no unrelated refactors, whitespace churn, or drive-by cleanups.
- [ ] Code follows proper indentation and naming conventions.
- [ ] Layering follows the [LUCA architecture](../blob/main/ARCHITECTURE.md): no logic in `DependencyClient`, no logic in `UserInterface` views, no Asset/String Catalog references from `Model`.
- [ ] Implemented using only APIs that can be submitted to the App Store.
- [ ] **Localization PRs only:** Every translated string in this PR was hand-crafted by a human translator. No machine translation or LLM output was used. See [CONTRIBUTING.md → Localization](../blob/main/CONTRIBUTING.md#localization).
