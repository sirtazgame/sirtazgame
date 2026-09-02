#import <Foundation/Foundation.h>

// Interface exposed to scripts (JavaScript and Python) so they can
// interact with the currently active editor document.
@protocol EditorHost <NSObject>
- (NSString *)editorText;
- (void)setEditorText:(NSString *)text;
- (NSString *)editorSelection;
- (void)replaceEditorSelection:(NSString *)text;
- (void)insertEditorText:(NSString *)text;
- (NSString *)currentFilePath;
- (NSInteger)editorLineCount;
- (void)appendConsole:(NSString *)text type:(NSString *)type;
@end
