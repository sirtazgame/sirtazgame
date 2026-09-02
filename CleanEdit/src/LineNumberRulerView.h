#import <Cocoa/Cocoa.h>

// Draws line numbers in the gutter of an NSTextView.
@interface LineNumberRulerView : NSRulerView
- (instancetype)initWithTextView:(NSTextView *)textView;
- (void)refresh;
@end
