#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "EditorHost.h"

// Methods exported into the JavaScript runtime as the global `editor` object.
@protocol EditorJSExport <JSExport>
- (NSString *)getText;
- (void)setText:(NSString *)text;
- (NSString *)getSelection;
- (void)replaceSelection:(NSString *)text;
- (void)insertText:(NSString *)text;
- (NSString *)getFilePath;
- (NSInteger)getLineCount;
- (void)log:(NSString *)message;
@end

@interface EditorBridge : NSObject <EditorJSExport>
- (instancetype)initWithHost:(id<EditorHost>)host;
// Applies a command dictionary produced by the Python bridge protocol.
- (void)applyCommand:(NSDictionary *)cmd;
@end
