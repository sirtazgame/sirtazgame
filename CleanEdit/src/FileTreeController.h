#import <Cocoa/Cocoa.h>

@protocol FileTreeDelegate <NSObject>
- (void)fileTreeDidSelectFile:(NSURL *)url;
@end

// Data source + delegate for the Explorer folder tree (NSOutlineView).
@interface FileTreeController : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property (weak) id<FileTreeDelegate> delegate;
@property (weak) NSOutlineView *outlineView;
@property (readonly) NSURL *rootURL;
- (void)setRootURL:(NSURL *)url;
- (void)reload;
@end
