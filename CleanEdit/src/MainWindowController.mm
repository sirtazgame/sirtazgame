#import "MainWindowController.h"
#import "Theme.h"
#import "SyntaxHighlighter.h"
#import "LineNumberRulerView.h"
#import "ScriptManager.h"

@implementation OpenDocument
@end

@interface FileTreeController (Click)
- (void)handleClick:(NSOutlineView *)ov;
@end

@interface MainWindowController () {
    NSWindow *_window;

    NSView *_sidebarContainer;
    NSView *_explorerPanel;
    NSView *_scriptsPanel;
    NSView *_settingsPanel;
    NSMutableArray<NSButton *> *_activityButtons;

    NSSplitView *_hSplit;
    NSSplitView *_vSplit;

    NSTextView *_editorView;
    NSScrollView *_editorScroll;
    LineNumberRulerView *_ruler;

    NSTextView *_consoleView;
    NSView *_consoleContainer;
    NSTextField *_consoleInput;

    NSStackView *_tabBar;

    NSOutlineView *_outline;
    FileTreeController *_tree;

    NSTableView *_scriptsTable;
    NSArray<NSURL *> *_scripts;
    NSMenu *_scriptsMenu;

    NSMutableArray<OpenDocument *> *_documents;
    NSInteger _currentIndex;
    BOOL _consoleVisible;
    BOOL _updatingEditor;
    BOOL _restoring;

    // Find & Replace
    NSView *_findBar;
    NSLayoutConstraint *_findBarHeight;
    NSTextField *_findField;
    NSTextField *_replaceField;
    NSTextField *_matchLabel;
    NSButton *_caseButton;
    NSButton *_regexButton;
    NSMutableArray<NSValue *> *_matches;
    NSInteger _matchIndex;
    BOOL _findVisible;
}
@end

static void pinFill(NSView *v, NSView *container) {
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [v.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [v.topAnchor constraintEqualToAnchor:container.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
}

@implementation MainWindowController

- (NSWindow *)window { return _window; }

- (void)showWindow {
    NSRect frame = NSMakeRect(0, 0, 1200, 760);
    _window = [[NSWindow alloc] initWithContentRect:frame
                                          styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                     NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    _window.title = @"CleanEdit";
    _window.titlebarAppearsTransparent = YES;
    _window.titleVisibility = NSWindowTitleVisible;
    _window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    _window.delegate = self;
    _window.minSize = NSMakeSize(760, 480);
    [_window center];

    _documents = [NSMutableArray array];
    _currentIndex = -1;
    _consoleVisible = YES;

    [self buildUI];

    [_window makeKeyAndOrderFront:nil];

    [[ScriptManager shared] ensureScriptsInstalled];
    [self reloadScripts];
    [self selectSidebarIndex:0];
    if (![self restoreSession]) {
        [self newFile:nil];
    }
    [[ScriptManager shared] runStartupExtensionsWithHost:self];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_hSplit setPosition:250 ofDividerAtIndex:0];
        CGFloat h = self->_vSplit.bounds.size.height;
        [self->_vSplit setPosition:h - 200 ofDividerAtIndex:0];
    });
}

#pragma mark - UI construction

- (void)buildUI {
    NSView *content = [[NSView alloc] initWithFrame:_window.contentView.bounds];
    content.wantsLayer = YES;
    content.layer.backgroundColor = [Theme backgroundColor].CGColor;
    _window.contentView = content;

    NSView *activityBar = [self buildActivityBar];
    [content addSubview:activityBar];

    _sidebarContainer = [[NSView alloc] init];
    _sidebarContainer.wantsLayer = YES;
    _sidebarContainer.layer.backgroundColor = [Theme sidebarColor].CGColor;

    [self buildExplorerPanel];
    [self buildScriptsPanel];
    [self buildSettingsPanel];
    [_sidebarContainer addSubview:_explorerPanel];
    [_sidebarContainer addSubview:_scriptsPanel];
    [_sidebarContainer addSubview:_settingsPanel];
    pinFill(_explorerPanel, _sidebarContainer);
    pinFill(_scriptsPanel, _sidebarContainer);
    pinFill(_settingsPanel, _sidebarContainer);

    NSView *editorArea = [self buildEditorArea];

    _hSplit = [[NSSplitView alloc] init];
    _hSplit.vertical = YES;
    _hSplit.dividerStyle = NSSplitViewDividerStyleThin;
    [_hSplit addArrangedSubview:_sidebarContainer];
    [_hSplit addArrangedSubview:editorArea];
    [editorArea.widthAnchor constraintGreaterThanOrEqualToConstant:320].active = YES;

    [content addSubview:_hSplit];

    activityBar.translatesAutoresizingMaskIntoConstraints = NO;
    _hSplit.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [activityBar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [activityBar.topAnchor constraintEqualToAnchor:content.topAnchor],
        [activityBar.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [activityBar.widthAnchor constraintEqualToConstant:48],
        [_hSplit.leadingAnchor constraintEqualToAnchor:activityBar.trailingAnchor],
        [_hSplit.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [_hSplit.topAnchor constraintEqualToAnchor:content.topAnchor],
        [_hSplit.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
    ]];
}

- (NSButton *)activityButton:(NSString *)symbol tip:(NSString *)tip tag:(NSInteger)tag action:(SEL)action {
    NSButton *b = [[NSButton alloc] init];
    b.bordered = NO;
    b.bezelStyle = NSBezelStyleRegularSquare;
    b.imagePosition = NSImageOnly;
    b.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tip];
    b.contentTintColor = [Theme mutedTextColor];
    b.toolTip = tip;
    b.tag = tag;
    b.target = self;
    b.action = action;
    [b.widthAnchor constraintEqualToConstant:40].active = YES;
    [b.heightAnchor constraintEqualToConstant:40].active = YES;
    return b;
}

- (NSView *)buildActivityBar {
    NSView *bar = [[NSView alloc] init];
    bar.wantsLayer = YES;
    bar.layer.backgroundColor = [Theme activityBarColor].CGColor;

    NSButton *explorer = [self activityButton:@"sidebar.left" tip:@"Explorer" tag:0 action:@selector(activityButtonClicked:)];
    NSButton *scripts = [self activityButton:@"chevron.left.forwardslash.chevron.right" tip:@"Scripts" tag:1 action:@selector(activityButtonClicked:)];
    NSButton *settings = [self activityButton:@"gearshape" tip:@"Settings" tag:2 action:@selector(activityButtonClicked:)];
    _activityButtons = [@[explorer, scripts, settings] mutableCopy];

    NSButton *run = [self activityButton:@"play.fill" tip:@"Run current file (\u2318R)" tag:-1 action:@selector(runFocusedScript:)];
    NSButton *console = [self activityButton:@"terminal" tip:@"Toggle console (\u2318J)" tag:-1 action:@selector(toggleConsole:)];
    NSButton *toggleExp = [self activityButton:@"sidebar.leading" tip:@"Show/Hide explorer" tag:-1 action:@selector(toggleSidebar:)];

    NSStackView *topStack = [NSStackView stackViewWithViews:@[explorer, scripts, toggleExp, run, console]];
    topStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    topStack.spacing = 4;
    topStack.alignment = NSLayoutAttributeCenterX;
    topStack.translatesAutoresizingMaskIntoConstraints = NO;

    [bar addSubview:topStack];
    [bar addSubview:settings];
    settings.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [topStack.topAnchor constraintEqualToAnchor:bar.topAnchor constant:12],
        [topStack.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
        [settings.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
        [settings.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-12],
    ]];
    return bar;
}

- (NSTextField *)panelHeader:(NSString *)title {
    NSTextField *label = [NSTextField labelWithString:title.uppercaseString];
    label.font = [Theme uiBoldFont];
    label.textColor = [Theme mutedTextColor];
    return label;
}

- (NSButton *)iconButton:(NSString *)symbol tip:(NSString *)tip action:(SEL)action {
    NSButton *b = [[NSButton alloc] init];
    b.bordered = NO;
    b.imagePosition = NSImageOnly;
    b.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tip];
    b.contentTintColor = [Theme mutedTextColor];
    b.toolTip = tip;
    b.target = self;
    b.action = action;
    [b.widthAnchor constraintEqualToConstant:22].active = YES;
    [b.heightAnchor constraintEqualToConstant:22].active = YES;
    return b;
}

- (void)buildExplorerPanel {
    _explorerPanel = [[NSView alloc] init];

    NSTextField *header = [self panelHeader:@"Explorer"];
    NSButton *newFileBtn = [self iconButton:@"doc.badge.plus" tip:@"New File" action:@selector(explorerNewFile:)];
    NSButton *newFolderBtn = [self iconButton:@"folder.badge.plus" tip:@"New Folder" action:@selector(explorerNewFolder:)];
    NSButton *openBtn = [self iconButton:@"folder" tip:@"Open Folder" action:@selector(openFolder:)];

    _outline = [[NSOutlineView alloc] init];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"main"];
    col.resizingMask = NSTableColumnAutoresizingMask;
    [_outline addTableColumn:col];
    _outline.outlineTableColumn = col;
    _outline.headerView = nil;
    _outline.backgroundColor = [Theme sidebarColor];
    _outline.rowSizeStyle = NSTableViewRowSizeStyleSmall;
    _outline.floatsGroupRows = NO;
    _outline.indentationPerLevel = 14;
    _outline.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    _outline.gridStyleMask = NSTableViewGridNone;
    _outline.target = self;
    _outline.action = @selector(outlineClicked:);

    NSMenu *ctx = [[NSMenu alloc] init];
    [ctx addItemWithTitle:@"New File" action:@selector(explorerNewFile:) keyEquivalent:@""].target = self;
    [ctx addItemWithTitle:@"New Folder" action:@selector(explorerNewFolder:) keyEquivalent:@""].target = self;
    [ctx addItem:[NSMenuItem separatorItem]];
    [ctx addItemWithTitle:@"Rename\u2026" action:@selector(explorerRename:) keyEquivalent:@""].target = self;
    [ctx addItemWithTitle:@"Move to Trash" action:@selector(explorerDelete:) keyEquivalent:@""].target = self;
    [ctx addItem:[NSMenuItem separatorItem]];
    [ctx addItemWithTitle:@"Reveal in Finder" action:@selector(explorerReveal:) keyEquivalent:@""].target = self;
    [ctx addItemWithTitle:@"Refresh" action:@selector(explorerRefresh:) keyEquivalent:@""].target = self;
    _outline.menu = ctx;

    _tree = [[FileTreeController alloc] init];
    _tree.delegate = self;
    _tree.outlineView = _outline;
    _outline.dataSource = _tree;
    _outline.delegate = _tree;

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.documentView = _outline;
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = YES;
    scroll.backgroundColor = [Theme sidebarColor];
    scroll.borderType = NSNoBorder;

    NSTextField *hint = [NSTextField labelWithString:@"Open a folder to browse files"];
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = [Theme mutedTextColor];

    [self layoutPanel:_explorerPanel header:header actionButtons:@[openBtn, newFolderBtn, newFileBtn] body:scroll footer:hint];
}

- (void)buildScriptsPanel {
    _scriptsPanel = [[NSView alloc] init];

    NSTextField *header = [self panelHeader:@"Scripts"];
    NSButton *runBtn = [self iconButton:@"play.fill" tip:@"Run Selected" action:@selector(runSelectedScript:)];
    NSButton *newBtn = [self iconButton:@"plus" tip:@"New Script" action:@selector(newScript:)];
    NSButton *refreshBtn = [self iconButton:@"arrow.clockwise" tip:@"Refresh" action:@selector(refreshScripts:)];
    NSButton *folderBtn = [self iconButton:@"folder" tip:@"Reveal Scripts Folder" action:@selector(revealScriptsFolder:)];

    _scriptsTable = [[NSTableView alloc] init];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"script"];
    [_scriptsTable addTableColumn:col];
    _scriptsTable.headerView = nil;
    _scriptsTable.backgroundColor = [Theme sidebarColor];
    _scriptsTable.rowSizeStyle = NSTableViewRowSizeStyleSmall;
    _scriptsTable.gridStyleMask = NSTableViewGridNone;
    _scriptsTable.dataSource = self;
    _scriptsTable.delegate = self;
    _scriptsTable.target = self;
    _scriptsTable.doubleAction = @selector(runSelectedScript:);
    _scriptsTable.action = @selector(openSelectedScript:);

    NSMenu *ctx = [[NSMenu alloc] init];
    [ctx addItemWithTitle:@"Run" action:@selector(contextRun:) keyEquivalent:@""].target = self;
    [ctx addItemWithTitle:@"Edit" action:@selector(contextEdit:) keyEquivalent:@""].target = self;
    [ctx addItem:[NSMenuItem separatorItem]];
    [ctx addItemWithTitle:@"Assign Shortcut\u2026" action:@selector(assignShortcut:) keyEquivalent:@""].target = self;
    [ctx addItemWithTitle:@"Clear Shortcut" action:@selector(clearShortcut:) keyEquivalent:@""].target = self;
    _scriptsTable.menu = ctx;

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.documentView = _scriptsTable;
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = YES;
    scroll.backgroundColor = [Theme sidebarColor];
    scroll.borderType = NSNoBorder;

    NSTextField *hint = [NSTextField labelWithString:@"Double-click to run \u00b7 Right-click to assign a shortcut"];
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = [Theme mutedTextColor];

    [self layoutPanel:_scriptsPanel
               header:header
        actionButtons:@[runBtn, newBtn, refreshBtn, folderBtn]
                 body:scroll
               footer:hint];
}

- (void)buildSettingsPanel {
    _settingsPanel = [[NSView alloc] init];

    NSTextField *header = [self panelHeader:@"Settings"];

    NSStackView *form = [[NSStackView alloc] init];
    form.orientation = NSUserInterfaceLayoutOrientationVertical;
    form.alignment = NSLayoutAttributeLeading;
    form.spacing = 14;
    form.translatesAutoresizingMaskIntoConstraints = NO;

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    // Font size
    NSInteger fontSize = [ud integerForKey:@"fontSize"] ?: 13;
    NSStepper *stepper = [[NSStepper alloc] init];
    stepper.minValue = 9; stepper.maxValue = 28; stepper.increment = 1;
    stepper.integerValue = fontSize;
    stepper.target = self; stepper.action = @selector(fontSizeChanged:);
    NSTextField *sizeLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"Font size: %ld", (long)fontSize]];
    sizeLabel.textColor = [Theme textColor];
    sizeLabel.tag = 901;
    NSStackView *sizeRow = [NSStackView stackViewWithViews:@[sizeLabel, stepper]];
    sizeRow.spacing = 10;
    [form addArrangedSubview:sizeRow];

    // Tab width
    NSTextField *tabLabel = [NSTextField labelWithString:@"Tab width:"];
    tabLabel.textColor = [Theme textColor];
    NSPopUpButton *tabPop = [[NSPopUpButton alloc] init];
    [tabPop addItemsWithTitles:@[@"2", @"4", @"8"]];
    NSInteger tw = [ud integerForKey:@"tabWidth"] ?: 4;
    [tabPop selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)tw]];
    tabPop.target = self; tabPop.action = @selector(tabWidthChanged:);
    NSStackView *tabRow = [NSStackView stackViewWithViews:@[tabLabel, tabPop]];
    tabRow.spacing = 10;
    [form addArrangedSubview:tabRow];

    // Checkboxes
    NSButton *lineNumbers = [NSButton checkboxWithTitle:@"Show line numbers" target:self action:@selector(lineNumbersChanged:)];
    lineNumbers.state = ([ud objectForKey:@"lineNumbers"] == nil || [ud boolForKey:@"lineNumbers"]) ? NSControlStateValueOn : NSControlStateValueOff;
    lineNumbers.contentTintColor = [Theme textColor];
    [self styleCheckbox:lineNumbers];
    [form addArrangedSubview:lineNumbers];

    NSButton *wordWrap = [NSButton checkboxWithTitle:@"Word wrap" target:self action:@selector(wordWrapChanged:)];
    wordWrap.state = [ud boolForKey:@"wordWrap"] ? NSControlStateValueOn : NSControlStateValueOff;
    [self styleCheckbox:wordWrap];
    [form addArrangedSubview:wordWrap];

    NSButton *showConsole = [NSButton checkboxWithTitle:@"Show console" target:self action:@selector(showConsoleChanged:)];
    showConsole.state = NSControlStateValueOn;
    [self styleCheckbox:showConsole];
    [form addArrangedSubview:showConsole];

    NSTextField *about = [NSTextField wrappingLabelWithString:@"CleanEdit \u2014 a minimal editor with JavaScript & Python scripting."];
    about.font = [NSFont systemFontOfSize:11];
    about.textColor = [Theme mutedTextColor];

    [self layoutPanel:_settingsPanel header:header actionButtons:@[] body:form footer:about];
}

- (void)styleCheckbox:(NSButton *)cb {
    NSMutableAttributedString *t = [[NSMutableAttributedString alloc] initWithString:cb.title];
    [t addAttribute:NSForegroundColorAttributeName value:[Theme textColor] range:NSMakeRange(0, t.length)];
    cb.attributedTitle = t;
}

// Generic panel layout: header row (title + action buttons), body (fills), footer.
- (void)layoutPanel:(NSView *)panel
             header:(NSView *)header
      actionButtons:(NSArray<NSButton *> *)buttons
               body:(NSView *)body
             footer:(NSView *)footer {
    header.translatesAutoresizingMaskIntoConstraints = NO;
    body.translatesAutoresizingMaskIntoConstraints = NO;
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:header];
    [panel addSubview:body];
    [panel addSubview:footer];

    NSView *lastButton = nil;
    for (NSButton *b in buttons) {
        b.translatesAutoresizingMaskIntoConstraints = NO;
        [panel addSubview:b];
        [b.centerYAnchor constraintEqualToAnchor:header.centerYAnchor].active = YES;
        if (lastButton) {
            [b.trailingAnchor constraintEqualToAnchor:lastButton.leadingAnchor constant:-6].active = YES;
        } else {
            [b.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12].active = YES;
        }
        lastButton = b;
    }

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:panel.topAnchor constant:14],
        [header.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12],

        [body.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:10],
        [body.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:8],
        [body.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-8],

        [footer.topAnchor constraintEqualToAnchor:body.bottomAnchor constant:8],
        [footer.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12],
        [footer.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12],
        [footer.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-12],
    ]];
}

- (NSView *)buildEditorArea {
    // Editor container (tab bar + editor)
    NSView *editorContainer = [[NSView alloc] init];
    editorContainer.wantsLayer = YES;
    editorContainer.layer.backgroundColor = [Theme backgroundColor].CGColor;

    // Tab bar
    _tabBar = [[NSStackView alloc] init];
    _tabBar.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    _tabBar.spacing = 1;
    _tabBar.alignment = NSLayoutAttributeCenterY;
    _tabBar.edgeInsets = NSEdgeInsetsMake(0, 0, 0, 0);
    NSScrollView *tabScroll = [[NSScrollView alloc] init];
    tabScroll.drawsBackground = YES;
    tabScroll.backgroundColor = [Theme tabInactiveColor];
    tabScroll.hasHorizontalScroller = NO;
    tabScroll.borderType = NSNoBorder;
    tabScroll.documentView = _tabBar;
    tabScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    [_tabBar.heightAnchor constraintEqualToConstant:36].active = YES;
    [_tabBar.leadingAnchor constraintEqualToAnchor:tabScroll.contentView.leadingAnchor].active = YES;

    // Editor text view
    _editorScroll = [[NSScrollView alloc] init];
    _editorScroll.hasVerticalScroller = YES;
    _editorScroll.hasHorizontalScroller = YES;
    _editorScroll.borderType = NSNoBorder;
    _editorScroll.drawsBackground = YES;
    _editorScroll.backgroundColor = [Theme backgroundColor];

    NSSize contentSize = _editorScroll.contentSize;
    _editorView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    _editorView.minSize = NSMakeSize(0, 0);
    _editorView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    _editorView.verticallyResizable = YES;
    _editorView.horizontallyResizable = YES;
    _editorView.textContainer.containerSize = NSMakeSize(FLT_MAX, FLT_MAX);
    _editorView.textContainer.widthTracksTextView = NO;
    _editorView.backgroundColor = [Theme backgroundColor];
    _editorView.textColor = [Theme textColor];
    _editorView.font = [Theme editorFont];
    _editorView.insertionPointColor = [Theme textColor];
    _editorView.selectedTextAttributes = @{ NSBackgroundColorAttributeName: [Theme selectionColor] };
    _editorView.automaticQuoteSubstitutionEnabled = NO;
    _editorView.automaticDashSubstitutionEnabled = NO;
    _editorView.automaticSpellingCorrectionEnabled = NO;
    _editorView.automaticTextReplacementEnabled = NO;
    _editorView.richText = NO;
    _editorView.allowsUndo = YES;
    _editorView.textContainerInset = NSMakeSize(6, 8);
    _editorView.delegate = self;
    _editorScroll.documentView = _editorView;

    _ruler = [[LineNumberRulerView alloc] initWithTextView:_editorView];
    _editorScroll.verticalRulerView = _ruler;
    _editorScroll.hasVerticalRuler = YES;
    _editorScroll.rulersVisible = YES;

    _findBar = [self buildFindBar];

    [editorContainer addSubview:tabScroll];
    [editorContainer addSubview:_findBar];
    [editorContainer addSubview:_editorScroll];
    _editorScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _findBar.translatesAutoresizingMaskIntoConstraints = NO;
    _findBarHeight = [_findBar.heightAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [tabScroll.topAnchor constraintEqualToAnchor:editorContainer.topAnchor],
        [tabScroll.leadingAnchor constraintEqualToAnchor:editorContainer.leadingAnchor],
        [tabScroll.trailingAnchor constraintEqualToAnchor:editorContainer.trailingAnchor],
        [tabScroll.heightAnchor constraintEqualToConstant:36],
        [_findBar.topAnchor constraintEqualToAnchor:tabScroll.bottomAnchor],
        [_findBar.leadingAnchor constraintEqualToAnchor:editorContainer.leadingAnchor],
        [_findBar.trailingAnchor constraintEqualToAnchor:editorContainer.trailingAnchor],
        _findBarHeight,
        [_editorScroll.topAnchor constraintEqualToAnchor:_findBar.bottomAnchor],
        [_editorScroll.leadingAnchor constraintEqualToAnchor:editorContainer.leadingAnchor],
        [_editorScroll.trailingAnchor constraintEqualToAnchor:editorContainer.trailingAnchor],
        [_editorScroll.bottomAnchor constraintEqualToAnchor:editorContainer.bottomAnchor],
    ]];
    _findBar.hidden = YES;

    // Console
    _consoleContainer = [self buildConsole];

    _vSplit = [[NSSplitView alloc] init];
    _vSplit.vertical = NO;
    _vSplit.dividerStyle = NSSplitViewDividerStyleThin;
    [_vSplit addArrangedSubview:editorContainer];
    [_vSplit addArrangedSubview:_consoleContainer];
    [editorContainer.heightAnchor constraintGreaterThanOrEqualToConstant:120].active = YES;
    [_consoleContainer.heightAnchor constraintGreaterThanOrEqualToConstant:0].active = YES;

    [self applyEditorSettings];
    return _vSplit;
}

- (NSButton *)barButton:(NSString *)title action:(SEL)action {
    NSButton *b = [[NSButton alloc] init];
    b.title = title;
    b.bezelStyle = NSBezelStyleRounded;
    b.controlSize = NSControlSizeSmall;
    b.font = [NSFont systemFontOfSize:11];
    b.target = self;
    b.action = action;
    return b;
}

- (NSTextField *)barField:(NSString *)placeholder {
    NSTextField *f = [[NSTextField alloc] init];
    f.placeholderString = placeholder;
    f.font = [NSFont systemFontOfSize:12];
    f.controlSize = NSControlSizeSmall;
    f.bezeled = YES;
    f.delegate = self;
    [f.widthAnchor constraintEqualToConstant:200].active = YES;
    return f;
}

- (NSView *)buildFindBar {
    NSView *bar = [[NSView alloc] init];
    bar.wantsLayer = YES;
    bar.layer.backgroundColor = [Theme sidebarColor].CGColor;

    _findField = [self barField:@"Find"];
    _findField.target = self;
    _findField.action = @selector(findNext:);
    _replaceField = [self barField:@"Replace"];
    _replaceField.target = self;
    _replaceField.action = @selector(replaceCurrent:);

    NSButton *prev = [self barButton:@"\u2039" action:@selector(findPrevious:)];
    NSButton *next = [self barButton:@"\u203A" action:@selector(findNext:)];
    _caseButton = [self barButton:@"Aa" action:@selector(toggleCaseSensitive:)];
    [_caseButton setButtonType:NSButtonTypePushOnPushOff];
    _caseButton.toolTip = @"Case sensitive";

    _regexButton = [self barButton:@".*" action:@selector(toggleCaseSensitive:)];
    [_regexButton setButtonType:NSButtonTypePushOnPushOff];
    _regexButton.toolTip = @"Regular expression";

    _matchLabel = [NSTextField labelWithString:@""];
    _matchLabel.font = [NSFont systemFontOfSize:11];
    _matchLabel.textColor = [Theme mutedTextColor];
    [_matchLabel.widthAnchor constraintGreaterThanOrEqualToConstant:70].active = YES;

    NSButton *replaceBtn = [self barButton:@"Replace" action:@selector(replaceCurrent:)];
    NSButton *replaceAllBtn = [self barButton:@"All" action:@selector(replaceAll:)];
    NSButton *closeBtn = [self barButton:@"\u2715" action:@selector(closeFindBar:)];

    NSStackView *row1 = [NSStackView stackViewWithViews:@[_findField, prev, next, _caseButton, _regexButton, _matchLabel]];
    row1.spacing = 6;
    NSStackView *row2 = [NSStackView stackViewWithViews:@[_replaceField, replaceBtn, replaceAllBtn, closeBtn]];
    row2.spacing = 6;

    NSStackView *rows = [NSStackView stackViewWithViews:@[row1, row2]];
    rows.orientation = NSUserInterfaceLayoutOrientationVertical;
    rows.alignment = NSLayoutAttributeLeading;
    rows.spacing = 6;
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:rows];
    [NSLayoutConstraint activateConstraints:@[
        [rows.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:10],
        [rows.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
    ]];
    return bar;
}

#pragma mark - Find & Replace

- (void)showFindBar:(id)sender {
    NSString *sel = [self editorSelection];
    if (sel.length > 0 && sel.length < 200) _findField.stringValue = sel;
    _findBar.hidden = NO;
    _findBarHeight.constant = 68;
    _findVisible = YES;
    [_window makeFirstResponder:_findField];
    [[_findField currentEditor] selectAll:nil];
    [self performFind:YES];
}

- (void)closeFindBar:(id)sender {
    _findBarHeight.constant = 0;
    _findBar.hidden = YES;
    _findVisible = NO;
    [self clearFindHighlights];
    [_window makeFirstResponder:_editorView];
}

- (void)toggleCaseSensitive:(id)sender { [self performFind:YES]; }

- (void)controlTextDidChange:(NSNotification *)obj {
    if (obj.object == _findField) [self performFind:YES];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if ((control == _findField || control == _replaceField) && commandSelector == @selector(cancelOperation:)) {
        [self closeFindBar:nil];
        return YES;
    }
    return NO;
}

- (void)clearFindHighlights {
    NSLayoutManager *lm = _editorView.layoutManager;
    [lm removeTemporaryAttribute:NSBackgroundColorAttributeName
              forCharacterRange:NSMakeRange(0, _editorView.string.length)];
}

- (void)highlightAllMatches {
    NSLayoutManager *lm = _editorView.layoutManager;
    NSColor *bg = [NSColor colorWithSRGBRed:0.60 green:0.50 blue:0.10 alpha:0.55];
    for (NSValue *v in _matches) {
        [lm addTemporaryAttribute:NSBackgroundColorAttributeName value:bg forCharacterRange:v.rangeValue];
    }
}

- (void)performFind:(BOOL)moveSelection {
    [self clearFindHighlights];
    _matches = [NSMutableArray array];
    NSString *needle = _findField.stringValue;
    if (needle.length == 0) { _matchLabel.stringValue = @""; return; }

    NSString *hay = _editorView.string;
    BOOL caseSensitive = (_caseButton.state == NSControlStateValueOn);

    if (_regexButton.state == NSControlStateValueOn) {
        NSRegularExpressionOptions ropts = 0;
        if (!caseSensitive) ropts |= NSRegularExpressionCaseInsensitive;
        NSError *err = nil;
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:needle options:ropts error:&err];
        if (!re) { _matchLabel.stringValue = @"Bad regex"; return; }
        [re enumerateMatchesInString:hay options:0 range:NSMakeRange(0, hay.length)
                          usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags flags, BOOL *stop) {
            if (m.range.length > 0) [_matches addObject:[NSValue valueWithRange:m.range]];
        }];
    } else {
        NSStringCompareOptions opts = caseSensitive ? 0 : NSCaseInsensitiveSearch;
        NSRange search = NSMakeRange(0, hay.length);
        while (search.length > 0) {
            NSRange r = [hay rangeOfString:needle options:opts range:search];
            if (r.location == NSNotFound) break;
            [_matches addObject:[NSValue valueWithRange:r]];
            NSUInteger nextLoc = r.location + MAX(r.length, (NSUInteger)1);
            if (nextLoc >= hay.length) break;
            search = NSMakeRange(nextLoc, hay.length - nextLoc);
        }
    }
    [self highlightAllMatches];

    if (moveSelection && _matches.count > 0) {
        _matchIndex = 0;
        [self selectMatchAtIndex:0];
    }
    [self updateMatchLabel];
}

- (void)selectMatchAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_matches.count) return;
    NSRange r = [_matches[index] rangeValue];
    [_editorView setSelectedRange:r];
    [_editorView scrollRangeToVisible:r];
    [_editorView showFindIndicatorForRange:r];
    [self updateMatchLabel];
}

- (void)updateMatchLabel {
    if (_matches.count == 0) {
        _matchLabel.stringValue = _findField.stringValue.length ? @"No results" : @"";
    } else {
        _matchLabel.stringValue = [NSString stringWithFormat:@"%ld of %ld",
                                   (long)(_matchIndex + 1), (long)_matches.count];
    }
}

- (void)findNext:(id)sender {
    if (!_findVisible) { [self showFindBar:sender]; return; }
    if (_matches.count == 0) { [self performFind:YES]; return; }
    _matchIndex = (_matchIndex + 1) % _matches.count;
    [self selectMatchAtIndex:_matchIndex];
}

- (void)findPrevious:(id)sender {
    if (_matches.count == 0) { [self performFind:YES]; return; }
    _matchIndex = (_matchIndex - 1 + _matches.count) % _matches.count;
    [self selectMatchAtIndex:_matchIndex];
}

- (void)replaceCurrent:(id)sender {
    if (_matches.count == 0 || _matchIndex >= (NSInteger)_matches.count) return;
    NSRange r = [_matches[_matchIndex] rangeValue];
    NSString *rep = _replaceField.stringValue ?: @"";

    if (_regexButton.state == NSControlStateValueOn) {
        NSRegularExpressionOptions ropts = 0;
        if (_caseButton.state != NSControlStateValueOn) ropts |= NSRegularExpressionCaseInsensitive;
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:_findField.stringValue options:ropts error:nil];
        if (re) {
            NSString *matched = [_editorView.string substringWithRange:r];
            rep = [re stringByReplacingMatchesInString:matched options:0
                                                 range:NSMakeRange(0, matched.length) withTemplate:rep];
        }
    }
    if ([_editorView shouldChangeTextInRange:r replacementString:rep]) {
        [_editorView.textStorage replaceCharactersInRange:r withString:rep];
        [_editorView didChangeText];
    }
    [self rehighlight];
    NSInteger keep = _matchIndex;
    [self performFind:NO];
    if (_matches.count > 0) {
        _matchIndex = MIN(keep, (NSInteger)_matches.count - 1);
        [self selectMatchAtIndex:_matchIndex];
    } else {
        [self updateMatchLabel];
    }
}

- (void)replaceAll:(id)sender {
    NSString *needle = _findField.stringValue;
    if (needle.length == 0) return;
    NSString *rep = _replaceField.stringValue ?: @"";
    NSString *hay = _editorView.string;
    NSMutableString *ms = [hay mutableCopy];
    NSUInteger count = 0;

    if (_regexButton.state == NSControlStateValueOn) {
        NSRegularExpressionOptions ropts = 0;
        if (_caseButton.state != NSControlStateValueOn) ropts |= NSRegularExpressionCaseInsensitive;
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:needle options:ropts error:nil];
        if (!re) { [self appendConsole:@"Bad regex - nothing replaced." type:@"error"]; return; }
        count = [re replaceMatchesInString:ms options:0 range:NSMakeRange(0, ms.length) withTemplate:rep];
    } else {
        NSStringCompareOptions opts = (_caseButton.state == NSControlStateValueOn) ? 0 : NSCaseInsensitiveSearch;
        count = [ms replaceOccurrencesOfString:needle withString:rep options:opts range:NSMakeRange(0, ms.length)];
    }

    if (count > 0) {
        NSRange full = NSMakeRange(0, hay.length);
        if ([_editorView shouldChangeTextInRange:full replacementString:ms]) {
            [_editorView.textStorage replaceCharactersInRange:full withString:ms];
            [_editorView didChangeText];
        }
        [self rehighlight];
        [self performFind:NO];
    }
    [self appendConsole:[NSString stringWithFormat:@"Replaced %lu occurrence%@.",
                         (unsigned long)count, count == 1 ? @"" : @"s"] type:@"info"];
}

#pragma mark - Go to line

- (void)gotoLine:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Go to Line";
    alert.informativeText = [NSString stringWithFormat:@"Enter a line number (1 - %ld):", (long)[self editorLineCount]];
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 120, 24)];
    alert.accessoryView = input;
    [alert addButtonWithTitle:@"Go"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert.window setInitialFirstResponder:input];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;

    NSInteger target = input.integerValue;
    if (target < 1) return;

    NSString *s = _editorView.string;
    NSInteger line = 1;
    NSUInteger index = 0;
    NSRange lineRange = NSMakeRange(0, 0);
    while (index <= s.length) {
        NSRange r = [s lineRangeForRange:NSMakeRange(index, 0)];
        if (line == target) { lineRange = r; break; }
        if (NSMaxRange(r) <= index) break;  // reached end
        index = NSMaxRange(r);
        line++;
    }
    if (line != target) {  // beyond end -> go to last position
        lineRange = NSMakeRange(s.length, 0);
    }
    NSRange caret = NSMakeRange(lineRange.location, 0);
    [_editorView setSelectedRange:caret];
    [_editorView scrollRangeToVisible:caret];
    [_editorView showFindIndicatorForRange:[s lineRangeForRange:caret]];
    [_window makeFirstResponder:_editorView];
}

- (NSView *)buildConsole {
    NSView *container = [[NSView alloc] init];
    container.wantsLayer = YES;
    container.layer.backgroundColor = [Theme backgroundColor].CGColor;

    NSView *headerBar = [[NSView alloc] init];
    headerBar.wantsLayer = YES;
    headerBar.layer.backgroundColor = [Theme sidebarColor].CGColor;

    NSTextField *title = [self panelHeader:@"Output"];
    NSButton *clearBtn = [self iconButton:@"trash" tip:@"Clear Console" action:@selector(clearConsole:)];
    NSButton *hideBtn = [self iconButton:@"xmark" tip:@"Hide Console" action:@selector(toggleConsole:)];

    _consoleView = [[NSTextView alloc] init];
    _consoleView.editable = NO;
    _consoleView.backgroundColor = [Theme backgroundColor];
    _consoleView.textColor = [Theme textColor];
    _consoleView.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    _consoleView.textContainerInset = NSMakeSize(8, 6);
    _consoleView.automaticQuoteSubstitutionEnabled = NO;

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.documentView = _consoleView;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSNoBorder;
    scroll.drawsBackground = YES;
    scroll.backgroundColor = [Theme backgroundColor];

    // Mini terminal: a prompt + input that runs real shell commands.
    NSView *inputRow = [[NSView alloc] init];
    inputRow.wantsLayer = YES;
    inputRow.layer.backgroundColor = [Theme sidebarColor].CGColor;
    NSTextField *promptLbl = [NSTextField labelWithString:@"\u276f"];
    promptLbl.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightBold];
    promptLbl.textColor = [Theme accentColor];
    _consoleInput = [[NSTextField alloc] init];
    _consoleInput.placeholderString = @"Run a shell command\u2026";
    _consoleInput.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    _consoleInput.bezeled = NO;
    _consoleInput.drawsBackground = NO;
    _consoleInput.textColor = [Theme textColor];
    _consoleInput.focusRingType = NSFocusRingTypeNone;
    _consoleInput.target = self;
    _consoleInput.action = @selector(runShellCommand:);
    [inputRow addSubview:promptLbl];
    [inputRow addSubview:_consoleInput];
    promptLbl.translatesAutoresizingMaskIntoConstraints = NO;
    _consoleInput.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [promptLbl.leadingAnchor constraintEqualToAnchor:inputRow.leadingAnchor constant:12],
        [promptLbl.centerYAnchor constraintEqualToAnchor:inputRow.centerYAnchor],
        [_consoleInput.leadingAnchor constraintEqualToAnchor:promptLbl.trailingAnchor constant:8],
        [_consoleInput.trailingAnchor constraintEqualToAnchor:inputRow.trailingAnchor constant:-10],
        [_consoleInput.centerYAnchor constraintEqualToAnchor:inputRow.centerYAnchor],
    ]];

    [headerBar addSubview:title];
    [headerBar addSubview:clearBtn];
    [headerBar addSubview:hideBtn];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    clearBtn.translatesAutoresizingMaskIntoConstraints = NO;
    hideBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:headerBar.leadingAnchor constant:12],
        [title.centerYAnchor constraintEqualToAnchor:headerBar.centerYAnchor],
        [hideBtn.trailingAnchor constraintEqualToAnchor:headerBar.trailingAnchor constant:-10],
        [hideBtn.centerYAnchor constraintEqualToAnchor:headerBar.centerYAnchor],
        [clearBtn.trailingAnchor constraintEqualToAnchor:hideBtn.leadingAnchor constant:-8],
        [clearBtn.centerYAnchor constraintEqualToAnchor:headerBar.centerYAnchor],
    ]];

    [container addSubview:headerBar];
    [container addSubview:scroll];
    [container addSubview:inputRow];
    headerBar.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    inputRow.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [headerBar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [headerBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [headerBar.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [headerBar.heightAnchor constraintEqualToConstant:28],
        [scroll.topAnchor constraintEqualToAnchor:headerBar.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:inputRow.topAnchor],
        [inputRow.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [inputRow.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [inputRow.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [inputRow.heightAnchor constraintEqualToConstant:30],
    ]];
    return container;
}

#pragma mark - Sidebar switching

- (void)activityButtonClicked:(NSButton *)sender {
    [self selectSidebarIndex:sender.tag];
}

- (void)selectSidebarIndex:(NSInteger)index {
    if (_sidebarContainer.hidden) _sidebarContainer.hidden = NO;  // opening a panel reveals the sidebar
    _explorerPanel.hidden = (index != 0);
    _scriptsPanel.hidden = (index != 1);
    _settingsPanel.hidden = (index != 2);
    for (NSInteger i = 0; i < (NSInteger)_activityButtons.count; i++) {
        _activityButtons[i].contentTintColor = (i == index) ? [Theme textColor] : [Theme mutedTextColor];
    }
    if (index == 1) [self reloadScripts];  // pick up scripts dropped into the folder
}

- (void)toggleSidebar:(id)sender {
    _sidebarContainer.hidden = !_sidebarContainer.hidden;
}

#pragma mark - Documents & tabs

- (OpenDocument *)currentDoc {
    if (_currentIndex < 0 || _currentIndex >= (NSInteger)_documents.count) return nil;
    return _documents[_currentIndex];
}

- (void)newFile:(id)sender {
    OpenDocument *doc = [OpenDocument new];
    doc.displayName = @"untitled";
    doc.text = @"";
    doc.modified = NO;
    [_documents addObject:doc];
    [self switchToIndex:_documents.count - 1];
}

- (void)openURL:(NSURL *)url {
    for (NSInteger i = 0; i < (NSInteger)_documents.count; i++) {
        if ([_documents[i].url isEqual:url]) { [self switchToIndex:i]; return; }
    }
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&err];
    if (!content) {
        [self appendConsole:[NSString stringWithFormat:@"Could not open %@: %@", url.lastPathComponent, err.localizedDescription] type:@"error"];
        return;
    }
    OpenDocument *doc = [OpenDocument new];
    doc.url = url;
    doc.displayName = url.lastPathComponent;
    doc.text = content;
    doc.modified = NO;

    // Replace a single empty untitled doc rather than stacking tabs.
    OpenDocument *cur = [self currentDoc];
    if (_documents.count == 1 && cur && !cur.url && cur.text.length == 0 && !cur.modified) {
        _documents[0] = doc;
        [self switchToIndex:0];
    } else {
        [_documents addObject:doc];
        [self switchToIndex:_documents.count - 1];
    }
}

- (void)switchToIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_documents.count) return;
    // Save current editor content into the outgoing document.
    OpenDocument *cur = [self currentDoc];
    if (cur) cur.text = _editorView.string;

    _currentIndex = index;
    OpenDocument *doc = _documents[index];

    _updatingEditor = YES;
    [_editorView setString:doc.text ?: @""];
    _updatingEditor = NO;
    [self rehighlight];
    [_ruler refresh];

    _window.title = [NSString stringWithFormat:@"%@%@ \u2014 CleanEdit",
                     doc.modified ? @"\u25CF " : @"", doc.displayName];
    [self rebuildTabs];
    [self saveSession];
}

- (void)rebuildTabs {
    for (NSView *v in [_tabBar.arrangedSubviews copy]) {
        [_tabBar removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    for (NSInteger i = 0; i < (NSInteger)_documents.count; i++) {
        OpenDocument *doc = _documents[i];
        BOOL active = (i == _currentIndex);

        NSView *tab = [[NSView alloc] init];
        tab.wantsLayer = YES;
        tab.layer.backgroundColor = (active ? [Theme tabActiveColor] : [Theme tabInactiveColor]).CGColor;

        NSButton *name = [[NSButton alloc] init];
        name.bordered = NO;
        name.tag = i;
        name.target = self;
        name.action = @selector(tabClicked:);
        NSString *label = [NSString stringWithFormat:@"%@%@", doc.modified ? @"\u25CF " : @"", doc.displayName];
        NSMutableAttributedString *at = [[NSMutableAttributedString alloc] initWithString:label];
        [at addAttribute:NSForegroundColorAttributeName
                   value:(active ? [Theme textColor] : [Theme mutedTextColor])
                   range:NSMakeRange(0, at.length)];
        [at addAttribute:NSFontAttributeName value:[Theme uiFont] range:NSMakeRange(0, at.length)];
        name.attributedTitle = at;

        NSButton *close = [[NSButton alloc] init];
        close.bordered = NO;
        close.tag = i;
        close.target = self;
        close.action = @selector(tabCloseClicked:);
        close.image = [NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:@"Close"];
        close.contentTintColor = [Theme mutedTextColor];

        [tab addSubview:name];
        [tab addSubview:close];
        name.translatesAutoresizingMaskIntoConstraints = NO;
        close.translatesAutoresizingMaskIntoConstraints = NO;
        tab.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [tab.heightAnchor constraintEqualToConstant:36],
            [name.leadingAnchor constraintEqualToAnchor:tab.leadingAnchor constant:12],
            [name.centerYAnchor constraintEqualToAnchor:tab.centerYAnchor],
            [close.leadingAnchor constraintEqualToAnchor:name.trailingAnchor constant:4],
            [close.trailingAnchor constraintEqualToAnchor:tab.trailingAnchor constant:-8],
            [close.centerYAnchor constraintEqualToAnchor:tab.centerYAnchor],
            [close.widthAnchor constraintEqualToConstant:16],
            [close.heightAnchor constraintEqualToConstant:16],
        ]];
        [_tabBar addArrangedSubview:tab];
    }
}

- (void)tabClicked:(NSButton *)sender { [self switchToIndex:sender.tag]; }

- (void)tabCloseClicked:(NSButton *)sender { [self closeTabAtIndex:sender.tag]; }

- (void)closeCurrentTab:(id)sender { [self closeTabAtIndex:_currentIndex]; }

- (void)closeTabAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_documents.count) return;
    // Persist live editor text into the current document so edits aren't lost.
    OpenDocument *live = [self currentDoc];
    if (live) live.text = _editorView.string;
    OpenDocument *doc = _documents[index];
    NSString *liveText = (index == _currentIndex) ? _editorView.string : doc.text;
    if (doc.modified || (index == _currentIndex && ![liveText isEqualToString:doc.text])) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = [NSString stringWithFormat:@"Save changes to %@?", doc.displayName];
        [alert addButtonWithTitle:@"Save"];
        [alert addButtonWithTitle:@"Don't Save"];
        [alert addButtonWithTitle:@"Cancel"];
        NSModalResponse resp = [alert runModal];
        if (resp == NSAlertThirdButtonReturn) return;
        if (resp == NSAlertFirstButtonReturn) {
            if (index == _currentIndex) { [self saveFile:nil]; }
        }
    }
    [_documents removeObjectAtIndex:index];
    if (_documents.count == 0) { [self newFile:nil]; return; }
    if (_currentIndex >= (NSInteger)_documents.count) _currentIndex = _documents.count - 1;
    else if (index < _currentIndex) _currentIndex--;
    NSInteger target = _currentIndex;
    _currentIndex = -1;  // force reload
    [self switchToIndex:target];
}

#pragma mark - File operations

- (void)openFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    if ([panel runModal] == NSModalResponseOK) {
        [self openURL:panel.URL];
    }
}

- (void)openFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    if ([panel runModal] == NSModalResponseOK) {
        [_tree setRootURL:panel.URL];
        [self selectSidebarIndex:0];
        [self saveSession];
    }
}

- (void)saveFile:(id)sender {
    OpenDocument *doc = [self currentDoc];
    if (!doc) return;
    doc.text = _editorView.string;
    if (!doc.url) {
        NSSavePanel *panel = [NSSavePanel savePanel];
        panel.nameFieldStringValue = @"untitled.txt";
        if ([panel runModal] != NSModalResponseOK) return;
        doc.url = panel.URL;
        doc.displayName = panel.URL.lastPathComponent;
    }
    NSError *err = nil;
    BOOL ok = [doc.text writeToURL:doc.url atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (!ok) {
        [self appendConsole:[NSString stringWithFormat:@"Save failed: %@", err.localizedDescription] type:@"error"];
        return;
    }
    doc.modified = NO;
    [self rehighlight];
    _window.title = [NSString stringWithFormat:@"%@ \u2014 CleanEdit", doc.displayName];
    [self rebuildTabs];
    [self saveSession];
}

#pragma mark - FileTreeDelegate

- (void)outlineClicked:(NSOutlineView *)sender { [_tree handleClick:sender]; }

- (void)fileTreeDidSelectFile:(NSURL *)url { [self openURL:url]; }

#pragma mark - Explorer actions

- (NSString *)promptText:(NSString *)title info:(NSString *)info default:(NSString *)def {
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = title;
    a.informativeText = info;
    NSTextField *f = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 240, 24)];
    f.stringValue = def ?: @"";
    a.accessoryView = f;
    [a addButtonWithTitle:@"OK"];
    [a addButtonWithTitle:@"Cancel"];
    [a.window setInitialFirstResponder:f];
    if ([a runModal] != NSAlertFirstButtonReturn) return nil;
    return [f.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (void)explorerNewFile:(id)sender {
    NSURL *dir = [_tree selectedDirectoryURL];
    if (!dir) { [self appendConsole:@"Open a folder first." type:@"info"]; [self openFolder:nil]; return; }
    NSString *name = [self promptText:@"New File" info:@"File name:" default:@"untitled.txt"];
    if (!name.length) return;
    NSURL *u = [dir URLByAppendingPathComponent:name];
    if (![[NSFileManager defaultManager] fileExistsAtPath:u.path]) {
        [@"" writeToURL:u atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    [_tree refresh];
    [self openURL:u];
}

- (void)explorerNewFolder:(id)sender {
    NSURL *dir = [_tree selectedDirectoryURL];
    if (!dir) { [self appendConsole:@"Open a folder first." type:@"info"]; [self openFolder:nil]; return; }
    NSString *name = [self promptText:@"New Folder" info:@"Folder name:" default:@"New Folder"];
    if (!name.length) return;
    NSURL *u = [dir URLByAppendingPathComponent:name isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:nil];
    [_tree refresh];
}

- (void)explorerRename:(id)sender {
    NSURL *u = [_tree clickedOrSelectedURL];
    if (!u) return;
    NSString *name = [self promptText:@"Rename" info:@"New name:" default:u.lastPathComponent];
    if (!name.length || [name isEqualToString:u.lastPathComponent]) return;
    NSURL *dest = [u.URLByDeletingLastPathComponent URLByAppendingPathComponent:name];
    [[NSFileManager defaultManager] moveItemAtURL:u toURL:dest error:nil];
    [_tree refresh];
}

- (void)explorerDelete:(id)sender {
    NSURL *u = [_tree clickedOrSelectedURL];
    if (!u) return;
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = [NSString stringWithFormat:@"Move \u201c%@\u201d to Trash?", u.lastPathComponent];
    [a addButtonWithTitle:@"Move to Trash"];
    [a addButtonWithTitle:@"Cancel"];
    if ([a runModal] != NSAlertFirstButtonReturn) return;
    [[NSFileManager defaultManager] trashItemAtURL:u resultingItemURL:nil error:nil];
    [_tree refresh];
}

- (void)explorerReveal:(id)sender {
    NSURL *u = [_tree clickedOrSelectedURL] ?: _tree.rootURL;
    if (u) [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[u]];
}

- (void)explorerRefresh:(id)sender { [_tree refresh]; }

#pragma mark - NSTextViewDelegate

- (void)textDidChange:(NSNotification *)notification {
    if (_updatingEditor) return;
    OpenDocument *doc = [self currentDoc];
    if (doc && !doc.modified) {
        doc.modified = YES;
        _window.title = [NSString stringWithFormat:@"\u25CF %@ \u2014 CleanEdit", doc.displayName];
        [self rebuildTabs];
    }
    [self rehighlight];
    [_ruler refresh];
    if (_findVisible) [self performFind:NO];
}

- (void)rehighlight {
    OpenDocument *doc = [self currentDoc];
    LanguageDefinition *lang = nil;
    if (doc.url) lang = [[SyntaxHighlighter shared] languageForExtension:doc.url.pathExtension];
    [[SyntaxHighlighter shared] highlight:_editorView.textStorage language:lang];
    _editorView.typingAttributes = @{
        NSForegroundColorAttributeName: [Theme textColor],
        NSFontAttributeName: [Theme editorFont]
    };
}

#pragma mark - EditorHost

- (NSString *)editorText { return _editorView.string ?: @""; }

- (void)setEditorText:(NSString *)text {
    _updatingEditor = YES;
    [_editorView setString:text ?: @""];
    _updatingEditor = NO;
    OpenDocument *doc = [self currentDoc];
    if (doc) doc.modified = YES;
    [self rehighlight];
    [_ruler refresh];
    [self rebuildTabs];
}

- (NSString *)editorSelection {
    NSRange r = _editorView.selectedRange;
    if (r.length == 0 || NSMaxRange(r) > _editorView.string.length) return @"";
    return [_editorView.string substringWithRange:r];
}

- (void)replaceEditorSelection:(NSString *)text {
    NSRange r = _editorView.selectedRange;
    if ([_editorView shouldChangeTextInRange:r replacementString:text]) {
        [_editorView.textStorage replaceCharactersInRange:r withString:text ?: @""];
        [_editorView didChangeText];
    }
    [self rehighlight];
    [_ruler refresh];
}

- (void)insertEditorText:(NSString *)text {
    [self replaceEditorSelection:text];
}

- (NSString *)currentFilePath {
    OpenDocument *doc = [self currentDoc];
    return doc.url ? doc.url.path : @"";
}

- (void)setHighlightMode:(NSString *)mode {
    [SyntaxHighlighter shared].npaMode = mode.lowercaseString;
    [self rehighlight];
    [self appendConsole:[NSString stringWithFormat:@"Highlight mode set to '%@'.", mode] type:@"info"];
}

- (NSInteger)editorLineCount {
    NSString *s = _editorView.string;
    if (s.length == 0) return 1;
    NSInteger n = 1;
    for (NSUInteger i = 0; i < s.length; i++) {
        if ([s characterAtIndex:i] == '\n') n++;
    }
    return n;
}

- (void)appendConsole:(NSString *)text type:(NSString *)type {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self appendConsole:text type:type]; });
        return;
    }
    if ([type isEqualToString:@"section"]) {
        NSString *dashes = [@"" stringByPaddingToLength:22 withString:@"\u2500" startingAtIndex:0];
        NSString *header = [NSString stringWithFormat:@"\n\u2500\u2500\u2500 %@ %@\n", text ?: @"", dashes];
        NSDictionary *hattrs = @{
            NSForegroundColorAttributeName: [Theme accentColor],
            NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightBold]
        };
        [_consoleView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:header attributes:hattrs]];
        [_consoleView scrollRangeToVisible:NSMakeRange(_consoleView.string.length, 0)];
        if (!_consoleVisible) [self setConsoleVisible:YES];
        return;
    }
    NSDictionary *attrs = @{
        NSForegroundColorAttributeName: [Theme consoleColorForType:type],
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]
    };
    NSAttributedString *line = [[NSAttributedString alloc]
        initWithString:[(text ?: @"") stringByAppendingString:@"\n"] attributes:attrs];
    [_consoleView.textStorage appendAttributedString:line];
    [_consoleView scrollRangeToVisible:NSMakeRange(_consoleView.string.length, 0)];
    if (!_consoleVisible) [self setConsoleVisible:YES];
}

#pragma mark - Console visibility

- (void)clearConsole:(id)sender {
    [_consoleView.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:@""]];
}

- (void)runShellCommand:(id)sender {
    NSString *cmd = [_consoleInput.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (cmd.length == 0) return;
    _consoleInput.stringValue = @"";

    NSString *cwd = _tree.rootURL ? _tree.rootURL.path : NSHomeDirectory();
    [self appendConsole:[NSString stringWithFormat:@"\u276f %@", cmd] type:@"info"];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/bash";
    task.arguments = @[@"-lc", cmd];
    task.currentDirectoryPath = cwd;
    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    task.standardError = errPipe;

    __weak typeof(self) weakSelf = self;
    __block NSMutableString *outBuf = [NSMutableString string];
    __block NSMutableString *errBuf = [NSMutableString string];
    void (^flush)(NSMutableString *, NSString *) = ^(NSMutableString *buf, NSString *kind) {
        NSRange nl;
        while ((nl = [buf rangeOfString:@"\n"]).location != NSNotFound) {
            NSString *line = [buf substringToIndex:nl.location];
            [buf deleteCharactersInRange:NSMakeRange(0, nl.location + 1)];
            [weakSelf appendConsole:line type:kind];
        }
    };
    outPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *d = fh.availableData;
        if (d.length == 0) return;
        NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: @"";
        dispatch_async(dispatch_get_main_queue(), ^{ [outBuf appendString:s]; flush(outBuf, @"output"); });
    };
    errPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *d = fh.availableData;
        if (d.length == 0) return;
        NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: @"";
        dispatch_async(dispatch_get_main_queue(), ^{ [errBuf appendString:s]; flush(errBuf, @"error"); });
    };
    task.terminationHandler = ^(NSTask *t) {
        outPipe.fileHandleForReading.readabilityHandler = nil;
        errPipe.fileHandleForReading.readabilityHandler = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (outBuf.length) [weakSelf appendConsole:outBuf type:@"output"];
            if (errBuf.length) [weakSelf appendConsole:errBuf type:@"error"];
        });
    };
    @try {
        [task launch];
    } @catch (NSException *ex) {
        [self appendConsole:[NSString stringWithFormat:@"Failed to run command: %@", ex.reason] type:@"error"];
    }
}

- (void)toggleConsole:(id)sender {
    [self setConsoleVisible:!_consoleVisible];
}

- (void)setConsoleVisible:(BOOL)visible {
    _consoleVisible = visible;
    CGFloat h = _vSplit.bounds.size.height;
    if (visible) {
        [_vSplit setPosition:h - 200 ofDividerAtIndex:0];
    } else {
        [_vSplit setPosition:h ofDividerAtIndex:0];
    }
}

#pragma mark - Scripts panel

- (void)reloadScripts {
    _scripts = [[ScriptManager shared] availableScripts];
    [_scriptsTable reloadData];
    [self refreshScriptsMenu];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _scripts.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"scell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 220, 20)];
        cell.identifier = @"scell";
        cell.autoresizesSubviews = YES;
        NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 2, 14, 14)];
        [cell addSubview:iv];
        cell.imageView = iv;
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(24, 0, 130, 18)];
        tf.bordered = NO; tf.editable = NO; tf.drawsBackground = NO;
        tf.font = [Theme uiFont]; tf.textColor = [Theme textColor];
        tf.lineBreakMode = NSLineBreakByTruncatingMiddle;
        tf.autoresizingMask = NSViewWidthSizable;
        [cell addSubview:tf];
        cell.textField = tf;
        NSTextField *sc = [[NSTextField alloc] initWithFrame:NSMakeRect(156, 0, 60, 18)];
        sc.bordered = NO; sc.editable = NO; sc.drawsBackground = NO;
        sc.font = [NSFont systemFontOfSize:11];
        sc.textColor = [Theme mutedTextColor];
        sc.alignment = NSTextAlignmentRight;
        sc.tag = 555;
        sc.autoresizingMask = NSViewMinXMargin;
        [cell addSubview:sc];
    }
    NSURL *url = _scripts[row];
    cell.textField.stringValue = url.lastPathComponent;
    NSString *sym = [url.pathExtension.lowercaseString isEqualToString:@"py"] ? @"terminal" : @"curlybraces";
    cell.imageView.image = [NSImage imageWithSystemSymbolName:sym accessibilityDescription:nil];
    cell.imageView.contentTintColor = [Theme mutedTextColor];

    NSTextField *sc = [cell viewWithTag:555];
    NSDictionary *bind = [self shortcutBindings][url.lastPathComponent];
    sc.stringValue = bind ? [self displayForKey:bind[@"key"] mods:[bind[@"mods"] integerValue]] : @"";
    return cell;
}

- (void)runSelectedScript:(id)sender {
    NSInteger row = _scriptsTable.selectedRow;
    if (row < 0 || row >= (NSInteger)_scripts.count) {
        [self appendConsole:@"Select a script to run." type:@"info"];
        return;
    }
    [[ScriptManager shared] runScriptAtURL:_scripts[row] host:self];
}

- (void)openSelectedScript:(id)sender {
    NSInteger row = _scriptsTable.clickedRow;
    if (row < 0 || row >= (NSInteger)_scripts.count) return;
    [self openURL:_scripts[row]];
}

- (void)newScript:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Script";
    alert.informativeText = @"Enter a file name ending in .js or .py";
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 240, 24)];
    input.stringValue = @"my_script.py";
    alert.accessoryView = input;
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn && input.stringValue.length) {
        NSURL *url = [[ScriptManager shared] createNewScriptWithName:input.stringValue];
        [self reloadScripts];
        [self openURL:url];
    }
}

- (void)refreshScripts:(id)sender { [self reloadScripts]; }

- (void)revealScriptsFolder:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[ScriptManager shared].scriptsDirectory];
}

- (void)runFocusedScript:(id)sender {
    OpenDocument *doc = [self currentDoc];
    if (!doc) return;
    NSString *ext = doc.url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"js"] || [ext isEqualToString:@"py"]) {
        doc.text = _editorView.string;
        [doc.text writeToURL:doc.url atomically:YES encoding:NSUTF8StringEncoding error:nil];
        doc.modified = NO;
        [self rebuildTabs];
        [[ScriptManager shared] runScriptAtURL:doc.url host:self];
    } else {
        // Run current buffer via a temp file.
        NSString *tmpName = [NSString stringWithFormat:@"cleanedit_run_%@.py", @((long)[NSDate date].timeIntervalSince1970)];
        NSURL *tmp = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:tmpName];
        [_editorView.string writeToURL:tmp atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [self appendConsole:@"Current file is not a .js/.py script; running buffer as Python." type:@"info"];
        [[ScriptManager shared] runScriptAtURL:tmp host:self];
    }
}

#pragma mark - Settings actions

- (void)fontSizeChanged:(NSStepper *)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:sender.integerValue forKey:@"fontSize"];
    NSTextField *label = [_settingsPanel viewWithTag:901];
    label.stringValue = [NSString stringWithFormat:@"Font size: %ld", (long)sender.integerValue];
    [self applyEditorSettings];
    [self rehighlight];
}

- (void)tabWidthChanged:(NSPopUpButton *)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:sender.titleOfSelectedItem.integerValue forKey:@"tabWidth"];
    [self applyEditorSettings];
}

- (void)lineNumbersChanged:(NSButton *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:(sender.state == NSControlStateValueOn) forKey:@"lineNumbers"];
    _editorScroll.rulersVisible = (sender.state == NSControlStateValueOn);
}

- (void)wordWrapChanged:(NSButton *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:(sender.state == NSControlStateValueOn) forKey:@"wordWrap"];
    [self applyEditorSettings];
}

- (void)showConsoleChanged:(NSButton *)sender {
    [self setConsoleVisible:(sender.state == NSControlStateValueOn)];
}

- (void)applyEditorSettings {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSFont *font = [Theme editorFont];
    _editorView.font = font;

    NSInteger tw = [ud integerForKey:@"tabWidth"] ?: 4;
    CGFloat charW = [@" " sizeWithAttributes:@{ NSFontAttributeName: font }].width;
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.tabStops = @[];
    ps.defaultTabInterval = charW * tw;
    _editorView.defaultParagraphStyle = ps;

    BOOL wrap = [ud boolForKey:@"wordWrap"];
    if (wrap) {
        _editorScroll.hasHorizontalScroller = NO;
        _editorView.horizontallyResizable = NO;
        _editorView.textContainer.widthTracksTextView = YES;
        NSSize sz = _editorScroll.contentSize;
        _editorView.textContainer.containerSize = NSMakeSize(sz.width, FLT_MAX);
    } else {
        _editorScroll.hasHorizontalScroller = YES;
        _editorView.horizontallyResizable = YES;
        _editorView.textContainer.widthTracksTextView = NO;
        _editorView.textContainer.containerSize = NSMakeSize(FLT_MAX, FLT_MAX);
    }
    BOOL ln = ([ud objectForKey:@"lineNumbers"] == nil) || [ud boolForKey:@"lineNumbers"];
    _editorScroll.rulersVisible = ln;
    [_ruler refresh];
}

#pragma mark - Session restore

- (void)saveSession {
    if (_restoring) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    if (_tree.rootURL) {
        [ud setObject:_tree.rootURL.path forKey:@"lastFolder"];
    } else {
        [ud removeObjectForKey:@"lastFolder"];
    }

    OpenDocument *cur = [self currentDoc];
    if (cur) cur.text = _editorView.string;

    NSMutableArray *paths = [NSMutableArray array];
    for (OpenDocument *d in _documents) {
        if (d.url) [paths addObject:d.url.path];
    }
    [ud setObject:paths forKey:@"openFiles"];
    [ud setObject:(cur.url ? cur.url.path : @"") forKey:@"currentFile"];
}

- (BOOL)restoreSession {
    _restoring = YES;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *folder = [ud stringForKey:@"lastFolder"];
    if (folder.length && [fm fileExistsAtPath:folder]) {
        [_tree setRootURL:[NSURL fileURLWithPath:folder]];
    }

    BOOL opened = NO;
    for (NSString *p in [ud arrayForKey:@"openFiles"]) {
        if ([p isKindOfClass:[NSString class]] && [fm fileExistsAtPath:p]) {
            [self openURL:[NSURL fileURLWithPath:p]];
            opened = YES;
        }
    }

    NSString *curp = [ud stringForKey:@"currentFile"];
    if (curp.length) {
        for (NSInteger i = 0; i < (NSInteger)_documents.count; i++) {
            if ([_documents[i].url.path isEqualToString:curp]) { [self switchToIndex:i]; break; }
        }
    }

    _restoring = NO;
    return opened;
}

- (void)windowWillClose:(NSNotification *)notification {
    [self saveSession];
}

#pragma mark - Script shortcuts

- (void)setScriptsMenu:(NSMenu *)menu {
    _scriptsMenu = menu;
    [self refreshScriptsMenu];
}

- (NSMutableDictionary *)shortcutBindings {
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"scriptShortcuts"];
    return d ? [d mutableCopy] : [NSMutableDictionary dictionary];
}

- (void)saveBindings:(NSDictionary *)bindings {
    [[NSUserDefaults standardUserDefaults] setObject:bindings forKey:@"scriptShortcuts"];
}

- (NSString *)displayForKey:(NSString *)key mods:(NSInteger)mods {
    NSMutableString *s = [NSMutableString string];
    if (mods & NSEventModifierFlagControl) [s appendString:@"\u2303"];
    if (mods & NSEventModifierFlagOption)  [s appendString:@"\u2325"];
    if (mods & NSEventModifierFlagShift)   [s appendString:@"\u21E7"];
    if (mods & NSEventModifierFlagCommand) [s appendString:@"\u2318"];
    [s appendString:key.uppercaseString];
    return s;
}

- (void)refreshScriptsMenu {
    if (!_scriptsMenu) return;
    // Keep the first static item ("Run Current File as Script"); rebuild the rest.
    while (_scriptsMenu.numberOfItems > 1) {
        [_scriptsMenu removeItemAtIndex:_scriptsMenu.numberOfItems - 1];
    }
    NSDictionary *bindings = [self shortcutBindings];
    BOOL addedSeparator = NO;
    for (NSURL *url in [[ScriptManager shared] availableScripts]) {
        NSDictionary *bind = bindings[url.lastPathComponent];
        if (!bind) continue;
        if (!addedSeparator) {
            [_scriptsMenu addItem:[NSMenuItem separatorItem]];
            addedSeparator = YES;
        }
        NSString *key = [bind[@"key"] lowercaseString] ?: @"";
        NSInteger mods = [bind[@"mods"] integerValue];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Run %@", url.lastPathComponent]
                                                      action:@selector(runBoundScript:)
                                               keyEquivalent:key];
        item.keyEquivalentModifierMask = mods;
        item.target = self;
        item.representedObject = url;
        [_scriptsMenu addItem:item];
    }
}

- (void)runBoundScript:(NSMenuItem *)sender {
    NSURL *url = sender.representedObject;
    if (url) {
        [self selectSidebarIndex:1];
        [[ScriptManager shared] runScriptAtURL:url host:self];
    }
}

- (NSURL *)contextScript {
    NSInteger row = _scriptsTable.clickedRow;
    if (row < 0) row = _scriptsTable.selectedRow;
    if (row < 0 || row >= (NSInteger)_scripts.count) return nil;
    return _scripts[row];
}

- (void)contextRun:(id)sender {
    NSURL *u = [self contextScript];
    if (u) [[ScriptManager shared] runScriptAtURL:u host:self];
}

- (void)contextEdit:(id)sender {
    NSURL *u = [self contextScript];
    if (u) [self openURL:u];
}

- (void)clearShortcut:(id)sender {
    NSURL *u = [self contextScript];
    if (!u) return;
    NSMutableDictionary *b = [self shortcutBindings];
    [b removeObjectForKey:u.lastPathComponent];
    [self saveBindings:b];
    [self reloadScripts];
}

- (void)assignShortcut:(id)sender {
    NSURL *u = [self contextScript];
    if (!u) return;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Shortcut for %@", u.lastPathComponent];
    alert.informativeText = @"Type a single key and pick modifiers (at least one).";

    NSView *acc = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 92)];

    NSTextField *keyLabel = [NSTextField labelWithString:@"Key:"];
    keyLabel.frame = NSMakeRect(0, 62, 34, 20);
    [acc addSubview:keyLabel];

    NSTextField *keyField = [[NSTextField alloc] initWithFrame:NSMakeRect(38, 60, 44, 24)];
    [acc addSubview:keyField];

    NSButton *cmd = [NSButton checkboxWithTitle:@"\u2318 Command" target:nil action:nil];
    cmd.frame = NSMakeRect(0, 34, 130, 20);
    cmd.state = NSControlStateValueOn;
    [acc addSubview:cmd];

    NSButton *shift = [NSButton checkboxWithTitle:@"\u21E7 Shift" target:nil action:nil];
    shift.frame = NSMakeRect(140, 34, 130, 20);
    [acc addSubview:shift];

    NSButton *option = [NSButton checkboxWithTitle:@"\u2325 Option" target:nil action:nil];
    option.frame = NSMakeRect(0, 8, 130, 20);
    [acc addSubview:option];

    NSButton *control = [NSButton checkboxWithTitle:@"\u2303 Control" target:nil action:nil];
    control.frame = NSMakeRect(140, 8, 130, 20);
    [acc addSubview:control];

    alert.accessoryView = acc;
    [alert addButtonWithTitle:@"Assign"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] != NSAlertFirstButtonReturn) return;

    NSString *key = keyField.stringValue;
    if (key.length == 0) {
        NSBeep();
        return;
    }
    key = [[key substringToIndex:1] lowercaseString];

    NSInteger mods = 0;
    if (cmd.state == NSControlStateValueOn)     mods |= NSEventModifierFlagCommand;
    if (shift.state == NSControlStateValueOn)   mods |= NSEventModifierFlagShift;
    if (option.state == NSControlStateValueOn)  mods |= NSEventModifierFlagOption;
    if (control.state == NSControlStateValueOn) mods |= NSEventModifierFlagControl;
    if (mods == 0) mods = NSEventModifierFlagCommand;  // require a modifier

    NSMutableDictionary *b = [self shortcutBindings];
    // Remove any other script already using this exact combo.
    for (NSString *fn in [b.allKeys copy]) {
        NSDictionary *e = b[fn];
        if ([e[@"key"] isEqualToString:key] && [e[@"mods"] integerValue] == mods) {
            [b removeObjectForKey:fn];
        }
    }
    b[u.lastPathComponent] = @{ @"key": key, @"mods": @(mods) };
    [self saveBindings:b];
    [self reloadScripts];
    [self appendConsole:[NSString stringWithFormat:@"Bound %@ to %@",
                         [self displayForKey:key mods:mods], u.lastPathComponent] type:@"info"];
}

@end
