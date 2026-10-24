# AGENTS.md

Guide for AI agents working on Copaste, a clipboard manager for macOS and iOS.

The stack follows Masa (`../masa/AGENTS.md`): Clean Architecture, feature-first folders, `@Observable` state,
protocol-driven repositories, async/await, Swift Testing.

> **Rule of thumb:** when this document and the code disagree, the code wins. Copy the closest existing pattern.

## 1. Project facts

| Item | Value |
|------|-------|
| Module | `Copaste` (`@testable import Copaste`) |
| Platforms | One multiplatform target: macOS 26.0+ and iOS 26.0+ (`SDKROOT = auto`). Platform code is wrapped in `#if os(macOS)` / `#if os(iOS)`. |
| Swift | Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency. Pure value types are `nonisolated`. |
| Project | Xcode project with synchronized folders (new files are picked up automatically). No Swift packages. |
| Targets | `Copaste` (app), `CopasteTests` (Swift Testing, macOS host) |
| Localization | `Copaste/App/Resources/Localizable.xcstrings`, **generated** from `scripts/strings.py` (English, Indonesian) |
| Storage | The user's vault folder (JSON, one file per entry). `UserDefaults` only for the vault bookmark and the iOS pasteboard change count. |
| Network | Only LinkPresentation, to fetch a copied link's title, favicon and preview image. |
| Commits | Conventional Commits, one commit per change. No AI co-author lines. |

## 2. Commands

```bash
python3 scripts/strings.py
swiftlint
xcodebuild -project Copaste.xcodeproj -scheme Copaste -destination 'platform=macOS' build
xcodebuild -project Copaste.xcodeproj -scheme Copaste -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
xcodebuild -project Copaste.xcodeproj -scheme Copaste -destination 'platform=macOS' test
```

## 3. Layout

```text
Copaste/
├── App/
│   ├── CopasteApp.swift            # @main: MenuBarExtra on macOS, WindowGroup on iOS
│   ├── DI/AppContainer.swift       # Composition root: vault location + session
│   ├── DI/ClipboardSession.swift   # The open vault's history; the one place entries change
│   ├── Mac/                        # App delegate (⇧⌘V hot key), hand-hosted windows, menu
│   └── Resources/
├── Core/                           # DesignSystem (tokens, L()), Storage (JSONFileStore), Logging, Platform, Input
└── Features/
    ├── Clipboard/                  # Domain (ClipItem, ClipClassifier, ColorValue, TimeSection, ClipAction, ClipUseCases)
    │                               # Data (FileClipRepository, SystemPasteboard, LinkMetadata, TextRecognition, PasteSimulator)
    │                               # Presentation (ClipboardViewModel, shared views, Mac panel, iOS screens)
    ├── Annotate/                   # Shared SwiftUI Canvas editor; marks use 0…1 coordinates
    ├── Settings/                   # AppSettings (vault config) and SettingsView
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

- **macOS:** menu bar app (`LSUIElement`), sandbox off. The clipboard is polled every 0.5 s. The floating window is a
  non-activating `NSPanel`, so the previous app stays in front and receives ⌘V (needs Accessibility; without it
  Copaste only copies). Keyboard shortcuts are handled by a local key monitor in `ClipboardPanelController`.
  The ad-hoc signature changes every build, so Accessibility may need granting again in debug builds.
- **iOS:** apps can't watch the clipboard. Copaste reads it when it becomes active (setting `captureOnOpen`, shows the
  system paste prompt unless allowed in Settings) and via `PasteButton` (no prompt). The vault is a folder picked in
  Files, kept with a security-scoped bookmark.
