#import "ScriptManager.h"
#import "ScriptRunner.h"

@implementation ScriptManager

+ (instancetype)shared {
    static ScriptManager *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[ScriptManager alloc] init]; });
    return inst;
}

- (NSURL *)scriptsDirectory {
    NSURL *support = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                            inDomain:NSUserDomainMask
                                                   appropriateForURL:nil
                                                              create:YES
                                                               error:nil];
    NSURL *dir = [[support URLByAppendingPathComponent:@"CleanEdit"]
                  URLByAppendingPathComponent:@"scripts"];
    return dir;
}

- (void)ensureScriptsInstalled {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *dir = self.scriptsDirectory;
    [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *bundled = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"scripts"];
    NSArray *files = [fm contentsOfDirectoryAtPath:bundled error:nil];
    for (NSString *file in files) {
        NSURL *dest = [dir URLByAppendingPathComponent:file];
        if (![fm fileExistsAtPath:dest.path]) {
            NSString *srcPath = [bundled stringByAppendingPathComponent:file];
            [fm copyItemAtPath:srcPath toPath:dest.path error:nil];
        }
    }
}

- (NSArray<NSURL *> *)availableScripts {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSURL *> *contents = [fm contentsOfDirectoryAtURL:self.scriptsDirectory
                                  includingPropertiesForKeys:nil
                                                     options:0
                                                       error:nil];
    NSMutableArray *result = [NSMutableArray array];
    for (NSURL *u in contents) {
        NSString *ext = u.pathExtension.lowercaseString;
        if ([u.lastPathComponent isEqualToString:@"cleanedit.py"]) continue;
        if ([ext isEqualToString:@"js"] || [ext isEqualToString:@"py"]) {
            [result addObject:u];
        }
    }
    [result sortUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        return [a.lastPathComponent caseInsensitiveCompare:b.lastPathComponent];
    }];
    return result;
}

- (void)runScriptAtURL:(NSURL *)url host:(id<EditorHost>)host {
    NSString *ext = url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"js"]) {
        [JSScriptRunner runScriptAtPath:url.path host:host];
    } else if ([ext isEqualToString:@"py"]) {
        [PythonScriptRunner runScriptAtPath:url.path
                                 scriptsDir:self.scriptsDirectory.path
                                       host:host];
    } else {
        [host appendConsole:@"Unsupported script type (use .js or .py)." type:@"error"];
    }
}

- (NSURL *)createNewScriptWithName:(NSString *)name {
    NSURL *url = [self.scriptsDirectory URLByAppendingPathComponent:name];
    NSString *ext = url.pathExtension.lowercaseString;
    NSString *template;
    if ([ext isEqualToString:@"py"]) {
        template = @"import cleanedit\n\n# Your script here.\ncleanedit.log(\"Hello from a new Python script!\")\n";
    } else {
        template = @"// Your script here.\neditor.log(\"Hello from a new JavaScript script!\");\n";
    }
    [template writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return url;
}

@end
