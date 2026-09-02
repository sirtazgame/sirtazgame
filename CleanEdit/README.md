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

The `.npa` grammar highlights `##` comment rows, `[TAG]` section markers (named tags in one
color, numeric IDs in another), `>`/`<` legend rows, and binary/number data. The `.tpa`
grammar highlights `> name.mpa` segment names, `^ ` comments, `##====##` borders, and `>>`
segment starters. Tweak any of these by editing `Resources/languages/npa.json` /
`tpa.json` (see the flexible format below) and rebuilding.

### NPA legend colors & data modes
A `.npa` file can carry a **legend** that drives its own colors. Put a `>` on the first
legend row and a `<` on the last; between them, write `color: TAG, TAG` lines. The color can
be a name (`red`, `green`, `blue`, `yellow`, `cyan`, `magenta`, `orange`, `purple`, `pink`,
`brown`, `gray`, `white`, `black`) or a hex code (`#ff8800`). Each tag's color is applied to
its `[TAG]` marker **and** the data lines beneath it:

```
>
red: FILE, WORD
#3bd6a0: DATA
<
[FILE]
    [WORD]  [ID]
    [DATA]
        0
        1
```

The raw data styling is controlled by a **mode** that a Python/JS script sets
(`cleanedit.set_mode(...)` / `editor.setMode(...)`), matching your Numbers / Mix / Binary
types:
- `binary` — only `0`/`1` are colored
- `numbers` — all digit runs are colored (default)
- `mix` — both words and numbers are colored

Run the bundled `npa_mode.py` script to switch modes on the fly. `^` rows are shown in gray.

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
editor.getArg()                  // value from an @prompt directive (see below)
editor.log("message")            // print to the console
editor.setMode("binary")         // .npa data mode: numbers | binary | mix
console.log("also works")
```
The global `argument` variable also holds the `@prompt` value.

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
arg  = cleanedit.get_arg()        # value from an @prompt directive (see below)
cleanedit.set_mode("binary")      # .npa data mode: numbers | binary | mix
```
Anything printed with `print()` also appears in the console. Python scripts run in a
subprocess, so `import`-ing any installed package works normally.

### Script arguments (`@prompt`)
Add a directive comment near the top of a script and CleanEdit will ask for a value
before running it, passing it to the script:

```python
# @prompt: What is your name?
import cleanedit
cleanedit.insert("Hello, " + (cleanedit.get_arg() or "world") + "!")
```
```js
// @prompt: Wrap selection with tag
editor.replaceSelection("<" + argument + ">" + editor.getSelection() + "</" + argument + ">");
```
This works whether the script is run from the panel or via a keyboard shortcut. Cancelling
the prompt cancels the run.

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
| Find | `⌘F` |
| Find next / previous | `⌘G` / `⇧⌘G` |
| Go to line | `⌘L` |

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
