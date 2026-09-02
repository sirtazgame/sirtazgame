#import "Theme.h"

static NSColor *hex(int r, int g, int b) {
    return [NSColor colorWithSRGBRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

@implementation Theme

+ (NSColor *)backgroundColor  { return hex(0x1e, 0x1e, 0x1e); }
+ (NSColor *)sidebarColor     { return hex(0x25, 0x25, 0x26); }
+ (NSColor *)activityBarColor { return hex(0x33, 0x33, 0x33); }
+ (NSColor *)panelColor       { return hex(0x1e, 0x1e, 0x1e); }
+ (NSColor *)tabActiveColor   { return hex(0x1e, 0x1e, 0x1e); }
+ (NSColor *)tabInactiveColor { return hex(0x2d, 0x2d, 0x2d); }
+ (NSColor *)textColor        { return hex(0xd4, 0xd4, 0xd4); }
+ (NSColor *)mutedTextColor   { return hex(0x85, 0x85, 0x85); }
+ (NSColor *)lineNumberColor  { return hex(0x6e, 0x6e, 0x6e); }
+ (NSColor *)accentColor      { return hex(0x00, 0x7a, 0xcc); }
+ (NSColor *)selectionColor   { return hex(0x26, 0x4f, 0x78); }
+ (NSColor *)borderColor      { return hex(0x18, 0x18, 0x18); }

+ (NSColor *)colorForToken:(NSString *)token {
    static NSDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            @"keyword":   hex(0x56, 0x9c, 0xd6),
            @"type":      hex(0x4e, 0xc9, 0xb0),
            @"builtin":   hex(0xdc, 0xdc, 0xaa),
            @"number":    hex(0xb5, 0xce, 0xa8),
            @"string":    hex(0xce, 0x91, 0x78),
            @"comment":   hex(0x6a, 0x99, 0x55),
            @"function":  hex(0xdc, 0xdc, 0xaa),
            @"heading":   hex(0x56, 0x9c, 0xd6),
            @"attribute": hex(0x9c, 0xdc, 0xfe),
            @"operator":  hex(0xd4, 0xd4, 0xd4),
            @"border":    hex(0x80, 0x80, 0x80),
            @"constant":  hex(0x56, 0x9c, 0xd6),
        };
    });
    NSColor *c = map[token];
    return c ?: [Theme textColor];
}

+ (NSColor *)consoleColorForType:(NSString *)type {
    if ([type isEqualToString:@"error"])   return hex(0xf4, 0x87, 0x71);
    if ([type isEqualToString:@"info"])    return hex(0x56, 0x9c, 0xd6);
    if ([type isEqualToString:@"success"]) return hex(0x6a, 0x99, 0x55);
    return [Theme textColor];
}

+ (NSFont *)editorFont {
    NSInteger size = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSize"];
    if (size <= 0) size = 13;
    NSString *name = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontName"];
    NSFont *f = name.length ? [NSFont fontWithName:name size:size] : nil;
    if (!f) f = [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightRegular];
    return f;
}

+ (NSFont *)uiFont     { return [NSFont systemFontOfSize:12]; }
+ (NSFont *)uiBoldFont { return [NSFont boldSystemFontOfSize:11]; }

@end
