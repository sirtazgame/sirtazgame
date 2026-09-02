#import <Cocoa/Cocoa.h>

// Central dark theme palette and fonts for CleanEdit.
@interface Theme : NSObject
+ (NSColor *)backgroundColor;
+ (NSColor *)sidebarColor;
+ (NSColor *)activityBarColor;
+ (NSColor *)panelColor;
+ (NSColor *)tabActiveColor;
+ (NSColor *)tabInactiveColor;
+ (NSColor *)textColor;
+ (NSColor *)mutedTextColor;
+ (NSColor *)lineNumberColor;
+ (NSColor *)accentColor;
+ (NSColor *)selectionColor;
+ (NSColor *)borderColor;
+ (NSColor *)colorForToken:(NSString *)token;
+ (NSColor *)consoleColorForType:(NSString *)type;
+ (NSFont *)editorFont;
+ (NSFont *)uiFont;
+ (NSFont *)uiBoldFont;
@end
