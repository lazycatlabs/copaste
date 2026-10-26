# AGENTS.md

Guide for AI agents working on Copaste, a clipboard manager for macOS.

The stack follows Masa (`../masa/AGENTS.md`): Clean Architecture, feature-first folders, `@Observable` state,
protocol-driven repositories, async/await, Swift Testing.

> **Rule of thumb:** when this document and the code disagree, the code wins. Copy the closest existing pattern.

## 1. Project facts

| Item | Value |
|------|-------|
| Module | `Copaste` (`@testable import Copaste`) |
| Platform | macOS 26.0+ only. iOS support was removed; don't add `#if os(iOS)` code back unless asked. |
| Swift | Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency. Pure value types are `nonisolated`. |
| Project | Xcode project with synchronized folders (new files are picked up automatically). No Swift packages. |
| Targets | `Copaste` (app), `CopasteTests` (Swift Testing, macOS host), `CopasteUITests` (XCUITest E2E, `CopasteE2E` scheme) |
| Localization | `Copaste/App/Resources/Localizable.xcstrings`, **generated** from `scripts/strings.py` (English, Indonesian) |
| Storage | The user's vault folder (JSON, one file per entry). `UserDefaults` (through `AppDefaults.store`) only for per-Mac preferences: the vault bookmark, shortcuts (`HotKeyStore`), text size and the clipboard window position (`PanelPlacement`). |
| Network | LinkPresentation, to fetch a copied link's title, favicon and preview image; and GitHub's releases API when Settings › Updates is opened (`GitHubReleasesDataSource`). |
| Support | Feedback and bug reports go to `admin@lazycatlabs.com` (`SupportLinks`); website `https://copaste.lazycatlabs.com`. |
| Commits | Conventional Commits, one commit per change. No AI co-author lines. |
| CI | GitHub Actions: `pull_request-ci.yml` (SwiftLint, generated strings, unit tests; E2E by hand via Run workflow) and `merge-ci.yml` (ad-hoc DMG + zip artifact, deletes the merged branch). |

## 2. Commands

```bash
python3 scripts/strings.py
swiftlint
xcodebuild -project Copaste.xcodeproj -scheme Copaste -destination 'platform=macOS' build
xcodebuild -project Copaste.xcodeproj -scheme Copaste -destination 'platform=macOS' test
scripts/e2e.sh   # E2E UI tests; screenshots in e2e-output/ (git-ignored). Drives the real mouse; quits a running Copaste.
```

E2E runs launch the app with `-e2e` (Debug only, see `AppDefaults.swift` / `E2EFixtures.swift`): a throwaway vault with
sample entries, a private clipboard and separate preferences, plus commands sent as distributed notifications.

## 3. Layout

```text
Copaste/
├── App/
│   ├── CopasteApp.swift            # @main: the menu bar item
│   ├── DI/AppContainer.swift       # Composition root: vault location + session
│   ├── DI/ClipboardSession.swift   # The open vault's history; the one place entries change
│   ├── MacAppDelegate.swift        # Global shortcut, Settings/welcome windows, menu bar menu
│   ├── MacWindows.swift            # Hand-hosted windows, ordered front even when Copaste isn't active
│   └── Resources/
├── Core/                           # DesignSystem (tokens, L()), Storage (JSONFileStore), Logging, Platform, Input
└── Features/
    ├── Clipboard/                  # Domain (ClipItem, ClipClassifier, ColorValue, TimeSection, ClipAction, ClipUseCases)
    │                               # Data (FileClipRepository, SystemPasteboard, LinkMetadata, TextRecognition, PasteSimulator)
    │                               # Presentation (ClipboardViewModel, list/detail views, the floating panel)
    ├── Annotate/                   # SwiftUI Canvas editor; marks use 0…1 coordinates
    ├── Settings/                   # AppSettings (vault config), SupportLinks and SettingsView
    └── Vault/                      # Folder picking and the bookmark
```

## 4. Rules

- Data flows DataSource → Repository → UseCase / ClipboardSession → View. Business rules live in `ClipUseCases` or entities so they can be unit-tested.
- Pasteboard types become `CapturedContent`, then `ClipKind` via `ClipClassifier`. Views compare enums.
- **No magic numbers** (`Spacing`, `Radius`, `Opacity`, `Metrics.<Area>`). **No hardcoded strings**: add keys to `scripts/strings.py`, run it, use `L(.key)` / `Text(.key)`.
- Vault writes go through `ClipboardSession.persist`, which reports failures to the user. Never fail silently.
- Vault format must stay backward compatible: new `AppSettings` fields need defaults; new `ClipItem` fields must be optional.
- Never record secrets: `SystemPasteboard` skips `org.nspasteboard.ConcealedType` / `TransientType`, and `AppSettings.ignoredApps` is checked in `ClipboardSession.handle`.
- Use `Log`, never `print`.

## 5. Vault format

```text
<vault>/
├── .copaste/config.json   # AppSettings
├── items/<uuid>.json      # ClipItem
└── blobs/                 # <uuid>.png images, <uuid>-icon favicons, <uuid>-preview link images
```

## 6. Platform notes

- Menu bar app (`LSUIElement`), sandbox off. The clipboard is polled every 0.5 s. The floating window is a
  non-activating `NSPanel`, so the previous app stays in front and receives ⌘V (needs Accessibility; without it
  Copaste only copies). Keyboard shortcuts are handled by a local key monitor in `ClipboardPanelController`.
- A single click on an entry selects it; double-click copies it and closes the window (a toast confirms on screen).
  ↩ pastes, ⌘↩ copies.
- The global shortcut (default ⇧⌘V) is recorded in Settings and re-registered through `HotKeyStore.onChange`.
- Copy and paste sounds are the system alert sounds (`ClipSound`, played by `SoundPlayer`).
- Tests must never touch the real clipboard: give `ClipboardSession` a `SystemPasteboard(pasteboard:)` with a private
  `NSPasteboard(name:)`. A running Copaste would otherwise record test data into the user's vault.
- The ad-hoc signature changes every build, so Accessibility may need granting again in debug builds.
- **Releases:** bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`, add a `## X.Y.Z — <date>` section to
  `CHANGELOG.md`, run `scripts/make_release.sh` (DMG + zip, prints the zip's sha256), tag `vX.Y.Z`, publish with
  `gh release create` (notes: that changelog section plus the install block), then update `Casks/copaste.rb` in
  `lazycatlabs/homebrew-tap`.
