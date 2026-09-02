#import "LineNumberRulerView.h"
#import "Theme.h"

@implementation LineNumberRulerView

- (instancetype)initWithTextView:(NSTextView *)textView {
    self = [super initWithScrollView:textView.enclosingScrollView orientation:NSVerticalRuler];
    if (self) {
        self.clientView = textView;
        self.ruleThickness = 48;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refresh)
                                                     name:NSTextDidChangeNotification
                                                   object:textView];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refresh {
    self.needsDisplay = YES;
}

- (NSTextView *)textView {
    return (NSTextView *)self.clientView;
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)rect {
    NSTextView *tv = [self textView];
    if (!tv) return;

    // Gutter background + right border line.
    [[Theme backgroundColor] set];
    NSRectFill(self.bounds);
    [[Theme borderColor] set];
    NSRectFill(NSMakeRect(self.bounds.size.width - 1, 0, 1, self.bounds.size.height));

    NSLayoutManager *lm = tv.layoutManager;
    NSTextContainer *tc = tv.textContainer;
    NSString *text = tv.string;
    NSRect visibleRect = tv.visibleRect;
    CGFloat inset = tv.textContainerInset.height;

    NSRange glyphRange = [lm glyphRangeForBoundingRect:visibleRect inTextContainer:tc];
    NSUInteger firstChar = [lm characterIndexForGlyphAtIndex:glyphRange.location];

    // Compute the line number of the first visible character.
    NSUInteger lineNumber = 1;
    for (NSUInteger i = 0; i < firstChar && i < text.length; i++) {
        if ([text characterAtIndex:i] == '\n') lineNumber++;
    }

    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [Theme lineNumberColor]
    };

    __block NSUInteger currentLine = lineNumber;
    CGFloat thickness = self.ruleThickness;

    [lm enumerateLineFragmentsForGlyphRange:glyphRange
                                 usingBlock:^(NSRect fragRect, NSRect usedRect, NSTextContainer *container,
                                              NSRange lineGlyphRange, BOOL *stop) {
        NSRange charR = [lm characterRangeForGlyphRange:lineGlyphRange actualGlyphRange:NULL];
        NSRange paraRange = [text lineRangeForRange:NSMakeRange(charR.location, 0)];
        BOOL isParagraphStart = (charR.location == paraRange.location);
        if (isParagraphStart) {
            CGFloat y = NSMinY(fragRect) + inset - NSMinY(visibleRect);
            NSString *num = [NSString stringWithFormat:@"%lu", (unsigned long)currentLine];
            NSSize sz = [num sizeWithAttributes:attrs];
            [num drawAtPoint:NSMakePoint(thickness - sz.width - 8, y + 1) withAttributes:attrs];
            currentLine++;
        }
    }];

    // Draw the number for a trailing empty line if present.
    if (text.length == 0 || [text characterAtIndex:text.length - 1] == '\n') {
        NSRect extra = [lm extraLineFragmentRect];
        CGFloat y = NSMinY(extra) + inset - NSMinY(visibleRect);
        NSString *num = [NSString stringWithFormat:@"%lu", (unsigned long)currentLine];
        NSSize sz = [num sizeWithAttributes:attrs];
        [num drawAtPoint:NSMakePoint(thickness - sz.width - 8, y + 1) withAttributes:attrs];
    }
}

@end
