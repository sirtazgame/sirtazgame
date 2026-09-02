#import "FileTreeController.h"
#import "Theme.h"

@interface FileNode : NSObject
@property (strong) NSURL *url;
@property (assign) BOOL isDirectory;
@property (strong) NSMutableArray<FileNode *> *children;
@property (assign) BOOL loaded;
@end

@implementation FileNode
@end

@implementation FileTreeController {
    FileNode *_root;
}

@synthesize rootURL = _rootURL;

- (void)setRootURL:(NSURL *)url {
    _rootURL = url;
    _root = [self nodeForURL:url];
    [self loadChildren:_root];
    [self reload];
}

- (void)reload {
    [self.outlineView reloadData];
}

- (FileNode *)nodeForURL:(NSURL *)url {
    FileNode *n = [FileNode new];
    n.url = url;
    NSNumber *isDir = nil;
    [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
    n.isDirectory = isDir.boolValue;
    n.children = [NSMutableArray array];
    return n;
}

- (void)loadChildren:(FileNode *)node {
    if (!node.isDirectory || node.loaded) return;
    node.loaded = YES;
    NSArray<NSURL *> *contents = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:node.url
      includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey]
                         options:0
                           error:nil];
    NSArray *sorted = [contents sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSNumber *ad = nil, *bd = nil;
        [a getResourceValue:&ad forKey:NSURLIsDirectoryKey error:nil];
        [b getResourceValue:&bd forKey:NSURLIsDirectoryKey error:nil];
        if (ad.boolValue != bd.boolValue) return ad.boolValue ? NSOrderedAscending : NSOrderedDescending;
        return [a.lastPathComponent caseInsensitiveCompare:b.lastPathComponent];
    }];
    for (NSURL *child in sorted) {
        if ([child.lastPathComponent hasPrefix:@"."]) continue;
        [node.children addObject:[self nodeForURL:child]];
    }
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
    FileNode *node = item ?: _root;
    if (!node) return 0;
    [self loadChildren:node];
    return node.children.count;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)index ofItem:(id)item {
    FileNode *node = item ?: _root;
    return node.children[index];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
    return ((FileNode *)item).isDirectory;
}

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)ov viewForTableColumn:(NSTableColumn *)col item:(id)item {
    FileNode *node = item;
    NSTableCellView *cell = [ov makeViewWithIdentifier:@"cell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
        cell.identifier = @"cell";

        NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(2, 2, 16, 16)];
        iv.imageScaling = NSImageScaleProportionallyDown;
        [cell addSubview:iv];
        cell.imageView = iv;

        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(22, 0, 180, 18)];
        tf.bordered = NO;
        tf.editable = NO;
        tf.drawsBackground = NO;
        tf.font = [Theme uiFont];
        tf.textColor = [Theme textColor];
        [cell addSubview:tf];
        cell.textField = tf;
    }
    cell.textField.stringValue = node.url.lastPathComponent;
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:node.url.path];
    icon.size = NSMakeSize(16, 16);
    cell.imageView.image = icon;
    return cell;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)ov rowViewForItem:(id)item {
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldSelectItem:(id)item {
    return YES;
}

// Called via the outline view's single-click action (configured by the window controller).
- (void)handleClick:(NSOutlineView *)ov {
    NSInteger row = ov.clickedRow;
    if (row < 0) return;
    FileNode *node = [ov itemAtRow:row];
    if (!node) return;
    if (node.isDirectory) {
        if ([ov isItemExpanded:node]) {
            [ov collapseItem:node];
        } else {
            [ov expandItem:node];
        }
    } else {
        [self.delegate fileTreeDidSelectFile:node.url];
    }
}

@end
