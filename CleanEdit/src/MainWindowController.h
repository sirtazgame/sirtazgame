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
    NSTextViewDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>
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
@end
