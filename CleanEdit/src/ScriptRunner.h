#import <Cocoa/Cocoa.h>
#import "EditorHost.h"

@interface JSScriptRunner : NSObject
+ (void)runScriptAtPath:(NSString *)path host:(id<EditorHost>)host;
@end

@interface PythonScriptRunner : NSObject
+ (void)runScriptAtPath:(NSString *)path
              scriptsDir:(NSString *)scriptsDir
                    host:(id<EditorHost>)host;
@end
