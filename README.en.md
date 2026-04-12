# MDViewer

**Markdown on macOS, the way it should feel.**

MDViewer is a fully native macOS Markdown reader and editor -- built with SwiftUI + AppKit, no Electron, no web views. It does one thing well: lets you write and read Markdown with the speed and polish of a first-party Mac app. Bidirectional sync between editor and preview is accurate to the heading level, and a single JSON file gives you full control over every typographic detail, hot-reloaded on save.

> Screenshot coming soon

[中文 README](README.md)

---

## Why MDViewer

**Truly native** -- Not a browser in disguise. Fast launch, low memory, and window behavior that respects macOS conventions.

**Editor and preview actually stay in sync** -- Click anywhere in the editor and the preview scrolls to the exact corresponding paragraph. Click in the preview and the editor follows. Positioning is anchored to headings, so long code blocks never cause the preview to drift.

**One JSON file controls all styling** -- Most Markdown editors limit themes to a color swap. MDViewer's `styles.json` defines everything: editor font, size, line height, syntax highlight colors, and the complete CSS for every Markdown element in the preview -- from H1 through tables, code blocks, and blockquotes. The app hot-reloads the moment you save.

**Write in Chinese or Japanese without a single glitch** -- Full IME support that never swallows characters, jumps the cursor, or breaks candidate selection.

## View Modes

| Shortcut | Mode | Description |
|----------|------|-------------|
| ⌘1 | Editor | Distraction-free writing |
| ⌘2 | Split | Editor on the left, live preview on the right |
| ⌘3 | Preview | Full-screen preview with table of contents sidebar (H1--H6, click to jump) |

## Style System

Three built-in styles, ready to use:

| Style | Description |
|-------|-------------|
| **GDS-Style** (default) | Four-color headings: H1 blue / H2 red / H3 yellow / H4 green, white background |
| **Dark** | Dark background with a low-contrast palette |
| **Sepia** | Warm vintage paper tone |

Want to customize? Open Preferences (⌘,), click "Open Config File", and edit `styles.json`:

```
~/Library/Application Support/MDViewer/styles.json
```

Each style has two sections: **editor** (font, size, line height, per-element highlight colors) and **display** (complete CSS covering every Markdown element). Save the file and the app reloads instantly -- no restart. If the config file is corrupt, built-in defaults are silently restored.

## Editor

- Markdown syntax highlighting: headings, bold, italic, inline code, links, strikethrough, blockquotes, code blocks (colors defined by the active style)
- Line numbers
- ⌘F Find and Replace (native Find Bar)
- Code block syntax highlighting via highlight.js (Swift support built-in)
- Images scale to fit width

## Files and Windows

- **⌘O** Open file / **⌘N** New window / **⌘⇧O** Open folder sidebar (recursively lists all `.md` files)
- Open by double-clicking in Finder or dragging onto the window
- Recent files list (File > Open Recent, up to 10 entries)
- Auto-reload when the file changes externally (FSEvents)
- Each file gets its own independent window; blank windows are reused intelligently
- Toolbar shows unsaved-changes indicator

## Save and Export

| Shortcut | Action |
|----------|--------|
| ⌘S | Save (prompts Save As for new files) |
| ⌘⇧S | Save As |
| ⌘E | Export as PDF |
| ⌘⇧E | Export as standalone HTML (CSS inlined, single shareable file) |

## Zoom

⌘= / ⌘- / ⌘0 (or toolbar buttons), range 50%--300%. Editor font size and preview zoom stay in sync. New windows inherit the last used zoom level.

## Help

⌘? opens the built-in feature guide.

---

## Requirements

- macOS 14.0+
- Xcode 15+

## Building

```bash
git clone https://github.com/dennylee2026/MDViewer.git
cd MDViewer
open MDViewer.xcodeproj
```

Select **My Mac** as the target in Xcode and press **⌘R** to build and run.

## Development

Feature development happens on the `dev` branch and is merged into `main` when stable. See [CHANGELOG.md](CHANGELOG.md) for the full history.
