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

To suggest a new feature:

1. Check if a similar feature request already exists.  
   If so, please contribute to the existing discussion instead of opening a new one.
2. Ensure your suggestion benefits a broad range of users and is not only a personal preference.
3. Click `New issue` and select the `Feature Request` template.
4. Fill out the template as clearly and completely as possible.
5. Submit the issue and remain available for follow-up questions.

---

### Other Issues

> [!IMPORTANT]
> This option is only for issues that do not fit into the categories above.
> Issues that do not use the appropriate template will be closed without notice.

1. Click `New issue` and select `Blank issue`.
2. Describe your request clearly and in detail.
3. Submit the issue and stay attentive to maintainer feedback.

---

## Pull Requests

### Before Opening a Pull Request

- All code must be written in **English**.  
  Use the localization system for user-facing text in other languages.
- Follow the existing formatting and conventions used in the codebase.
- Keep each pull request focused on **a single change or context**.
  For multiple unrelated changes, create separate pull requests.
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

All style rules are defined in [CODING_STYLE.md](CODING_STYLE.md).
Follow them together with the existing conventions in the codebase.

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
