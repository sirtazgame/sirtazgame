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
        [self applyPattern:@"\\b\\d+(?:\\.\\d+)?(?:[eE][-+]?\\d+)?\\b"
                     token:@"number" group:0 multiline:NO storage:storage text:text];

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

    [storage endEditing];
}

@end
