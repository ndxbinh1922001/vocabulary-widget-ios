# AGENTS.md — VocabWidget

iOS app that shows English vocabulary on the iPhone Lock Screen
(`accessoryInline`, `accessoryRectangular`) and in StandBy (`systemSmall`).
The app ships a built-in word list and lets the user add, edit and delete
their own words. Everything is offline; there is no backend.

## Layout

| Path | Purpose |
|---|---|
| `Packages/VocabularyKit` | Foundation-only Swift package: model, built-in list, validation, storage, settings, deterministic rotation, timeline planning, design tokens. All business logic lives here and is tested with `swift test` on macOS. |
| `Shared/` | SwiftUI theme and the word card view. Member of **both** the app and the widget target. |
| `App/` | SwiftUI app target (tabs: Hôm nay / Từ vựng / Cài đặt). The only process that writes data. |
| `Widget/` | WidgetKit extension. Read-only consumer of the shared data. |
| `AppTests/` | Hosted test target for iOS-only integration checks. |
| `Config/` | `Base.xcconfig` (bundle ids, App Group id, versions) and an optional, git-ignored `Local.xcconfig` for `DEVELOPMENT_TEAM`. |
| `VocabWidget.xcodeproj` | Hand-written project (objectVersion 77, synchronized folders) plus the shared `VocabWidget` scheme. |

## Validation commands

Use the Makefile; do not invent other commands.

| Command | Needs Xcode | What it checks |
|---|---|---|
| `make lint` | no | `swift-format lint --strict` |
| `make test-core` | no | VocabularyKit unit tests on macOS |
| `make check-core` | no | lint + test-core |
| `make project-lint` | yes | pbxproj/scheme syntax and `xcodebuild -list` |
| `make build` | yes | App + widget build for the iOS Simulator (unsigned) |
| `make test` | yes | `AppTests` on the simulator named by `SIM` |
| `make check` | yes | everything above |

Concurrent runs in the same working tree must isolate their build output and
simulator, for example:

```sh
make check BUILD_ROOT=.build/codex SIM="iPhone 17"
make check BUILD_ROOT=.build/agy   SIM="iPhone 17 Pro"
```

## Conventions

- Swift 6 language mode. The app target defaults to `MainActor` isolation;
  the widget target does not (WidgetKit `TimelineProvider` requirements are
  nonisolated).
- Code, comments and examples in code are written in English. User-facing
  strings are Vietnamese and hard-coded (no `.xcstrings`).
- Never force-unwrap or `try!` (enforced by `.swift-format`).
- The app is the single writer of `user_words.json` and `settings.json`;
  writes are atomic. A corrupt word file is moved aside, never overwritten.
  The widget only reads.
- Word order for rotation is derived from stable string ids only, never from
  `hashValue`, `Set` or `Dictionary` iteration order.
- The App Group id is defined once in `Config/Base.xcconfig` and read at
  runtime from the `AppGroupID` Info.plist key.
- Shared files live in `<App Group container>/Library/Application Support/VocabWidget/`
  (`StorageLocator.appGroupDataSubpath`). Version 1.0 used the container root;
  `LegacyStorageMigration` moves those files on app launch and never overwrites.
- Colors come from `DesignTokens` (package) through `Theme` (Shared);
  do not hard-code hex values in views.

## Review rules

- Reviewers must not modify production code, commit, push, merge or rebase.
- Review output goes to the location given in the review task, never into
  the source tree.
