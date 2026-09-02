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

    NSStackView *_tabBar;

    NSOutlineView *_outline;
    FileTreeController *_tree;

    NSTableView *_scriptsTable;
    NSArray<NSURL *> *_scripts;

    NSMutableArray<OpenDocument *> *_documents;
    NSInteger _currentIndex;
    BOOL _consoleVisible;
    BOOL _updatingEditor;
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
    [self newFile:nil];

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
    [_sidebarContainer.widthAnchor constraintGreaterThanOrEqualToConstant:170].active = YES;
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

- (NSView *)buildActivityBar {
    NSView *bar = [[NSView alloc] init];
    bar.wantsLayer = YES;
    bar.layer.backgroundColor = [Theme activityBarColor].CGColor;

    _activityButtons = [NSMutableArray array];
    NSArray *symbols = @[@"folder", @"chevron.left.forwardslash.chevron.right", @"gearshape"];
    NSArray *tips = @[@"Explorer", @"Scripts", @"Settings"];

    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 6;
    stack.alignment = NSLayoutAttributeCenterX;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSInteger i = 0; i < symbols.count; i++) {
        NSButton *b = [[NSButton alloc] init];
        b.bordered = NO;
        b.bezelStyle = NSBezelStyleRegularSquare;
        b.imagePosition = NSImageOnly;
        NSImage *img = [NSImage imageWithSystemSymbolName:symbols[i] accessibilityDescription:tips[i]];
        b.image = img;
        b.contentTintColor = [Theme mutedTextColor];
        b.toolTip = tips[i];
        b.tag = i;
        b.target = self;
        b.action = @selector(activityButtonClicked:);
        [b.widthAnchor constraintEqualToConstant:40].active = YES;
        [b.heightAnchor constraintEqualToConstant:40].active = YES;
        [_activityButtons addObject:b];
        [stack addArrangedSubview:b];
    }

    [bar addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:bar.topAnchor constant:12],
        [stack.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
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
    NSButton *openBtn = [self iconButton:@"folder.badge.plus" tip:@"Open Folder" action:@selector(openFolder:)];

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

    [self layoutPanel:_explorerPanel header:header actionButtons:@[openBtn] body:scroll footer:hint];
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

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.documentView = _scriptsTable;
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = YES;
    scroll.backgroundColor = [Theme sidebarColor];
    scroll.borderType = NSNoBorder;

    NSTextField *hint = [NSTextField labelWithString:@"Double-click to run \u00b7 Single-click to edit"];
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

    [editorContainer addSubview:tabScroll];
    [editorContainer addSubview:_editorScroll];
    _editorScroll.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [tabScroll.topAnchor constraintEqualToAnchor:editorContainer.topAnchor],
        [tabScroll.leadingAnchor constraintEqualToAnchor:editorContainer.leadingAnchor],
        [tabScroll.trailingAnchor constraintEqualToAnchor:editorContainer.trailingAnchor],
        [tabScroll.heightAnchor constraintEqualToConstant:36],
        [_editorScroll.topAnchor constraintEqualToAnchor:tabScroll.bottomAnchor],
        [_editorScroll.leadingAnchor constraintEqualToAnchor:editorContainer.leadingAnchor],
        [_editorScroll.trailingAnchor constraintEqualToAnchor:editorContainer.trailingAnchor],
        [_editorScroll.bottomAnchor constraintEqualToAnchor:editorContainer.bottomAnchor],
    ]];

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
    headerBar.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [headerBar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [headerBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [headerBar.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [headerBar.heightAnchor constraintEqualToConstant:28],
        [scroll.topAnchor constraintEqualToAnchor:headerBar.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    return container;
}

#pragma mark - Sidebar switching

- (void)activityButtonClicked:(NSButton *)sender {
    [self selectSidebarIndex:sender.tag];
}

- (void)selectSidebarIndex:(NSInteger)index {
    _explorerPanel.hidden = (index != 0);
    _scriptsPanel.hidden = (index != 1);
    _settingsPanel.hidden = (index != 2);
    for (NSInteger i = 0; i < _activityButtons.count; i++) {
        _activityButtons[i].contentTintColor = (i == index) ? [Theme textColor] : [Theme mutedTextColor];
    }
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
}

#pragma mark - FileTreeDelegate

- (void)outlineClicked:(NSOutlineView *)sender { [_tree handleClick:sender]; }

- (void)fileTreeDidSelectFile:(NSURL *)url { [self openURL:url]; }

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
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _scripts.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"scell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
        cell.identifier = @"scell";
        NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 2, 14, 14)];
        [cell addSubview:iv];
        cell.imageView = iv;
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(24, 0, 180, 18)];
        tf.bordered = NO; tf.editable = NO; tf.drawsBackground = NO;
        tf.font = [Theme uiFont]; tf.textColor = [Theme textColor];
        [cell addSubview:tf];
        cell.textField = tf;
    }
    NSURL *url = _scripts[row];
    cell.textField.stringValue = url.lastPathComponent;
    NSString *sym = [url.pathExtension.lowercaseString isEqualToString:@"py"] ? @"terminal" : @"curlybraces";
    cell.imageView.image = [NSImage imageWithSystemSymbolName:sym accessibilityDescription:nil];
    cell.imageView.contentTintColor = [Theme mutedTextColor];
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

@end
