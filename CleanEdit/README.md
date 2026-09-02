# CleanEdit

A minimal, modern, dark-themed code editor for macOS — written in C++ (Objective-C++ / Cocoa).
Think "VSCode, but without all the clutter": just a folder tree, an editor, a console, a
scripting system, and settings.

![CleanEdit](docs/screenshot.png)

## Features

- **Explorer** — open a folder and browse it as a tree. **One click opens a file.**
- **Editor** — clean monospaced editor with line numbers, syntax highlighting, tabs,
  undo/redo, and multiple open documents.
- **Console** — output panel for script results and errors (toggle with `⌘J`).
- **Scripts** — write your own automations in **JavaScript** or **Python** and run them
  against the current document. Bind **custom keyboard shortcuts** to any script.
- **Session restore** — reopens your last folder and tabs automatically on launch.
- **Settings** — font size, tab width, line numbers, word wrap, console visibility.
- **Dark theme** throughout, VSCode-inspired palette.

## Syntax highlighting

Bundled languages: **C++, Python, JavaScript, JSON, Markdown**, plus your own
**`.npa`** and **`.tpa`** formats.

Highlighting is defined by simple JSON files in `Resources/languages/`. To tweak the
`.npa` / `.tpa` grammars (keywords, comments, section headers, etc.) just edit
`Resources/languages/npa.json` and `tpa.json` — no recompilation of grammars needed;
rebuild the app to bundle the changes. Each definition supports:

```json
{
  "name": "MyLang",
  "extensions": ["npa"],
  "lineComment": "#",
  "blockCommentStart": "/*",
  "blockCommentEnd": "*/",
  "stringDelimiters": ["\"", "'"],
  "functionCalls": true,
  "keywords": ["if", "else"],
  "types": ["int", "node"],
  "builtins": ["print"],
  "rules": [
    { "pattern": "^\\s*\\[[^\\]]+\\]", "type": "heading", "multiline": true }
  ]
}
```
Token `type` values map to theme colors: `keyword`, `type`, `builtin`, `number`,
`string`, `comment`, `function`, `heading`, `attribute`.

## Build & run

Requirements: **macOS 11+** and **Xcode Command Line Tools** (`xcode-select --install`).
Python scripting additionally needs **Python 3** (`python3` on your `PATH`).

### Option A — build script (simplest)
```bash
cd CleanEdit
chmod +x build.sh
./build.sh
open build/CleanEdit.app
```

### Option B — CMake
```bash
cd CleanEdit
cmake -B build
cmake --build build
open build/CleanEdit.app
```

## Scripting

Scripts live in `~/Library/Application Support/CleanEdit/scripts/`. The bundled examples
are copied there on first launch. Use the **Scripts** tab (the `</>` icon in the activity
bar) to run, create, edit and refresh them. Double-click a script to run it; single-click
to open it in the editor.

### JavaScript API (powered by JavaScriptCore)
A global `editor` object is available:

```js
editor.getText()                 // full document text
editor.setText("...")            // replace whole document
editor.getSelection()            // selected text
editor.replaceSelection("...")   // replace the selection
editor.insertText("...")         // insert at the cursor
editor.getFilePath()             // path of current file ("" if unsaved)
editor.getLineCount()            // number of lines
editor.log("message")            // print to the console
console.log("also works")
```

### Python API
Import the bundled `cleanedit` module:

```python
import cleanedit

text = cleanedit.get_text()
cleanedit.log("Hello!")
cleanedit.set_text(text.upper())
cleanedit.insert("...")
cleanedit.replace_selection("...")
sel  = cleanedit.get_selection()
path = cleanedit.get_file_path()
```
Anything printed with `print()` also appears in the console. Python scripts run in a
subprocess, so `import`-ing any installed package works normally.

You can also press `⌘R` to run the currently focused editor buffer as a script.

### Script shortcuts
Right-click any script in the **Scripts** panel and choose **Assign Shortcut…** to bind a
key combination (e.g. `⌘⇧U`). The shortcut appears next to the script name and is added to
the **Scripts** menu, so it works anywhere in the app. Bindings persist across launches;
use **Clear Shortcut** to remove one.

## Keyboard shortcuts

| Action | Shortcut |
|---|---|
| New file | `⌘N` |
| Open file | `⌘O` |
| Open folder | `⇧⌘O` |
| Save | `⌘S` |
| Close tab | `⌘W` |
| Toggle console | `⌘J` |
| Run current file as script | `⌘R` |

## Project layout
```
CleanEdit/
├── build.sh                # one-command build
├── CMakeLists.txt          # alternative CMake build
├── Info.plist
├── Resources/
│   ├── languages/*.json    # syntax definitions (edit these!)
│   └── scripts/            # bundled example scripts + cleanedit.py
└── src/                    # Objective-C++ source
    ├── main.mm
    ├── AppDelegate.*        # app + menu bar
    ├── MainWindowController.* # window, tabs, editor, console, settings
    ├── FileTreeController.* # explorer folder tree
    ├── SyntaxHighlighter.*  # JSON-driven highlighter
    ├── LineNumberRulerView.*# gutter line numbers
    ├── ScriptManager.*      # discover/install/run scripts
    ├── ScriptRunner.*       # JavaScript + Python runners
    ├── EditorBridge.*       # API exposed to scripts
    └── Theme.*              # dark color palette + fonts
```

## Notes
- The app is unsigned. On first launch macOS Gatekeeper may block it — right-click the
  app and choose **Open**, or run `xattr -dr com.apple.quarantine build/CleanEdit.app`.
