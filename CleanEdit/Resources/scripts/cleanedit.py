"""CleanEdit Python scripting bridge.

Import this module in your Python scripts to interact with the editor:

    import cleanedit
    text = cleanedit.get_text()
    cleanedit.log("Hello!")
    cleanedit.set_text(text.upper())

All output printed with print() also appears in the CleanEdit console.
"""
import os
import sys
import json

_MARKER = "##CE##"


def _send(cmd):
    sys.stdout.write(_MARKER + json.dumps(cmd) + "\n")
    sys.stdout.flush()


def get_text():
    """Return the full text of the current document."""
    path = os.environ.get("CLEANEDIT_INPUT")
    if not path or not os.path.exists(path):
        return ""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def get_selection():
    """Return the currently selected text (empty string if none)."""
    path = os.environ.get("CLEANEDIT_SELECTION")
    if not path or not os.path.exists(path):
        return ""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def get_file_path():
    """Return the path of the current file (empty string if unsaved)."""
    return os.environ.get("CLEANEDIT_FILE", "")


def set_text(text):
    """Replace the entire document content."""
    _send({"action": "setText", "value": str(text)})


def insert(text):
    """Insert text at the current cursor position."""
    _send({"action": "insertText", "value": str(text)})


def replace_selection(text):
    """Replace the current selection with new text."""
    _send({"action": "replaceSelection", "value": str(text)})


def log(message):
    """Print a message to the CleanEdit console."""
    _send({"action": "log", "value": str(message)})
