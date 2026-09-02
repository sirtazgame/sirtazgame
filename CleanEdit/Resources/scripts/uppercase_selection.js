// Uppercase the currently selected text.

var sel = editor.getSelection();
if (sel.length === 0) {
    editor.log("Select some text first, then run this script.");
} else {
    editor.replaceSelection(sel.toUpperCase());
    editor.log("Uppercased " + sel.length + " characters.");
}
