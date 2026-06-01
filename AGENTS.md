# Open YouTube Music Agent Guidelines & Specifications

This document outlines the strict guidelines and development specifications for AI coding agents working on the **Open YouTube Music macOS** repository. All AI agents must strictly adhere to these rules.

---

## 1. Strict Commit Controls (未经授权禁止擅自提交代码)

Do **NOT** execute Git commits (`git commit`) or stage files (`git add`) under any circumstances unless the user has **explicitly commanded/requested** you to commit the changes first (e.g., "先commit一下代码", "commit the changes", or "推代码发一版吧").

### Development Requirements:
- **No Proactive Committing**: AI coding agents must restrict their operations solely to editing code, compiling, and running local tests. Proactively staging or committing code is strictly forbidden.
- **User-Controlled Git History**: Always present the completed file modifications in the chat for the user to review. Committing must be performed *only* upon receiving an explicit request from the user. This ensures the developer maintains absolute ownership and control over their Git tree, staging state, and commit messages.

---

## 2. Strict Release Freeze (未经授权禁止发布新版本)

Do **NOT** bump application versions, create release Git tags (e.g., `v*`), publish GitHub Releases, or trigger deployment pipelines unless the user has **explicitly commanded** you to publish/release a new version ("我让你发才发" / "Only release when explicitly told to do so").

### Development Requirements:
- **No Implicit Version Bumping**: All development, refactoring, and hotfixes must be written, built, and tested locally. You are forbidden from proactively increasing the application's version in build scripts or pushing release tags online.
- **Safe Staging & Verification**: Restrict your operations to local compilation and verification. Always present the candidate fixes for the user to verify first. Wait for the user's explicit release command before bumping versions and pushing tags.

---

## 3. Centralized App i18n Specification (客户端双语国际化规范)

All user-facing interfaces, panels, menus, descriptions, tooltips, and overlay labels in the **Open YouTube Music** application must fully support **Internationalization (i18n)** in both English (`en`) and Simplified Chinese (`zh`).

### Development Requirements:
- **Centralized Localization Helper**: This codebase does NOT use standard Apple localizable string catalogs (`Localizable.xcstrings`). Instead, it uses a centralized switch-case helper:
  - In Swift UI views and managers, resolve strings dynamically using `state.loc("...")` or `AppState.shared.loc("...")`.
- **Adding New Keys**: When introducing any new user-facing labels or strings, you **MUST** add a corresponding translation entry inside the `switch key` block inside the `loc(_:)` function in `src/swift/main.swift`:
  ```swift
  func loc(_ key: String) -> String {
      let lang = getActiveLanguageCode()
      let isZh = lang.hasPrefix("zh")
      
      switch key {
      // ...
      case "New String Key": return isZh ? "中文字符串" : "New String Key"
      // ...
      }
  }
  ```
- **No Hardcoded Chinese/English UI Strings**: Never write raw Chinese or English strings directly in Swift views (e.g. `Text("暂无歌词")`). Always wrap them with the `state.loc` helper (e.g. `Text(state.loc("暂无歌词"))`).

---

## 4. No Hardcoded Paths (禁止硬编码写死路径)

Do **NOT** hardcode absolute file paths anywhere in the codebase. This is especially critical for user-specific directories (e.g., paths starting with `/Users/username/...`).

### Development Requirements:
- **Dynamic Directory Resolution**: Always resolve directories and files dynamically using native macOS / system APIs:
  - Use `FileManager.default.temporaryDirectory` for temporary files.
  - Use `FileManager.default.urls(for:in:)` to locate standard user folders (e.g., `Library`, `Logs`, `Application Support`).
- **Environment & User Isolation**: All caching, logs, databases, temporary file saving, or scratchpad outputs must strictly rely on dynamic user paths or sandbox-provided temporary folders. The codebase must remain completely portable, secure, and executable across different user accounts and machine environments without manual configuration.

---

## 5. Factual Logging Requirements (严格的日志输出规范)

Logging statements inside Swift code must be strictly factual and objective. They must only describe the observed phenomenon, not speculate on the underlying reasons or conjectural causes.

### Development Requirements:
- **Describe the Phenomenon, Not the Cause**: Logs must state *what* happened, not *why* it might have happened. Avoid descriptive text containing assumptions or reasons.
- **Example of Correct (Factual) Logging**:
  ```swift
  print("⚠️ LrcLib: Request to '\(urlString)' returned HTML instead of JSON.")
  ```
- **Example of Incorrect (Speculative) Logging**:
  ```swift
  print("⚠️ LrcLib: Request to '\(urlString)' returned HTML because the request was blocked by Cloudflare or hijacked by the network provider.")
  ```
- **Conciseness**: Keep logs brief, clear, and direct.
