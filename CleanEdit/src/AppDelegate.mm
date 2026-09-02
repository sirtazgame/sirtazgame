#import "AppDelegate.h"
#import "MainWindowController.h"

@implementation AppDelegate {
    MainWindowController *_controller;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _controller = [[MainWindowController alloc] init];
    [self buildMenu];
    [_controller showWindow];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)buildMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    // App menu
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"About CleanEdit"
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit CleanEdit"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
    appItem.submenu = appMenu;

    // File menu
    NSMenuItem *fileItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:fileItem];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [self add:fileMenu title:@"New File" action:@selector(newFile:) key:@"n" flags:NSEventModifierFlagCommand];
    [self add:fileMenu title:@"Open File\u2026" action:@selector(openFile:) key:@"o" flags:NSEventModifierFlagCommand];
    [self add:fileMenu title:@"Open Folder\u2026" action:@selector(openFolder:) key:@"o" flags:(NSEventModifierFlagCommand | NSEventModifierFlagShift)];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [self add:fileMenu title:@"Save" action:@selector(saveFile:) key:@"s" flags:NSEventModifierFlagCommand];
    [self add:fileMenu title:@"Close Tab" action:@selector(closeCurrentTab:) key:@"w" flags:NSEventModifierFlagCommand];
    fileItem.submenu = fileMenu;

    // View menu
    NSMenuItem *viewItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:viewItem];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    [self add:viewMenu title:@"Toggle Console" action:@selector(toggleConsole:) key:@"j" flags:NSEventModifierFlagCommand];
    viewItem.submenu = viewMenu;

    // Scripts menu
    NSMenuItem *scriptsItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:scriptsItem];
    NSMenu *scriptsMenu = [[NSMenu alloc] initWithTitle:@"Scripts"];
    [self add:scriptsMenu title:@"Run Current File as Script" action:@selector(runFocusedScript:) key:@"r" flags:NSEventModifierFlagCommand];
    scriptsItem.submenu = scriptsMenu;

    // Edit menu (standard, gives Cut/Copy/Paste/Undo)
    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:editItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = editMenu;

    NSApp.mainMenu = mainMenu;
}

- (void)add:(NSMenu *)menu title:(NSString *)title action:(SEL)action key:(NSString *)key flags:(NSEventModifierFlags)flags {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.keyEquivalentModifierMask = flags;
    item.target = _controller;  // route custom commands to the window controller
    [menu addItem:item];
}

@end
