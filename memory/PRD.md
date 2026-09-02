# CleanEdit — PRD

## Problem statement
A clean, simple, modern (VSCode-like but minimal) text editor written in C++ for macOS.
Required areas: Explorer (folder tree), main text editor, console, custom scripting, settings.

## User choices (2026-06)
- GUI: Native Cocoa / Objective-C++ (AppKit)
- Scripting languages: Python + JavaScript
- Syntax highlighting: common langs (C++, Python, JS, JSON, Markdown) + custom `.npa` and `.tpa`
- Theme: Dark only
- Delivery: full source + build instructions (built on user's Mac; cannot run in cloud env)
- Extra: one-click open from folder tree; scripting is the priority feature

## Architecture
- Native macOS app, Objective-C++ (`.mm`), AppKit + JavaScriptCore.
- Build via `build.sh` (clang++) or CMake -> `CleanEdit.app` bundle.
- Frameworks: Cocoa, JavaScriptCore.
- JSON-driven syntax highlighter (`Resources/languages/*.json`) — user-editable grammars.
- Scripting: JavaScript via embedded JavaScriptCore (`editor` global); Python via `python3`
  subprocess with a `cleanedit` helper module + `##CE##` JSON stdout protocol.
- Scripts stored in `~/Library/Application Support/CleanEdit/scripts/` (examples auto-installed).

## Implemented (2026-06) (Explorer / Scripts / Settings) with panel switching.
- Explorer folder tree (NSOutlineView), single-click opens files.
- Editor: NSTextView, line-number gutter, syntax highlighting, tabs, multi-document,
  undo/redo, non-wrapping by default.
- Console output panel (toggle ⌘J), colored by message type; script stdout/stderr routed here.
- Scripts panel: list/run (double-click)/edit (single-click)/new/refresh/reveal-folder.
- Settings: font size, tab width, line numbers, word wrap, console visibility (NSUserDefaults).
- Dark VSCode-inspired theme; menu bar with standard + custom shortcuts.
- Languages bundled: C++, Python, JavaScript, JSON, Markdown, NPA, TPA.
- Script shortcuts: bind custom key combos to scripts (right-click → Assign Shortcut); shown
  in the script list, registered as Scripts-menu items, persisted in NSUserDefaults.
- Session restore: last folder + open tabs + active tab reopened on launch.
- Find & Replace bar (⌘F) with all-match highlighting, next/prev (⌘G/⇧⌘G), case toggle,
  replace + replace-all, live match count.
- Go to Line (⌘L) jump box.
- Script arguments: `@prompt:` directive in a script triggers an input dialog before running;
  value exposed as `cleanedit.get_arg()` (Python) / `editor.getArg()` & `argument` (JS).

## Verification status
- JSON grammars validated; Python scripts compile; brace/paren balance verified.
- NOT compiled/run here (Linux cloud lacks macOS frameworks). Needs Xcode CLT on macOS.

## Backlog / Next
- Auto-indent / bracket matching.
- Refine `.npa` / `.tpa` grammars to the real language spec (placeholders for now).
- Split editor / side-by-side.
- App icon, code signing/notarization instructions.
