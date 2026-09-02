// Example JavaScript script for CleanEdit.
// The global `editor` object lets you interact with the current document.

editor.log("Hello from JavaScript!");
editor.log("Current file: " + (editor.getFilePath() || "(unsaved)"));
editor.log("Line count: " + editor.getLineCount());

var sel = editor.getSelection();
if (sel.length > 0) {
    editor.log("You have " + sel.length + " characters selected.");
}
