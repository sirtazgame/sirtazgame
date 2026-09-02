#import <Cocoa/Cocoa.h>

// A single language grammar loaded from a JSON definition file.
@interface LanguageDefinition : NSObject
@property (copy) NSString *name;
@property (copy) NSArray<NSString *> *extensions;
@property (copy) NSArray<NSString *> *keywords;
@property (copy) NSArray<NSString *> *types;
@property (copy) NSArray<NSString *> *builtins;
@property (copy) NSString *lineComment;
@property (copy) NSString *blockCommentStart;
@property (copy) NSString *blockCommentEnd;
@property (copy) NSArray<NSString *> *stringDelimiters;
@property (assign) BOOL functionCalls;
@property (copy) NSArray<NSDictionary *> *rules;
@end

@interface SyntaxHighlighter : NSObject
+ (instancetype)shared;
- (LanguageDefinition *)languageForExtension:(NSString *)ext;
- (void)highlight:(NSTextStorage *)storage language:(LanguageDefinition *)lang;
@end
