<p align="center">
  <img src="docs/icon.png" alt="Snapsol" width="128">
</p>

<h1 align="center">Snapsol</h1>

<p align="center">
  English · <a href="README.ja.md">日本語</a>
</p>

A personal macOS screenshot app that lives in the menu bar. Capture, share instantly, annotate, and grab text from the screen.
Built from scratch as a minimal take on [Screendrop](https://github.com/fayazara/screendrop) (CC0).

## Features

| Action | Default shortcut |
| --- | --- |
| Capture full screen (the display under the cursor) | ⌥1 |
| Capture a window | ⌥2 |
| Capture an area | ⌥3 |
| Copy text from an area (OCR, Japanese and English) | ⌥4 |

- **Preview cards**: new captures stack up in the bottom-right corner. Copy, save, annotate, delete, or drag them into other apps. Cards stay open while you hover over them.
- **Annotation editor**: rectangles, arrows, text, and mosaic, with select / move / resize and undo. Saving burns the annotations into the image.
- **History**: the 5 most recent captures in the menu bar (click to copy), plus a grid window of everything.
- **Settings**: rebind shortcuts, choose what happens after a capture (show card / copy to clipboard / open editor), and set how long cards stay open.

Where files go:

- Capture history: `~/Library/Application Support/Snapsol/` (`History/` and `history.json`)
- "Save" exports to: `~/Pictures/Snapsol/`

## Build

Requirements: macOS 26 or later, Xcode 27, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
xcodegen generate
xcodebuild -project Snapsol.xcodeproj -scheme Snapsol -derivedDataPath build build
open build/Build/Products/Debug/Snapsol.app
```

Tests:

```sh
xcodebuild -project Snapsol.xcodeproj -scheme Snapsol -derivedDataPath build test
```

The app icon lives in `Resources/Snapsol.icon` and can be edited in Icon Composer. actool compiles it into `Assets.car` at build time.

On first launch, macOS asks for Screen Recording permission. Grant it in System Settings, then relaunch the app.
Because the app is signed with a Team ID, the permission survives rebuilds.

## Architecture

```
Snapsol/
├─ App/             AppDelegate and AppContainer (the only place that wires dependencies)
├─ Domain/          Value types and pure logic (annotations, hotkeys, history, reading order, card state machine)
├─ Application/     Use cases and state (capture flow, history, hotkeys, editor) plus Ports (protocols)
├─ Infrastructure/  Port implementations (screencapture, Carbon, Vision, files, rendering)
└─ Presentation/    AppKit / SwiftUI UI
```

Dependencies point this way. Infrastructure implements the Ports defined by Application.

```
Presentation ─→ Application ─→ Domain
                    ↑
             Infrastructure
```

The test target compiles without App and Presentation, so if Domain / Application / Infrastructure references a type
from Presentation or App, the test build fails.
Framework imports such as `import AppKit` are not caught by the compiler, so that part is kept in check by review.
