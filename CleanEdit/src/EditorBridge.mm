#import "EditorBridge.h"

@implementation EditorBridge {
    __weak id<EditorHost> _host;
}

- (instancetype)initWithHost:(id<EditorHost>)host {
    if ((self = [super init])) {
        _host = host;
    }
    return self;
}

- (NSString *)getText { return [_host editorText] ?: @""; }

- (void)setText:(NSString *)text { [_host setEditorText:text ?: @""]; }

- (NSString *)getSelection { return [_host editorSelection] ?: @""; }

- (void)replaceSelection:(NSString *)text { [_host replaceEditorSelection:text ?: @""]; }

- (void)insertText:(NSString *)text { [_host insertEditorText:text ?: @""]; }

- (NSString *)getFilePath { return [_host currentFilePath] ?: @""; }

- (NSInteger)getLineCount { return [_host editorLineCount]; }

- (void)log:(NSString *)message {
    [_host appendConsole:message ?: @"" type:@"output"];
}

- (void)applyCommand:(NSDictionary *)cmd {
    NSString *action = cmd[@"action"];
    NSString *value = cmd[@"value"] ?: @"";
    if ([action isEqualToString:@"setText"]) {
        [self setText:value];
    } else if ([action isEqualToString:@"insertText"]) {
        [self insertText:value];
    } else if ([action isEqualToString:@"replaceSelection"]) {
        [self replaceSelection:value];
    } else if ([action isEqualToString:@"log"]) {
        [self log:value];
    }
}

@end
