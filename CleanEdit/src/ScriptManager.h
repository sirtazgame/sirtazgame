#import <Cocoa/Cocoa.h>
#import "EditorHost.h"

// Discovers, installs and runs user scripts (.js / .py).
@interface ScriptManager : NSObject
+ (instancetype)shared;
@property (readonly) NSURL *scriptsDirectory;
@property (readonly) NSURL *extensionsDirectory;
- (void)ensureScriptsInstalled;
- (void)runStartupExtensionsWithHost:(id<EditorHost>)host;
- (NSArray<NSURL *> *)availableScripts;
- (void)runScriptAtURL:(NSURL *)url host:(id<EditorHost>)host;
- (NSURL *)createNewScriptWithName:(NSString *)name;
@end
