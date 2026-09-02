#import "SyntaxHighlighter.h"
#import "Theme.h"

@implementation LanguageDefinition
@end

@implementation SyntaxHighlighter {
    NSMutableDictionary<NSString *, LanguageDefinition *> *_byExtension;
}

+ (instancetype)shared {
    static SyntaxHighlighter *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[SyntaxHighlighter alloc] init]; });
    return inst;
}

- (instancetype)init {
    if ((self = [super init])) {
        _byExtension = [NSMutableDictionary dictionary];
        [self loadLanguages];
    }
    return self;
}

- (void)loadLanguages {
    NSString *dir = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"languages"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *file in files) {
        if (![file.pathExtension isEqualToString:@"json"]) continue;
        NSString *full = [dir stringByAppendingPathComponent:file];
        NSData *data = [NSData dataWithContentsOfFile:full];
        if (!data) continue;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![dict isKindOfClass:[NSDictionary class]]) continue;

        LanguageDefinition *d = [LanguageDefinition new];
        d.name = dict[@"name"];
        d.extensions = dict[@"extensions"] ?: @[];
        d.keywords = dict[@"keywords"] ?: @[];
        d.types = dict[@"types"] ?: @[];
        d.builtins = dict[@"builtins"] ?: @[];
        d.lineComment = dict[@"lineComment"];
        d.blockCommentStart = dict[@"blockCommentStart"];
        d.blockCommentEnd = dict[@"blockCommentEnd"];
        d.stringDelimiters = dict[@"stringDelimiters"] ?: @[];
        d.functionCalls = [dict[@"functionCalls"] boolValue];
        d.autoNumbers = dict[@"numbers"] ? [dict[@"numbers"] boolValue] : YES;
        d.rules = dict[@"rules"] ?: @[];

        for (NSString *ext in d.extensions) {
            _byExtension[ext.lowercaseString] = d;
        }
    }
}

- (LanguageDefinition *)languageForExtension:(NSString *)ext {
    if (!ext.length) return nil;
    return _byExtension[ext.lowercaseString];
}

#pragma mark - Highlighting

- (void)applyPattern:(NSString *)pattern
               token:(NSString *)token
               group:(NSInteger)group
           multiline:(BOOL)multiline
             storage:(NSTextStorage *)storage
                text:(NSString *)text {
    if (!pattern.length) return;
    NSRegularExpressionOptions opts = 0;
    if (multiline) opts |= NSRegularExpressionAnchorsMatchLines;
    NSError *err = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                       options:opts
                                                                         error:&err];
    if (!re) return;
    NSColor *color = [Theme colorForToken:token];
    [re enumerateMatchesInString:text
                         options:0
                           range:NSMakeRange(0, text.length)
                      usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags flags, BOOL *stop) {
        NSRange r = (group >= 0 && group < (NSInteger)m.numberOfRanges) ? [m rangeAtIndex:group] : m.range;
        if (r.location != NSNotFound && NSMaxRange(r) <= text.length) {
            [storage addAttribute:NSForegroundColorAttributeName value:color range:r];
        }
    }];
}

- (void)applyWordList:(NSArray<NSString *> *)words
                token:(NSString *)token
              storage:(NSTextStorage *)storage
                 text:(NSString *)text {
    if (words.count == 0) return;
    NSMutableArray *escaped = [NSMutableArray array];
    for (NSString *w in words) {
        [escaped addObject:[NSRegularExpression escapedPatternForString:w]];
    }
    NSString *pattern = [NSString stringWithFormat:@"\\b(?:%@)\\b",
                         [escaped componentsJoinedByString:@"|"]];
    [self applyPattern:pattern token:token group:0 multiline:NO storage:storage text:text];
}

- (void)highlight:(NSTextStorage *)storage language:(LanguageDefinition *)lang {
    NSString *text = storage.string;
    NSRange full = NSMakeRange(0, text.length);

    [storage beginEditing];
    [storage addAttribute:NSForegroundColorAttributeName value:[Theme textColor] range:full];
    [storage addAttribute:NSFontAttributeName value:[Theme editorFont] range:full];

    if (lang) {
        // Custom rules first.
        for (NSDictionary *rule in lang.rules) {
            NSString *pattern = rule[@"pattern"];
            NSString *type = rule[@"type"] ?: @"keyword";
            NSInteger grp = rule[@"group"] ? [rule[@"group"] integerValue] : 0;
            BOOL ml = [rule[@"multiline"] boolValue];
            [self applyPattern:pattern token:type group:grp multiline:ml storage:storage text:text];
        }

        [self applyWordList:lang.keywords token:@"keyword" storage:storage text:text];
        [self applyWordList:lang.types token:@"type" storage:storage text:text];
        [self applyWordList:lang.builtins token:@"builtin" storage:storage text:text];

        if (lang.functionCalls) {
            [self applyPattern:@"\\b([A-Za-z_][A-Za-z0-9_]*)\\s*\\("
                         token:@"function" group:1 multiline:NO storage:storage text:text];
        }

        // Numbers.
        if (lang.autoNumbers) {
            [self applyPattern:@"\\b\\d+(?:\\.\\d+)?(?:[eE][-+]?\\d+)?\\b"
                         token:@"number" group:0 multiline:NO storage:storage text:text];
        }

        // Strings (override earlier tokens inside them).
        for (NSString *delim in lang.stringDelimiters) {
            NSString *d = [NSRegularExpression escapedPatternForString:delim];
            NSString *pattern = [NSString stringWithFormat:@"%@(?:\\\\.|[^%@\\\\\\n])*%@", d, d, d];
            [self applyPattern:pattern token:@"string" group:0 multiline:NO storage:storage text:text];
        }

        // Comments last so they always win.
        if (lang.lineComment.length) {
            NSString *lc = [NSRegularExpression escapedPatternForString:lang.lineComment];
            NSString *pattern = [NSString stringWithFormat:@"%@[^\\n]*", lc];
            [self applyPattern:pattern token:@"comment" group:0 multiline:NO storage:storage text:text];
        }
        if (lang.blockCommentStart.length && lang.blockCommentEnd.length) {
            NSString *s = [NSRegularExpression escapedPatternForString:lang.blockCommentStart];
            NSString *e = [NSRegularExpression escapedPatternForString:lang.blockCommentEnd];
            NSString *pattern = [NSString stringWithFormat:@"%@[\\s\\S]*?%@", s, e];
            [self applyPattern:pattern token:@"comment" group:0 multiline:NO storage:storage text:text];
        }
    }

    if ([lang.name isEqualToString:@"NPA"]) {
        [self applyNPA:storage text:text];
    }

    [storage endEditing];
}

- (NSColor *)npaColorFromString:(NSString *)raw {
    NSString *s = [[raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
    if (s.length == 0) return nil;
    if ([s hasPrefix:@"#"]) {
        NSString *hex = [s substringFromIndex:1];
        if (hex.length == 3) {
            NSString *r = [hex substringWithRange:NSMakeRange(0, 1)];
            NSString *g = [hex substringWithRange:NSMakeRange(1, 1)];
            NSString *b = [hex substringWithRange:NSMakeRange(2, 1)];
            hex = [NSString stringWithFormat:@"%@%@%@%@%@%@", r, r, g, g, b, b];
        }
        if (hex.length != 6) return nil;
        unsigned int val = 0;
        [[NSScanner scannerWithString:hex] scanHexInt:&val];
        return [NSColor colorWithSRGBRed:((val >> 16) & 0xff) / 255.0
                                   green:((val >> 8) & 0xff) / 255.0
                                    blue:(val & 0xff) / 255.0 alpha:1.0];
    }
    static NSDictionary *named = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        named = @{
            @"red": [NSColor colorWithSRGBRed:0.90 green:0.30 blue:0.30 alpha:1],
            @"green": [NSColor colorWithSRGBRed:0.40 green:0.80 blue:0.40 alpha:1],
            @"blue": [NSColor colorWithSRGBRed:0.35 green:0.60 blue:0.95 alpha:1],
            @"yellow": [NSColor colorWithSRGBRed:0.90 green:0.85 blue:0.35 alpha:1],
            @"cyan": [NSColor colorWithSRGBRed:0.35 green:0.82 blue:0.82 alpha:1],
            @"magenta": [NSColor colorWithSRGBRed:0.85 green:0.40 blue:0.80 alpha:1],
            @"orange": [NSColor colorWithSRGBRed:0.95 green:0.60 blue:0.25 alpha:1],
            @"purple": [NSColor colorWithSRGBRed:0.70 green:0.50 blue:0.90 alpha:1],
            @"pink": [NSColor colorWithSRGBRed:0.95 green:0.55 blue:0.75 alpha:1],
            @"brown": [NSColor colorWithSRGBRed:0.70 green:0.50 blue:0.35 alpha:1],
            @"gray": [NSColor colorWithSRGBRed:0.60 green:0.60 blue:0.60 alpha:1],
            @"grey": [NSColor colorWithSRGBRed:0.60 green:0.60 blue:0.60 alpha:1],
            @"white": [NSColor colorWithSRGBRed:0.92 green:0.92 blue:0.92 alpha:1],
            @"black": [NSColor colorWithSRGBRed:0.20 green:0.20 blue:0.20 alpha:1],
        };
    });
    return named[s];
}

- (void)npaParseLegendLine:(NSString *)line into:(NSMutableDictionary<NSString *, NSColor *> *)map {
    NSRange colon = [line rangeOfString:@":"];
    if (colon.location == NSNotFound) return;
    NSColor *col = [self npaColorFromString:[line substringToIndex:colon.location]];
    if (!col) return;
    NSString *tagsStr = [line substringFromIndex:colon.location + 1];
    for (NSString *raw in [tagsStr componentsSeparatedByString:@","]) {
        NSString *tag = [raw stringByReplacingOccurrencesOfString:@"[" withString:@""];
        tag = [tag stringByReplacingOccurrencesOfString:@"]" withString:@""];
        tag = [[tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
        if (tag.length) map[tag] = col;
    }
}

// Dynamic per-file NPA coloring: legend (`> ... <`) drives tag/data colors, and the
// script-set mode (numbers/binary/mix) styles the raw data values.
- (void)applyNPA:(NSTextStorage *)storage text:(NSString *)text {
    NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
    NSArray<NSString *> *lines = [text componentsSeparatedByString:@"\n"];

    // Parse legend region: first line starting with '>' to next line starting with '<'.
    NSMutableDictionary<NSString *, NSColor *> *tagColors = [NSMutableDictionary dictionary];
    NSInteger lstart = -1, lend = -1;
    for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
        NSString *t = [lines[i] stringByTrimmingCharactersInSet:ws];
        if (lstart < 0) { if ([t hasPrefix:@">"]) lstart = i; }
        else { if ([t hasPrefix:@"<"]) { lend = i; break; } }
    }
    if (lstart >= 0 && lend > lstart) {
        for (NSInteger i = lstart + 1; i < lend; i++) {
            [self npaParseLegendLine:lines[i] into:tagColors];
        }
    }

    NSColor *numColor = [Theme colorForToken:@"number"];
    NSColor *wordColor = [Theme colorForToken:@"type"];
    NSString *mode = [self.npaMode lowercaseString] ?: @"";

    NSRegularExpression *tagRe = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]" options:0 error:nil];
    NSRegularExpression *digitsRe = [NSRegularExpression regularExpressionWithPattern:@"\\d+" options:0 error:nil];
    NSRegularExpression *binRe = [NSRegularExpression regularExpressionWithPattern:@"[01]" options:0 error:nil];
    NSRegularExpression *wordRe = [NSRegularExpression regularExpressionWithPattern:@"[A-Za-z_][A-Za-z0-9_]*" options:0 error:nil];

    NSColor *active = nil;
    NSUInteger offset = 0;
    for (NSString *line in lines) {
        NSUInteger len = line.length;
        NSUInteger lineStart = offset;
        offset += len + 1;  // account for the '\n'

        NSString *t = [line stringByTrimmingCharactersInSet:ws];
        if (t.length == 0) { active = nil; continue; }
        unichar c0 = [t characterAtIndex:0];
        if ([t hasPrefix:@"##"] || c0 == '^' || c0 == '>' || c0 == '<') continue;

        if (c0 == '[') {
            // Marker line: apply legend colors to recognized tags, set active section color.
            __block NSColor *lineActive = nil;
            [tagRe enumerateMatchesInString:line options:0 range:NSMakeRange(0, len)
                                 usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags f, BOOL *stop) {
                NSString *name = [[line substringWithRange:[m rangeAtIndex:1]] uppercaseString];
                NSColor *col = tagColors[name];
                if (col) {
                    [storage addAttribute:NSForegroundColorAttributeName value:col
                                    range:NSMakeRange(lineStart + m.range.location, m.range.length)];
                    lineActive = col;
                }
            }];
            active = lineActive;
            continue;
        }

        // Data line.
        NSRange lineRange = NSMakeRange(lineStart, len);
        if (active) {
            NSUInteger a = 0; while (a < len && [ws characterIsMember:[line characterAtIndex:a]]) a++;
            NSUInteger b = len; while (b > a && [ws characterIsMember:[line characterAtIndex:b - 1]]) b--;
            if (b > a) [storage addAttribute:NSForegroundColorAttributeName value:active
                                       range:NSMakeRange(lineStart + a, b - a)];
        } else {
            void (^colorWith)(NSRegularExpression *, NSColor *) = ^(NSRegularExpression *re, NSColor *col) {
                [re enumerateMatchesInString:text options:0 range:lineRange
                                  usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags f, BOOL *stop) {
                    [storage addAttribute:NSForegroundColorAttributeName value:col range:m.range];
                }];
            };
            if ([mode isEqualToString:@"binary"]) {
                colorWith(binRe, numColor);
            } else if ([mode isEqualToString:@"mix"]) {
                colorWith(wordRe, wordColor);
                colorWith(digitsRe, numColor);
            } else {
                colorWith(digitsRe, numColor);
            }
        }
    }
}

@end
