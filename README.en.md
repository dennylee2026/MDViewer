# MDViewer

A native macOS Markdown reader and editor focused on beautiful typography and reading experience.

> Screenshot coming soon

[中文 README](README.md)

## Features

### File Management
- **⌘O** Open file picker — automatically navigates to the last used directory
- **⌘N** New blank window
- **⌘⇧O** Open folder — shows all `.md` / `.markdown` files in a left sidebar (recursive subdirectory support)
- Open files by double-clicking in Finder or dragging into the window
- **File > Open Recent** — quick access to the last 10 opened files
- Auto-reload when the file is modified externally (FSEvents)

### View Modes
| Shortcut | Mode | Description |
|----------|------|-------------|
| ⌘1 | Editor | Full-screen editor, no sidebar |
| ⌘2 | Split | Editor on the left, live preview on the right |
| ⌘3 | Preview | Full-screen preview with table of contents sidebar |

### Editor
- Markdown syntax highlighting: headings (Google colors), bold, italic, inline code, links, strikethrough, blockquotes, code blocks
- Line numbers
- **⌘F** Find & Replace (native Find Bar)
- Full IME compatibility (Chinese, Japanese)
- Configurable font in Preferences: SF Pro (default) / Menlo (monospace) / Palatino (serif)

### Split Sync
- Clicking in the editor automatically scrolls the preview to the corresponding position
- Uses the nearest heading as an anchor — code blocks do not cause vertical drift
- The target element appears at the same proportional vertical position in the preview as the cursor in the editor

### Preview Rendering
- Google brand heading colors: H1 blue / H2 red / H3 yellow / H4 green
- Code block syntax highlighting via highlight.js (Swift support built-in)
- Images scale to fit width
- Automatically follows system light/dark appearance

### Themes
Choose a preview theme in **⌘,** Preferences:
- Follow System (default)
- Always Light
- Always Dark
- Sepia (vintage paper)

### Table of Contents
- Preview mode (⌘3) shows an auto-generated outline supporting H1–H6 with indent levels
- Click any heading to smoothly scroll to that section

### Zoom
- **⌘=** / **⌘-** / **⌘0** or toolbar buttons — range 50%–300%
- Editor font size and preview page zoom stay in sync
- New windows inherit the last used zoom level

### Save & Export
| Shortcut | Action |
|----------|--------|
| ⌘S | Save; prompts Save As for new files |
| ⌘⇧S | Save As |
| ⌘E | Export as PDF (based on current rendering) |
| ⌘⇧E | Export as HTML (self-contained file with inlined theme CSS) |

### Multi-Window
- Each file opens in its own fully independent window
- If the current window is blank and unedited, opening a file reuses it — no unnecessary empty windows
- Toolbar shows an orange "Unsaved" indicator for unsaved changes; a brief "Saved ✓" toast appears after saving

### Help
- **⌘?** Opens the built-in feature guide

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
