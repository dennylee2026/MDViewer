English | [中文](README.md)

# MDViewer

**Your Mac deserves a Markdown editor that actually feels native.**

Most Markdown tools are either a website stuffed inside a browser shell, or something that types like Notepad. MDViewer is different — built from scratch with SwiftUI + AppKit, it launches instantly, uses almost no memory, and behaves exactly like a first-party Mac app should. Writing Markdown doesn't have to be a compromise.

---

## Why MDViewer

**Native, not wrapped** — No Electron. No web view. No Chromium process quietly eating your RAM. MDViewer runs directly on AppKit. It opens in milliseconds, and closing the window means it's actually gone.

**Editor and preview that genuinely stay in sync** — Click anywhere in the editor and the preview scrolls to the exact paragraph. Click in the preview and the editor jumps to match. Sync is anchored to headings, so long code blocks never make the preview drift. When you're writing something long, this matters more than you'd think.

**Style everything, see changes instantly** — Other editors swap themes and call it customization. MDViewer's `styles.json` gives you full control: editor font, size, line height, syntax highlight colors, and the complete CSS for every Markdown element in the preview — H1 through tables, code blocks, and blockquotes. Save the file and the app reloads live. Tweak until it's perfect.

**CJK input that just works** — Type Chinese or Japanese without a single dropped character, cursor jump, or broken candidate selection. It sounds like table stakes. Very few editors actually get it right.

**Export for every context** — Desktop PDF, mobile PDF (390pt wide, optimized for phone reading), mobile PNG screenshot, standalone HTML, or hit Export All and get everything at once.

---

## View Modes

| Shortcut | Mode | Description |
|----------|------|-------------|
| ⌘1 | Editor | Distraction-free writing, nothing else in sight |
| ⌘2 | Split | Editor on the left, live preview on the right |
| ⌘3 | Preview | Full-screen preview with table of contents sidebar (H1–H6, click to jump) |

## Style System

Three built-in styles, ready out of the box:

| Style | Description |
|-------|-------------|
| **GDS-Style** (default) | Four-color headings: H1 blue / H2 red / H3 yellow / H4 green — information hierarchy at a glance |
| **Dark** | Dark background with a low-contrast palette — easy on the eyes for long sessions |
| **Sepia** | Warm vintage paper tone — the best atmosphere for reading long documents |

Want to go further? Open Preferences (⌘,), click "Open Config File", and edit `styles.json`:

```
~/Library/Application Support/MDViewer/styles.json
```

Each style has two sections: **editor** (font, size, line height, per-element highlight colors) and **display** (complete CSS covering every Markdown element). Save and the app reloads instantly — no restart needed. If the config file ever gets corrupted, built-in defaults are silently restored.

## Editor

- Markdown syntax highlighting: headings, bold, italic, inline code, links, strikethrough, blockquotes, fenced code blocks (colors defined by the active style)
- Line numbers
- ⌘F Find and Replace (native Find Bar)
- Code block syntax highlighting via highlight.js (Swift support built-in)
- Images scale to fit width

## Files and Windows

- **⌘O** Open file / **⌘N** New window / **⌘⇧O** Open folder sidebar (recursively lists all `.md` files)
- Open by double-clicking in Finder or dragging onto the window
- Recent files list (File > Open Recent, up to 10 entries)
- Auto-reloads when the file changes externally (FSEvents)
- Each file gets its own independent window; blank windows are reused intelligently
- Toolbar shows unsaved-changes indicator

## Save and Export

| Shortcut | Action |
|----------|--------|
| ⌘S | Save (prompts Save As for new files) |
| ⌘⇧S | Save As |
| ⌘E | Export as desktop PDF |
| ⌘⇧E | Export as standalone HTML (CSS inlined, single shareable file) |
| — | Export as mobile PDF (390pt wide, optimized for phone reading) |
| — | Export as mobile PNG (high-res screenshot, great for sharing) |
| — | Export All (desktop PDF + mobile PDF + mobile PNG in one shot) |

## Zoom

⌘= / ⌘- / ⌘0 (or toolbar buttons), range 50%–300%. Editor font size and preview zoom stay in sync. New windows inherit the last used zoom level.

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
