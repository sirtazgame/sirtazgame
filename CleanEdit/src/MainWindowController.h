#import <Cocoa/Cocoa.h>
#import "EditorHost.h"
#import "FileTreeController.h"

// A single open document (tab).
@interface OpenDocument : NSObject
@property (strong) NSURL *url;            // nil for an untitled document
@property (copy) NSString *displayName;
@property (copy) NSString *text;          // last loaded / saved snapshot
@property (assign) BOOL modified;
@end

@interface MainWindowController : NSObject <EditorHost, FileTreeDelegate,
    NSTextViewDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>
- (void)showWindow;
- (NSWindow *)window;

// Menu actions
- (void)newFile:(id)sender;
- (void)openFile:(id)sender;
- (void)openFolder:(id)sender;
- (void)saveFile:(id)sender;
- (void)closeCurrentTab:(id)sender;
- (void)toggleConsole:(id)sender;
- (void)runFocusedScript:(id)sender;
- (void)showFindBar:(id)sender;
- (void)findNext:(id)sender;
- (void)findPrevious:(id)sender;
- (void)gotoLine:(id)sender;

// Called by the app delegate to give the controller the Scripts submenu so it can
// register user-defined script shortcuts as menu items.
- (void)setScriptsMenu:(NSMenu *)menu;
@end
