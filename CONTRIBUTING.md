# Contributing to RunCat Neo

Thank you for your interest in contributing to **RunCat Neo** 🐈  
RunCat Neo is a macOS system monitoring application represented as a running cat animation.

All kinds of contributions are welcome: bug reports, feature requests, and code contributions.

This document describes the rules, steps, and expectations for contributing to this project.

---

## Before Getting Started

- **Only contributions in English are accepted.** Any contribution in another language may be closed.
- **This project is macOS-only.** Issues or requests related to Windows, Linux, or other platforms will not be accepted.
- Always use the provided **Issue** and **Pull Request** templates. Submissions that do not follow the templates may be closed.
- **Runner requests do not belong here.** Custom runners are managed in the [Runner Gallery](https://runcat-dev.github.io/RunnerGallery/). Requests to add a new runner, or contributions of a runner you made, should go there instead.
- Be respectful, constructive, and professional in all interactions.

---

## Table of Contents

- [Before Getting Started](#before-getting-started)
- [Issues](#issues)
  - [Bug Reports](#bug-reports)
  - [Feature Requests](#feature-requests)
  - [Other Issues](#other-issues)
- [Localization](#localization)
  - [Requesting a New Language](#requesting-a-new-language)
  - [Contributing a Translation](#contributing-a-translation)
- [Pull Requests](#pull-requests)
  - [Before Opening a Pull Request](#before-opening-a-pull-request)
  - [Cloning and Working on the Repository](#cloning-and-working-on-the-repository)
  - [Submitting a Pull Request](#submitting-a-pull-request)
- [Code Style Guidelines](#code-style-guidelines)
- [Review Process](#review-process)
  - [Community Reviews](#community-reviews)
  - [Responding to Review Comments](#responding-to-review-comments)
- [Thank You](#thank-you)

---

## Issues

> [!IMPORTANT]
> **One issue = one topic.** If your report or request is not exactly the same as an existing issue, open a **new** issue instead of piling replies onto the existing one. Cross-link related issues by writing `Related: #123` in a comment — but do not stack similar-but-distinct problems or ideas as a tree of comments under a single issue. Each issue must be triageable, discussable, and closeable on its own.

---

### Bug Reports

To report a bug:

1. Make sure there is no existing issue reporting the same bug.  
   If one exists, add any additional relevant information as a comment instead of creating a new issue.
2. Click `New issue` and select the `Bug Report` template.
3. Follow all checklist steps and confirm that the bug still occurs.
4. Provide clear and complete information. More details help maintainers resolve the issue faster.
5. Submit the issue and stay attentive, as maintainers may request additional information.

---

### Feature Requests

> [!IMPORTANT]
> Requests to add a new runner are out of scope for this repository.
> Custom runners are showcased and distributed in the [Runner Gallery](https://runcat-dev.github.io/RunnerGallery/) — please make such requests there.
> Feature requests here should be about the app itself.

> [!IMPORTANT]
> **"Would be convenient" is not sufficient.** Every accepted feature carries an ongoing maintenance cost — code to keep alive, edge cases to test, translations to ship, regressions to answer for. A request is accepted only when its **benefit × breadth of need** clearly outweighs that cost. Requests that mainly serve a single user, replicate what the OS or an existing feature already handles, or trade a large maintenance surface for a small convenience will be declined even if the idea itself is reasonable.

To suggest a new feature:

1. Check if the **same** feature request already exists.  
   If it does, add supporting information there instead of opening a duplicate. For a **similar-but-distinct** idea, open a new issue and cross-link the related one — do not stack it as a reply.
2. Confirm that the feature benefits a broad range of users and that its benefit clearly exceeds the ongoing maintenance cost it would add.
3. Click `New issue` and select the `Feature Request` template.
4. Fill out the template as clearly and completely as possible — in particular, explain **who** benefits, **how much**, and **why the benefit is worth the maintenance cost**.
5. Submit the issue and remain available for follow-up questions.

> [!NOTE]
> Requests to add a new **UI language** are welcome as Feature Requests — see [Localization](#localization).

---

### Other Issues

> [!IMPORTANT]
> This option is only for issues that do not fit into the categories above.
> Issues that do not use the appropriate template will be closed without notice.

1. Click `New issue` and select `Blank issue`.
2. Describe your request clearly and in detail.
3. Submit the issue and stay attentive to maintainer feedback.

---

## Localization

RunCat Neo ships translations that real users read every day, so localization is treated as its own contribution track with rules that differ from ordinary code contributions.

### Requesting a New Language

If you want RunCat Neo to support a language it does not yet ship with, **open an issue** using the `Feature Request` template and state:

- the target language, and
- your reason for the request (e.g. size of the audience, personal need).

**Do not open a translation pull request unless you can meet the standard in [Contributing a Translation](#contributing-a-translation).** Filing an issue is enough, and it is the preferred path — maintainers will decide whether and when to add the language.

### Contributing a Translation

Translation pull requests are held to a strict standard because the strings ship to real users:

- **Only hand-crafted, human-authored translations are accepted.** Pull requests whose strings were produced by machine translators or LLMs (e.g. Google Translate, DeepL, ChatGPT, Claude) will be closed without merge. If machine-quality translation were acceptable here, maintainers would run it themselves — the value of a community translation PR is the human care put into every single string.
- Translate **every entry** in [`Localizable.xcstrings`](LocalPackage/Sources/UserInterface/Resources/Localizable.xcstrings) and [`RunnerNames.xcstrings`](LocalPackage/Sources/UserInterface/Resources/RunnerNames.xcstrings). Verify each string fits its UI context (menu items, tooltips, settings labels) and that punctuation, spacing, and casing follow your language's conventions.
- Declare in the pull request description that the translation is entirely human-authored, and note whether you are a native or fluent speaker of the target language.
- If you cannot translate every string by hand, please file a [language request issue](#requesting-a-new-language) instead of opening a partial or machine-assisted PR.

---

## Pull Requests

### Before Opening a Pull Request

- All code must be written in **English**.  
  Use the localization system for user-facing text in other languages.
- Follow the existing formatting and conventions used in the codebase.
- Keep each pull request focused on **a single change or context**.
  For multiple unrelated changes, create separate pull requests.
- **Keep the diff minimal.** Small, focused pull requests get reviewed faster and more carefully. Do not fold refactors, cleanup, whitespace fixes, or drive-by improvements into a change request — file those as separate PRs. Reviewer attention is the bottleneck; every unrelated line you add costs some of it.
- **Localization pull requests have additional rules.** See [Localization](#localization) — only hand-crafted, human-authored translations are accepted.
- Keep code clean, readable, and easy to understand.
- This repository is licensed under **Apache-2.0**.

---

### Cloning and Working on the Repository

1. Fork the `main` branch.
2. Make sure Git is installed.
3. Clone your fork locally:

   ```bash
   git clone https://github.com/your-username/RunCatNeo.git
   cd RunCatNeo
   ```

4. Create a new branch:

   ```bash
   git switch -c branch-name
   ```

   Use a short, descriptive branch name.

5. Make your changes using your preferred IDE (Xcode is recommended).
6. Keep functions within their respective classes.
7. Verify that the project builds and runs without errors.
8. Ensure no unnecessary or accidental changes were made.
9. Stage your changes:

   ```bash
   git add .
   ```

10. Commit your changes:

    ```bash
    git commit -m "Clear and descriptive commit message" -s
    ```

11. Push the branch:

    ```bash
    git push origin branch-name
    ```

---

### Submitting a Pull Request

1. Click **New pull request**.
2. Select the branch you worked on.
3. Choose the type of contribution.
4. Fill in all requested information clearly and completely.
5. Ensure all checklist items are satisfied.
6. Submit the pull request.

---

## Code Style Guidelines

Two documents define the rules for code shape. Follow both, together with the existing conventions in the codebase:

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — the [LUCA architecture](https://github.com/Kyome22/LUCA) rules: layer responsibilities, dependency direction, `DependencyClient` boundaries, the Store/Composable pattern, and resource placement.
- **[CODING_STYLE.md](CODING_STYLE.md)** — line-level style: naming, formatting, comments, patterns, license headers.

Key architectural rules that most PRs need to check:

- **`DependencyClient` is a spot-mock boundary, not a place for logic.** Clients are never covered by tests, so anything more than one direct call into the underlying system API silently degrades the test guarantees the rest of the code depends on.
- **`UserInterface` (SwiftUI views) must not contain logic.** All state changes go through a `Composable` store's `Action`.
- **`Model` must not reference Asset Catalog or String Catalog resources.** Resource lookup lives only in `UserInterface`.

Pull requests that violate these boundaries will need to be restructured before merge.

---

## Review Process

- Pull requests are reviewed as time permits.
- Not all contributions are guaranteed to be accepted.
- Maintainers may request changes before merging.
- Inactive or non-responsive pull requests may be closed.

### Community Reviews

- Reviews and comments from non-maintainer community members are welcome and appreciated.
- However, **only feedback from maintainers is considered official**, and only maintainers decide whether a pull request is merged.
- Community reviewers may not be fully familiar with this project's contribution guidelines, so their suggestions may not always align with project policy.
- Contributors are free to consider community feedback, but should use their own judgment and wait for maintainer review before treating any change as required.

### Responding to Review Comments

- **Do not click `Resolve conversation` unless you are the reviewer.**
  Even after pushing a fix in response to a review comment, only the reviewer can decide whether the issue is actually resolved.
  Pushing a follow-up commit and resolving the conversation yourself bypasses that judgment.
- **Address each review comment individually rather than bundling them together**, unless there is a clear reason to combine them.
  The larger a single response or diff becomes, the harder it is for the reviewer to evaluate whether each point has been handled correctly.
  Reply to each comment with the corresponding change so that the discussion stays focused and easy to follow.

---

## Thank You

Thank you again for contributing to **RunCat Neo**.
Your time and effort help make this project better for everyone 😸
